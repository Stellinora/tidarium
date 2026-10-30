import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';
import 'package:tidarium/features/timetable/timetable_ui_settings_page.dart';
import 'package:tidarium/ui/theme.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      initialTimetableProvider.overrideWithValue(
        TimetableData(
          config: const TimetableConfig(semesterStart: null, totalWeeks: 20),
          timeSlots: defaultTimeSlots,
          courses: const [],
        ),
      ),
      timetableStoreProvider.overrideWithValue(InMemoryTimetableStore()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const TimetableUiSettingsPage(),
    ),
  );
}

void main() {
  testWidgets('shows font and background controls', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('课程名称'), findsOneWidget);
    expect(find.text('教师 / 地点'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('背景'), 300);
    expect(find.text('背景'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('选择背景图'), 300);
    expect(find.text('选择背景图'), findsOneWidget);
  });
}
