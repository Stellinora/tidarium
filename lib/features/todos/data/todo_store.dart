import 'dart:async';

import '../model/todo_item.dart';

abstract interface class TodoStore {
  /// [profileId] 非空时只返回该课表下的待办。
  Future<List<TodoItem>> all({String? profileId});

  Stream<List<TodoItem>> watchAll({String? profileId});

  Future<void> upsert(TodoItem item);

  Future<void> delete(String id);

  /// 把一组归属下的待办整体改挂到另一个归属，返回改动条数。
  Future<int> reassignOwner({
    required Iterable<String> fromOwnerIds,
    required String toOwnerId,
    required String profileId,
  });

  /// 把一个课表下的待办整体迁到另一个课表，并统一改挂到指定归属。
  Future<int> moveToProfile({
    required String fromProfileId,
    required String toProfileId,
    required String ownerId,
  });

  /// 删除某个课表下的全部待办，返回删除条数。
  Future<int> deleteProfile(String profileId);
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

  @override
  Future<int> reassignOwner({
    required Iterable<String> fromOwnerIds,
    required String toOwnerId,
    required String profileId,
  }) async {
    final sources = fromOwnerIds.toSet();
    var changed = 0;
    for (final entry in _items.entries.toList(growable: false)) {
      final item = entry.value;
      if (item.profileId != profileId) continue;
      if (!sources.contains(item.ownerId)) continue;
      _items[entry.key] = item.copyWith(
        ownerId: toOwnerId,
        updatedAt: DateTime.now(),
      );
      changed += 1;
    }
    if (changed > 0) _emit();
    return changed;
  }

  @override
  Future<int> moveToProfile({
    required String fromProfileId,
    required String toProfileId,
    required String ownerId,
  }) async {
    final now = DateTime.now();
    var changed = 0;
    for (final entry in _items.entries.toList(growable: false)) {
      final item = entry.value;
      if (item.profileId != fromProfileId) continue;
      _items[entry.key] = item.copyWith(
        profileId: toProfileId,
        ownerId: ownerId,
        updatedAt: now,
      );
      changed += 1;
    }
    if (changed > 0) _emit();
    return changed;
  }

  @override
  Future<int> deleteProfile(String profileId) async {
    final before = _items.length;
    _items.removeWhere((_, item) => item.profileId == profileId);
    final changed = before - _items.length;
    if (changed > 0) _emit();
    return changed;
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




