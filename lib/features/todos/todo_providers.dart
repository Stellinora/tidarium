import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../timetable/timetable_providers.dart';
import 'data/todo_store.dart';
import 'model/todo_item.dart';

final todoStoreProvider = Provider<TodoStore>((ref) => InMemoryTodoStore());

/// 首页与待办列表只看当前选中的课表（activeId）。
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final profileId = ref.watch(timetableLibraryProvider).activeId;
  return ref.watch(todoStoreProvider).watchAll(profileId: profileId);
});
