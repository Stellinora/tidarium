import 'dart:async';

import '../model/tag.dart';

/// 标签读写接口。标签按 profile 隔离，同一 profile 内名字归一化后唯一。
abstract interface class TagStore {
  Future<List<Tag>> all(String profileId);

  Stream<List<Tag>> watchAll(String profileId);

  Future<Tag?> findByName(String profileId, String nameNorm);

  Future<Tag> upsertByName(
    String profileId,
    String name, {
    int? colorIndex,
  });

  Future<void> delete(String id);

  /// 删除整张课表下的标签与关联。
  Future<void> deleteProfile(String profileId);

  Future<List<String>> tagIdsOf(String todoId);

  Future<Map<String, List<String>>> tagIdsOfMany(List<String> todoIds);

  Future<void> setTodoTags(
    String todoId,
    Iterable<String> tagIds, {
    String? profileId,
  });
}

class InMemoryTagStore implements TagStore {
  InMemoryTagStore({List<Tag> initial = const []}) {
    for (final tag in initial) {
      _tags[tag.id] = tag;
    }
  }

  final Map<String, Tag> _tags = {};
  final Map<String, Set<String>> _links = {};
  final _controller = StreamController<void>.broadcast();

  @override
  Future<List<Tag>> all(String profileId) async {
    final items = _tags.values
        .where((tag) => tag.profileId == profileId && !tag.archived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(items);
  }

  @override
  Stream<List<Tag>> watchAll(String profileId) async* {
    yield await all(profileId);
    await for (final _ in _controller.stream) {
      yield await all(profileId);
    }
  }

  @override
  Future<Tag?> findByName(String profileId, String nameNorm) async {
    for (final tag in _tags.values) {
      if (tag.profileId == profileId && tag.nameNorm == nameNorm) return tag;
    }
    return null;
  }

  @override
  Future<Tag> upsertByName(
    String profileId,
    String name, {
    int? colorIndex,
  }) async {
    final normalized = normalizeTagName(name);
    final existing = await findByName(profileId, normalized);
    if (existing != null) return existing;

    final now = DateTime.now();
    final tag = Tag(
      id: newTagId(),
      profileId: profileId,
      name: name.trim(),
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
    );
    _tags[tag.id] = tag;
    _emit();
    return tag;
  }

  @override
  Future<void> delete(String id) async {
    _tags.remove(id);
    for (final entry in _links.entries) {
      entry.value.remove(id);
    }
    _emit();
  }

  @override
  Future<List<String>> tagIdsOf(String todoId) async {
    return (_links[todoId] ?? const <String>{}).toList(growable: false);
  }

  @override
  Future<Map<String, List<String>>> tagIdsOfMany(List<String> todoIds) async {
    return {
      for (final id in todoIds)
        id: (_links[id] ?? const <String>{}).toList(growable: false),
    };
  }

  @override
  Future<void> setTodoTags(
    String todoId,
    Iterable<String> tagIds, {
    String? profileId,
  }) async {
    final valid = tagIds.where((id) {
      final tag = _tags[id];
      if (tag == null) return false;
      if (profileId == null || profileId.isEmpty) return true;
      return tag.profileId == profileId;
    }).toSet();
    if (valid.isEmpty) {
      _links.remove(todoId);
    } else {
      _links[todoId] = valid;
    }
    _emit();
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final ids = _tags.values
        .where((tag) => tag.profileId == profileId)
        .map((tag) => tag.id)
        .toSet();
    _tags.removeWhere((_, tag) => tag.profileId == profileId);
    for (final entry in _links.entries) {
      entry.value.removeWhere(ids.contains);
    }
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(null);
  }
}

