import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/model/standard_event.dart';
import 'package:tidarium/features/home/today_agenda.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';

Course _course({
  required String id,
  required String name,
  int day = 1,
  Set<int> weeks = const {1},
  int startSection = 1,
  int endSection = 2,
}) {
  return Course(
    id: id,
    name: name,
    day: day,
    startSection: startSection,
    endSection: endSection,
    weeks: weeks,
    colorIndex: 0,
  );
}

void main() {
  final monday = DateTime(2026, 9, 7);
  final config = TimetableConfig(semesterStart: monday, totalWeeks: 20);

  test('merges today courses and today events by time', () {
    final data = TimetableData(
      config: config,
      timeSlots: defaultTimeSlots,
      courses: [
        _course(id: 'today', name: '今天的课'),
        _course(id: 'other-day', name: '明天的课', day: 2),
        _course(id: 'other-week', name: '下周的课', weeks: {2}),
      ],
    );
    final events = [
      StandardEvent(
        id: 'today-event',
        type: EventType.assignment,
        title: '今天的作业',
        source: 'chaoxing',
        dueTime: DateTime(2026, 9, 7, 10),
      ),
      StandardEvent(
        id: 'tomorrow-event',
        type: EventType.assignment,
        title: '明天的作业',
        source: 'chaoxing',
        dueTime: DateTime(2026, 9, 8, 10),
      ),
    ];

    final agenda = buildTodayAgenda(
      data: data,
      events: events,
      now: DateTime(2026, 9, 7, 10),
    );

    expect(agenda.status, TodayAgendaStatus.normal);
    expect(agenda.weekNumber, 1);
    expect(agenda.items, hasLength(2));
    expect(agenda.items[0].course?.name, '今天的课');
    expect(agenda.items[0].finished, isTrue);
    expect(agenda.items[1].event?.title, '今天的作业');
    expect(agenda.items[1].finished, isFalse);
  });

  test('still shows today events without a semester start', () {
    final data = TimetableData(
      config: const TimetableConfig(semesterStart: null),
      timeSlots: defaultTimeSlots,
      courses: [_course(id: 'today', name: '今天的课')],
    );

    final agenda = buildTodayAgenda(
      data: data,
      events: [
        StandardEvent(
          id: 'event',
          type: EventType.assignment,
          title: '作业',
          source: 'mooc',
          dueTime: DateTime(2026, 9, 7, 12),
        ),
      ],
      now: DateTime(2026, 9, 7, 9),
    );

    expect(agenda.status, TodayAgendaStatus.noSemester);
    expect(agenda.items, hasLength(1));
    expect(agenda.items.single.event?.title, '作业');
  });
}
