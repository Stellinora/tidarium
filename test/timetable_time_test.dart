import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/model/time_slot.dart';
import 'package:tidarium/features/timetable/timetable_time.dart';

void main() {
  group('week math', () {
    test('startOfWeek aligns to Monday and Sunday', () {
      final wednesday = DateTime(2026, 9, 2);

      expect(startOfWeek(wednesday), DateTime(2026, 8, 31));
      expect(
        startOfWeek(wednesday, firstWeekday: DateTime.sunday),
        DateTime(2026, 8, 30),
      );
    });

    test('weekNumberFor counts from the aligned semester week', () {
      final semesterStart = DateTime(2026, 9, 2);

      expect(weekNumberFor(DateTime(2026, 8, 30), semesterStart), 0);
      expect(weekNumberFor(DateTime(2026, 9, 2), semesterStart), 1);
      expect(weekNumberFor(DateTime(2026, 9, 6), semesterStart), 1);
      expect(weekNumberFor(DateTime(2026, 9, 7), semesterStart), 2);
      expect(weekNumberFor(DateTime(2026, 9, 2), null), isNull);
    });

    test('weekNumberFor respects a Sunday first day', () {
      final semesterStart = DateTime(2026, 9, 2);

      expect(
        weekNumberFor(
          DateTime(2026, 9, 6),
          semesterStart,
          firstWeekday: DateTime.sunday,
        ),
        2,
      );
    });

    test('dateOfWeekday maps a week and weekday back to a date', () {
      final semesterStart = DateTime(2026, 9, 2);

      expect(
        dateOfWeekday(2, DateTime.wednesday, semesterStart: semesterStart),
        DateTime(2026, 9, 9),
      );
      expect(
        dateOfWeekday(
          1,
          DateTime.sunday,
          semesterStart: semesterStart,
          firstWeekday: DateTime.sunday,
        ),
        DateTime(2026, 8, 30),
      );
    });

    test('orderedWeekdays follows the configured first day', () {
      expect(orderedWeekdays(firstWeekday: 1, showWeekends: false), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(orderedWeekdays(firstWeekday: 7, showWeekends: false), [
        7,
        1,
        2,
        3,
        4,
      ]);
      expect(orderedWeekdays(firstWeekday: 1, showWeekends: true), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
    });
  });

  group('minutes', () {
    test('formats and parses minute of day', () {
      expect(formatMinuteOfDay(8 * 60), '08:00');
      expect(formatMinuteOfDay(21 * 60 + 5), '21:05');
      expect(parseMinuteOfDay('08:45'), 8 * 60 + 45);
      expect(parseMinuteOfDay('bad'), 0);
    });

    test('finds the current section', () {
      const slots = [
        TimeSlot(number: 1, startMinutes: 480, endMinutes: 525),
        TimeSlot(number: 2, startMinutes: 530, endMinutes: 575),
      ];

      expect(currentSectionNumber(slots, DateTime(2026, 1, 1, 8, 10)), 1);
      expect(currentSectionNumber(slots, DateTime(2026, 1, 1, 8, 55)), 2);
      expect(currentSectionNumber(slots, DateTime(2026, 1, 1, 12)), isNull);
    });
  });

  group('formatWeeks', () {
    test('compresses consecutive ranges', () {
      expect(formatWeeks({}), '未选择周次');
      expect(formatWeeks({1, 2, 3, 4}), '1-4 周');
      expect(formatWeeks({1, 3, 4, 5, 8}), '1, 3-5, 8 周');
      expect(formatWeeks({7}), '7 周');
    });
  });
}
