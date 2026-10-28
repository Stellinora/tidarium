import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import/school_selection_page.dart';
import 'import/wakeup_school_selection_page.dart';
import 'io/ics_exporter.dart';
import 'io/ics_importer.dart';
import 'io/timetable_file_service.dart';
import 'timetable_providers.dart';
import 'timetable_time.dart';

class TimetableIoPage extends ConsumerWidget {
  const TimetableIoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('导入与导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(title: '教务系统', theme: theme),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('教务系统导入'),
              subtitle: const Text('从学校教务系统抓取课程表（拾光适配器）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SchoolSelectionPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('WakeUp 学校库'),
              subtitle: const Text('1,941 所学校 · 支持正方、青果、URP、超星'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WakeUpSchoolSelectionPage(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              'WakeUp / 星链分享码适配器在「通用工具与服务」中。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'ICS 日历', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('导出 ICS'),
                  subtitle: const Text('按周展开课程，可设置课前提醒'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportIcs(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('导入 ICS'),
                  subtitle: const Text('从 ICS 日历恢复课程表'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importIcs(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '教务系统适配器在 WebView 中运行，只能通过桥接保存课表数据，'
            '不会读取本地文件。导入会覆盖当前课程表，请先备份。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportIcs(BuildContext context, WidgetRef ref) async {
    final data = ref.read(timetableProvider);
    if (data.config.semesterStart == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('无法导出'),
          content: const Text('请先在课程表设置中填写学期开始日期。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final choice = await showDialog<_AlarmChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('导出 ICS'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('选择课程开始前的提醒时间'),
          ),
          for (final option in _alarmOptions)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_AlarmChoice(option.value)),
              child: Text(option.label),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    try {
      final export = buildIcsExport(data, alarmMinutes: choice.minutes);
      final eventCount = 'BEGIN:VEVENT'.allMatches(export.content).length;
      final sizeKb = utf8.encode(export.content).length / 1024;

      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ICS 已生成',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(export.fileName),
                Text(
                  '$eventCount 个课程事件 · ${sizeKb.toStringAsFixed(1)} KB',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final saved = await TimetableFileService.saveIcs(
                              content: export.content,
                              fileName: export.fileName,
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(saved ? 'ICS 已保存' : '已取消保存'),
                              ),
                            );
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('保存失败：$error')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存文件'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            await TimetableFileService.shareIcs(
                              content: export.content,
                              fileName: export.fileName,
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('分享失败：$error')),
                            );
                          }
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('分享'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  Future<void> _importIcs(BuildContext context, WidgetRef ref) async {
    String? content;
    try {
      content = await TimetableFileService.pickIcsContent();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('读取文件失败：$error')));
      return;
    }
    if (content == null || !context.mounted) return;

    final data = ref.read(timetableProvider);
    IcsImportPreview preview;
    try {
      preview = parseIcsImport(content, data: data);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('解析 ICS 失败：$error')));
      return;
    }

    if (preview.courses.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可导入的课程，请检查节次时间是否匹配')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入 ICS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '识别到 ${preview.courses.length} 门课程，'
                '${preview.matchedEventCount} 个事件匹配现有节次。',
              ),
              const SizedBox(height: 8),
              Text(
                '学期开始：${formatFullDate(preview.semesterStart)}'
                '${preview.usedInferredSemesterStart ? '（由文件推断）' : ''}',
              ),
              Text('总周数：${preview.totalWeeks}'),
              if (preview.skipped.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '有 ${preview.skipped.length} 个事件无法导入：',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
                for (final skipped in preview.skipped.take(4))
                  Text('• $skipped', style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 8),
              const Text('导入会覆盖当前课程表，节次设置保持不变。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('导入并覆盖'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var config = data.config.copyWith(
      semesterStart: preview.semesterStart,
      totalWeeks: preview.totalWeeks,
    );
    if (preview.courses.any((course) => course.day > 5)) {
      config = config.copyWith(showWeekends: true);
    }

    await ref
        .read(timetableProvider.notifier)
        .replaceSchedule(config: config, courses: preview.courses);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${preview.courses.length} 门课程')),
    );
  }
}

class _AlarmOption {
  const _AlarmOption(this.value, this.label);

  final int? value;
  final String label;
}

const _alarmOptions = [
  _AlarmOption(null, '无提醒'),
  _AlarmOption(0, '准时提醒'),
  _AlarmOption(5, '提前 5 分钟'),
  _AlarmOption(10, '提前 10 分钟'),
  _AlarmOption(15, '提前 15 分钟'),
  _AlarmOption(30, '提前 30 分钟'),
  _AlarmOption(60, '提前 60 分钟'),
];

class _AlarmChoice {
  const _AlarmChoice(this.minutes);

  final int? minutes;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
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
