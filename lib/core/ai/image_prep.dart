import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 送进模型前的图片处理：按长边缩放、转 JPEG。
/// 统一走这里，OCR 与多模态两条通路共用同一份参数。
class ImagePrep {
  const ImagePrep._();

  static const int defaultMaxEdge = 1600;
  static const int defaultQuality = 85;

  static Uint8List? shrink(
    Uint8List bytes, {
    int maxEdge = defaultMaxEdge,
    int quality = defaultQuality,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final longEdge = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      var image = decoded;
      if (longEdge > maxEdge) {
        final scale = maxEdge / longEdge;
        image = img.copyResize(
          decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (_) {
      return null;
    }
  }

  /// 识别图片格式，给 data URL 用。
  static String mimeOf(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
