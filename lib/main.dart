import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/timetable/data/timetable_store.dart';
import 'features/timetable/timetable_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = JsonFileTimetableStore();
  final saved = await store.load();

  runApp(
    ProviderScope(
      overrides: [
        timetableStoreProvider.overrideWithValue(store),
        if (saved != null) initialTimetableProvider.overrideWithValue(saved),
      ],
      child: const TidariumApp(),
    ),
  );
}
