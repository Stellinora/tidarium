import 'dart:async';

import '../model/owner.dart';

/// 归属的读写接口。所有查询都按 profile 隔离。
abstract interface class OwnerStore {
  Future<List<Owner>> all(String profileId, {bool includeArchived = false});

  Stream<List<Owner>> watchAll(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Owner?> findById(String id);

  Future<Owner?> findDefault(String profileId);

  Future<Owner?> findByRef(String refType, String refId);

  Future<List<OwnerRef>> refsOf(String ownerId);

  Future<void> upsert(Owner owner);

  Future<void> attachRef(OwnerRef ref);

  Future<void> detachRef(String refType, String refId);

  Future<void> archive(String id);

  Future<void> delete(String id);

  /// 删除整张课表下的归属与绑定（不处理待办）。
  Future<void> deleteProfile(String profileId);
}

class InMemoryOwnerStore implements OwnerStore {
  InMemoryOwnerStore({List<Owner> initial = const []}) {
    for (final owner in initial) {
      _owners[owner.id] = owner;
    }
  }

  final Map<String, Owner> _owners = {};
  final List<OwnerRef> _refs = [];
  final _controller = StreamController<void>.broadcast();

  @override
  Future<List<Owner>> all(
    String profileId, {
    bool includeArchived = false,
  }) async {
    return _filter(profileId, includeArchived);
  }

  @override
  Stream<List<Owner>> watchAll(
    String profileId, {
    bool includeArchived = false,
  }) async* {
    yield _filter(profileId, includeArchived);
    await for (final _ in _controller.stream) {
      yield _filter(profileId, includeArchived);
    }
  }

  List<Owner> _filter(String profileId, bool includeArchived) {
    final items = _owners.values
        .where(
          (owner) =>
              owner.profileId == profileId &&
              (includeArchived || !owner.archived),
        )
        .toList();
    items.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(items);
  }

  @override
  Future<Owner?> findById(String id) async => _owners[id];

  @override
  Future<Owner?> findDefault(String profileId) async {
    for (final owner in _owners.values) {
      if (owner.profileId == profileId && owner.isDefault) return owner;
    }
    return null;
  }

  @override
  Future<Owner?> findByRef(String refType, String refId) async {
    for (final ref in _refs) {
      if (ref.refType == refType && ref.refId == refId) {
        return _owners[ref.ownerId];
      }
    }
    return null;
  }

  @override
  Future<List<OwnerRef>> refsOf(String ownerId) async {
    return _refs.where((ref) => ref.ownerId == ownerId).toList();
  }

  @override
  Future<void> upsert(Owner owner) async {
    validateOwnerPlatform(owner.kind, owner.platform);
    _owners[owner.id] = owner;
    _emit();
  }

  @override
  Future<void> attachRef(OwnerRef ref) async {
    _refs.removeWhere(
      (existing) =>
          existing.refType == ref.refType && existing.refId == ref.refId,
    );
    _refs.add(ref);
    _emit();
  }

  @override
  Future<void> detachRef(String refType, String refId) async {
    _refs.removeWhere(
      (ref) => ref.refType == refType && ref.refId == refId,
    );
    _emit();
  }

  @override
  Future<void> archive(String id) async {
    final owner = _owners[id];
    if (owner == null || owner.isDefault) return;
    _owners[id] = owner.copyWith(archived: true, updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    final owner = _owners[id];
    if (owner == null || owner.isDefault) return;
    _owners.remove(id);
    _refs.removeWhere((ref) => ref.ownerId == id);
    _emit();
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _owners.removeWhere((_, owner) => owner.profileId == profileId);
    _refs.removeWhere((ref) => ref.profileId == profileId);
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(null);
  }
}

String defaultOwnerId(String profileId) => 'owner_default_$profileId';

/// 构造某个 profile 的默认组。
Owner buildDefaultOwner(String profileId, {DateTime? now}) {
  final moment = now ?? DateTime.now();
  return Owner(
    id: defaultOwnerId(profileId),
    profileId: profileId,
    kind: OwnerKind.personal,
    name: '自有任务',
    origin: OwnerOrigin.seed,
    isDefault: true,
    createdAt: moment,
    updatedAt: moment,
  );
}

