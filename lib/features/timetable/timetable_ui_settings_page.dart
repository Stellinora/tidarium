import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'model/timetable_config.dart';
import 'timetable_providers.dart';

class TimetableUiSettingsPage extends ConsumerStatefulWidget {
  const TimetableUiSettingsPage({super.key});

  @override
  ConsumerState<TimetableUiSettingsPage> createState() =>
      _TimetableUiSettingsPageState();
}

class _TimetableUiSettingsPageState
    extends ConsumerState<TimetableUiSettingsPage> {
  var _pickingImage = false;

  void _update(TimetableConfig Function(TimetableConfig config) update) {
    final current = ref.read(timetableProvider).config;
    ref.read(timetableLibraryProvider.notifier).updateConfig(update(current));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(timetableProvider).config;

    return Scaffold(
      appBar: AppBar(title: const Text('界面设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(title: '字体大小', theme: theme),
          _FontSlider(
            label: '课程名称',
            value: config.courseNameFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(courseNameFontSize: value)),
          ),
          _FontSlider(
            label: '教师 / 地点',
            value: config.courseInfoFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(courseInfoFontSize: value)),
          ),
          _FontSlider(
            label: '节次标签',
            value: config.sectionLabelFontSize,
            onChanged: (value) => _update(
              (config) => config.copyWith(sectionLabelFontSize: value),
            ),
          ),
          _FontSlider(
            label: '星期标题',
            value: config.weekdayHeaderFontSize,
            onChanged: (value) => _update(
              (config) => config.copyWith(weekdayHeaderFontSize: value),
            ),
          ),
          _FontSlider(
            label: '日期',
            value: config.dateFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(dateFontSize: value)),
          ),
          _FontSlider(
            label: '节次数字',
            value: config.timeSlotFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(timeSlotFontSize: value)),
          ),
          _FontSlider(
            label: '时间文字',
            value: config.timeTextFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(timeTextFontSize: value)),
          ),
          _FontSlider(
            label: '顶部周次',
            value: config.weekTitleFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(weekTitleFontSize: value)),
          ),
          _FontSlider(
            label: '提示文字',
            value: config.hintFontSize,
            onChanged: (value) =>
                _update((config) => config.copyWith(hintFontSize: value)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _update(
                (config) => config.copyWith(
                  courseNameFontSize: 12,
                  courseInfoFontSize: 9.5,
                  sectionLabelFontSize: 9,
                  weekdayHeaderFontSize: 14,
                  dateFontSize: 10,
                  timeSlotFontSize: 11,
                  timeTextFontSize: 9,
                  weekTitleFontSize: 16,
                  hintFontSize: 12,
                ),
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('恢复默认字体'),
            ),
          ),
          const Divider(),
          _SectionHeader(title: '背景', theme: theme),
          if (config.backgroundImagePath != null)
            _BackgroundPreview(path: config.backgroundImagePath!),
          if (config.backgroundImagePath != null)
            _FontSlider(
              label: '背景可见度',
              value: config.backgroundImageOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (value) => _update(
                (config) => config.copyWith(backgroundImageOpacity: value),
              ),
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _pickingImage ? null : _pickBackground,
            icon: _pickingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: Text(config.backgroundImagePath == null ? '选择背景图' : '更换背景图'),
          ),
          if (config.backgroundImagePath != null)
            TextButton.icon(
              onPressed: _removeBackground,
              icon: const Icon(Icons.delete_outline),
              label: const Text('移除背景图'),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '背景图只作用于当前课表，保存在本机应用目录。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBackground() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;

      final directory = await getApplicationSupportDirectory();
      final extension = _extensionOf(picked.name);
      final target = File(
        '${directory.path}${Platform.pathSeparator}'
        'timetable_background_${DateTime.now().microsecondsSinceEpoch}'
        '$extension',
      );
      await File(picked.path).copy(target.path);
      if (!mounted) return;

      final oldPath = ref.read(timetableProvider).config.backgroundImagePath;
      await ref
          .read(timetableLibraryProvider.notifier)
          .updateConfig(
            ref
                .read(timetableProvider)
                .config
                .copyWith(backgroundImagePath: target.path),
          );
      if (oldPath != null && oldPath != target.path) {
        await _deleteQuietly(oldPath);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('选择背景图失败：$error');
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _removeBackground() async {
    final path = ref.read(timetableProvider).config.backgroundImagePath;
    await ref
        .read(timetableLibraryProvider.notifier)
        .updateConfig(
          ref
              .read(timetableProvider)
              .config
              .copyWith(clearBackgroundImage: true),
        );
    if (path != null) await _deleteQuietly(path);
    if (mounted) _showMessage('已移除背景图');
  }

  String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    return index < 0 ? '.jpg' : name.substring(index);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The old image may already be gone.
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FontSlider extends StatelessWidget {
  const _FontSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 7,
    this.max = 24,
    this.divisions = 34,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              safeValue.toStringAsFixed(1),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: safeValue,
          min: min,
          max: max,
          divisions: divisions,
          label: safeValue.toStringAsFixed(1),
          onChanged: (value) =>
              onChanged(divisions <= 20 ? value : value.roundToDouble()),
        ),
      ],
    );
  }
}

class _BackgroundPreview extends StatelessWidget {
  const _BackgroundPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('背景图文件不存在')),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
