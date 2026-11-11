import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../model/owner.dart';
import 'owner_store.dart';

class DriftOwnerStore implements OwnerStore {
  DriftOwnerStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<Owner>> all(
    String profileId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.owners)
      ..where((table) => table.profileId.equals(profileId));
    if (!includeArchived) {
      query.where((table) => table.archived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm(expression: table.isDefault, mode: OrderingMode.desc),
      (table) => OrderingTerm(expression: table.name),
    ]);
    final rows = await query.get();
    return rows.map(_toOwner).toList(growable: false);
  }

  @override
  Stream<List<Owner>> watchAll(
    String profileId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.owners)
      ..where((table) => table.profileId.equals(profileId));
    if (!includeArchived) {
      query.where((table) => table.archived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm(expression: table.isDefault, mode: OrderingMode.desc),
      (table) => OrderingTerm(expression: table.name),
    ]);
    return query.watch().map(
      (rows) => rows.map(_toOwner).toList(growable: false),
    );
  }

  @override
  Future<Owner?> findById(String id) async {
    final row = await (_db.select(
      _db.owners,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toOwner(row);
  }

  @override
  Future<Owner?> findDefault(String profileId) async {
    final row = await (_db.select(_db.owners)..where(
          (table) =>
              table.profileId.equals(profileId) & table.isDefault.equals(true),
        ))
        .getSingleOrNull();
    return row == null ? null : _toOwner(row);
  }

  @override
  Future<Owner?> findByRef(String refType, String refId) async {
    final ref = await (_db.select(_db.ownerRefs)..where(
          (table) => table.refType.equals(refType) & table.refId.equals(refId),
        ))
        .getSingleOrNull();
    if (ref == null) return null;
    return findById(ref.ownerId);
  }

  @override
  Future<List<OwnerRef>> refsOf(String ownerId) async {
    final rows = await (_db.select(
      _db.ownerRefs,
    )..where((table) => table.ownerId.equals(ownerId))).get();
    return rows
        .map(
          (row) => OwnerRef(
            ownerId: row.ownerId,
            profileId: row.profileId,
            refType: row.refType,
            refId: row.refId,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsert(Owner owner) async {
    validateOwnerPlatform(owner.kind, owner.platform);
    await _db
        .into(_db.owners)
        .insertOnConflictUpdate(
          OwnersCompanion.insert(
            id: owner.id,
            profileId: owner.profileId,
            kind: owner.kind.name,
            name: owner.name,
            platform: Value(owner.platform?.name),
            origin: Value(owner.origin.name),
            nameCustom: Value(owner.nameCustom),
            colorIndex: Value(owner.colorIndex),
            isDefault: Value(owner.isDefault),
            archived: Value(owner.archived),
            createdAt: owner.createdAt.millisecondsSinceEpoch,
            updatedAt: owner.updatedAt.millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> attachRef(OwnerRef ref) async {
    await _db
        .into(_db.ownerRefs)
        .insertOnConflictUpdate(
          OwnerRefsCompanion.insert(
            ownerId: ref.ownerId,
            profileId: ref.profileId,
            refType: ref.refType,
            refId: ref.refId,
          ),
        );
  }

  @override
  Future<void> detachRef(String refType, String refId) {
    return (_db.delete(_db.ownerRefs)..where(
          (table) => table.refType.equals(refType) & table.refId.equals(refId),
        ))
        .go();
  }

  @override
  Future<void> archive(String id) async {
    final owner = await findById(id);
    if (owner == null || owner.isDefault) return;
    await upsert(owner.copyWith(archived: true, updatedAt: DateTime.now()));
  }

  @override
  Future<void> delete(String id) async {
    final owner = await findById(id);
    if (owner == null || owner.isDefault) return;
    await (_db.delete(_db.owners)..where((table) => table.id.equals(id))).go();
    await (_db.delete(
      _db.ownerRefs,
    )..where((table) => table.ownerId.equals(id))).go();
  }

  Owner _toOwner(OwnerRow row) {
    return Owner(
      id: row.id,
      profileId: row.profileId,
      kind: OwnerKind.parse(row.kind),
      name: row.name,
      platform: OnlinePlatform.parse(row.platform),
      origin: OwnerOrigin.parse(row.origin),
      nameCustom: row.nameCustom,
      colorIndex: row.colorIndex,
      isDefault: row.isDefault,
      archived: row.archived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
