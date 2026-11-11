import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/db/app_database.dart';
import '../../features/timetable/model/timetable_library.dart';
import '../owners/data/owner_store.dart';
import '../owners/model/owner.dart';

/// 启动时的一次性数据准备：
/// 1. 为每张课表补建默认归属；
/// 2. 把 v1 升级上来的待办回填 profileId 与 ownerId。
///
/// 幂等，可以重复执行。
class StorageBootstrap {
  StorageBootstrap({
    required this.database,
    required this.owners,
    required this.library,
  });

  final AppDatabase database;
  final OwnerStore owners;
  final TimetableLibrary library;

  Future<void> run() async {
    final primaryId = library.primaryId;

    for (final timetable in library.timetables) {
      final existing = await owners.findDefault(timetable.id);
      if (existing == null) {
        await owners.upsert(buildDefaultOwner(timetable.id));
      }
    }

    await _backfillTodos(primaryId);
  }

  Future<void> _backfillTodos(String primaryId) async {
    final rows = await database.select(database.todos).get();
    for (final row in rows) {
      final profileId = row.profileId.isEmpty ? primaryId : row.profileId;
      var ownerId = row.ownerId;
      if (ownerId.isEmpty) {
        var owner = await owners.findDefault(profileId);
        owner ??= await _ensureDefault(profileId);
        ownerId = owner.id;
      }
      if (profileId == row.profileId && ownerId == row.ownerId) continue;

      await (database.update(
        database.todos,
      )..where((table) => table.id.equals(row.id))).write(
        TodosCompanion(
          profileId: Value(profileId),
          ownerId: Value(ownerId),
        ),
      );
      debugPrint('bootstrap: todo ${row.id} -> $profileId / $ownerId');
    }
  }

  Future<Owner> _ensureDefault(String profileId) async {
    final owner = buildDefaultOwner(profileId);
    await owners.upsert(owner);
    return owner;
  }
}

