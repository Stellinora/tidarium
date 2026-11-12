import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profiles/profile_lifecycle.dart';
import '../profiles/profile_providers.dart';
import 'model/timetable_data.dart';
import 'model/timetable_library.dart';
import 'timetable_providers.dart';
import 'timetable_settings_page.dart';

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
            '每个课表有独立的课程、学期、显示和作息设置。'
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
              primary: timetable.id == library.primaryId,
              canDelete: library.timetables.length > 1,
              onTap: () async {
                await controller.selectTimetable(timetable.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              onSettings: () => _openSettings(context, ref, timetable),
              onRename: () => _renameTimetable(context, ref, timetable),
              onSetPrimary: () => ref
                  .read(timetableLibraryProvider.notifier)
                  .setPrimaryTimetable(timetable.id),
              onDelete: () => _deleteTimetable(
                context,
                ref,
                timetable,
                library,
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

  Future<void> _openSettings(
    BuildContext context,
    WidgetRef ref,
    TimetableData timetable,
  ) async {
    await ref
        .read(timetableLibraryProvider.notifier)
        .selectTimetable(timetable.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TimetableSettingsPage()),
    );
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
    TimetableLibrary library,
  ) async {
    final canDelete = library.timetables.length > 1;
    if (!canDelete) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('至少保留一个课表')));
      return;
    }

    final strategy = await showDialog<ProfileDeleteStrategy>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除课表'),
        content: Text(
          '「${timetable.config.name}」下有 ${timetable.courses.length} 门课程。'
          '这张课表的待办怎么处理？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(ProfileDeleteStrategy.deleteAll),
            child: const Text('一并删除'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext)
                .pop(ProfileDeleteStrategy.migrateToPrimary),
            child: const Text('迁移到主课表'),
          ),
        ],
      ),
    );
    if (strategy == null || !context.mounted) return;

    try {
      final outcome = await ref
          .read(profileLifecycleProvider)
          .deleteProfile(
            library: ref.read(timetableLibraryProvider),
            profileId: timetable.id,
            strategy: strategy,
          );
      await ref
          .read(timetableLibraryProvider.notifier)
          .replaceLibrary(outcome.library);
      if (!context.mounted) return;
      final message = strategy == ProfileDeleteStrategy.migrateToPrimary
          ? '已删除，迁移 ${outcome.movedTodos} 条待办'
          : '已删除，清除 ${outcome.deletedTodos} 条待办';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ProfileLifecycleError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
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
    required this.primary,
    required this.canDelete,
    required this.onTap,
    required this.onSettings,
    required this.onRename,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final TimetableData timetable;
  final bool active;
  final bool primary;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onSettings;
  final VoidCallback onRename;
  final VoidCallback onSetPrimary;
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
          '${timetable.timeSlots.length} 个时间段'
          '${primary ? ' · 主课表' : ''}',
        ),
        trailing: PopupMenuButton<_TableAction>(
          tooltip: '更多操作',
          onSelected: (action) {
            switch (action) {
              case _TableAction.settings:
                onSettings();
              case _TableAction.rename:
                onRename();
              case _TableAction.setPrimary:
                onSetPrimary();
              case _TableAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _TableAction.settings,
              child: ListTile(
                leading: Icon(Icons.tune),
                title: Text('设置'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _TableAction.rename,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('重命名'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _TableAction.setPrimary,
              enabled: !primary,
              child: const ListTile(
                leading: Icon(Icons.star_outline),
                title: Text('设为主课表'),
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

enum _TableAction { settings, rename, setPrimary, delete }


