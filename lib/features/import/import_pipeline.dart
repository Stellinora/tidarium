import 'dart:convert';

import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_settings.dart';
import '../../core/ai/image_prep.dart';
import '../../core/ai/llm_client.dart';
import '../intake/image_intake.dart';
import '../owners/model/owner.dart';
import 'import_parser.dart';
import 'prompt.dart';

/// 图片 → 文字 → 草稿。两段式：先 OCR，再由文本模型抽取。
class ImportPipeline {
  ImportPipeline({
    required this.client,
    required this.parser,
    AiQuota? quota,
  }) : quota = quota ?? AiQuota();

  final LlmClient client;
  final ImportParser parser;
  final AiQuota quota;

  /// 同一张图重复导入时直接复用 OCR 文本（仅本次进程内）。
  static final Map<int, String> _ocrCache = {};

  static void clearCache() => _ocrCache.clear();

  Future<ParseResult> parseImage({
    required ImageIntake intake,
    required AiSettings settings,
    required String? apiKey,
    String profileName = '当前课表',
    DateTime? now,
    List<Owner> owners = const [],
  }) async {
    if (!settings.isReadyForVision) {
      return const ParseResult.failure('未配置视觉模型');
    }

    final started = DateTime.now();
    final shrunk = ImagePrep.shrink(intake.bytes);
    final bytes = shrunk ?? intake.bytes;
    final mime = shrunk != null ? 'image/jpeg' : intake.mimeType;

    String text;
    final signature = '${settings.normalizedBaseUrl}|${settings.visionModel}';
    final cacheKey = _hash(bytes) ^ _hash(utf8.encode(signature));
    final cached = _ocrCache[cacheKey];
    if (cached != null && cached.trim().isNotEmpty) {
      text = cached;
    } else {
      if (!quota.tryAcquire()) {
        return const ParseResult.failure('本次导入调用次数过多，请稍后再试');
      }
      try {
        text = await client.completeVision(
          settings: settings,
          apiKey: apiKey,
          image: bytes,
          mimeType: mime,
          prompt: buildOcrPrompt(),
        );
      } on LlmException catch (error) {
        return ParseResult.failure(error.message);
      } catch (_) {
        return const ParseResult.failure('图片识别失败');
      }
      if (text.trim().isEmpty) {
        return const ParseResult.failure('没有从图片里识别出文字');
      }
      _ocrCache[cacheKey] = text;
    }

    final result = await parser.parseText(
      text: text,
      settings: settings,
      apiKey: apiKey,
      profileName: profileName,
      now: now,
      owners: owners,
    );

    if (!result.isSuccess) return result;
    return ParseResult(
      drafts: result.drafts,
      elapsed: DateTime.now().difference(started),
    );
  }

  static int _hash(List<int> bytes) {
    var hash = 0x811c9dc5;
    final limit = bytes.length < 8192 ? bytes.length : 8192;
    for (var i = 0; i < limit; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    hash ^= bytes.length;
    return hash & 0xffffffff;
  }
}



