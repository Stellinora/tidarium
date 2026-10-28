import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_merge.dart';
import 'model/course.dart';
import 'timetable_providers.dart';
import 'timetable_settings_page.dart';
import 'timetable_time.dart';
import 'widgets/course_detail_sheet.dart';
import 'widgets/course_editor_sheet.dart';
import 'widgets/timetable_grid.dart';
import 'widgets/week_selector_sheet.dart';

class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(timetableProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final config = data.config;

    final now = DateTime.now();
    final totalWeeks = config.totalWeeks.clamp(1, 52);
    final currentWeek = weekNumberFor(
      now,
      config.semesterStart,
      firstWeekday: config.firstWeekday,
    );
    final week = (selectedWeek ?? currentWeek ?? 1)
        .clamp(1, totalWeeks)
        .toInt();
    final isCurrentWeek = currentWeek != null && week == currentWeek;
    final todayWeekday = isCurrentWeek ? now.weekday : null;
    final activeWeekday = todayWeekday ?? now.weekday;
    final defaultDay = !config.showWeekends && activeWeekday > 5
        ? DateTime.monday
        : activeWeekday;

    final blocks = mergeCoursesForWeek(
      data.courses,
      week,
      maxSection: data.timeSlots.length,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openWeekSelector(
            context,
            ref,
            totalWeeks: totalWeeks,
            currentWeek: currentWeek,
            selectedWeek: week,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 $week 周',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _weekRangeLabel(
                        config.semesterStart,
                        week,
                        config.firstWeekday,
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          if (!isCurrentWeek)
            IconButton(
              tooltip: '回到本周',
              onPressed: () =>
                  ref.read(selectedWeekProvider.notifier).followToday(),
              icon: const Icon(Icons.today_outlined),
            ),
          PopupMenuButton<_MenuAction>(
            tooltip: '更多',
            onSelected: (action) =>
                _handleMenuAction(context, ref, action, day: defaultDay),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MenuAction.addCourse,
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('添加课程'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.toggleWeekends,
                child: ListTile(
                  leading: Icon(
                    config.showWeekends
                        ? Icons.view_week_outlined
                        : Icons.calendar_view_week_outlined,
                  ),
                  title: Text(config.showWeekends ? '隐藏周末' : '显示周末'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('课程表设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _MenuAction.clearCourses,
                enabled: data.courses.isNotEmpty,
                child: const ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('清空课程'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCourse(context, ref, day: defaultDay, section: 1),
        icon: const Icon(Icons.add),
        label: const Text('添加课程'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (data.courses.isEmpty)
              _HintBar(
                icon: Icons.touch_app_outlined,
                message: '还没有课程。点按空白格或右下角按钮添加第一门课程。',
                actionLabel: null,
                onAction: null,
              ),
            if (config.semesterStart == null)
              _HintBar(
                icon: Icons.event_busy_outlined,
                message: '还没有设置学期开始日期，周次不会自动定位。',
                actionLabel: '去设置',
                onAction: () => _openSettings(context),
              ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 180) return;
                  final target = velocity < 0 ? week + 1 : week - 1;
                  if (target < 1 || target > totalWeeks) return;
                  ref.read(selectedWeekProvider.notifier).select(target);
                },
                child: TimetableGrid(
                  config: config,
                  timeSlots: data.timeSlots,
                  blocks: blocks,
                  weekNumber: week,
                  todayWeekday: todayWeekday,
                  currentSection: isCurrentWeek
                      ? currentSectionNumber(data.timeSlots, now)
                      : null,
                  onCourseTap: (course) => _openCourse(context, ref, course),
                  onCellTap: (day, section) =>
                      _addCourse(context, ref, day: day, section: section),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekRangeLabel(DateTime? semesterStart, int week, int firstWeekday) {
    if (semesterStart == null) return '学期未设置';
    final start = weekStartDate(
      week,
      semesterStart: semesterStart,
      firstWeekday: firstWeekday,
    );
    final end = addCalendarDays(start, 6);
    return '${formatShortDate(start)} - ${formatShortDate(end)}';
  }

  Future<void> _openWeekSelector(
    BuildContext context,
    WidgetRef ref, {
    required int totalWeeks,
    required int? currentWeek,
    required int selectedWeek,
  }) {
    return showWeekSelectorSheet(
      context,
      totalWeeks: totalWeeks,
      currentWeek: currentWeek,
      selectedWeek: selectedWeek,
      onSelected: (week) =>
          ref.read(selectedWeekProvider.notifier).select(week),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    _MenuAction action, {
    required int day,
  }) async {
    switch (action) {
      case _MenuAction.addCourse:
        await _addCourse(context, ref, day: day, section: 1);
      case _MenuAction.toggleWeekends:
        final config = ref.read(timetableProvider).config;
        await ref
            .read(timetableProvider.notifier)
            .updateConfig(config.copyWith(showWeekends: !config.showWeekends));
      case _MenuAction.settings:
        await _openSettings(context);
      case _MenuAction.clearCourses:
        await _clearCourses(context, ref);
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TimetableSettingsPage()),
    );
  }

  Future<void> _addCourse(
    BuildContext context,
    WidgetRef ref, {
    required int day,
    required int section,
  }) async {
    final data = ref.read(timetableProvider);
    final course = await showCourseEditorSheet(
      context,
      config: data.config,
      timeSlots: data.timeSlots,
      initialDay: day,
      initialSection: section,
      suggestedColorIndex: data.courses.length,
    );
    if (course == null || !context.mounted) return;

    await ref.read(timetableProvider.notifier).addCourse(course);
    await _revealWeekendIfNeeded(ref, course);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已添加「${course.name}」')));
  }

  Future<void> _openCourse(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final data = ref.read(timetableProvider);
    final action = await showCourseDetailSheet(
      context,
      course: course,
      timeSlots: data.timeSlots,
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case CourseDetailAction.edit:
        final updated = await showCourseEditorSheet(
          context,
          course: course,
          config: data.config,
          timeSlots: data.timeSlots,
        );
        if (updated == null || !context.mounted) return;
        await ref.read(timetableProvider.notifier).updateCourse(updated);
        await _revealWeekendIfNeeded(ref, updated);
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
        if (confirmed != true || !context.mounted) return;
        await ref.read(timetableProvider.notifier).removeCourse(course.id);
    }
  }

  Future<void> _revealWeekendIfNeeded(WidgetRef ref, Course course) async {
    if (course.day <= 5) return;
    final config = ref.read(timetableProvider).config;
    if (config.showWeekends) return;
    await ref
        .read(timetableProvider.notifier)
        .updateConfig(config.copyWith(showWeekends: true));
  }

  Future<void> _clearCourses(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空课程'),
        content: const Text('将删除当前课表中的全部课程，确定继续吗？'),
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

    await ref.read(timetableProvider.notifier).clearCourses();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('课程已清空')));
  }
}

enum _MenuAction { addCourse, toggleWeekends, settings, clearCourses }

class _HintBar extends StatelessWidget {
  const _HintBar({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
