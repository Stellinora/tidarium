import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/model/standard_event.dart';
import '../settings/settings_page.dart';
import '../timetable/course_palette.dart';
import '../timetable/model/course.dart';
import '../timetable/model/timetable_config.dart';
import '../timetable/timetable_providers.dart';
import '../timetable/timetable_time.dart';
import '../timetable/widgets/course_detail_sheet.dart';
import '../timetable/widgets/course_editor_sheet.dart';
import '../todos/model/todo_item.dart';
import '../todos/todo_providers.dart';
import '../todos/widgets/todo_editor_sheet.dart';
import '../todos/widgets/todo_section.dart';
import 'today_agenda.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(todayAgendaProvider);
    final tomorrow = ref.watch(tomorrowCoursesProvider);
    final config = ref.watch(timetableProvider).config;
    final todos = ref.watch(todosProvider).value ?? const <TodoItem>[];
    final hasTimetable = ref
        .watch(timetableLibraryProvider)
        .timetables
        .isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日日程'),
        actions: [
          IconButton(
            tooltip: '添加待办',
            onPressed: _addTodo,
            icon: const Icon(Icons.add_task),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: hasTimetable
          ? null
          : FloatingActionButton.extended(
              onPressed: _addCourse,
              icon: const Icon(Icons.add),
              label: const Text('添加课程'),
            ),
      body: SafeArea(
        child: agenda.when(
          data: (data) => _buildBody(
            context,
            data,
            tomorrow.value,
            config,
            todos,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('读取日程失败：$error')),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TodayAgenda agenda,
    DayCourses? tomorrow,
    TimetableConfig config,
    List<TodoItem> todos,
  ) {
    final theme = Theme.of(context);
    final todayCourses = agenda.items
        .where((item) => item.type == AgendaItemType.course)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text(
          '${DateFormat('M月d日').format(agenda.date)} '
          '${weekdayName(agenda.date.weekday)}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                _statusLabel(agenda),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              agenda.tableName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: '今日课程',
          trailing: todayCourses.isEmpty ? null : '${todayCourses.length} 节',
        ),
        if (todayCourses.isEmpty)
          const _EmptyHint(icon: Icons.wb_sunny_outlined, text: '今天没有课程')
        else
          for (final item in todayCourses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgendaItemTile(
                item: item,
                config: config,
                onCourseTap: item.course == null
                    ? null
                    : () => _openCourse(item.course!),
              ),
            ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: '明日课程',
          trailing: (tomorrow == null || tomorrow.isEmpty)
              ? null
              : '${tomorrow.courses.length} 节',
        ),
        if (tomorrow == null)
          const _EmptyHint(
            icon: Icons.schedule,
            text: '正在读取明日课程…',
          )
        else if (tomorrow.isEmpty)
          const _EmptyHint(icon: Icons.nights_stay_outlined, text: '明天没有课程')
        else
          for (final item in tomorrow.courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgendaItemTile(
                item: item,
                config: config,
                onCourseTap: item.course == null
                    ? null
                    : () => _openCourse(item.course!),
              ),
            ),
        const SizedBox(height: 4),
        TodoSection(
          title: '待办事项',
          todos: todos,
          showOverdue: true,
          onToggle: _toggleTodo,
          onEdit: _editTodo,
          onDelete: _deleteTodo,
        ),
      ],
    );
  }

  String _statusLabel(TodayAgenda agenda) {
    return switch (agenda.status) {
      TodayAgendaStatus.noSemester => '未设置学期开始日期',
      TodayAgendaStatus.beforeSemester => '学期尚未开始',
      TodayAgendaStatus.afterSemester => '学期已结束',
      TodayAgendaStatus.normal => '第 ${agenda.weekNumber} 周',
    };
  }

  Future<void> _addCourse() async {
    final data = ref.read(timetableProvider);
    final course = await showCourseEditorSheet(
      context,
      config: data.config,
      timeSlots: data.timeSlots,
      initialDay: DateTime.now().weekday,
      initialSection: 1,
      suggestedColorIndex: data.courses.length,
    );
    if (course == null || !mounted) return;

    await ref.read(timetableLibraryProvider.notifier).addCourse(course);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已添加「${course.name}」')));
  }

  Future<void> _addTodo() async {
    final todo = await showTodoEditorSheet(context);
    if (todo == null || !mounted) return;
    await ref.read(todoStoreProvider).upsert(todo);
  }

  Future<void> _editTodo(TodoItem todo) async {
    final updated = await showTodoEditorSheet(context, initial: todo);
    if (updated == null || !mounted) return;
    await ref.read(todoStoreProvider).upsert(updated);
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    final now = DateTime.now();
    final updated = todo.copyWith(
      completed: !todo.completed,
      completedAt: todo.completed ? null : now,
      clearCompletedAt: todo.completed,
      updatedAt: now,
    );
    await ref.read(todoStoreProvider).upsert(updated);
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确定删除「${todo.title}」吗？'),
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
    if (confirmed != true || !mounted) return;
    await ref.read(todoStoreProvider).delete(todo.id);
  }

  Future<void> _openCourse(Course course) async {
    final data = ref.read(timetableProvider);
    final action = await showCourseDetailSheet(
      context,
      course: course,
      timeSlots: data.timeSlots,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CourseDetailAction.edit:
        final updated = await showCourseEditorSheet(
          context,
          course: course,
          config: data.config,
          timeSlots: data.timeSlots,
        );
        if (updated == null || !mounted) return;
        await ref.read(timetableLibraryProvider.notifier).updateCourse(updated);
      case CourseDetailAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除课程'),
            content: Text('确定删除「${course.name}」吗？此操作不可撤销。'),
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
        if (confirmed != true || !mounted) return;
        await ref
            .read(timetableLibraryProvider.notifier)
            .removeCourse(course.id);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaItemTile extends StatelessWidget {
  const _AgendaItemTile({
    required this.item,
    required this.config,
    required this.onCourseTap,
  });

  final AgendaItem item;
  final TimetableConfig config;
  final VoidCallback? onCourseTap;

  @override
  Widget build(BuildContext context) {
    final start = item.start;
    final end = item.end;
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Opacity(
      opacity: item.finished ? 0.55 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    start == null ? '--:--' : DateFormat('HH:mm').format(start),
                    style: timeStyle?.copyWith(
                      decoration: item.finished
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (end != null)
                    Text(
                      DateFormat('HH:mm').format(end),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 14,
              child: Column(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: item.finished
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildCard(context, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme) {
    if (item.course != null) {
      final course = item.course!;
      final background = courseColor(course.colorIndex, theme.brightness);
      final foreground = onCourseColor(background);
      final textDecoration = item.finished ? TextDecoration.lineThrough : null;

      return Card(
        margin: EdgeInsets.zero,
        color: background,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onCourseTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    decoration: textDecoration,
                  ),
                ),
                if (config.showLocation && course.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${course.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (config.showTeacher && course.teacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    course.teacher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (item.event != null) {
      final event = item.event!;
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(_eventIcon(event.type)),
          title: Text(event.title),
          subtitle: Text(event.source),
          trailing: item.finished
              ? const Icon(Icons.check_circle_outline, size: 18)
              : null,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  IconData _eventIcon(EventType type) {
    return switch (type) {
      EventType.assignment => Icons.assignment_outlined,
      EventType.course => Icons.school_outlined,
      EventType.onlineSession => Icons.live_tv_outlined,
    };
  }
}

