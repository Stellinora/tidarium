import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/standard_event.dart';
import '../timetable/model/course.dart';
import '../timetable/model/timetable_config.dart';
import '../timetable/model/timetable_data.dart';
import '../timetable/timetable_providers.dart';
import '../timetable/timetable_time.dart';
import '../todos/model/todo_item.dart';
import '../todos/todo_providers.dart';
import 'home_providers.dart';

enum TodayAgendaStatus { normal, noSemester, beforeSemester, afterSemester }

enum AgendaItemType { course, event, todo }

class AgendaItem {
  const AgendaItem({
    required this.type,
    required this.start,
    required this.end,
    required this.finished,
    this.course,
    this.event,
    this.todo,
  });

  final AgendaItemType type;
  final DateTime? start;
  final DateTime? end;
  final bool finished;
  final Course? course;
  final StandardEvent? event;
  final TodoItem? todo;
}

class TodayAgenda {
  const TodayAgenda({
    required this.date,
    required this.status,
    required this.weekNumber,
    required this.tableName,
    required this.items,
  });

  final DateTime date;
  final TodayAgendaStatus status;
  final int? weekNumber;
  final String tableName;
  final List<AgendaItem> items;

  bool get isEmpty => items.isEmpty;
}

/// 某一天的课程集合（用于「今日课程 / 明日课程」分区）。
class DayCourses {
  const DayCourses({
    required this.date,
    required this.status,
    required this.weekNumber,
    required this.courses,
  });

  final DateTime date;
  final TodayAgendaStatus status;
  final int? weekNumber;
  final List<AgendaItem> courses;

  bool get isEmpty => courses.isEmpty;
}

final tomorrowCoursesProvider = FutureProvider<DayCourses>((ref) async {
  final data = ref.watch(timetableProvider);
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return buildDayCourses(data: data, date: tomorrow, now: now);
});

DayCourses buildDayCourses({
  required TimetableData data,
  required DateTime date,
  required DateTime now,
}) {
  final config = data.config;
  final day = DateTime(date.year, date.month, date.day);
  final weekNumber = weekNumberFor(
    day,
    config.semesterStart,
    firstWeekday: config.firstWeekday,
  );
  final status = _statusFor(config, weekNumber);
  final items = _courseItemsFor(
    data: data,
    date: day,
    now: now,
    weekNumber: weekNumber,
    status: status,
  );
  return DayCourses(
    date: day,
    status: status,
    weekNumber: weekNumber,
    courses: List.unmodifiable(items),
  );
}

TodayAgendaStatus _statusFor(TimetableConfig config, int? weekNumber) {
  if (config.semesterStart == null) return TodayAgendaStatus.noSemester;
  if (weekNumber == null || weekNumber < 1) {
    return TodayAgendaStatus.beforeSemester;
  }
  if (weekNumber > config.totalWeeks) return TodayAgendaStatus.afterSemester;
  return TodayAgendaStatus.normal;
}

List<AgendaItem> _courseItemsFor({
  required TimetableData data,
  required DateTime date,
  required DateTime now,
  required int? weekNumber,
  required TodayAgendaStatus status,
}) {
  if (status != TodayAgendaStatus.normal || weekNumber == null) {
    return const [];
  }
  final slots = {for (final slot in data.timeSlots) slot.number: slot};
  final items = <AgendaItem>[];
  for (final course in data.courses) {
    if (course.day != date.weekday || !course.weeks.contains(weekNumber)) {
      continue;
    }
    final startSlot = slots[course.startSection];
    final endSlot = slots[course.endSection];
    if (startSlot == null || endSlot == null) continue;

    final start = _atMinutes(date, startSlot.startMinutes);
    final end = _atMinutes(date, endSlot.endMinutes);
    items.add(
      AgendaItem(
        type: AgendaItemType.course,
        start: start,
        end: end,
        finished: !end.isAfter(now) && _sameDay(date, now),
        course: course,
      ),
    );
  }
  items.sort((a, b) {
    final aStart = a.start;
    final bStart = b.start;
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1;
    if (bStart == null) return -1;
    return aStart.compareTo(bStart);
  });
  return items;
}

final todayAgendaProvider = FutureProvider<TodayAgenda>((ref) async {
  final data = ref.watch(timetableProvider);
  final events = ref.watch(eventsProvider).value ?? const <StandardEvent>[];
  final todos = ref.watch(todosProvider).value ?? const <TodoItem>[];
  return buildTodayAgenda(
    data: data,
    events: events,
    todos: todos,
    now: DateTime.now(),
  );
});

TodayAgenda buildTodayAgenda({
  required TimetableData data,
  required List<StandardEvent> events,
  required DateTime now,
  List<TodoItem> todos = const [],
}) {
  final today = dateOnly(now);
  final config = data.config;
  final weekNumber = weekNumberFor(
    today,
    config.semesterStart,
    firstWeekday: config.firstWeekday,
  );

  final status = _statusFor(config, weekNumber);
  final items = <AgendaItem>[
    ..._courseItemsFor(
      data: data,
      date: today,
      now: now,
      weekNumber: weekNumber,
      status: status,
    ),
  ];

  for (final event in events) {
    final due = event.dueTime?.toLocal();
    if (due == null || !_sameDay(due, today)) continue;
    items.add(
      AgendaItem(
        type: AgendaItemType.event,
        start: due,
        end: due,
        finished: due.isBefore(now),
        event: event,
      ),
    );
  }

  for (final todo in todos) {
    if (!_sameDay(todo.dueAt, today)) continue;
    items.add(
      AgendaItem(
        type: AgendaItemType.todo,
        start: todo.dueAt,
        end: todo.dueAt,
        finished: todo.completed,
        todo: todo,
      ),
    );
  }

  items.sort((a, b) {
    final aStart = a.start;
    final bStart = b.start;
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1;
    if (bStart == null) return -1;
    final byStart = aStart.compareTo(bStart);
    if (byStart != 0) return byStart;
    return a.type.index.compareTo(b.type.index);
  });

  return TodayAgenda(
    date: today,
    status: status,
    weekNumber: weekNumber,
    tableName: config.name,
    items: List.unmodifiable(items),
  );
}

DateTime _atMinutes(DateTime date, int minutes) {
  final safe = minutes.clamp(0, 24 * 60 - 1);
  return DateTime(date.year, date.month, date.day, safe ~/ 60, safe % 60);
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}


