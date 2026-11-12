import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_settings.dart';
import '../../core/ai/image_prep.dart';
import '../../core/ai/llm_client.dart';
import '../intake/image_intake.dart';
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

  Future<ParseResult> parseImage({
    required ImageIntake intake,
    required AiSettings settings,
    required String? apiKey,
    String profileName = '当前课表',
    DateTime? now,
  }) async {
    if (!settings.isReadyForVision) {
      return const ParseResult.failure('未配置视觉模型');
    }
    if (!quota.tryAcquire()) {
      return const ParseResult.failure('本次导入调用次数过多，请稍后再试');
    }

    final shrunk = ImagePrep.shrink(intake.bytes);
    final bytes = shrunk ?? intake.bytes;
    final mime = shrunk != null ? 'image/jpeg' : intake.mimeType;

    String text;
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

    return parser.parseText(
      text: text,
      settings: settings,
      apiKey: apiKey,
      profileName: profileName,
      now: now,
    );
  }
}

