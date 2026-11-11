import '../owners/data/owner_store.dart';
import '../tags/data/tag_store.dart';
import '../timetable/model/timetable_library.dart';
import '../todos/data/todo_store.dart';

enum ProfileDeleteStrategy {
  /// 待办迁到主课表，标签按名字在目标课表复用或新建。
  migrateToPrimary,

  /// 连同待办、归属、标签一并删除。
  deleteAll,
}

class ProfileLifecycleError implements Exception {
  ProfileLifecycleError(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileDeleteOutcome {
  const ProfileDeleteOutcome({
    required this.library,
    this.movedTodos = 0,
    this.deletedTodos = 0,
  });

  final TimetableLibrary library;
  final int movedTodos;
  final int deletedTodos;
}

class ProfileLifecycle {
  ProfileLifecycle({
    required this.owners,
    required this.tags,
    required this.todos,
  });

  final OwnerStore owners;
  final TagStore tags;
  final TodoStore todos;

  /// 指定主课表。主课表只影响删除迁移的落点与新任务默认归属。
  TimetableLibrary setPrimary(TimetableLibrary library, String profileId) {
    if (library.find(profileId) == null) return library;
    return library.copyWith(primaryId: profileId);
  }

  Future<ProfileDeleteOutcome> deleteProfile({
    required TimetableLibrary library,
    required String profileId,
    required ProfileDeleteStrategy strategy,
  }) async {
    if (library.timetables.length <= 1) {
      throw ProfileLifecycleError('只剩一张课表，无法删除');
    }
    if (library.find(profileId) == null) {
      throw ProfileLifecycleError('课表不存在：$profileId');
    }

    final next = library.remove(profileId);

    switch (strategy) {
      case ProfileDeleteStrategy.migrateToPrimary:
        final moved = await _migrate(
          fromProfileId: profileId,
          toProfileId: next.primaryId,
        );
        return ProfileDeleteOutcome(library: next, movedTodos: moved);
      case ProfileDeleteStrategy.deleteAll:
        final deleted = await todos.deleteProfile(profileId);
        await owners.deleteProfile(profileId);
        await tags.deleteProfile(profileId);
        return ProfileDeleteOutcome(library: next, deletedTodos: deleted);
    }
  }

  Future<int> _migrate({
    required String fromProfileId,
    required String toProfileId,
  }) async {
    var targetDefault = await owners.findDefault(toProfileId);
    if (targetDefault == null) {
      targetDefault = buildDefaultOwner(toProfileId);
      await owners.upsert(targetDefault);
    }

    final tagMap = <String, String>{};
    for (final tag in await tags.all(fromProfileId)) {
      final target = await tags.upsertByName(toProfileId, tag.name);
      tagMap[tag.id] = target.id;
    }

    final items = await todos.all(profileId: fromProfileId);
    for (final item in items) {
      final sourceIds = await tags.tagIdsOf(item.id);
      final mapped = sourceIds
          .map((id) => tagMap[id])
          .whereType<String>()
          .toList(growable: false);
      await tags.setTodoTags(item.id, mapped, profileId: toProfileId);
    }

    final moved = await todos.moveToProfile(
      fromProfileId: fromProfileId,
      toProfileId: toProfileId,
      ownerId: targetDefault.id,
    );

    await owners.deleteProfile(fromProfileId);
    await tags.deleteProfile(fromProfileId);
    return moved;
  }
}

/// 便于调用方拿到迁移落点的默认组 id。
String targetDefaultOwnerId(String profileId) => defaultOwnerId(profileId);



