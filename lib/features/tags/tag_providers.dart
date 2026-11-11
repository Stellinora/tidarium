import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/tag_store.dart';
import 'model/tag.dart';

final tagStoreProvider = Provider<TagStore>((ref) => InMemoryTagStore());

final tagsProvider = StreamProvider.family<List<Tag>, String>((ref, profileId) {
  return ref.watch(tagStoreProvider).watchAll(profileId);
});
