import '../model/course.dart';
import '../model/timetable_data.dart';
import '../timetable_time.dart';

class CourseReminderOccurrence {
  const CourseReminderOccurrence({
    required this.course,
    required this.startsAt,
    required this.remindAt,
  });

  final Course course;
  final DateTime startsAt;
  final DateTime remindAt;

  int get notificationId => courseReminderNotificationId(course.id, startsAt);
}

List<CourseReminderOccurrence> buildCourseReminderOccurrences({
  required TimetableData data,
  required DateTime from,
  int horizonDays = 21,
  int maxCount = 500,
}) {
  final semesterStart = data.config.semesterStart;
  if (semesterStart == null || horizonDays <= 0 || maxCount <= 0) {
    return const [];
  }

  final slots = {for (final slot in data.timeSlots) slot.number: slot};
  final firstDay = dateOnly(from);
  final occurrences = <CourseReminderOccurrence>[];

  for (var offset = 0; offset < horizonDays; offset++) {
    final date = addCalendarDays(firstDay, offset);
    final week = weekNumberFor(
      date,
      semesterStart,
      firstWeekday: data.config.firstWeekday,
    );
    if (week == null || week < 1 || week > data.config.totalWeeks) continue;

    for (final course in data.courses) {
      if (course.day != date.weekday || !course.weeks.contains(week)) {
        continue;
      }

      final slot = slots[course.startSection];
      if (slot == null) continue;

      final startsAt = DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: slot.startMinutes));
      final remindAt = startsAt.subtract(
        Duration(minutes: data.config.reminderMinutesBefore),
      );
      if (!remindAt.isAfter(from)) continue;

      occurrences.add(
        CourseReminderOccurrence(
          course: course,
          startsAt: startsAt,
          remindAt: remindAt,
        ),
      );
    }
  }

  occurrences.sort((a, b) {
    final byTime = a.remindAt.compareTo(b.remindAt);
    if (byTime != 0) return byTime;
    return a.course.id.compareTo(b.course.id);
  });

  if (occurrences.length <= maxCount) return occurrences;
  return occurrences.sublist(0, maxCount);
}

int courseReminderNotificationId(String courseId, DateTime startsAt) {
  var hash = 0x811c9dc5;
  for (final codeUnit in courseId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  hash ^= startsAt.year;
  hash = (hash * 0x01000193) & 0x7fffffff;
  hash ^= startsAt.month;
  hash = (hash * 0x01000193) & 0x7fffffff;
  hash ^= startsAt.day;
  hash = (hash * 0x01000193) & 0x7fffffff;
  hash ^= startsAt.hour;
  hash = (hash * 0x01000193) & 0x7fffffff;
  hash ^= startsAt.minute;
  return hash & 0x7fffffff;
}
