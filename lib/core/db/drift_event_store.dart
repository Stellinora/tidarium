import 'package:drift/drift.dart';

import '../model/standard_event.dart';
import 'app_database.dart';
import 'event_store.dart';

class DriftEventStore implements EventStore {
  DriftEventStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<StandardEvent>> all() async {
    final rows = await _db.select(_db.standardEvents).get();
    return rows.map(_toEvent).toList(growable: false);
  }

  @override
  Stream<List<StandardEvent>> watchAll() {
    return _db
        .select(_db.standardEvents)
        .watch()
        .map((rows) => rows.map(_toEvent).toList(growable: false));
  }

  @override
  Future<void> upsertAll(Iterable<StandardEvent> events) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final event in events) {
      await _db
          .into(_db.standardEvents)
          .insertOnConflictUpdate(
            StandardEventsCompanion.insert(
              id: event.id,
              type: event.type.wireName,
              title: event.title,
              dueTime: Value(event.dueTime?.millisecondsSinceEpoch),
              source: event.source,
              fetchedAt: now,
            ),
          );
    }
  }

  @override
  Future<void> clear() {
    return _db.delete(_db.standardEvents).go();
  }

  StandardEvent _toEvent(StandardEventRow row) {
    return StandardEvent(
      id: row.id,
      type: EventType.parse(row.type),
      title: row.title,
      source: row.source,
      dueTime: row.dueTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.dueTime!),
    );
  }
}
