import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../model/todo_item.dart';
import 'todo_store.dart';

class DriftTodoStore implements TodoStore {
  DriftTodoStore(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$TodosTable, TodoRow> _query({String? profileId}) {
    final query = _db.select(_db.todos);
    if (profileId != null && profileId.isNotEmpty) {
      // 兼容迁移期尚未回填的空 profileId（启动 bootstrap 会补齐）。
      query.where(
        (table) =>
            table.profileId.equals(profileId) | table.profileId.equals(''),
      );
    }
    query.orderBy([
      (table) => OrderingTerm(expression: table.dueAt),
      (table) => OrderingTerm(expression: table.createdAt),
    ]);
    return query;
  }

  @override
  Future<List<TodoItem>> all({String? profileId}) async {
    final rows = await _query(profileId: profileId).get();
    return rows.map(_toItem).toList(growable: false);
  }

  @override
  Stream<List<TodoItem>> watchAll({String? profileId}) {
    return _query(
      profileId: profileId,
    ).watch().map((rows) => rows.map(_toItem).toList(growable: false));
  }

  @override
  Future<void> upsert(TodoItem item) {
    return _db
        .into(_db.todos)
        .insertOnConflictUpdate(
          TodosCompanion.insert(
            id: item.id,
            title: item.title,
            note: Value(item.note),
            dueAt: item.dueAt.millisecondsSinceEpoch,
            source: Value(item.source),
            completed: Value(item.completed),
            completedAt: Value(item.completedAt?.millisecondsSinceEpoch),
            createdAt: item.createdAt.millisecondsSinceEpoch,
            updatedAt: item.updatedAt.millisecondsSinceEpoch,
            profileId: Value(item.profileId),
            ownerId: Value(item.ownerId),
          ),
        );
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.todos)..where((table) => table.id.equals(id))).go();
  }

  @override
  Future<int> reassignOwner({
    required Iterable<String> fromOwnerIds,
    required String toOwnerId,
    required String profileId,
  }) {
    final sources = fromOwnerIds.toList(growable: false);
    if (sources.isEmpty) return Future<int>.value(0);

    return (_db.update(_db.todos)..where(
          (table) =>
              table.profileId.equals(profileId) &
              table.ownerId.isIn(sources),
        ))
        .write(
          TodosCompanion(
            ownerId: Value(toOwnerId),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  TodoItem _toItem(TodoRow row) {
    return TodoItem(
      id: row.id,
      title: row.title,
      note: row.note,
      dueAt: DateTime.fromMillisecondsSinceEpoch(row.dueAt),
      source: row.source,
      completed: row.completed,
      completedAt: row.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      profileId: row.profileId,
      ownerId: row.ownerId,
    );
  }
}

