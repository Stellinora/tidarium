import 'package:flutter/material.dart';

import '../model/course.dart';
import '../model/merged_course_block.dart';
import '../model/time_slot.dart';
import '../model/timetable_config.dart';
import '../timetable_time.dart';
import 'course_block.dart';

const double timetableRowHeight = 68;
const double timetableHeaderHeight = 54;
const double timetableTimeColumnWidth = 44;

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.config,
    required this.timeSlots,
    required this.blocks,
    required this.weekNumber,
    required this.todayWeekday,
    required this.currentSection,
    required this.onCourseTap,
    required this.onCellTap,
  });

  final TimetableConfig config;
  final List<TimeSlot> timeSlots;
  final List<MergedCourseBlock> blocks;
  final int weekNumber;
  final int? todayWeekday;
  final int? currentSection;
  final ValueChanged<Course> onCourseTap;
  final void Function(int day, int section) onCellTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = orderedWeekdays(
      firstWeekday: config.firstWeekday,
      showWeekends: config.showWeekends,
    );
    final semesterStart = config.semesterStart;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - timetableTimeColumnWidth;
        final cellWidth = contentWidth / days.length;
        final gridHeight = timetableRowHeight * timeSlots.length;

        return Column(
          children: [
            _DayHeader(
              days: days,
              weekNumber: weekNumber,
              semesterStart: semesterStart,
              firstWeekday: config.firstWeekday,
              todayWeekday: todayWeekday,
              weekdayHeaderFontSize: config.weekdayHeaderFontSize,
              dateFontSize: config.dateFontSize,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey<String>('timetable-scroll-$weekNumber'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: timetableTimeColumnWidth,
                      height: gridHeight,
                      child: _TimeColumn(
                        timeSlots: timeSlots,
                        highlightedSection: currentSection,
                        slotFontSize: config.timeSlotFontSize,
                        textFontSize: config.timeTextFontSize,
                      ),
                    ),
                    SizedBox(
                      width: contentWidth,
                      height: gridHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (cellWidth <= 0 || timeSlots.isEmpty) return;
                          final dayIndex =
                              (details.localPosition.dx / cellWidth)
                                  .floor()
                                  .clamp(0, days.length - 1)
                                  .toInt();
                          final sectionIndex =
                              (details.localPosition.dy / timetableRowHeight)
                                  .floor()
                                  .clamp(0, timeSlots.length - 1)
                                  .toInt();
                          onCellTap(
                            days[dayIndex],
                            timeSlots[sectionIndex].number,
                          );
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TimetableGridPainter(
                                  dayCount: days.length,
                                  rowCount: timeSlots.length,
                                  todayIndex: todayWeekday == null
                                      ? null
                                      : days.indexOf(todayWeekday!),
                                  currentSectionIndex: currentSection == null
                                      ? null
                                      : timeSlots.indexWhere(
                                          (slot) =>
                                              slot.number == currentSection,
                                        ),
                                  lineColor: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.55),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            for (final block in blocks)
                              if (days.contains(block.course.day))
                                Positioned(
                                  left:
                                      (days.indexOf(block.course.day) +
                                              block.leftFraction) *
                                          cellWidth +
                                      1.5,
                                  top:
                                      (block.startSection - 1) *
                                          timetableRowHeight +
                                      1.5,
                                  width: (block.widthFraction * cellWidth - 3)
                                      .clamp(18, cellWidth)
                                      .toDouble(),
                                  height:
                                      (block.sectionSpan * timetableRowHeight -
                                              3)
                                          .clamp(18, gridHeight)
                                          .toDouble(),
                                  child: TimetableCourseBlock(
                                    key: ValueKey(block.course.id),
                                    course: block.course,
                                    showTeacher: config.showTeacher,
                                    showLocation: config.showLocation,
                                    courseNameFontSize:
                                        config.courseNameFontSize,
                                    courseInfoFontSize:
                                        config.courseInfoFontSize,
                                    sectionLabelFontSize:
                                        config.sectionLabelFontSize,
                                    onTap: () => onCourseTap(block.course),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.days,
    required this.weekNumber,
    required this.semesterStart,
    required this.firstWeekday,
    required this.todayWeekday,
    required this.weekdayHeaderFontSize,
    required this.dateFontSize,
  });

  final List<int> days;
  final int weekNumber;
  final DateTime? semesterStart;
  final int firstWeekday;
  final int? todayWeekday;
  final double weekdayHeaderFontSize;
  final double dateFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );

    return Container(
      height: timetableHeaderHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timetableTimeColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '第$weekNumber周',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = days[index];
                  final isToday = todayWeekday == day;
                  final date = semesterStart == null
                      ? null
                      : dateOfWeekday(
                          weekNumber,
                          day,
                          semesterStart: semesterStart!,
                          firstWeekday: firstWeekday,
                        );

                  return Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.35,
                            )
                          : null,
                      border: index == 0
                          ? null
                          : Border(left: BorderSide(color: dividerColor)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayName(day).replaceFirst('周', ''),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: weekdayHeaderFontSize,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            formatShortDate(date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: dateFontSize,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.timeSlots,
    required this.highlightedSection,
    required this.slotFontSize,
    required this.textFontSize,
  });

  final List<TimeSlot> timeSlots;
  final int? highlightedSection;
  final double slotFontSize;
  final double textFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final slot in timeSlots)
          Container(
            height: timetableRowHeight,
            width: double.infinity,
            color: slot.number == highlightedSection
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.alias ?? '${slot.number}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: slotFontSize,
                    fontWeight: FontWeight.w700,
                    color: slot.number == highlightedSection
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  formatMinuteOfDay(slot.startMinutes),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: textFontSize,
                    height: 1.05,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatMinuteOfDay(slot.endMinutes),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: textFontSize,
                    height: 1.05,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimetableGridPainter extends CustomPainter {
  const _TimetableGridPainter({
    required this.dayCount,
    required this.rowCount,
    required this.todayIndex,
    required this.currentSectionIndex,
    required this.lineColor,
    required this.highlightColor,
  });

  final int dayCount;
  final int rowCount;
  final int? todayIndex;
  final int? currentSectionIndex;
  final Color lineColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (rowCount <= 0 || dayCount <= 0 || size.isEmpty) return;
    final cellWidth = size.width / dayCount;
    final rowHeight = size.height / rowCount;

    if (todayIndex != null && todayIndex! >= 0 && todayIndex! < dayCount) {
      canvas.drawRect(
        Rect.fromLTWH(todayIndex! * cellWidth, 0, cellWidth, size.height),
        Paint()..color = highlightColor,
      );
    }

    if (currentSectionIndex != null &&
        currentSectionIndex! >= 0 &&
        currentSectionIndex! < rowCount) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          currentSectionIndex! * rowHeight,
          size.width,
          rowHeight,
        ),
        Paint()..color = highlightColor,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (var column = 1; column < dayCount; column++) {
      final x = column * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    for (var row = 1; row < rowCount; row++) {
      final y = row * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimetableGridPainter oldDelegate) {
    return oldDelegate.dayCount != dayCount ||
        oldDelegate.rowCount != rowCount ||
        oldDelegate.todayIndex != todayIndex ||
        oldDelegate.currentSectionIndex != currentSectionIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
