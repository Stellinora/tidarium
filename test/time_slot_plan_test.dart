import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/time_slot.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/time_slot_plan.dart';

TimeSlot _slot(int number, int start, int end, {String? alias}) {
  return TimeSlot(
    number: number,
    startMinutes: start,
    endMinutes: end,
    alias: alias,
  );
}

Course _course(String id, int startSection, int endSection) {
  return Course(
    id: id,
    name: '课程 $id',
    day: 1,
    startSection: startSection,
    endSection: endSection,
    weeks: const {1},
    colorIndex: 0,
  );
}

void main() {
  group('TimeSlotPlan', () {
    test('builds the next slot from the last end plus break', () {
      final slot = TimeSlotPlan.buildNewSlot(
        slots: [_slot(1, 8 * 60, 8 * 60 + 45)],
        config: const TimetableConfig(
          defaultClassMinutes: 45,
          defaultBreakMinutes: 10,
        ),
      );

      expect(slot.number, 2);
      expect(slot.startMinutes, 8 * 60 + 55);
      expect(slot.endMinutes, 9 * 60 + 40);
    });

    test('rejects overlapping slots but allows adjacent slots', () {
      final existing = [_slot(1, 8 * 60, 9 * 60)];

      expect(
        TimeSlotPlan.validate(
          slot: _slot(2, 8 * 60 + 30, 9 * 60 + 30),
          existing: existing,
        ),
        contains('重叠'),
      );
      expect(
        TimeSlotPlan.validate(
          slot: _slot(2, 9 * 60, 9 * 60 + 45),
          existing: existing,
        ),
        isNull,
      );
    });

    test('adding an earlier slot renumbers and remaps courses', () {
      final slots = [
        _slot(1, 8 * 60, 8 * 60 + 45),
        _slot(2, 10 * 60, 10 * 60 + 45),
      ];
      final courses = [_course('a', 2, 2)];

      final result = TimeSlotPlan.add(
        slots: slots,
        courses: courses,
        slot: _slot(3, 9 * 60, 9 * 60 + 45),
      );

      expect(result.ok, isTrue);
      expect(result.slots.map((slot) => slot.number), [1, 2, 3]);
      expect(result.slots[2].startMinutes, 10 * 60);
      expect(result.courses.single.startSection, 3);
      expect(result.courses.single.endSection, 3);
    });

    test('adding at the end keeps course sections stable', () {
      final slots = [_slot(1, 8 * 60, 8 * 60 + 45)];
      final courses = [_course('a', 1, 1)];

      final result = TimeSlotPlan.add(
        slots: slots,
        courses: courses,
        slot: _slot(2, 9 * 60, 9 * 60 + 45),
      );

      expect(result.courses.single.startSection, 1);
      expect(result.slots.last.number, 2);
    });

    test('cannot delete a slot used by courses', () {
      final slots = [
        _slot(1, 8 * 60, 8 * 60 + 45),
        _slot(2, 9 * 60, 9 * 60 + 45),
      ];
      final courses = [_course('a', 1, 2)];

      final result = TimeSlotPlan.remove(
        slots: slots,
        courses: courses,
        number: 2,
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('门课程使用'));
    });

    test('deleting an unused middle slot renumbers and remaps courses', () {
      final slots = [
        _slot(1, 8 * 60, 8 * 60 + 45),
        _slot(2, 9 * 60, 9 * 60 + 45),
        _slot(3, 10 * 60, 10 * 60 + 45),
      ];
      final courses = [_course('a', 3, 3)];

      final result = TimeSlotPlan.remove(
        slots: slots,
        courses: courses,
        number: 2,
      );

      expect(result.ok, isTrue);
      expect(result.slots.length, 2);
      expect(result.slots[1].startMinutes, 10 * 60);
      expect(result.courses.single.startSection, 2);
      expect(result.courses.single.endSection, 2);
    });

    test(
      'updating a slot keeps its number and excludes itself from overlap',
      () {
        final slots = [
          _slot(1, 8 * 60, 8 * 60 + 45),
          _slot(2, 9 * 60, 9 * 60 + 45),
        ];

        final result = TimeSlotPlan.update(
          slots: slots,
          slot: _slot(1, 8 * 60 + 5, 8 * 60 + 50),
        );

        expect(result.ok, isTrue);
        expect(result.slots.first.number, 1);
        expect(result.slots.first.startMinutes, 8 * 60 + 5);
      },
    );

    test('counts courses spanning a slot', () {
      final courses = [_course('a', 1, 3), _course('b', 2, 2)];

      expect(TimeSlotPlan.usageCount(courses, 1), 1);
      expect(TimeSlotPlan.usageCount(courses, 2), 2);
      expect(TimeSlotPlan.usageCount(courses, 4), 0);
    });
  });
}
