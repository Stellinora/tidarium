import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// 端上 OCR：不联网、不需要 API Key。
/// 仅 Android / iOS 可用；桌面与测试环境返回 null。
class LocalOcrEngine {
  const LocalOcrEngine();

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<String?> recognize(Uint8List bytes) async {
    if (!isSupported || bytes.isEmpty) return null;

    File? temp;
    TextRecognizer? recognizer;
    try {
      final dir = await getTemporaryDirectory();
      temp = File('${dir.path}${Platform.pathSeparator}ocr_local.jpg');
      await temp.writeAsBytes(bytes, flush: false);

      recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final input = InputImage.fromFilePath(temp.path);
      final result = await recognizer.processImage(input);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      await recognizer?.close();
      try {
        await temp?.delete();
      } catch (_) {
        // 临时文件清理失败不影响结果。
      }
    }
  }
}
