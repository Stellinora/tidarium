import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../model/timetable_library.dart';
import 'timetable_store.dart';

class DriftTimetableStore extends TimetableStore {
  DriftTimetableStore(this._db);

  static const _libraryId = 'library';

  final AppDatabase _db;

  @override
  Future<TimetableLibrary?> loadLibrary() async {
    try {
      final row = await (_db.select(
        _db.timetablePayloads,
      )..where((table) => table.id.equals(_libraryId))).getSingleOrNull();
      if (row == null) return null;

      final decoded = jsonDecode(row.payloadJson);
      if (decoded is! Map) return null;
      return TimetableLibrary.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLibrary(TimetableLibrary library) async {
    await _db
        .into(_db.timetablePayloads)
        .insertOnConflictUpdate(
          TimetablePayloadsCompanion.insert(
            id: _libraryId,
            payloadJson: jsonEncode(library.toJson()),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> migrateFrom(TimetableStore legacy) async {
    if (await loadLibrary() != null) return;
    final library = await legacy.loadLibrary();
    if (library != null) {
      await saveLibrary(library);
    }
  }
}
