import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/todo_store.dart';
import 'model/todo_item.dart';

final todoStoreProvider = Provider<TodoStore>((ref) => InMemoryTodoStore());

final todosProvider = StreamProvider<List<TodoItem>>(
  (ref) => ref.watch(todoStoreProvider).watchAll(),
);
