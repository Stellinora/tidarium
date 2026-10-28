import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/import_payload.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';

void main() {
  group('import payload', () {
    test('parses time slots and rejects overlaps', () {
      final slots = parseImportedTimeSlots(
        jsonEncode([
          {'number': 1, 'startTime': '08:00', 'endTime': '08:45'},
          {
            'number': 2,
            'startTime': '08:55',
            'endTime': '09:40',
            'alias': '第二节',
          },
        ]),
      );

      expect(slots, hasLength(2));
      expect(slots.first.startMinutes, 8 * 60);
      expect(slots.last.alias, '第二节');

      expect(
        () => parseImportedTimeSlots(
          jsonEncode([
            {'number': 1, 'startTime': '08:00', 'endTime': '09:00'},
            {'number': 2, 'startTime': '08:30', 'endTime': '09:30'},
          ]),
        ),
        throwsFormatException,
      );
    });

    test('parses config while keeping unspecified fields', () {
      final base = TimetableConfig(
        semesterStart: DateTime(2026, 9, 1),
        totalWeeks: 20,
        showWeekends: false,
        firstWeekday: DateTime.monday,
      );

      final config = parseImportedConfig(
        jsonEncode({
          'semesterStartDate': '2026-09-07',
          'semesterTotalWeeks': 18,
          'defaultClassDuration': 50,
          'defaultBreakDuration': 5,
        }),
        base,
      );

      expect(config.semesterStart, DateTime(2026, 9, 7));
      expect(config.totalWeeks, 18);
      expect(config.defaultClassMinutes, 50);
      expect(config.defaultBreakMinutes, 5);
      expect(config.showWeekends, isFalse);
    });

    test('parses courses, maps custom time and fills empty weeks', () {
      final config = const TimetableConfig(totalWeeks: 4);
      final imported = parseImportedCourses(
        jsonEncode([
          {
            'name': '高等数学',
            'teacher': '张老师',
            'position': 'A101',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 2],
          },
          {
            'name': '体育',
            'day': 6,
            'isCustomTime': true,
            'customStartTime': '08:00',
            'customEndTime': '08:45',
          },
          {
            'name': '无效课程',
            'day': 1,
            'startSection': 99,
            'endSection': 99,
            'weeks': [1],
          },
        ]),
        config: config,
        slots: defaultTimeSlots,
      );

      expect(imported.courses, hasLength(2));
      expect(imported.courses.first.weeks, {1, 2});
      expect(imported.courses.first.teacher, '张老师');
      expect(imported.courses.first.location, 'A101');

      final pe = imported.courses.last;
      expect(pe.name, '体育');
      expect(pe.day, 6);
      expect(pe.startSection, 1);
      expect(pe.endSection, 1);
      expect(pe.weeks, {1, 2, 3, 4});

      expect(imported.warnings.single, contains('无效课程'));
    });

    test('assigns the same color to the same course name', () {
      final imported = parseImportedCourses(
        jsonEncode([
          {
            'name': '物理',
            'day': 1,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
          },
          {
            'name': '物理',
            'day': 3,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
          },
          {
            'name': '化学',
            'day': 2,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
          },
        ]),
        config: const TimetableConfig(totalWeeks: 4),
        slots: defaultTimeSlots,
      );

      expect(imported.courses[0].colorIndex, imported.courses[1].colorIndex);
      expect(
        imported.courses[0].colorIndex,
        isNot(imported.courses[2].colorIndex),
      );
    });
  });
}
