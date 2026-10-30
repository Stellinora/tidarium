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

Future<void> _openTimeSlots(WidgetTester tester) async {
  final entry = find.text('作息时间与默认时长');
  await tester.scrollUntilVisible(entry, 300);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens the time slot settings page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _openTimeSlots(tester);

    expect(find.text('默认时长'), findsOneWidget);
    expect(find.text('时间段列表'), findsOneWidget);
    expect(find.text('时段 1'), findsOneWidget);
    expect(find.text('共 13 个时间段'), findsOneWidget);
  });

  testWidgets('shows current-table display switches without table management', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('课表管理'), findsNothing);
    expect(find.text('显示周末'), findsOneWidget);
    expect(find.text('显示教师'), findsOneWidget);
    expect(find.text('显示上课地点'), findsOneWidget);
  });

  testWidgets('opens the import and export page', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表导入与导出'));
    await tester.pumpAndSettle();

    expect(find.text('拾光学校库'), findsOneWidget);
    expect(find.text('通用教务'), findsOneWidget);
    expect(find.text('WakeUp 学校库'), findsOneWidget);
    expect(find.text('导出 ICS'), findsOneWidget);
    expect(find.text('导入 ICS'), findsOneWidget);
  });

  testWidgets('adds and removes time slots', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _openTimeSlots(tester);

    await tester.tap(find.byTooltip('新增时间段'));
    await tester.pumpAndSettle();
    expect(find.text('新增时间段'), findsOneWidget);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('共 14 个时间段'), findsOneWidget);

    await tester.tap(find.byTooltip('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('共 13 个时间段'), findsOneWidget);
  });
}
