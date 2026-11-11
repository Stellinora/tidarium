import '../../features/timetable/model/course.dart';
import '../../features/timetable/model/timetable_data.dart';
import '../todos/data/todo_store.dart';
import 'data/owner_store.dart';
import 'model/owner.dart';

/// 一次课程同步的结果，便于测试与日志。
class OwnerSyncReport {
  const OwnerSyncReport({
    this.created = 0,
    this.renamed = 0,
    this.archived = 0,
    this.refsRemoved = 0,
  });

  final int created;
  final int renamed;
  final int archived;
  final int refsRemoved;

  bool get isEmpty =>
      created == 0 && renamed == 0 && archived == 0 && refsRemoved == 0;

  @override
  String toString() =>
      'created=$created renamed=$renamed archived=$archived refsRemoved=$refsRemoved';
}

/// 同名同教师的课程归属，交给用户确认后再合并。
class MergeCandidate {
  const MergeCandidate({
    required this.owners,
    required this.name,
    required this.teacher,
  });

  final List<Owner> owners;
  final String name;
  final String teacher;
}

class OwnerSync {
  OwnerSync({required this.ownerStore, required this.todoStore});

  final OwnerStore ownerStore;
  final TodoStore todoStore;

  /// 按 course.id 幂等创建课程归属；课程改名时同步显示名；课程消失时归档空归属。
  Future<OwnerSyncReport> syncFromTimetable(TimetableData timetable) async {
    var created = 0;
    var renamed = 0;
    var archived = 0;
    var refsRemoved = 0;
    final now = DateTime.now();

    final courseIds = timetable.courses.map((course) => course.id).toSet();

    for (final course in timetable.courses) {
      final existing = await ownerStore.findByRef(
        OwnerRef.courseRefType,
        course.id,
      );
      if (existing == null) {
        final owner = Owner(
          id: newOwnerId(),
          profileId: timetable.id,
          kind: OwnerKind.course,
          name: course.name,
          colorIndex: course.colorIndex,
          origin: OwnerOrigin.timetable,
          createdAt: now,
          updatedAt: now,
        );
        await ownerStore.upsert(owner);
        await ownerStore.attachRef(
          OwnerRef(
            ownerId: owner.id,
            profileId: timetable.id,
            refType: OwnerRef.courseRefType,
            refId: course.id,
          ),
        );
        created += 1;
        continue;
      }

      if (!existing.nameCustom &&
          existing.name != course.name &&
          existing.profileId == timetable.id) {
        await ownerStore.upsert(
          existing.copyWith(name: course.name, updatedAt: now),
        );
        renamed += 1;
      }
    }

    final owners = await ownerStore.all(timetable.id, includeArchived: true);
    for (final owner in owners) {
      if (owner.archived || owner.kind != OwnerKind.course) continue;
      final refs = await ownerStore.refsOf(owner.id);
      if (refs.isEmpty) continue;

      final courseRefs = refs
          .where((ref) => ref.refType == OwnerRef.courseRefType)
          .toList(growable: false);
      var removedHere = 0;
      for (final ref in courseRefs) {
        if (courseIds.contains(ref.refId)) continue;
        await ownerStore.detachRef(ref.refType, ref.refId);
        removedHere += 1;
        refsRemoved += 1;
      }
      if (removedHere > 0) {
        final remaining = await ownerStore.refsOf(owner.id);
        if (remaining.isEmpty && owner.origin == OwnerOrigin.timetable) {
          await ownerStore.archive(owner.id);
          archived += 1;
        }
      }
    }

    return OwnerSyncReport(
      created: created,
      renamed: renamed,
      archived: archived,
      refsRemoved: refsRemoved,
    );
  }

  /// 找出同 profile 内「同名 + 同教师」的课程归属，只提示不自动合并。
  Future<List<MergeCandidate>> findMergeCandidates({
    required String profileId,
    required List<Course> courses,
  }) async {
    final byId = {for (final course in courses) course.id: course};
    final owners = await ownerStore.all(profileId);
    final groups = <String, List<Owner>>{};
    final meta = <String, ({String name, String teacher})>{};

    for (final owner in owners) {
      if (owner.kind != OwnerKind.course) continue;
      final refs = await ownerStore.refsOf(owner.id);
      final linked = refs
          .where((ref) => ref.refType == OwnerRef.courseRefType)
          .map((ref) => byId[ref.refId])
          .whereType<Course>()
          .toList(growable: false);
      if (linked.isEmpty) continue;
      final teacher = _normalizeTeacher(linked.first.teacher);
      if (teacher.isEmpty) continue;
      final name = _normalizeName(owner.name);
      final key = '$name|$teacher';
      groups.putIfAbsent(key, () => <Owner>[]).add(owner);
      meta[key] = (name: owner.name, teacher: teacher);
    }

    return [
      for (final entry in groups.entries)
        if (entry.value.length >= 2)
          MergeCandidate(
            owners: List.unmodifiable(entry.value),
            name: meta[entry.key]!.name,
            teacher: meta[entry.key]!.teacher,
          ),
    ];
  }

  /// 合并归属：refs 与待办改指目标，被合并方归档。返回迁移的 refs 数量。
  Future<int> mergeOwners({
    required String targetId,
    required Iterable<String> sourceIds,
    required String profileId,
  }) async {
    final target = await ownerStore.findById(targetId);
    if (target == null) {
      throw StateError('目标归属不存在：$targetId');
    }
    var movedRefs = 0;

    for (final id in sourceIds.toSet()) {
      if (id == targetId) continue;
      final source = await ownerStore.findById(id);
      if (source == null || source.profileId != profileId) continue;

      final refs = await ownerStore.refsOf(id);
      for (final ref in refs) {
        await ownerStore.detachRef(ref.refType, ref.refId);
        await ownerStore.attachRef(
          OwnerRef(
            ownerId: targetId,
            profileId: profileId,
            refType: ref.refType,
            refId: ref.refId,
          ),
        );
        movedRefs += 1;
      }

      await todoStore.reassignOwner(
        fromOwnerIds: [id],
        toOwnerId: targetId,
        profileId: profileId,
      );
      await ownerStore.archive(id);
    }

    return movedRefs;
  }
}

String _normalizeName(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

String _normalizeTeacher(String raw) {
  final parts = raw
      .split(RegExp(r'[,，、/]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList()
    ..sort();
  return parts.join('|');
}
