import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/reminder/course_reminder_schedule.dart';

void main() {
  final config = TimetableConfig(
    semesterStart: DateTime(2026, 9, 7),
    totalWeeks: 20,
    reminderEnabled: true,
    reminderMinutesBefore: 10,
  );

  TimetableData dataWith(Course course) {
    return TimetableData(
      config: config,
      timeSlots: defaultTimeSlots,
      courses: [course],
    );
  }

  test('builds a reminder before the next matching course', () {
    final occurrences = buildCourseReminderOccurrences(
      data: dataWith(
        const Course(
          id: 'c1',
          name: '高等数学',
          day: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weeks: {1},
          colorIndex: 0,
          location: 'A101',
          teacher: '张老师',
        ),
      ),
      from: DateTime(2026, 9, 7, 7),
    );

    expect(occurrences, hasLength(1));
    expect(occurrences.single.startsAt, DateTime(2026, 9, 7, 8));
    expect(occurrences.single.remindAt, DateTime(2026, 9, 7, 7, 50));
  });

  test('skips reminders that are already in the past', () {
    final occurrences = buildCourseReminderOccurrences(
      data: dataWith(
        const Course(
          id: 'c1',
          name: '高等数学',
          day: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weeks: {1},
          colorIndex: 0,
        ),
      ),
      from: DateTime(2026, 9, 7, 7, 55),
    );

    expect(occurrences, isEmpty);
  });

  test('skips courses that are not active in the current week', () {
    final occurrences = buildCourseReminderOccurrences(
      data: dataWith(
        const Course(
          id: 'c1',
          name: '高等数学',
          day: DateTime.monday,
          startSection: 1,
          endSection: 2,
          weeks: {2},
          colorIndex: 0,
        ),
      ),
      from: DateTime(2026, 9, 7, 7),
      horizonDays: 6,
    );

    expect(occurrences, isEmpty);
  });

  test('notification ids are stable and unique per occurrence', () {
    final first = courseReminderNotificationId(
      'course_a',
      DateTime(2026, 9, 7, 8),
    );
    final same = courseReminderNotificationId(
      'course_a',
      DateTime(2026, 9, 7, 8),
    );
    final nextDay = courseReminderNotificationId(
      'course_a',
      DateTime(2026, 9, 14, 8),
    );
    final otherCourse = courseReminderNotificationId(
      'course_b',
      DateTime(2026, 9, 7, 8),
    );

    expect(first, same);
    expect(first, isNot(nextDay));
    expect(first, isNot(otherCourse));
    expect(first, inInclusiveRange(0, 0x7fffffff));
  });

  test('reminder settings survive config json round trips', () {
    final decoded = TimetableConfig.fromJson(config.toJson());

    expect(decoded.reminderEnabled, isTrue);
    expect(decoded.reminderMinutesBefore, 10);
  });
}
