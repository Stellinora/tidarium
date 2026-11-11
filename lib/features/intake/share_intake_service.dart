import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'image_intake.dart';

/// 接收系统分享进来的图片。
///
/// 只处理图片类型；不申请存储权限，分享进来的 content URI 由插件转成本地文件路径。
/// 处理完必须 reset，否则同一个 intent 会重复投递。
class ShareIntakeService {
  ShareIntakeService();

  static const int maxImages = 3;

  final StreamController<IntakeBatch> _controller =
      StreamController<IntakeBatch>.broadcast();
  final List<int> _recentHashes = <int>[];

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  bool _started = false;

  Stream<IntakeBatch> get stream => _controller.stream;

  /// 监听 App 存活期间收到的分享。
  void start() {
    if (_started) return;
    _started = true;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        unawaited(_handle(files));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('intake: stream error: $error');
      },
    );
  }

  /// 处理 App 被分享拉起（冷启动）时携带的图片。
  Future<IntakeBatch?> readInitial() async {
    try {
      final files = await ReceiveSharingIntent.instance.getInitialMedia();
      debugPrint('intake: initial media count=${files.length}');
      if (files.isEmpty) return null;
      return await _handle(files);
    } catch (error) {
      debugPrint('intake: initial media failed: $error');
      return null;
    }
  }

  Future<IntakeBatch> _handle(List<SharedMediaFile> files) async {
    final images = files
        .where((file) => file.type == SharedMediaType.image)
        .toList(growable: false);
    final dropped = images.length > maxImages ? images.length - maxImages : 0;
    final selected = images.take(maxImages);

    final items = <ImageIntake>[];
    for (final file in selected) {
      final intake = await _read(file);
      if (intake != null) items.add(intake);
    }

    // 处理完再 reset，防止同一次分享被重复消费。
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (error) {
      debugPrint('intake: reset failed: $error');
    }

    final batch = IntakeBatch(
      items: List<ImageIntake>.unmodifiable(items),
      dropped: dropped,
      receivedAt: DateTime.now(),
    );
    if (!batch.isEmpty) _controller.add(batch);
    return batch;
  }

  Future<ImageIntake?> _read(SharedMediaFile file) async {
    try {
      final source = File(file.path);
      if (!await source.exists()) {
        debugPrint('intake: file missing: ${file.path}');
        return null;
      }
      final bytes = await source.readAsBytes();
      if (bytes.isEmpty) return null;

      final hash = _fnv1a32(bytes);
      if (_recentHashes.contains(hash)) {
        debugPrint('intake: duplicate ignored');
        return null;
      }
      _recentHashes.add(hash);
      if (_recentHashes.length > 16) _recentHashes.removeAt(0);

      final mime = _mimeOf(file);
      final cachedPath = await _cache(bytes, hash, mime);

      return ImageIntake(
        origin: ImageOrigin.systemShare,
        bytes: bytes,
        mimeType: mime,
        receivedAt: DateTime.now(),
        fileName: file.path.split(Platform.pathSeparator).last,
        cachedPath: cachedPath,
      );
    } catch (error) {
      debugPrint('intake: read failed: $error');
      return null;
    }
  }

  Future<String?> _cache(List<int> bytes, int hash, String mime) async {
    try {
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}intake',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}${Platform.pathSeparator}$hash${_extOf(mime)}';
      await File(path).writeAsBytes(bytes, flush: false);
      return path;
    } catch (error) {
      debugPrint('intake: cache failed: $error');
      return null;
    }
  }

  String _mimeOf(SharedMediaFile file) {
    final declared = file.mimeType?.trim() ?? '';
    if (declared.startsWith('image/')) return declared;
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String _extOf(String mime) {
    return switch (mime) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/heic' => '.heic',
      _ => '.jpg',
    };
  }

  /// 取前 8KB 做一次 FNV-1a，够区分截图，避免整图哈希的开销。
  int _fnv1a32(List<int> bytes) {
    var hash = 0x811c9dc5;
    final limit = bytes.length < 8192 ? bytes.length : 8192;
    for (var i = 0; i < limit; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    hash ^= bytes.length;
    return hash & 0xffffffff;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    await _controller.close();
  }
}
