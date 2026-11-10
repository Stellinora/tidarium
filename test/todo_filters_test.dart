import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';
import 'package:tidarium/features/todos/todo_filters.dart';

TodoItem _todo(
  String id,
  DateTime dueAt, {
  bool completed = false,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 9, 1);
  return TodoItem(
    id: id,
    title: id,
    dueAt: dueAt,
    completed: completed,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  final now = DateTime(2026, 9, 7, 12);

  test('filters tomorrow todos', () {
    final todos = [
      _todo('today', DateTime(2026, 9, 7, 18)),
      _todo('tomorrow', DateTime(2026, 9, 8, 10)),
      _todo('later', DateTime(2026, 9, 9, 10)),
    ];

    final result = todosDueOn(todos, DateTime(2026, 9, 8));
    expect(result.map((todo) => todo.id), ['tomorrow']);
  });

  test('keeps overdue and future todos out of today and tomorrow', () {
    final todos = [
      _todo('today', DateTime(2026, 9, 7, 18)),
      _todo('tomorrow', DateTime(2026, 9, 8, 10)),
      _todo('overdue', DateTime(2026, 9, 6, 10)),
      _todo('later', DateTime(2026, 9, 9, 10)),
      _todo(
        'overdue-completed',
        DateTime(2026, 9, 6, 9),
        completed: true,
      ),
    ];

    final result = todosOutsideTodayAndTomorrow(todos, now);
    expect(result.map((todo) => todo.id), [
      'overdue',
      'later',
      'overdue-completed',
    ]);
  });

  test('puts completed todos after active ones', () {
    final todos = [
      _todo('done', DateTime(2026, 9, 9, 9), completed: true),
      _todo('active', DateTime(2026, 9, 10, 9)),
    ];

    final result = todosOutsideTodayAndTomorrow(todos, now);
    expect(result.map((todo) => todo.id), ['active', 'done']);
  });
}
