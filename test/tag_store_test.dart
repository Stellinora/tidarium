import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/tags/data/drift_tag_store.dart';
import 'package:tidarium/features/tags/model/tag.dart';
import 'package:tidarium/features/todos/data/drift_todo_store.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

void main() {
  group('normalizeTagName', () {
    test('去掉首尾空白并折叠内部空白', () {
      expect(normalizeTagName('  作业   一  '), '作业 一');
    });

    test('全角转半角并转小写', () {
      expect(normalizeTagName('ＤＤＬ'), 'ddl');
    });

    test('空串归一化为空', () {
      expect(normalizeTagName('   '), '');
    });
  });

  group('DriftTagStore', () {
    late AppDatabase database;
    late DriftTagStore store;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      store = DriftTagStore(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('同 profile 内按归一化名称去重', () async {
      final first = await store.upsertByName('p1', '作业');
      final second = await store.upsertByName('p1', ' 作业 ');
      expect(second.id, first.id);
      expect(await store.all('p1'), hasLength(1));
    });

    test('不同 profile 可以重名', () async {
      await store.upsertByName('p1', '作业');
      await store.upsertByName('p2', '作业');
      expect(await store.all('p1'), hasLength(1));
      expect(await store.all('p2'), hasLength(1));
    });

    test('设置标签时忽略不属于该 profile 的 id', () async {
      final tag = await store.upsertByName('p1', '作业');
      final other = await store.upsertByName('p2', '作业');
      await store.setTodoTags(
        'todo_1',
        [tag.id, other.id, 'missing'],
        profileId: 'p1',
      );

      final ids = await store.tagIdsOf('todo_1');
      expect(ids, [tag.id]);
    });

    test('删除标签会清理关联', () async {
      final tag = await store.upsertByName('p1', '作业');
      await store.setTodoTags('todo_1', [tag.id]);
      await store.delete(tag.id);

      expect(await store.tagIdsOf('todo_1'), isEmpty);
      expect(await store.all('p1'), isEmpty);
    });

    test('批量查询按待办分组', () async {
      final a = await store.upsertByName('p1', '作业');
      final b = await store.upsertByName('p1', '英语');
      await store.setTodoTags('t1', [a.id]);
      await store.setTodoTags('t2', [a.id, b.id]);

      final grouped = await store.tagIdsOfMany(['t1', 't2', 't3']);
      expect(grouped['t1'], [a.id]);
      expect(grouped['t2'], hasLength(2));
      expect(grouped['t3'], isEmpty);
    });
  });

  test('标签随 profile 隔离到待办查询', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final todoStore = DriftTodoStore(database);
    final now = DateTime(2026, 11, 10, 9);
    await todoStore.upsert(
      TodoItem(
        id: 't1',
        title: '写作业',
        dueAt: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
        profileId: 'p1',
        ownerId: 'o1',
      ),
    );
    await todoStore.upsert(
      TodoItem(
        id: 't2',
        title: '社团开会',
        dueAt: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
        profileId: 'p2',
        ownerId: 'o2',
      ),
    );

    final p1 = await todoStore.all(profileId: 'p1');
    expect(p1.map((item) => item.id), ['t1']);

    await database.close();
  });
}
