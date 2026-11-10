import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/home/today_agenda.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

void main() {
  test('includes today todos in the agenda', () {
    final date = DateTime(2026, 9, 7);
    final now = DateTime(2026, 9, 7, 9);
    final data = TimetableData.initial(now: date);
    final todo = TodoItem(
      id: 'today',
      title: '交作业',
      dueAt: DateTime(2026, 9, 7, 10),
      source: '高数老师',
      createdAt: date,
      updatedAt: date,
    );

    final agenda = buildTodayAgenda(
      data: data,
      events: const [],
      todos: [todo],
      now: now,
    );

    final item = agenda.items.singleWhere((item) => item.todo?.id == 'today');
    expect(item.finished, isFalse);
    expect(item.start, DateTime(2026, 9, 7, 10));
  });

  test('marks completed today todos as finished', () {
    final date = DateTime(2026, 9, 7);
    final data = TimetableData.initial(now: date);
    final todo = TodoItem(
      id: 'today',
      title: '交作业',
      dueAt: DateTime(2026, 9, 7, 10),
      completed: true,
      completedAt: DateTime(2026, 9, 7, 8),
      createdAt: date,
      updatedAt: date,
    );

    final agenda = buildTodayAgenda(
      data: data,
      events: const [],
      todos: [todo],
      now: DateTime(2026, 9, 7, 12),
    );

    expect(
      agenda.items.singleWhere((item) => item.todo?.id == 'today').finished,
      isTrue,
    );
  });
}
