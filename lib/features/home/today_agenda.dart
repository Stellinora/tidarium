import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/standard_event.dart';
import '../timetable/model/course.dart';
import '../timetable/model/timetable_data.dart';
import '../timetable/timetable_providers.dart';
import '../timetable/timetable_time.dart';
import 'home_providers.dart';

enum TodayAgendaStatus { normal, noSemester, beforeSemester, afterSemester }

enum AgendaItemType { course, event }

class AgendaItem {
  const AgendaItem({
    required this.type,
    required this.start,
    required this.end,
    required this.finished,
    this.course,
    this.event,
  });

  final AgendaItemType type;
  final DateTime? start;
  final DateTime? end;
  final bool finished;
  final Course? course;
  final StandardEvent? event;
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

final todayAgendaProvider = FutureProvider<TodayAgenda>((ref) async {
  final data = ref.watch(timetableProvider);
  final events = await ref.watch(eventsProvider.future);
  return buildTodayAgenda(data: data, events: events, now: DateTime.now());
});

TodayAgenda buildTodayAgenda({
  required TimetableData data,
  required List<StandardEvent> events,
  required DateTime now,
}) {
  final today = dateOnly(now);
  final config = data.config;
  final weekNumber = weekNumberFor(
    today,
    config.semesterStart,
    firstWeekday: config.firstWeekday,
  );

  final TodayAgendaStatus status;
  if (config.semesterStart == null) {
    status = TodayAgendaStatus.noSemester;
  } else if (weekNumber == null || weekNumber < 1) {
    status = TodayAgendaStatus.beforeSemester;
  } else if (weekNumber > config.totalWeeks) {
    status = TodayAgendaStatus.afterSemester;
  } else {
    status = TodayAgendaStatus.normal;
  }

  final slots = {for (final slot in data.timeSlots) slot.number: slot};
  final items = <AgendaItem>[];

  if (status == TodayAgendaStatus.normal && weekNumber != null) {
    for (final course in data.courses) {
      if (course.day != today.weekday || !course.weeks.contains(weekNumber)) {
        continue;
      }
      final startSlot = slots[course.startSection];
      final endSlot = slots[course.endSection];
      if (startSlot == null || endSlot == null) continue;

      final start = _atMinutes(today, startSlot.startMinutes);
      final end = _atMinutes(today, endSlot.endMinutes);
      items.add(
        AgendaItem(
          type: AgendaItemType.course,
          start: start,
          end: end,
          finished: !end.isAfter(now),
          course: course,
        ),
      );
    }
  }

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
