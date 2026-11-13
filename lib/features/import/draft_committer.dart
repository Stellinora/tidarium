import '../owners/data/owner_store.dart';
import '../owners/model/owner.dart';
import '../tags/data/tag_store.dart';
import '../todos/data/todo_store.dart';
import '../todos/model/todo_item.dart';
import 'model/import_draft.dart';

class DraftCommitResult {
  const DraftCommitResult({
    this.inserted = 0,
    this.skippedDuplicates = 0,
    this.skippedNoTime = 0,
    this.conflicts = 0,
  });

  final int inserted;
  final int skippedDuplicates;

  /// 没有截止时间、且没有选择自动补齐的草稿数量。
  final int skippedNoTime;

  /// 与已有待办落在同一分钟的数量，仅提示，不阻止写入。
  final int conflicts;
}

/// 把确认后的草稿写入当前课表。负责去重、冲突计数与标签挂接。
class DraftCommitter {
  DraftCommitter({
    required this.todos,
    required this.tags,
    required this.owners,
  });

  final TodoStore todos;
  final TagStore tags;
  final OwnerStore owners;

  Future<DraftCommitResult> commit({
    required List<ImportDraft> drafts,
    required String profileId,
    List<String> tagNames = const [],
    bool fillMissingDueWithToday = false,
  }) async {
    if (drafts.isEmpty) return const DraftCommitResult();

    var defaultOwner = await owners.findDefault(profileId);
    defaultOwner ??= buildDefaultOwner(profileId);
    if (await owners.findDefault(profileId) == null) {
      await owners.upsert(defaultOwner);
    }

    final profileOwners = await owners.all(profileId);
    final existing = await todos.all(profileId: profileId);
    final seen = <String>{
      for (final item in existing) _dedupeKey(item.title, item.dueAt),
    };

    final tagIds = <String>[];
    for (final name in tagNames) {
      final tag = await tags.upsertByName(profileId, name);
      tagIds.add(tag.id);
    }

    var inserted = 0;
    var skipped = 0;
    var skippedNoTime = 0;
    var conflicts = 0;
    final now = DateTime.now();
    final fallbackDue = fillMissingDueWithToday
        ? DateTime(now.year, now.month, now.day, 23, 59)
        : null;

    final existingMinutes = <String>{
      for (final item in existing) _minuteKey(item.dueAt),
    };

    for (final draft in drafts) {
      final dueAt = draft.dueAt ?? fallbackDue;
      // 没有时间的草稿默认不落库，避免误记到今天；用户明确选择后才补齐。
      if (dueAt == null) {
        skippedNoTime += 1;
        continue;
      }

      final key = _dedupeKey(draft.title, dueAt);
      if (seen.contains(key)) {
        skipped += 1;
        continue;
      }
      seen.add(key);

      if (existingMinutes.contains(_minuteKey(dueAt))) conflicts += 1;
      existingMinutes.add(_minuteKey(dueAt));

      final owner = await _resolveOwner(
        draft: draft,
        profileId: profileId,
        fallback: defaultOwner,
        profileOwners: profileOwners,
      );

      final item = TodoItem(
        id: newTodoId(),
        title: draft.title,
        note: draft.materials.isEmpty
            ? ''
            : '材料：${draft.materials.join('、')}',
        dueAt: dueAt,
        source: draft.source.isEmpty ? '截屏导入' : draft.source,
        createdAt: now,
        updatedAt: now,
        profileId: profileId,
        ownerId: owner.id,
      );
      await todos.upsert(item);
      if (tagIds.isNotEmpty) {
        await tags.setTodoTags(item.id, tagIds, profileId: profileId);
      }
      inserted += 1;
    }

    return DraftCommitResult(
      inserted: inserted,
      skippedDuplicates: skipped,
      skippedNoTime: skippedNoTime,
      conflicts: conflicts,
    );
  }

  /// 归属解析：模型给的 id → 同类唯一归属 → 默认组。
  Future<Owner> _resolveOwner({
    required ImportDraft draft,
    required String profileId,
    required Owner fallback,
    required List<Owner> profileOwners,
  }) async {
    final explicitId = draft.ownerId;
    if (explicitId != null && explicitId.isNotEmpty) {
      final found = await owners.findById(explicitId);
      if (found != null && found.profileId == profileId && !found.archived) {
        return found;
      }
    }

    final sameKind = profileOwners
        .where((owner) => owner.kind == draft.kind && !owner.isDefault)
        .toList(growable: false);
    if (sameKind.length == 1) return sameKind.single;

    return fallback;
  }

  String _dedupeKey(String title, DateTime dueAt) {
    final normalizedTitle =
        title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '$normalizedTitle|${_minuteKey(dueAt)}';
  }

  String _minuteKey(DateTime value) {
    return '${value.year}-${value.month}-${value.day} '
        '${value.hour}:${value.minute}';
  }
}



