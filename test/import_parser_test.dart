import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/ai/ai_gateway.dart';
import 'package:tidarium/core/ai/ai_settings.dart';
import 'package:tidarium/core/ai/llm_client.dart';
import 'package:tidarium/features/import/import_parser.dart';
import 'package:tidarium/features/import/import_pipeline.dart';
import 'package:tidarium/features/intake/image_intake.dart';
import 'package:tidarium/features/owners/model/owner.dart';

class _FakeClient implements LlmClient {
  _FakeClient({
    this.textJson,
    this.visionText = '识别出的通知文字',
    this.textError,
    this.visionError,
  });

  final Map<String, Object?>? textJson;
  final String visionText;
  final String? textError;
  final String? visionError;

  int textCalls = 0;
  int visionCalls = 0;

  @override
  Future<Map<String, Object?>> completeText({
    required AiSettings settings,
    required String? apiKey,
    required String prompt,
    Map<String, Object?>? schema,
  }) async {
    textCalls += 1;
    if (textError != null) throw LlmException(textError!);
    return textJson ?? const {};
  }

  @override
  Future<String> completeVision({
    required AiSettings settings,
    required String? apiKey,
    required Uint8List image,
    required String prompt,
  }) async {
    visionCalls += 1;
    if (visionError != null) throw LlmException(visionError!);
    return visionText;
  }
}

const _settings = AiSettings(
  baseUrl: 'https://api.example.com/v1',
  textModel: 'text-model',
  visionModel: 'vision-model',
);

ImageIntake _image() {
  return ImageIntake(
    origin: ImageOrigin.systemShare,
    bytes: Uint8List.fromList(const [1, 2, 3]),
    mimeType: 'image/png',
    receivedAt: DateTime(2026, 11, 10),
  );
}

void main() {
  group('ImportParser', () {
    test('解析出多条草稿，缺时间的标记待补', () async {
      final client = _FakeClient(
        textJson: {
          'items': [
            {
              'title': '  提交英语计划书 ',
              'type': 'course',
              'dueAt': '2026-11-20T23:59:00',
              'materials': ['计划书', '海报'],
              'confidence': 0.9,
            },
            {
              'title': '心理作业',
              'type': 'other',
              'dueAt': null,
              'materials': [],
              'confidence': 0.4,
            },
          ],
        },
      );
      final parser = ImportParser(client: client, quota: AiQuota());

      final result = await parser.parseText(
        text: '两条通知',
        settings: _settings,
        apiKey: 'k',
        now: DateTime(2026, 11, 10),
      );

      expect(result.isSuccess, isTrue);
      expect(result.drafts, hasLength(2));
      expect(result.drafts.first.title, '提交英语计划书');
      expect(result.drafts.first.kind, OwnerKind.course);
      expect(result.drafts.first.materials, ['计划书', '海报']);
      expect(result.drafts.first.needsTime, isFalse);
      expect(result.drafts.last.needsTime, isTrue);
      expect(result.drafts.last.warnings, contains('时间待补'));
      expect(result.drafts.last.isLowConfidence, isTrue);
    });

    test('空标题被丢弃，最多保留 10 条', () async {
      final items = List.generate(
        12,
        (index) => {'title': '任务 $index', 'dueAt': null},
      );
      items.insert(0, {'title': '   '});
      final client = _FakeClient(textJson: {'items': items});
      final parser = ImportParser(client: client);

      final result = await parser.parseText(
        text: '很多通知',
        settings: _settings,
        apiKey: null,
      );

      expect(result.drafts, hasLength(10));
      expect(result.drafts.every((draft) => draft.title.isNotEmpty), isTrue);
    });

    test('未配置文本模型时不调用模型', () async {
      final client = _FakeClient(textJson: const {'items': []});
      final parser = ImportParser(client: client);

      final result = await parser.parseText(
        text: '通知',
        settings: const AiSettings(baseUrl: 'https://x/v1'),
        apiKey: null,
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('未配置文本模型'));
      expect(client.textCalls, 0);
    });

    test('模型异常会转成可读错误', () async {
      final client = _FakeClient(textError: 'Key 无效或无权限');
      final parser = ImportParser(client: client);

      final result = await parser.parseText(
        text: '通知',
        settings: _settings,
        apiKey: 'bad',
      );

      expect(result.error, 'Key 无效或无权限');
    });

    test('配额用尽后不再调用', () async {
      final client = _FakeClient(textJson: const {'items': []});
      final parser = ImportParser(
        client: client,
        quota: AiQuota(maxCallsPerRun: 1),
      );

      await parser.parseText(text: 'a', settings: _settings, apiKey: null);
      final second = await parser.parseText(
        text: 'b',
        settings: _settings,
        apiKey: null,
      );

      expect(second.error, contains('调用次数过多'));
      expect(client.textCalls, 1);
    });
  });

  group('ImportPipeline', () {
    test('先视觉后文本，两段式调用', () async {
      final client = _FakeClient(
        visionText: '11月20日前提交英语计划书',
        textJson: {
          'items': [
            {
              'title': '提交英语计划书',
              'type': 'course',
              'dueAt': '2026-11-20T23:59:00',
            },
          ],
        },
      );
      final parser = ImportParser(client: client);
      final pipeline = ImportPipeline(client: client, parser: parser);

      final result = await pipeline.parseImage(
        intake: _image(),
        settings: _settings,
        apiKey: 'k',
        now: DateTime(2026, 11, 10),
      );

      expect(result.isSuccess, isTrue);
      expect(result.drafts.single.title, '提交英语计划书');
      expect(client.visionCalls, 1);
      expect(client.textCalls, 1);
    });

    test('未配置视觉模型时直接失败', () async {
      final client = _FakeClient();
      final parser = ImportParser(client: client);
      final pipeline = ImportPipeline(client: client, parser: parser);

      final result = await pipeline.parseImage(
        intake: _image(),
        settings: const AiSettings(baseUrl: 'https://x/v1', textModel: 'm'),
        apiKey: null,
      );

      expect(result.error, contains('未配置视觉模型'));
      expect(client.visionCalls, 0);
    });

    test('识别结果为空时不进入抽取', () async {
      final client = _FakeClient(visionText: '   ');
      final parser = ImportParser(client: client);
      final pipeline = ImportPipeline(client: client, parser: parser);

      final result = await pipeline.parseImage(
        intake: _image(),
        settings: _settings,
        apiKey: null,
      );

      expect(result.error, contains('没有从图片里识别出文字'));
      expect(client.textCalls, 0);
    });

    test('视觉调用异常会转成可读错误', () async {
      final client = _FakeClient(visionError: 'Key 无效或无权限');
      final parser = ImportParser(client: client);
      final pipeline = ImportPipeline(client: client, parser: parser);

      final result = await pipeline.parseImage(
        intake: _image(),
        settings: _settings,
        apiKey: 'bad',
      );

      expect(result.error, 'Key 无效或无权限');
      expect(client.textCalls, 0);
    });
  });
}
