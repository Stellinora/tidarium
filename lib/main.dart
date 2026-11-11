import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/drift_event_store.dart';
import 'core/db/event_store.dart';
import 'features/home/home_providers.dart';
import 'features/intake/debug/intake_debug_page.dart';
import 'features/intake/image_intake.dart';
import 'features/intake/share_intake_service.dart';
import 'features/owners/data/drift_owner_store.dart';
import 'features/owners/data/owner_store.dart';
import 'features/owners/owner_providers.dart';
import 'features/owners/owner_sync.dart';
import 'features/profiles/storage_bootstrap.dart';
import 'features/tags/data/drift_tag_store.dart';
import 'features/tags/data/tag_store.dart';
import 'features/tags/tag_providers.dart';
import 'features/timetable/data/drift_timetable_store.dart';
import 'features/timetable/model/timetable_library.dart';
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
  OwnerStore ownerStore = InMemoryOwnerStore();
  TagStore tagStore = InMemoryTagStore();
  AppDatabase? database;

  try {
    final db = AppDatabase(openAppDatabase());
    database = db;
    final driftStore = DriftTimetableStore(db);
    await driftStore.migrateFrom(legacyStore);
    timetableStore = driftStore;
    eventStore = DriftEventStore(db);
    todoStore = DriftTodoStore(db);
    ownerStore = DriftOwnerStore(db);
    tagStore = DriftTagStore(db);
  } catch (error) {
    debugPrint('Drift storage is unavailable, using legacy storage: $error');
  }

  final saved = await timetableStore.loadLibrary();

  if (database != null) {
    final library = saved ?? TimetableLibrary.initial();
    try {
      await StorageBootstrap(
        database: database,
        owners: ownerStore,
        library: library,
      ).run();

      final sync = OwnerSync(ownerStore: ownerStore, todoStore: todoStore);
      for (final timetable in library.timetables) {
        await sync.syncFromTimetable(timetable);
      }
    } catch (error) {
      debugPrint('Storage bootstrap failed: $error');
    }
  }

  final reminderService = CourseReminderService();
  try {
    await reminderService.initialize();
  } catch (error) {
    debugPrint('Course reminders are unavailable: $error');
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  final intakeService = ShareIntakeService();
  var intakePageVisible = false;

  void showIntake(IntakeBatch batch) {
    if (batch.isEmpty) return;
    // S5 会替换为正式确认页；当前仅在调试包内验证入口。
    if (!kDebugMode) return;
    if (intakePageVisible) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    intakePageVisible = true;
    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (_) => IntakeDebugPage(batch: batch),
          ),
        )
        .whenComplete(() => intakePageVisible = false);
  }

  intakeService.stream.listen(showIntake);
  intakeService.start();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await intakeService.readInitial();
  });

  runApp(
    ProviderScope(
      overrides: [
        timetableStoreProvider.overrideWithValue(timetableStore),
        eventStoreProvider.overrideWithValue(eventStore),
        todoStoreProvider.overrideWithValue(todoStore),
        ownerStoreProvider.overrideWithValue(ownerStore),
        tagStoreProvider.overrideWithValue(tagStore),
        courseReminderServiceProvider.overrideWithValue(reminderService),
        if (saved != null)
          initialTimetableLibraryProvider.overrideWithValue(saved),
      ],
      child: TidariumApp(navigatorKey: navigatorKey),
    ),
  );
}


