import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/timetable/data/timetable_store.dart';
import 'features/timetable/reminder/course_reminder_coordinator.dart';
import 'features/timetable/reminder/course_reminder_service.dart';
import 'features/timetable/timetable_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = JsonFileTimetableStore();
  final saved = await store.loadLibrary();
  final reminderService = CourseReminderService();
  try {
    await reminderService.initialize();
  } catch (error) {
    debugPrint('Course reminders are unavailable: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        timetableStoreProvider.overrideWithValue(store),
        courseReminderServiceProvider.overrideWithValue(reminderService),
        if (saved != null)
          initialTimetableLibraryProvider.overrideWithValue(saved),
      ],
      child: const TidariumApp(),
    ),
  );
}
