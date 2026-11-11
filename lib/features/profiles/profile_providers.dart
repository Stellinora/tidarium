import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../owners/owner_providers.dart';
import '../tags/tag_providers.dart';
import '../todos/todo_providers.dart';
import 'profile_lifecycle.dart';

final profileLifecycleProvider = Provider<ProfileLifecycle>((ref) {
  return ProfileLifecycle(
    owners: ref.watch(ownerStoreProvider),
    tags: ref.watch(tagStoreProvider),
    todos: ref.watch(todoStoreProvider),
  );
});
