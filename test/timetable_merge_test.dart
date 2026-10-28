import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/course_merge.dart';
import 'package:tidarium/features/timetable/model/course.dart';

Course _course({
  required String id,
  int day = 1,
  int start = 1,
  int end = 2,
  Set<int>? weeks,
  String name = '课程',
}) {
  return Course(
    id: id,
    name: name,
    day: day,
    startSection: start,
    endSection: end,
    weeks: weeks ?? {1},
    colorIndex: 0,
  );
}

void main() {
  group('mergeCoursesForWeek', () {
    test('filters courses by week', () {
      final courses = [
        _course(id: 'a', weeks: {1}),
        _course(id: 'b', weeks: {2}),
      ];

      expect(mergeCoursesForWeek(courses, 1).map((b) => b.course.id), ['a']);
      expect(mergeCoursesForWeek(courses, 2).map((b) => b.course.id), ['b']);
    });

    test('puts overlapping courses in separate columns', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', start: 1, end: 2),
        _course(id: 'b', start: 2, end: 3),
      ], 1);

      expect(blocks, hasLength(2));
      final a = blocks.firstWhere((block) => block.course.id == 'a');
      final b = blocks.firstWhere((block) => block.course.id == 'b');
      expect(a.columnCount, 2);
      expect(a.columnIndex, 0);
      expect(b.columnCount, 2);
      expect(b.columnIndex, 1);
    });

    test('keeps non-overlapping courses full width', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', start: 1, end: 2),
        _course(id: 'b', start: 3, end: 4),
      ], 1);

      expect(blocks, hasLength(2));
      expect(blocks.every((block) => block.columnCount == 1), isTrue);
      expect(blocks.every((block) => block.columnIndex == 0), isTrue);
    });

    test('assigns a third column to a triple overlap', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', start: 1, end: 4),
        _course(id: 'b', start: 2, end: 3),
        _course(id: 'c', start: 3, end: 5),
      ], 1);

      expect(blocks, hasLength(3));
      expect(blocks.every((block) => block.columnCount == 3), isTrue);
      expect(
        blocks.map((block) => block.columnIndex),
        containsAll(<int>[0, 1, 2]),
      );
    });

    test('merges clusters connected through a bridging course', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', start: 1, end: 2),
        _course(id: 'b', start: 4, end: 5),
        _course(id: 'c', start: 2, end: 4),
      ], 1);

      final a = blocks.firstWhere((block) => block.course.id == 'a');
      final b = blocks.firstWhere((block) => block.course.id == 'b');
      final c = blocks.firstWhere((block) => block.course.id == 'c');

      expect(a.columnCount, 2);
      expect(b.columnCount, 2);
      expect(c.columnCount, 2);
      expect(a.columnIndex, 0);
      expect(b.columnIndex, 0);
      expect(c.columnIndex, 1);
    });

    test('keeps days independent', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', day: 1),
        _course(id: 'b', day: 2),
      ], 1);

      expect(blocks, hasLength(2));
      expect(blocks.every((block) => block.columnCount == 1), isTrue);
    });

    test('clamps and skips sections beyond the grid', () {
      final blocks = mergeCoursesForWeek(
        [
          _course(id: 'a', start: 9, end: 13),
          _course(id: 'b', start: 11, end: 12),
        ],
        1,
        maxSection: 10,
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.course.id, 'a');
      expect(blocks.single.endSection, 10);
    });

    test('skips courses with an invalid section range', () {
      final blocks = mergeCoursesForWeek([
        _course(id: 'a', start: 5, end: 3),
        _course(id: 'b', start: 0, end: 2),
      ], 1);

      expect(blocks, isEmpty);
    });
  });
}
