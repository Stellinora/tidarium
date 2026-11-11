import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/db/app_database.dart';
import 'package:tidarium/features/owners/data/drift_owner_store.dart';
import 'package:tidarium/features/owners/model/owner.dart';
import 'package:tidarium/features/owners/owner_sync.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/todos/data/drift_todo_store.dart';
import 'package:tidarium/features/todos/model/todo_item.dart';

Course _course({
  required String id,
  required String name,
  String teacher = '张老师',
  int day = 1,
}) {
  return Course(
    id: id,
    name: name,
    day: day,
    startSection: 1,
    endSection: 2,
    weeks: const {1, 2, 3},
    colorIndex: 0,
    teacher: teacher,
  );
}

TimetableData _timetable(List<Course> courses, {String id = 'p1'}) {
  return TimetableData.initial(
    id: id,
    now: DateTime(2026, 9, 7),
  ).copyWith(courses: courses);
}

void main() {
  late AppDatabase database;
  late DriftOwnerStore owners;
  late DriftTodoStore todos;
  late OwnerSync sync;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    owners = DriftOwnerStore(database);
    todos = DriftTodoStore(database);
    sync = OwnerSync(ownerStore: owners, todoStore: todos);
  });

  tearDown(() async {
    await database.close();
  });

  test('按 course.id 建归属，重复同步不重复创建', () async {
    final timetable = _timetable([
      _course(id: 'c1', name: '数据结构'),
      _course(id: 'c2', name: '高等数学', teacher: '李老师'),
    ]);

    final first = await sync.syncFromTimetable(timetable);
    expect(first.created, 2);

    final second = await sync.syncFromTimetable(timetable);
    expect(second.created, 0);
    expect(await owners.all('p1'), hasLength(2));

    final owner = await owners.findByRef(OwnerRef.courseRefType, 'c1');
    expect(owner!.name, '数据结构');
    expect(owner.profileId, 'p1');
  });

  test('课程改名会同步归属名，用户改过名则跳过', () async {
    await sync.syncFromTimetable(
      _timetable([_course(id: 'c1', name: '数据结构')]),
    );

    final report = await sync.syncFromTimetable(
      _timetable([_course(id: 'c1', name: '数据结构与算法')]),
    );
    expect(report.renamed, 1);
    expect(
      (await owners.findByRef(OwnerRef.courseRefType, 'c1'))!.name,
      '数据结构与算法',
    );

    final custom = (await owners.findByRef(
      OwnerRef.courseRefType,
      'c1',
    ))!.copyWith(name: '我的数据结构', nameCustom: true);
    await owners.upsert(custom);

    await sync.syncFromTimetable(
      _timetable([_course(id: 'c1', name: '又改了一次')]),
    );
    expect(
      (await owners.findByRef(OwnerRef.courseRefType, 'c1'))!.name,
      '我的数据结构',
    );
  });

  test('课程被删除时解除绑定并归档空归属', () async {
    await sync.syncFromTimetable(
      _timetable([
        _course(id: 'c1', name: '数据结构'),
        _course(id: 'c2', name: '高等数学'),
      ]),
    );

    final report = await sync.syncFromTimetable(
      _timetable([_course(id: 'c2', name: '高等数学')]),
    );

    expect(report.refsRemoved, 1);
    expect(report.archived, 1);
    expect(await owners.findByRef(OwnerRef.courseRefType, 'c1'), isNull);
    expect(await owners.all('p1'), hasLength(1));
    expect(await owners.all('p1', includeArchived: true), hasLength(2));
  });

  test('同名同教师的课程会生成合并候选', () async {
    final courses = [
      _course(id: 'c1', name: '大学物理', teacher: '王老师'),
      _course(id: 'c2', name: '大学物理', teacher: '王老师'),
      _course(id: 'c3', name: '大学物理', teacher: '赵老师'),
    ];
    await sync.syncFromTimetable(_timetable(courses));

    final candidates = await sync.findMergeCandidates(
      profileId: 'p1',
      courses: courses,
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.owners, hasLength(2));
    expect(candidates.single.teacher, '王老师');
  });

  test('教师为空时不参与合并', () async {
    final courses = [
      _course(id: 'c1', name: '体育', teacher: ''),
      _course(id: 'c2', name: '体育', teacher: ''),
    ];
    await sync.syncFromTimetable(_timetable(courses));

    final candidates = await sync.findMergeCandidates(
      profileId: 'p1',
      courses: courses,
    );
    expect(candidates, isEmpty);
  });

  test('合并会迁移 refs 与待办，并归档被合并方', () async {
    final courses = [
      _course(id: 'c1', name: '大学物理', teacher: '王老师'),
      _course(id: 'c2', name: '大学物理', teacher: '王老师'),
    ];
    await sync.syncFromTimetable(_timetable(courses));

    final first = await owners.findByRef(OwnerRef.courseRefType, 'c1');
    final second = await owners.findByRef(OwnerRef.courseRefType, 'c2');
    expect(first, isNotNull);
    expect(second, isNotNull);

    final now = DateTime(2026, 11, 10, 9);
    await todos.upsert(
      TodoItem(
        id: 't1',
        title: '物理实验报告',
        dueAt: now,
        createdAt: now,
        updatedAt: now,
        profileId: 'p1',
        ownerId: second!.id,
      ),
    );

    final moved = await sync.mergeOwners(
      targetId: first!.id,
      sourceIds: [second.id],
      profileId: 'p1',
    );

    expect(moved, 1);
    expect(await owners.refsOf(first.id), hasLength(2));
    expect(await owners.refsOf(second.id), isEmpty);
    expect((await owners.findById(second.id))!.archived, isTrue);
    expect((await todos.all()).single.ownerId, first.id);
  });
}

