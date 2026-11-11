import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/owners/data/drift_owner_store.dart';
import 'package:tidarium/features/owners/data/owner_store.dart';
import 'package:tidarium/features/profiles/storage_bootstrap.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/model/timetable_library.dart';
import 'package:tidarium/features/todos/data/drift_todo_store.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

TimetableLibrary _library() {
  final a = TimetableData.initial(
    id: 'p1',
    name: '主课表',
    now: DateTime(2026, 9, 7),
  );
  final b = TimetableData.initial(
    id: 'p2',
    name: '社团课表',
    now: DateTime(2026, 9, 7),
  );
  return TimetableLibrary(
    activeId: 'p1',
    timetables: [a, b],
    primaryId: 'p1',
  );
}

void main() {
  late AppDatabase database;
  late DriftOwnerStore owners;
  late DriftTodoStore todos;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    owners = DriftOwnerStore(database);
    todos = DriftTodoStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('为每张课表补建默认组，并把旧待办回填到主课表', () async {
    final now = DateTime(2026, 11, 10, 8);
    await todos.upsert(
      TodoItem(
        id: 't1',
        title: '旧数据',
        dueAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await StorageBootstrap(
      database: database,
      owners: owners,
      library: _library(),
    ).run();

    expect(await owners.findDefault('p1'), isNotNull);
    expect(await owners.findDefault('p2'), isNotNull);

    final loaded = (await todos.all()).single;
    expect(loaded.profileId, 'p1');
    expect(loaded.ownerId, defaultOwnerId('p1'));
  });

  test('重复执行不会重复创建归属', () async {
    final bootstrap = StorageBootstrap(
      database: database,
      owners: owners,
      library: _library(),
    );
    await bootstrap.run();
    await bootstrap.run();

    expect(await owners.all('p1'), hasLength(1));
    expect(await owners.all('p2'), hasLength(1));
  });

  test('已经带 profileId 的待办不会被改动', () async {
    final now = DateTime(2026, 11, 10, 8);
    await owners.upsert(buildDefaultOwner('p2'));
    final clubOwner = await owners.findDefault('p2');
    await todos.upsert(
      TodoItem(
        id: 't2',
        title: '社团任务',
        dueAt: now,
        createdAt: now,
        updatedAt: now,
        profileId: 'p2',
        ownerId: clubOwner!.id,
      ),
    );

    await StorageBootstrap(
      database: database,
      owners: owners,
      library: _library(),
    ).run();

    final loaded = (await todos.all()).single;
    expect(loaded.profileId, 'p2');
    expect(loaded.ownerId, clubOwner.id);
  });
}
