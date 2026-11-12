import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/import/draft_committer.dart';
import 'package:tidarium/features/import/model/import_draft.dart';
import 'package:tidarium/features/owners/data/drift_owner_store.dart';
import 'package:tidarium/features/owners/data/owner_store.dart';
import 'package:tidarium/features/owners/model/owner.dart';
import 'package:tidarium/features/tags/data/drift_tag_store.dart';
import 'package:tidarium/features/todos/data/drift_todo_store.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

ImportDraft _draft(
  String id,
  String title, {
  DateTime? dueAt,
  List<String> materials = const [],
  String? ownerId,
  OwnerKind kind = OwnerKind.personal,
}) {
  return ImportDraft(
    id: id,
    title: title,
    dueAt: dueAt,
    materials: materials,
    ownerId: ownerId,
    kind: kind,
  );
}

void main() {
  late AppDatabase database;
  late DriftTodoStore todos;
  late DriftTagStore tags;
  late DriftOwnerStore owners;
  late DraftCommitter committer;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    todos = DriftTodoStore(database);
    tags = DriftTagStore(database);
    owners = DriftOwnerStore(database);
    committer = DraftCommitter(todos: todos, tags: tags, owners: owners);
  });

  tearDown(() async {
    await database.close();
  });

  test('写入带时间的草稿，自动补建默认组', () async {
    final due = DateTime(2026, 11, 20, 23, 59);
    final result = await committer.commit(
      drafts: [_draft('d1', '提交英语计划书', dueAt: due)],
      profileId: 'p1',
    );

    expect(result.inserted, 1);
    final saved = (await todos.all(profileId: 'p1')).single;
    expect(saved.title, '提交英语计划书');
    expect(saved.ownerId, defaultOwnerId('p1'));
    expect(await owners.findDefault('p1'), isNotNull);
  });

  test('没有时间的草稿不落库', () async {
    final result = await committer.commit(
      drafts: [_draft('d1', '待补时间的任务')],
      profileId: 'p1',
    );

    expect(result.inserted, 0);
    expect(result.skippedDuplicates, 1);
    expect(await todos.all(profileId: 'p1'), isEmpty);
  });

  test('与已有待办重复时跳过', () async {
    final due = DateTime(2026, 11, 20, 23, 59);
    final now = DateTime(2026, 11, 10);
    await todos.upsert(
      TodoItem(
        id: 't1',
        title: '提交英语计划书',
        dueAt: due,
        createdAt: now,
        updatedAt: now,
        profileId: 'p1',
        ownerId: defaultOwnerId('p1'),
      ),
    );

    final result = await committer.commit(
      drafts: [_draft('d1', ' 提交英语计划书 ', dueAt: due)],
      profileId: 'p1',
    );

    expect(result.inserted, 0);
    expect(result.skippedDuplicates, 1);
    expect(await todos.all(profileId: 'p1'), hasLength(1));
  });

  test('同一批里的重复只写一条', () async {
    final due = DateTime(2026, 11, 21, 23, 59);
    final result = await committer.commit(
      drafts: [
        _draft('d1', '交作业', dueAt: due),
        _draft('d2', '交作业', dueAt: due),
      ],
      profileId: 'p1',
    );

    expect(result.inserted, 1);
    expect(result.skippedDuplicates, 1);
  });

  test('同一时刻的已有待办计入冲突但不阻止写入', () async {
    final due = DateTime(2026, 11, 22, 23, 59);
    final now = DateTime(2026, 11, 10);
    await todos.upsert(
      TodoItem(
        id: 't1',
        title: '另一件事',
        dueAt: due,
        createdAt: now,
        updatedAt: now,
        profileId: 'p1',
        ownerId: defaultOwnerId('p1'),
      ),
    );

    final result = await committer.commit(
      drafts: [_draft('d1', '新任务', dueAt: due)],
      profileId: 'p1',
    );

    expect(result.inserted, 1);
    expect(result.conflicts, 1);
  });

  test('使用模型给出的归属 id', () async {
    final now = DateTime(2026, 11, 10);
    final course = Owner(
      id: 'o_course',
      profileId: 'p1',
      kind: OwnerKind.course,
      name: '数据结构',
      createdAt: now,
      updatedAt: now,
    );
    await owners.upsert(course);

    final result = await committer.commit(
      drafts: [
        _draft(
          'd1',
          '交数据结构作业',
          dueAt: DateTime(2026, 11, 24, 23, 59),
          ownerId: 'o_course',
          kind: OwnerKind.course,
        ),
      ],
      profileId: 'p1',
    );

    expect(result.inserted, 1);
    expect((await todos.all(profileId: 'p1')).single.ownerId, 'o_course');
  });

  test('模型没给归属时，同类型只有一个归属就回落到它', () async {
    final now = DateTime(2026, 11, 10);
    await owners.upsert(
      Owner(
        id: 'o_club',
        profileId: 'p1',
        kind: OwnerKind.club,
        name: 'ACM 集训队',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await committer.commit(
      drafts: [
        _draft(
          'd1',
          '社团例会',
          dueAt: DateTime(2026, 11, 25, 23, 59),
          kind: OwnerKind.club,
        ),
      ],
      profileId: 'p1',
    );

    expect((await todos.all(profileId: 'p1')).single.ownerId, 'o_club');
  });

  test('无法判断归属时落到默认组', () async {
    final now = DateTime(2026, 11, 10);
    await owners.upsert(
      Owner(
        id: 'o_a',
        profileId: 'p1',
        kind: OwnerKind.course,
        name: '数据结构',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await owners.upsert(
      Owner(
        id: 'o_b',
        profileId: 'p1',
        kind: OwnerKind.course,
        name: '高等数学',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await committer.commit(
      drafts: [
        _draft(
          'd1',
          '某门课作业',
          dueAt: DateTime(2026, 11, 26, 23, 59),
          kind: OwnerKind.course,
        ),
      ],
      profileId: 'p1',
    );

    expect(
      (await todos.all(profileId: 'p1')).single.ownerId,
      defaultOwnerId('p1'),
    );
  });

  test('材料写入备注，标签挂到新待办', () async {
    final due = DateTime(2026, 11, 23, 23, 59);
    final result = await committer.commit(
      drafts: [
        _draft('d1', '心理作业', dueAt: due, materials: ['报告', '照片']),
      ],
      profileId: 'p1',
      tagNames: ['作业', '心理'],
    );

    expect(result.inserted, 1);
    final saved = (await todos.all(profileId: 'p1')).single;
    expect(saved.note, contains('报告'));
    expect(await tags.tagIdsOf(saved.id), hasLength(2));
  });
}

