import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/drift_event_store.dart';
import 'core/db/event_store.dart';
import 'features/home/home_providers.dart';
import 'features/timetable/data/drift_timetable_store.dart';
import 'features/timetable/data/timetable_store.dart';
import 'features/timetable/reminder/course_reminder_coordinator.dart';
import 'features/timetable/reminder/course_reminder_service.dart';
import 'features/timetable/timetable_providers.dart';
import 'features/todos/data/drift_todo_store.dart';
import 'features/todos/data/todo_store.dart';
import 'features/todos/todo_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final legacyStore = JsonFileTimetableStore();
  TimetableStore timetableStore = legacyStore;
  EventStore eventStore = InMemoryEventStore();
  TodoStore todoStore = InMemoryTodoStore();

  try {
    final database = AppDatabase(openAppDatabase());
    final driftStore = DriftTimetableStore(database);
    await driftStore.migrateFrom(legacyStore);
    timetableStore = driftStore;
    eventStore = DriftEventStore(database);
    todoStore = DriftTodoStore(database);
  } catch (error) {
    debugPrint('Drift storage is unavailable, using legacy storage: $error');
  }

  final saved = await timetableStore.loadLibrary();
  final reminderService = CourseReminderService();
  try {
    await reminderService.initialize();
  } catch (error) {
    debugPrint('Course reminders are unavailable: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        timetableStoreProvider.overrideWithValue(timetableStore),
        eventStoreProvider.overrideWithValue(eventStore),
        todoStoreProvider.overrideWithValue(todoStore),
        courseReminderServiceProvider.overrideWithValue(reminderService),
        if (saved != null)
          initialTimetableLibraryProvider.overrideWithValue(saved),
      ],
      child: const TidariumApp(),
    ),
  );
}
