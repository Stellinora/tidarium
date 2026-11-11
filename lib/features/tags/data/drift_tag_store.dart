import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../model/tag.dart';
import 'tag_store.dart';

class DriftTagStore implements TagStore {
  DriftTagStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<Tag>> all(String profileId) async {
    final rows = await _baseQuery(profileId).get();
    return rows.map(_toTag).toList(growable: false);
  }

  @override
  Stream<List<Tag>> watchAll(String profileId) {
    return _baseQuery(
      profileId,
    ).watch().map((rows) => rows.map(_toTag).toList(growable: false));
  }

  SimpleSelectStatement<$TagsTable, TagRow> _baseQuery(String profileId) {
    final query = _db.select(_db.tags)
      ..where(
        (table) =>
            table.profileId.equals(profileId) & table.archived.equals(false),
      )
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    return query;
  }

  @override
  Future<Tag?> findByName(String profileId, String nameNorm) async {
    final row = await (_db.select(_db.tags)..where(
          (table) =>
              table.profileId.equals(profileId) &
              table.nameNorm.equals(nameNorm),
        ))
        .getSingleOrNull();
    return row == null ? null : _toTag(row);
  }

  @override
  Future<Tag> upsertByName(
    String profileId,
    String name, {
    int? colorIndex,
  }) async {
    final normalized = normalizeTagName(name);
    final existing = await findByName(profileId, normalized);
    if (existing != null) return existing;

    final now = DateTime.now();
    final tag = Tag(
      id: newTagId(),
      profileId: profileId,
      name: name.trim(),
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
    );
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: tag.id,
            profileId: tag.profileId,
            name: tag.name,
            nameNorm: normalized,
            colorIndex: Value(tag.colorIndex),
            createdAt: tag.createdAt.millisecondsSinceEpoch,
            updatedAt: tag.updatedAt.millisecondsSinceEpoch,
          ),
        );
    return tag;
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.tags)..where((table) => table.id.equals(id))).go();
    await (_db.delete(
      _db.todoTags,
    )..where((table) => table.tagId.equals(id))).go();
  }

  @override
  Future<List<String>> tagIdsOf(String todoId) async {
    final rows = await (_db.select(
      _db.todoTags,
    )..where((table) => table.todoId.equals(todoId))).get();
    return rows.map((row) => row.tagId).toList(growable: false);
  }

  @override
  Future<Map<String, List<String>>> tagIdsOfMany(List<String> todoIds) async {
    if (todoIds.isEmpty) return const {};
    final rows = await (_db.select(
      _db.todoTags,
    )..where((table) => table.todoId.isIn(todoIds))).get();
    final grouped = <String, List<String>>{
      for (final id in todoIds) id: <String>[],
    };
    for (final row in rows) {
      grouped.putIfAbsent(row.todoId, () => <String>[]).add(row.tagId);
    }
    return grouped;
  }

  @override
  Future<void> setTodoTags(
    String todoId,
    Iterable<String> tagIds, {
    String? profileId,
  }) async {
    var targetProfile = profileId ?? '';
    if (targetProfile.isEmpty) {
      final todo = await (_db.select(
        _db.todos,
      )..where((table) => table.id.equals(todoId))).getSingleOrNull();
      targetProfile = todo?.profileId ?? '';
    }

    final ids = tagIds.toSet();
    await (_db.delete(
      _db.todoTags,
    )..where((table) => table.todoId.equals(todoId))).go();
    for (final tagId in ids) {
      final tag = await (_db.select(
        _db.tags,
      )..where((table) => table.id.equals(tagId))).getSingleOrNull();
      if (tag == null) continue;
      if (targetProfile.isNotEmpty && tag.profileId != targetProfile) continue;
      await _db
          .into(_db.todoTags)
          .insert(
            TodoTagsCompanion.insert(todoId: todoId, tagId: tagId),
          );
    }
  }

  Tag _toTag(TagRow row) {
    return Tag(
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      colorIndex: row.colorIndex,
      archived: row.archived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
