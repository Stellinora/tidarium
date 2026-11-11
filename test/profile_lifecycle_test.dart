import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/owners/data/drift_owner_store.dart';
import 'package:tidarium/features/owners/data/owner_store.dart';
import 'package:tidarium/features/profiles/profile_lifecycle.dart';
import 'package:tidarium/features/tags/data/drift_tag_store.dart';
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

TodoItem _todo(String id, String profileId, String ownerId) {
  final now = DateTime(2026, 11, 10, 9);
  return TodoItem(
    id: id,
    title: id,
    dueAt: now,
    createdAt: now,
    updatedAt: now,
    profileId: profileId,
    ownerId: ownerId,
  );
}

void main() {
  late AppDatabase database;
  late DriftOwnerStore owners;
  late DriftTagStore tags;
  late DriftTodoStore todos;
  late ProfileLifecycle lifecycle;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    owners = DriftOwnerStore(database);
    tags = DriftTagStore(database);
    todos = DriftTodoStore(database);
    lifecycle = ProfileLifecycle(owners: owners, tags: tags, todos: todos);
  });

  tearDown(() async {
    await database.close();
  });

  test('只剩一张课表时拒绝删除', () async {
    await owners.upsert(buildDefaultOwner('p1'));
    final single = TimetableLibrary(
      activeId: 'p1',
      timetables: [
        TimetableData.initial(id: 'p1', now: DateTime(2026, 9, 7)),
      ],
    );

    await expectLater(
      lifecycle.deleteProfile(
        library: single,
        profileId: 'p1',
        strategy: ProfileDeleteStrategy.deleteAll,
      ),
      throwsA(isA<ProfileLifecycleError>()),
    );
  });

  test('全删策略会清掉该课表的待办、归属与标签', () async {
    await owners.upsert(buildDefaultOwner('p1'));
    await owners.upsert(buildDefaultOwner('p2'));
    await todos.upsert(_todo('t1', 'p2', defaultOwnerId('p2')));
    await tags.upsertByName('p2', '社团');

    final outcome = await lifecycle.deleteProfile(
      library: _library(),
      profileId: 'p2',
      strategy: ProfileDeleteStrategy.deleteAll,
    );

    expect(outcome.deletedTodos, 1);
    expect(await todos.all(profileId: 'p2'), isEmpty);
    expect(await owners.all('p2'), isEmpty);
    expect(await tags.all('p2'), isEmpty);
    expect(await todos.all(profileId: 'p1'), isEmpty);
  });

  test('迁移策略把待办搬到主课表默认组，并复用同名标签', () async {
    await owners.upsert(buildDefaultOwner('p1'));
    await owners.upsert(buildDefaultOwner('p2'));
    final existing = await tags.upsertByName('p1', '社团');
    final source = await tags.upsertByName('p2', '社团');
    await tags.upsertByName('p2', '活动');

    await todos.upsert(_todo('t1', 'p2', defaultOwnerId('p2')));
    await tags.setTodoTags('t1', [source.id], profileId: 'p2');

    final outcome = await lifecycle.deleteProfile(
      library: _library(),
      profileId: 'p2',
      strategy: ProfileDeleteStrategy.migrateToPrimary,
    );

    expect(outcome.movedTodos, 1);

    final moved = (await todos.all(profileId: 'p1')).single;
    expect(moved.ownerId, defaultOwnerId('p1'));

    final p1Tags = await tags.all('p1');
    expect(p1Tags.map((tag) => tag.name).toSet(), {'社团', '活动'});

    final linked = await tags.tagIdsOf('t1');
    expect(linked, [existing.id]);

    expect(await owners.all('p2', includeArchived: true), isEmpty);
  });

  test('删除主课表后 primary 顺延到剩下的课表', () async {
    await owners.upsert(buildDefaultOwner('p1'));
    await owners.upsert(buildDefaultOwner('p2'));

    final outcome = await lifecycle.deleteProfile(
      library: _library(),
      profileId: 'p1',
      strategy: ProfileDeleteStrategy.deleteAll,
    );

    expect(outcome.library.primaryId, 'p2');
    expect(outcome.library.timetables.single.id, 'p2');
  });

  test('setPrimary 只改主课表，不动数据', () async {
    final updated = lifecycle.setPrimary(_library(), 'p2');
    expect(updated.primaryId, 'p2');
    expect(updated.activeId, 'p1');
  });
}

