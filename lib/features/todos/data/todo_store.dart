import 'dart:async';

import '../model/todo_item.dart';

abstract interface class TodoStore {
  /// [profileId] 非空时只返回该课表下的待办。
  Future<List<TodoItem>> all({String? profileId});

  Stream<List<TodoItem>> watchAll({String? profileId});

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
  Future<List<TodoItem>> all({String? profileId}) async =>
      _sorted(profileId: profileId);

  @override
  Stream<List<TodoItem>> watchAll({String? profileId}) async* {
    yield await all(profileId: profileId);
    yield* _controller.stream.map(
      (items) => profileId == null || profileId.isEmpty
          ? items
          : items
                .where(
                  (item) => item.profileId.isEmpty || item.profileId == profileId,
                )
                .toList(),
    );
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

  List<TodoItem> _sorted({String? profileId}) {
    final items = _items.values
        .where(
          (item) =>
              profileId == null ||
              profileId.isEmpty ||
              item.profileId.isEmpty ||
              item.profileId == profileId,
        )
        .toList(growable: false);
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


