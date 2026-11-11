import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/owner_store.dart';
import 'model/owner.dart';

final ownerStoreProvider = Provider<OwnerStore>((ref) => InMemoryOwnerStore());

final ownersProvider = StreamProvider.family<List<Owner>, String>((
  ref,
  profileId,
) {
  return ref.watch(ownerStoreProvider).watchAll(profileId);
});
