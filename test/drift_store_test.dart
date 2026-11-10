import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/core/db/drift_event_store.dart';
import 'package:tidarium/core/model/standard_event.dart';
import 'package:tidarium/features/timetable/data/drift_timetable_store.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/todos/data/drift_todo_store.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('persists and toggles todos', () async {
    final store = DriftTodoStore(database);
    final now = DateTime(2026, 9, 7, 12);
    final todo = TodoItem(
      id: 't1',
      title: '高数作业',
      note: '第一章',
      dueAt: DateTime(2026, 9, 8, 23, 59),
      source: '高数老师',
      createdAt: now,
      updatedAt: now,
    );

    await store.upsert(todo);
    var loaded = await store.all();
    expect(loaded, hasLength(1));
    expect(loaded.single.title, '高数作业');
    expect(loaded.single.source, '高数老师');

    final completedAt = DateTime(2026, 9, 7, 13);
    await store.upsert(
      todo.copyWith(
        completed: true,
        completedAt: completedAt,
        updatedAt: completedAt,
      ),
    );
    loaded = await store.all();
    expect(loaded.single.completed, isTrue);
    expect(loaded.single.completedAt, completedAt);

    await store.delete('t1');
    expect(await store.all(), isEmpty);
  });

  test('persists events', () async {
    final store = DriftEventStore(database);
    final due = DateTime(2026, 9, 8, 23, 59);
    await store.upsertAll([
      StandardEvent(
        id: 'e1',
        type: EventType.assignment,
        title: '提交作业',
        source: 'chaoxing',
        dueTime: due,
      ),
    ]);

    final events = await store.all();
    expect(events, hasLength(1));
    expect(events.single.title, '提交作业');
    expect(events.single.dueTime, due);

    await store.clear();
    expect(await store.all(), isEmpty);
  });

  test('migrates the legacy timetable library once', () async {
    final legacy = InMemoryTimetableStore(
      initial: TimetableData.initial(
        now: DateTime(2026, 9, 7),
        name: '测试课表',
      ),
    );
    final store = DriftTimetableStore(database);

    await store.migrateFrom(legacy);
    final loaded = await store.loadLibrary();
    expect(loaded, isNotNull);
    expect(loaded!.active.config.name, '测试课表');

    await store.saveLibrary(loaded.replace(loaded.active));
    await store.migrateFrom(legacy);
    expect((await store.loadLibrary())!.active.config.name, '测试课表');
  });
}
