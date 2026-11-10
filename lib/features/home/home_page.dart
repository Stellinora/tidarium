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
import '../todos/todo_filters.dart';
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
  final _activeItemKey = GlobalKey();
  var _didAutoScroll = false;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(todayAgendaProvider);
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
          data: (data) => _buildAgenda(context, data, config, todos),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('读取日程失败：$error')),
        ),
      ),
    );
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

  Widget _buildAgenda(
    BuildContext context,
    TodayAgenda agenda,
    TimetableConfig config,
    List<TodoItem> todos,
  ) {
    final theme = Theme.of(context);
    final firstActive = agenda.items.indexWhere((item) => !item.finished);
    final activeIndex = firstActive < 0 ? null : firstActive;
    final now = DateTime.now();
    final today = dateOnly(agenda.date);
    final reference = DateTime(
      agenda.date.year,
      agenda.date.month,
      agenda.date.day,
      now.hour,
      now.minute,
    );
    final tomorrowTodos = todosDueOn(todos, addCalendarDays(today, 1));
    final listTodos = todosOutsideTodayAndTomorrow(todos, reference);

    if (activeIndex != null && !_didAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final itemContext = _activeItemKey.currentContext;
        if (itemContext == null) return;
        _didAutoScroll = true;
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              if (agenda.items.isEmpty) ...[
                const SizedBox(height: 40),
                const _EmptyState(),
                const SizedBox(height: 16),
              ] else ...[
                for (var index = 0; index < agenda.items.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _AgendaItemTile(
                    key: index == activeIndex ? _activeItemKey : null,
                    item: agenda.items[index],
                    config: config,
                    onCourseTap: agenda.items[index].course == null
                        ? null
                        : () => _openCourse(agenda.items[index].course!),
                    onTodoToggle: agenda.items[index].todo == null
                        ? null
                        : () => _toggleTodo(agenda.items[index].todo!),
                    onTodoTap: agenda.items[index].todo == null
                        ? null
                        : () => _editTodo(agenda.items[index].todo!),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              TodoSection(
                title: '明日待办',
                todos: tomorrowTodos,
                onToggle: _toggleTodo,
                onEdit: _editTodo,
                onDelete: _deleteTodo,
              ),
              const SizedBox(height: 8),
              TodoSection(
                title: '待办清单',
                todos: listTodos,
                showOverdue: true,
                onToggle: _toggleTodo,
                onEdit: _editTodo,
                onDelete: _deleteTodo,
              ),
            ],
          ),
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

class _AgendaItemTile extends StatelessWidget {
  const _AgendaItemTile({
    super.key,
    required this.item,
    required this.config,
    required this.onCourseTap,
    this.onTodoToggle,
    this.onTodoTap,
  });

  final AgendaItem item;
  final TimetableConfig config;
  final VoidCallback? onCourseTap;
  final VoidCallback? onTodoToggle;
  final VoidCallback? onTodoTap;

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

    if (item.todo != null) {
      final todo = item.todo!;
      final subtitle = [
        if (todo.source.isNotEmpty) todo.source,
        '截止 ${DateFormat('HH:mm').format(todo.dueAt)}',
      ].join(' · ');
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Checkbox(
            value: todo.completed,
            onChanged: (_) => onTodoToggle?.call(),
          ),
          title: Text(
            todo.title,
            style: theme.textTheme.titleSmall?.copyWith(
              decoration: todo.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(subtitle),
          onTap: onTodoTap,
        ),
      );
    }

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

  IconData _eventIcon(EventType type) {
    return switch (type) {
      EventType.assignment => Icons.assignment_outlined,
      EventType.course => Icons.school_outlined,
      EventType.onlineSession => Icons.live_tv_outlined,
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_note_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text('今天没有安排', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '课程和今日事件会显示在这里',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

