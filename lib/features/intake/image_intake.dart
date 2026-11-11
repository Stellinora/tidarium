import 'dart:typed_data';

/// 图片进入 App 的渠道。本期只开放系统分享，其余保留给调试入口。
enum ImageOrigin { systemShare, gallery, camera, paste }

extension ImageOriginLabel on ImageOrigin {
  String get label {
    return switch (this) {
      ImageOrigin.systemShare => '系统分享',
      ImageOrigin.gallery => '相册选择',
      ImageOrigin.camera => '相机拍摄',
      ImageOrigin.paste => '剪贴板',
    };
  }
}

/// 一次导入中单张图片的载体。字节已经在内存里，cachedPath 指向临时副本。
class ImageIntake {
  const ImageIntake({
    required this.origin,
    required this.bytes,
    required this.mimeType,
    required this.receivedAt,
    this.fileName = '',
    this.cachedPath,
  });

  final ImageOrigin origin;
  final Uint8List bytes;
  final String mimeType;
  final DateTime receivedAt;
  final String fileName;
  final String? cachedPath;

  int get byteSize => bytes.length;

  String get sizeLabel {
    final size = byteSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 一次分享事件产生的这一批图片。
class IntakeBatch {
  const IntakeBatch({
    required this.items,
    required this.receivedAt,
    this.dropped = 0,
  });

  final List<ImageIntake> items;
  final DateTime receivedAt;

  /// 超过上限被丢弃的张数。
  final int dropped;

  bool get isEmpty => items.isEmpty;
}
