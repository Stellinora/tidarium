import 'dart:async';

import '../model/todo_item.dart';

abstract interface class TodoStore {
  Future<List<TodoItem>> all();

  Stream<List<TodoItem>> watchAll();

  Future<void> upsert(TodoItem item);

  Future<void> delete(String id);
}

class InMemoryTodoStore implements TodoStore {
  InMemoryTodoStore({List<TodoItem> initial = const []}) {
    for (final item in initial) {
      _items[item.id] = item;
    }
  }

  final Map<String, TodoItem> _items = {};
  final _controller = StreamController<List<TodoItem>>.broadcast();

  @override
  Future<List<TodoItem>> all() async => _sorted();

  @override
  Stream<List<TodoItem>> watchAll() async* {
    yield await all();
    yield* _controller.stream;
  }

  @override
  Future<void> upsert(TodoItem item) async {
    _items[item.id] = item;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  List<TodoItem> _sorted() {
    final items = _items.values.toList(growable: false);
    items.sort((a, b) {
      final byDue = a.dueAt.compareTo(b.dueAt);
      if (byDue != 0) return byDue;
      return a.createdAt.compareTo(b.createdAt);
    });
    return items;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_sorted());
    }
  }
}
