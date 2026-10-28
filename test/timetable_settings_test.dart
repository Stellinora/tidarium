import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';
import 'package:tidarium/features/timetable/timetable_settings_page.dart';
import 'package:tidarium/ui/theme.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      initialTimetableProvider.overrideWithValue(
        TimetableData(
          config: TimetableConfig(
            semesterStart: DateTime(2026, 9, 2),
            totalWeeks: 20,
          ),
          timeSlots: defaultTimeSlots,
          courses: const [],
        ),
      ),
      timetableStoreProvider.overrideWithValue(InMemoryTimetableStore()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const TimetableSettingsPage(),
    ),
  );
}

void main() {
  testWidgets('opens the time slot settings page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('节次时间与默认时长'));
    await tester.pumpAndSettle();

    expect(find.text('默认时长'), findsOneWidget);
    expect(find.text('节次列表'), findsOneWidget);
    expect(find.text('第 1 节'), findsOneWidget);
    expect(find.text('共 13 节'), findsOneWidget);
  });

  testWidgets('opens the import and export page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表导入与导出'));
    await tester.pumpAndSettle();

    expect(find.text('教务系统导入'), findsOneWidget);
    expect(find.text('导出 ICS'), findsOneWidget);
    expect(find.text('导入 ICS'), findsOneWidget);
  });

  testWidgets('adds and removes time slots', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('节次时间与默认时长'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新增节次'));
    await tester.pumpAndSettle();
    expect(find.text('新增节次'), findsOneWidget);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('共 14 节'), findsOneWidget);

    await tester.tap(find.byTooltip('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('共 13 节'), findsOneWidget);
  });
}
