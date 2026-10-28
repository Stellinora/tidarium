import 'package:flutter/material.dart';

import '../course_palette.dart';
import '../model/course.dart';
import '../model/time_slot.dart';
import '../timetable_time.dart';

enum CourseDetailAction { edit, delete }

Future<CourseDetailAction?> showCourseDetailSheet(
  BuildContext context, {
  required Course course,
  required List<TimeSlot> timeSlots,
}) {
  return showModalBottomSheet<CourseDetailAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final background = courseColor(course.colorIndex, theme.brightness);
      final foreground = onCourseColor(background);
      final startSlot = _slotAt(timeSlots, course.startSection);
      final endSlot = _slotAt(timeSlots, course.endSection);
      final timeText = startSlot == null || endSlot == null
          ? '第 ${course.startSection}-${course.endSection} 节'
          : '第 ${course.startSection}-${course.endSection} 节 · '
                '${formatMinuteOfDay(startSlot.startMinutes)}-'
                '${formatMinuteOfDay(endSlot.endMinutes)}';

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${weekdayName(course.day)} · $timeText',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.person_outline,
                label: '教师',
                value: course.teacher.isEmpty ? '未填写' : course.teacher,
              ),
              _DetailRow(
                icon: Icons.place_outlined,
                label: '地点',
                value: course.location.isEmpty ? '未填写' : course.location,
              ),
              _DetailRow(
                icon: Icons.date_range_outlined,
                label: '周次',
                value: formatWeeks(course.weeks),
              ),
              if (course.remark.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: '备注',
                  value: course.remark,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          Navigator.of(sheetContext)
                              .pop(CourseDetailAction.edit),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(sheetContext)
                              .pop(CourseDetailAction.delete),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

TimeSlot? _slotAt(List<TimeSlot> slots, int number) {
  for (final slot in slots) {
    if (slot.number == number) return slot;
  }
  return null;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
