import 'package:flutter/material.dart';

import '../course_palette.dart';
import '../model/course.dart';
import '../model/time_slot.dart';
import '../model/timetable_config.dart';
import '../timetable_providers.dart';
import '../timetable_time.dart';

Future<Course?> showCourseEditorSheet(
  BuildContext context, {
  Course? course,
  required TimetableConfig config,
  required List<TimeSlot> timeSlots,
  int initialDay = 1,
  int initialSection = 1,
  int suggestedColorIndex = 0,
}) {
  return showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final available = media.size.height - media.viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * 0.92),
          child: _CourseEditorSheet(
            course: course,
            config: config,
            timeSlots: timeSlots,
            initialDay: initialDay,
            initialSection: initialSection,
            suggestedColorIndex: suggestedColorIndex,
          ),
        ),
      );
    },
  );
}

class _CourseEditorSheet extends StatefulWidget {
  const _CourseEditorSheet({
    required this.course,
    required this.config,
    required this.timeSlots,
    required this.initialDay,
    required this.initialSection,
    required this.suggestedColorIndex,
  });

  final Course? course;
  final TimetableConfig config;
  final List<TimeSlot> timeSlots;
  final int initialDay;
  final int initialSection;
  final int suggestedColorIndex;

  @override
  State<_CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<_CourseEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late final TextEditingController _remarkController;

  late int _day;
  late int _startSection;
  late int _endSection;
  late Set<int> _weeks;
  late int _colorIndex;
  String? _error;

  int get _sectionCount => widget.timeSlots.length;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    final maxSection = _sectionCount;

    _nameController = TextEditingController(text: course?.name ?? '');
    _teacherController = TextEditingController(text: course?.teacher ?? '');
    _locationController = TextEditingController(text: course?.location ?? '');
    _remarkController = TextEditingController(text: course?.remark ?? '');

    _day = (course?.day ?? widget.initialDay).clamp(1, 7);
    _startSection = (course?.startSection ?? widget.initialSection).clamp(
      1,
      maxSection,
    );
    _endSection = (course?.endSection ?? _startSection).clamp(
      _startSection,
      maxSection,
    );
    _weeks = course == null
        ? {for (var week = 1; week <= widget.config.totalWeeks; week++) week}
        : {...course.weeks};
    _colorIndex = normalizeColorIndex(
      course?.colorIndex ?? widget.suggestedColorIndex,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.course != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEditing ? '编辑课程' : '添加课程',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '课程名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _teacherController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '教师',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '地点',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('时间', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _day,
                        decoration: const InputDecoration(
                          labelText: '星期',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var day = 1; day <= 7; day++)
                            DropdownMenuItem(
                              value: day,
                              child: Text(weekdayName(day)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _day = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _startSection,
                        decoration: const InputDecoration(
                          labelText: '开始时段',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final slot in widget.timeSlots)
                            DropdownMenuItem(
                              value: slot.number,
                              child: Text(
                                '${slot.number} · ${formatMinuteOfDay(slot.startMinutes)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _startSection = value;
                            if (_endSection < value) _endSection = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _endSection,
                        decoration: const InputDecoration(
                          labelText: '结束时段',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final slot in widget.timeSlots)
                            if (slot.number >= _startSection)
                              DropdownMenuItem(
                                value: slot.number,
                                child: Text(
                                  '${slot.number} · ${formatMinuteOfDay(slot.endMinutes)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _endSection = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('上课周次', style: theme.textTheme.titleSmall),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _weeks = {
                            for (
                              var week = 1;
                              week <= widget.config.totalWeeks;
                              week++
                            )
                              week,
                          };
                        });
                      },
                      child: const Text('全选'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _weeks = {}),
                      child: const Text('清除'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var week = 1; week <= widget.config.totalWeeks; week++)
                      FilterChip(
                        label: Text('$week'),
                        visualDensity: VisualDensity.compact,
                        selected: _weeks.contains(week),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _weeks.add(week);
                            } else {
                              _weeks.remove(week);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('颜色', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var index = 0; index < courseColors.length; index++)
                      _ColorDot(
                        color: courseColor(index, theme.brightness),
                        selected: index == _colorIndex,
                        onTap: () => setState(() => _colorIndex = index),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _remarkController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? '保存' : '添加'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写课程名称');
      return;
    }
    final validWeeks = _weeks
        .where((week) => week >= 1 && week <= widget.config.totalWeeks)
        .toSet();
    if (validWeeks.isEmpty) {
      setState(() => _error = '请至少选择一个上课周次');
      return;
    }

    final existing = widget.course;
    final course = Course(
      id: existing?.id ?? newCourseId(),
      name: name,
      day: _day,
      startSection: _startSection,
      endSection: _endSection,
      weeks: validWeeks,
      colorIndex: _colorIndex,
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      remark: _remarkController.text.trim(),
    );

    Navigator.of(context).pop(course);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.colorScheme.onSurface : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? Icon(Icons.check, size: 18, color: onCourseColor(color))
            : null,
      ),
    );
  }
}
