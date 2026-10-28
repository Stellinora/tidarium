import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/io/ics_exporter.dart';
import 'package:tidarium/features/timetable/io/ics_importer.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';

Course _course({
  required String id,
  required String name,
  required int day,
  required int start,
  required int end,
  required Set<int> weeks,
  String teacher = '',
  String location = '',
}) {
  return Course(
    id: id,
    name: name,
    day: day,
    startSection: start,
    endSection: end,
    weeks: weeks,
    colorIndex: 0,
    teacher: teacher,
    location: location,
  );
}

TimetableData _data() {
  return TimetableData(
    config: TimetableConfig(semesterStart: DateTime(2026, 9, 2), totalWeeks: 4),
    timeSlots: defaultTimeSlots,
    courses: [
      _course(
        id: 'c1',
        name: '高等数学',
        day: 1,
        start: 1,
        end: 2,
        weeks: {1, 2},
        teacher: '张老师',
        location: 'A101',
      ),
      _course(
        id: 'c2',
        name: '线性代数',
        day: 3,
        start: 3,
        end: 3,
        weeks: {2},
        teacher: '李老师',
        location: 'B202',
      ),
    ],
  );
}

void main() {
  group('ICS export', () {
    test('exports one event per course occurrence', () {
      final result = buildIcsExport(
        _data(),
        alarmMinutes: 15,
        now: DateTime(2026, 9, 1, 10, 30),
      );

      expect(result.content, contains('BEGIN:VCALENDAR'));
      expect(result.content, contains('PRODID:-//Tidarium//ZH'));
      expect(result.content, contains('SUMMARY:高等数学'));
      expect(result.content, contains('LOCATION:A101'));
      expect(result.content, contains('DESCRIPTION:教师：张老师'));
      expect(result.content, contains('TRIGGER:-PT15M'));
      expect('BEGIN:VEVENT'.allMatches(result.content).length, 3);
      expect(
        result.content,
        contains('DTSTART;TZID=Asia/Shanghai:20260831T080000'),
      );
      expect(result.fileName, 'Tidarium-20260901-1030.ics');
    });

    test('escapes calendar text', () {
      final data = TimetableData(
        config: TimetableConfig(
          semesterStart: DateTime(2026, 9, 2),
          totalWeeks: 2,
        ),
        timeSlots: defaultTimeSlots,
        courses: [
          _course(
            id: 'c1',
            name: '数学, 分析;实验',
            day: 1,
            start: 1,
            end: 1,
            weeks: {1},
          ),
        ],
      );

      final result = buildIcsExport(data, now: DateTime(2026, 9, 1));
      expect(result.content, contains(r'SUMMARY:数学\, 分析\;实验'));
    });
  });

  group('ICS import', () {
    test('round-trips an exported timetable', () {
      final data = _data();
      final exported = buildIcsExport(data, now: DateTime(2026, 9, 1));
      final preview = parseIcsImport(exported.content, data: data);

      expect(preview.eventCount, 3);
      expect(preview.matchedEventCount, 3);
      expect(preview.skipped, isEmpty);
      expect(preview.usedInferredSemesterStart, isFalse);
      expect(preview.courses, hasLength(2));

      final math = preview.courses.firstWhere(
        (course) => course.name == '高等数学',
      );
      expect(math.weeks, {1, 2});
      expect(math.startSection, 1);
      expect(math.endSection, 2);
      expect(math.teacher, '张老师');
      expect(math.location, 'A101');
    });

    test('infers the semester start when it is not configured', () {
      final data = _data();
      final exported = buildIcsExport(data, now: DateTime(2026, 9, 1));
      final withoutStart = TimetableData(
        config: const TimetableConfig(totalWeeks: 4),
        timeSlots: defaultTimeSlots,
        courses: const [],
      );

      final preview = parseIcsImport(exported.content, data: withoutStart);

      expect(preview.usedInferredSemesterStart, isTrue);
      expect(preview.semesterStart, DateTime(2026, 8, 31));
      expect(preview.courses, isNotEmpty);
    });

    test('skips events that do not match existing slots', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:午休课程
DTSTART;TZID=Asia/Shanghai:20260907T123000
DTEND;TZID=Asia/Shanghai:20260907T130000
END:VEVENT
END:VCALENDAR
''';

      final preview = parseIcsImport(ics, data: _data());

      expect(preview.courses, isEmpty);
      expect(preview.skipped.single, contains('不匹配'));
    });

    test('expands a simple weekly RRULE', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:体育
DTSTART;TZID=Asia/Shanghai:20260831T080000
DTEND;TZID=Asia/Shanghai:20260831T084500
RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=2
END:VEVENT
END:VCALENDAR
''';

      final preview = parseIcsImport(ics, data: _data());

      expect(preview.courses.single.weeks, {1, 2});
    });
  });
}
