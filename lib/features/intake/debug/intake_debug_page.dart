import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../image_intake.dart';

/// 仅用于开发期验证分享入口，release 不会进入这个页面。
class IntakeDebugPage extends StatefulWidget {
  const IntakeDebugPage({super.key, required this.batch});

  final IntakeBatch batch;

  @override
  State<IntakeDebugPage> createState() => _IntakeDebugPageState();
}

class _IntakeDebugPageState extends State<IntakeDebugPage> {
  late List<ImageIntake> _items = List<ImageIntake>.of(widget.batch.items);

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    final added = <ImageIntake>[];
    for (final file in picked.take(3)) {
      final Uint8List bytes = await file.readAsBytes();
      added.add(
        ImageIntake(
          origin: ImageOrigin.gallery,
          bytes: bytes,
          mimeType: file.mimeType ?? _guessMime(file.name),
          receivedAt: DateTime.now(),
          fileName: file.name,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _items = [..._items, ...added].take(3).toList());
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropped = widget.batch.dropped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入接收（调试）'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '从相册选择',
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '走系统分享进入这里：截屏 → 分享 → 时匣。\n'
                '冷启动与热启动都会落到本页，收到 ${_items.length} 张'
                '${dropped > 0 ? '，另有 $dropped 张超出上限被忽略' : ''}。',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('没有收到图片')),
            )
          else
            for (final item in _items) _IntakeTile(item: item),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _IntakeTile extends StatelessWidget {
  const _IntakeTile({required this.item});

  final ImageIntake item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                item.bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName.isEmpty ? '未命名图片' : item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.mimeType} · ${item.sizeLabel}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '来源：${item.origin.label} · '
                    '${_formatTime(item.receivedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.cachedPath != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '缓存：${item.cachedPath!.split('\\').last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
