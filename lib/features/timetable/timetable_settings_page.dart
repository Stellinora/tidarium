import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model/timetable_config.dart';
import 'time_slot_settings_page.dart';
import 'timetable_io_page.dart';
import 'timetable_manager_page.dart';
import 'timetable_providers.dart';
import 'timetable_time.dart';

class TimetableSettingsPage extends ConsumerWidget {
  const TimetableSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(timetableProvider);
    final config = data.config;
    final controller = ref.read(timetableLibraryProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('课表设置')),
      body: ListView(
        children: [
          _SectionHeader(title: '课表', theme: theme),
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: const Text('课表管理'),
            subtitle: Text(
              '当前：${config.name} · 共 ${ref.watch(timetableLibraryProvider).timetables.length} 个课表',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TimetableManagerPage(),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(title: '学期', theme: theme),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('当前课表名称'),
            subtitle: Text(config.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _renameTable(context, ref, config),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('学期开始日期'),
            subtitle: Text(
              config.semesterStart == null
                  ? '未设置'
                  : formatFullDate(config.semesterStart!),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSemesterStart(context, ref, config),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('学期总周数'),
            trailing: DropdownButton<int>(
              value: config.totalWeeks,
              underline: const SizedBox.shrink(),
              items: _weekOptions(config.totalWeeks),
              onChanged: (value) {
                if (value == null) return;
                controller.updateConfig(config.copyWith(totalWeeks: value));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.first_page_outlined),
            title: const Text('每周起始日'),
            trailing: DropdownButton<int>(
              value: config.firstWeekday,
              underline: const SizedBox.shrink(),
              items: [
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(value: day, child: Text(weekdayName(day))),
              ],
              onChanged: (value) {
                if (value == null) return;
                controller.updateConfig(config.copyWith(firstWeekday: value));
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.weekend_outlined),
            title: const Text('显示周末'),
            value: config.showWeekends,
            onChanged: (value) {
              controller.updateConfig(config.copyWith(showWeekends: value));
            },
          ),
          const Divider(),
          _SectionHeader(title: '作息时间', theme: theme),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('作息时间与默认时长'),
            subtitle: Text('共 ${data.timeSlots.length} 个时间段 · 可新增、删除、调整时间'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TimeSlotSettingsPage(),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(title: '导入与导出', theme: theme),
          ListTile(
            leading: const Icon(Icons.swap_vert_circle_outlined),
            title: const Text('课表导入与导出'),
            subtitle: const Text('教务系统、ICS 导入/导出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TimetableIoPage()),
            ),
          ),
          const Divider(),
          _SectionHeader(title: '维护', theme: theme),
          ListTile(
            leading: Icon(
              Icons.delete_sweep_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              '清空全部课程',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text('当前共 ${data.courses.length} 门课程'),
            onTap: () => _clearCourses(context, ref),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              '课表数据保存在本机应用目录，不会上传到服务器。'
              '删除应用数据会一并清除所有课表。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _weekOptions(int current) {
    final weeks = {
      for (var week = 1; week <= 52; week++) week,
      current,
    }.toList()..sort();
    return [
      for (final week in weeks)
        DropdownMenuItem(value: week, child: Text('$week 周')),
    ];
  }

  Future<void> _renameTable(
    BuildContext context,
    WidgetRef ref,
    TimetableConfig config,
  ) async {
    final controller = TextEditingController(text: config.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('当前课表名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !context.mounted) return;
    await ref
        .read(timetableLibraryProvider.notifier)
        .updateConfig(config.copyWith(name: name));
  }

  Future<void> _pickSemesterStart(
    BuildContext context,
    WidgetRef ref,
    TimetableConfig config,
  ) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: config.semesterStart ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择学期开始日期',
    );
    if (picked == null || !context.mounted) return;

    await ref
        .read(timetableLibraryProvider.notifier)
        .updateConfig(config.copyWith(semesterStart: dateOnly(picked)));
  }

  Future<void> _clearCourses(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部课程'),
        content: const Text('确定删除当前课表中的全部课程吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(timetableLibraryProvider.notifier).clearCourses();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('课程已清空')));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
