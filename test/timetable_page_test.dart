import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/timetable_page.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';
import 'package:tidarium/ui/theme.dart';

Widget _app(TimetableData data) {
  return ProviderScope(
    overrides: [
      initialTimetableProvider.overrideWithValue(data),
      timetableStoreProvider.overrideWithValue(InMemoryTimetableStore()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const TimetablePage(),
    ),
  );
}

void main() {
  final config = TimetableConfig(
    semesterStart: DateTime(2026, 9, 2),
    totalWeeks: 20,
  );

  testWidgets('renders courses and opens the detail sheet', (tester) async {
    final data = TimetableData(
      config: config,
      timeSlots: defaultTimeSlots,
      courses: const [
        Course(
          id: 'c1',
          name: '高等数学',
          day: 1,
          startSection: 1,
          endSection: 2,
          weeks: {
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            20,
          },
          colorIndex: 0,
          teacher: '张老师',
          location: 'A101',
        ),
      ],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();

    expect(find.text('高等数学'), findsOneWidget);

    await tester.tap(find.text('高等数学'));
    await tester.pumpAndSettle();

    expect(find.text('张老师'), findsNWidgets(2));
    expect(find.text('A101'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('编辑课程'), findsOneWidget);
  });

  testWidgets('fits the editor on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = TimetableData(
      config: config,
      timeSlots: defaultTimeSlots,
      courses: [
        Course(
          id: 'c1',
          name: '高等数学',
          day: 1,
          startSection: 1,
          endSection: 2,
          weeks: {for (var week = 1; week <= 20; week++) week},
          colorIndex: 0,
          teacher: '张老师',
          location: 'A101',
        ),
      ],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();

    await tester.tap(find.text('高等数学'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('编辑课程'), findsOneWidget);
  });

  testWidgets('adds a course from the editor', (tester) async {
    await tester.pumpWidget(
      _app(
        TimetableData(
          config: config,
          timeSlots: defaultTimeSlots,
          courses: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加课程'));
    await tester.pumpAndSettle();

    expect(find.text('课程名称'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '线性代数');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('线性代数'), findsOneWidget);
  });

  testWidgets('shows an empty hint on a fresh timetable', (tester) async {
    await tester.pumpWidget(
      _app(
        TimetableData(
          config: config,
          timeSlots: defaultTimeSlots,
          courses: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有课程'), findsOneWidget);
    expect(find.text('添加课程'), findsWidgets);
  });
}
