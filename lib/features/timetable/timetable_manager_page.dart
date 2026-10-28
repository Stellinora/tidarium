import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model/timetable_data.dart';
import 'model/timetable_library.dart';
import 'timetable_providers.dart';

class TimetableManagerPage extends ConsumerWidget {
  const TimetableManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(timetableLibraryProvider);
    final controller = ref.read(timetableLibraryProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('课表管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTimetable(context, ref, library),
        icon: const Icon(Icons.add),
        label: const Text('新建课表'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            '每个课表有独立的课程、作息时间和学期设置。'
            '点击课表即可切换。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final timetable in library.timetables)
            _TimetableCard(
              timetable: timetable,
              active: timetable.id == library.activeId,
              canDelete: library.timetables.length > 1,
              onTap: () async {
                await controller.selectTimetable(timetable.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              onRename: () => _renameTimetable(context, ref, timetable),
              onDelete: () => _deleteTimetable(
                context,
                ref,
                timetable,
                library.timetables.length > 1,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createTimetable(
    BuildContext context,
    WidgetRef ref,
    TimetableLibrary library,
  ) async {
    final name = await _askName(
      context,
      title: '新建课表',
      initial: '课表 ${library.timetables.length + 1}',
    );
    if (name == null || !context.mounted) return;

    await ref.read(timetableLibraryProvider.notifier).addTimetable(name: name);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _renameTimetable(
    BuildContext context,
    WidgetRef ref,
    TimetableData timetable,
  ) async {
    final name = await _askName(
      context,
      title: '重命名课表',
      initial: timetable.config.name,
    );
    if (name == null || !context.mounted) return;

    await ref
        .read(timetableLibraryProvider.notifier)
        .renameTimetable(timetable.id, name);
  }

  Future<void> _deleteTimetable(
    BuildContext context,
    WidgetRef ref,
    TimetableData timetable,
    bool canDelete,
  ) async {
    if (!canDelete) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('至少保留一个课表')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除课表'),
        content: Text(
          '确定删除「${timetable.config.name}」吗？'
          '其中的 ${timetable.courses.length} 门课程也会一并删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(timetableLibraryProvider.notifier)
        .deleteTimetable(timetable.id);
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: '课表名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
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
    if (name == null || name.isEmpty) return null;
    return name;
  }
}

class _TimetableCard extends StatelessWidget {
  const _TimetableCard({
    required this.timetable,
    required this.active,
    required this.canDelete,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final TimetableData timetable;
  final bool active;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            active ? Icons.check : Icons.calendar_view_week_outlined,
            color: active
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(timetable.config.name),
        subtitle: Text(
          '${timetable.courses.length} 门课程 · '
          '${timetable.timeSlots.length} 个时间段',
        ),
        trailing: PopupMenuButton<_TableAction>(
          tooltip: '更多操作',
          onSelected: (action) {
            switch (action) {
              case _TableAction.rename:
                onRename();
              case _TableAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _TableAction.rename,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('重命名'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _TableAction.delete,
              enabled: canDelete,
              child: const ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('删除'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

enum _TableAction { rename, delete }
