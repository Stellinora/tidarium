import 'model/todo_item.dart';

DateTime todoDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime todoAddDays(DateTime date, int days) {
  final shifted = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: days));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

bool todoIsSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<TodoItem> todosDueOn(List<TodoItem> todos, DateTime day) {
  final date = todoDateOnly(day);
  final next = todoAddDays(date, 1);
  final result = todos
      .where((todo) => !todo.dueAt.isBefore(date) && todo.dueAt.isBefore(next))
      .toList(growable: false);
  return _sortTodos(result, now: DateTime.now());
}

List<TodoItem> todosOutsideTodayAndTomorrow(
  List<TodoItem> todos,
  DateTime now,
) {
  final today = todoDateOnly(now);
  final dayAfterTomorrow = todoAddDays(today, 2);
  final result = todos
      .where(
        (todo) =>
            todo.dueAt.isBefore(today) ||
            !todo.dueAt.isBefore(dayAfterTomorrow),
      )
      .toList(growable: false);
  return _sortTodos(result, now: now);
}

List<TodoItem> _sortTodos(List<TodoItem> todos, {required DateTime now}) {
  final sorted = [...todos];
  sorted.sort((a, b) {
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final aOverdue = a.isOverdueAt(now);
    final bOverdue = b.isOverdueAt(now);
    if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
    final byDue = a.dueAt.compareTo(b.dueAt);
    if (byDue != 0) return byDue;
    return a.createdAt.compareTo(b.createdAt);
  });
  return List.unmodifiable(sorted);
}
