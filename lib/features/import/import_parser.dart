import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_settings.dart';
import '../../core/ai/llm_client.dart';
import 'model/import_draft.dart';
import 'prompt.dart';

class ParseResult {
  const ParseResult({this.drafts = const [], this.error});

  const ParseResult.failure(String message) : this(error: message);

  final List<ImportDraft> drafts;
  final String? error;

  bool get isSuccess => error == null;
  bool get isEmpty => drafts.isEmpty;
}

/// 文本 → 草稿。只做抽取与校验，不写入任何存储。
class ImportParser {
  ImportParser({required this.client, AiQuota? quota})
    : quota = quota ?? AiQuota();

  static const int maxDrafts = 10;

  final LlmClient client;
  final AiQuota quota;

  Future<ParseResult> parseText({
    required String text,
    required AiSettings settings,
    required String? apiKey,
    String profileName = '当前课表',
    DateTime? now,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ParseResult.failure('没有可解析的文字');
    if (!settings.isReadyForText) {
      return const ParseResult.failure('未配置文本模型');
    }
    if (!quota.tryAcquire()) {
      return const ParseResult.failure('本次导入调用次数过多，请稍后再试');
    }

    try {
      final json = await client.completeText(
        settings: settings,
        apiKey: apiKey,
        prompt: buildExtractPrompt(
          text: trimmed,
          today: now ?? DateTime.now(),
          profileName: profileName,
        ),
        schema: const {
          'type': 'object',
          'properties': {
            'items': {'type': 'array'},
          },
        },
      );
      return ParseResult(drafts: _toDrafts(json));
    } on LlmException catch (error) {
      return ParseResult.failure(error.message);
    } catch (_) {
      return const ParseResult.failure('解析失败，请重试');
    }
  }

  List<ImportDraft> _toDrafts(Map<String, Object?> json) {
    final rawItems = json['items'];
    if (rawItems is! List) return const [];

    final drafts = <ImportDraft>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final draft = ImportDraft.fromJson(
        raw.cast<String, Object?>(),
        id: newDraftId(),
      );
      if (draft.title.isEmpty) continue;
      drafts.add(draft);
      if (drafts.length >= maxDrafts) break;
    }
    return List.unmodifiable(drafts);
  }
}
