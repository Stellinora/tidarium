import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tidarium/core/ai/image_prep.dart';

void main() {
  test('按长边缩放并转成 JPEG', () {
    final source = img.Image(width: 2000, height: 1000);
    img.fill(source, color: img.ColorRgb8(200, 40, 40));
    final png = Uint8List.fromList(img.encodePng(source));

    final shrunk = ImagePrep.shrink(png, maxEdge: 1600);
    expect(shrunk, isNotNull);

    final decoded = img.decodeImage(shrunk!)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(ImagePrep.mimeOf(shrunk), 'image/jpeg');
  });

  test('小图不放大', () {
    final source = img.Image(width: 400, height: 300);
    final png = Uint8List.fromList(img.encodePng(source));

    final processed = ImagePrep.shrink(png, maxEdge: 1600)!;
    final decoded = img.decodeImage(processed)!;
    expect(decoded.width, 400);
    expect(decoded.height, 300);
  });

  test('无法解码时返回 null', () {
    expect(ImagePrep.shrink(Uint8List.fromList([1, 2, 3])), isNull);
  });

  testWidgets('两张样例图随包提供且可解码', (tester) async {
    for (final path in const [
      'assets/diagnostics/ocr_sample.jpg',
      'assets/diagnostics/vision_sample.jpg',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1024));
      final bytes = data.buffer.asUint8List();
      expect(img.decodeImage(bytes), isNotNull);
      expect(ImagePrep.shrink(bytes), isNotNull);
    }
  });

  test('识别常见图片头', () {
    expect(
      ImagePrep.mimeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      'image/jpeg',
    );
    expect(
      ImagePrep.mimeOf(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      'image/png',
    );
  });
}


