import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../model/todo_item.dart';
import 'todo_store.dart';

class DriftTodoStore implements TodoStore {
  DriftTodoStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<TodoItem>> all() async {
    final rows = await (_db.select(
      _db.todos,
    )..orderBy([(table) => OrderingTerm(expression: table.dueAt)])).get();
    return rows.map(_toItem).toList(growable: false);
  }

  @override
  Stream<List<TodoItem>> watchAll() {
    final query = _db.select(_db.todos)
      ..orderBy([
        (table) => OrderingTerm(expression: table.dueAt),
        (table) => OrderingTerm(expression: table.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toItem).toList(growable: false),
    );
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
          ),
        );
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.todos)..where((table) => table.id.equals(id))).go();
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
    );
  }
}
