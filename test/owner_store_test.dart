import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/owners/data/drift_owner_store.dart';
import 'package:tidarium/features/owners/data/owner_store.dart';
import 'package:tidarium/features/owners/model/owner.dart';

void main() {
  late AppDatabase database;
  late DriftOwnerStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftOwnerStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('每个 profile 各自拥有一个默认组', () async {
    await store.upsert(buildDefaultOwner('p1'));
    await store.upsert(buildDefaultOwner('p2'));

    final first = await store.findDefault('p1');
    final second = await store.findDefault('p2');

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.id, defaultOwnerId('p1'));
    expect(second!.id, defaultOwnerId('p2'));
    expect(await store.all('p1'), hasLength(1));
    expect(await store.all('p2'), hasLength(1));
  });

  test('默认组不可归档、不可删除', () async {
    final owner = buildDefaultOwner('p1');
    await store.upsert(owner);

    await store.archive(owner.id);
    await store.delete(owner.id);

    final loaded = await store.findById(owner.id);
    expect(loaded, isNotNull);
    expect(loaded!.archived, isFalse);
  });

  test('同一个 refId 只能绑定一个归属', () async {
    final now = DateTime(2026, 11, 10);
    final a = Owner(
      id: 'o1',
      profileId: 'p1',
      kind: OwnerKind.course,
      name: '数据结构',
      createdAt: now,
      updatedAt: now,
    );
    final b = a.copyWith(id: 'o2', name: '数据结构（实验）');
    await store.upsert(a);
    await store.upsert(b);

    await store.attachRef(
      const OwnerRef(
        ownerId: 'o1',
        profileId: 'p1',
        refType: OwnerRef.courseRefType,
        refId: 'course_1',
      ),
    );
    await store.attachRef(
      const OwnerRef(
        ownerId: 'o2',
        profileId: 'p1',
        refType: OwnerRef.courseRefType,
        refId: 'course_1',
      ),
    );

    final owner = await store.findByRef(OwnerRef.courseRefType, 'course_1');
    expect(owner!.id, 'o2');
    expect(await store.refsOf('o1'), isEmpty);
    expect(await store.refsOf('o2'), hasLength(1));
  });

  test('网课必须带平台，其他类型必须不带', () async {
    final now = DateTime(2026, 11, 10);
    final onlineWithoutPlatform = Owner(
      id: 'o1',
      profileId: 'p1',
      kind: OwnerKind.onlineCourse,
      name: '学习通 · 大学物理',
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      store.upsert(onlineWithoutPlatform),
      throwsA(isA<OwnerValidationError>()),
    );

    final courseWithPlatform = Owner(
      id: 'o2',
      profileId: 'p1',
      kind: OwnerKind.course,
      name: '数据结构',
      platform: OnlinePlatform.chaoxing,
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      store.upsert(courseWithPlatform),
      throwsA(isA<OwnerValidationError>()),
    );
  });

  test('归档后默认查询不可见，但可以包含归档项查询', () async {
    final now = DateTime(2026, 11, 10);
    final owner = Owner(
      id: 'o1',
      profileId: 'p1',
      kind: OwnerKind.club,
      name: 'ACM 集训队',
      createdAt: now,
      updatedAt: now,
    );
    await store.upsert(owner);
    await store.archive(owner.id);

    expect(await store.all('p1'), isEmpty);
    expect(await store.all('p1', includeArchived: true), hasLength(1));
  });
}
