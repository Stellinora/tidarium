import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/model/standard_event.dart';
import 'package:tidarium/features/home/home_page.dart';
import 'package:tidarium/features/home/today_agenda.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';
import 'package:tidarium/ui/theme.dart';

void main() {
  testWidgets('shows today courses, events and the tomorrow placeholder', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 7);
    final agenda = TodayAgenda(
      date: date,
      status: TodayAgendaStatus.normal,
      weekNumber: 1,
      tableName: '我的课表',
      items: [
        AgendaItem(
          type: AgendaItemType.course,
          start: DateTime(2026, 9, 7, 8),
          end: DateTime(2026, 9, 7, 9, 35),
          finished: false,
          course: const Course(
            id: 'c1',
            name: '高等数学',
            day: 1,
            startSection: 1,
            endSection: 2,
            weeks: {1},
            colorIndex: 0,
            teacher: '张老师',
            location: 'A101',
          ),
        ),
        AgendaItem(
          type: AgendaItemType.event,
          start: DateTime(2026, 9, 7, 10),
          end: DateTime(2026, 9, 7, 10),
          finished: false,
          event: StandardEvent(
            id: 'e1',
            type: EventType.assignment,
            title: '提交作业',
            source: 'chaoxing',
            dueTime: DateTime(2026, 9, 7, 10),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialTimetableProvider.overrideWithValue(
            TimetableData.initial(now: date),
          ),
          todayAgendaProvider.overrideWith((ref) async => agenda),
        ],
        child: MaterialApp(
          theme: buildTidariumTheme(Brightness.light),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日日程'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('提交作业'), findsOneWidget);
    expect(find.text('添加课程'), findsNothing);
    expect(find.text('明天与更多日程'), findsOneWidget);
  });

  testWidgets('shows add course button when today has no course', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 7);
    final agenda = TodayAgenda(
      date: date,
      status: TodayAgendaStatus.normal,
      weekNumber: 1,
      tableName: '我的课表',
      items: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialTimetableProvider.overrideWithValue(
            TimetableData.initial(now: date),
          ),
          todayAgendaProvider.overrideWith((ref) async => agenda),
        ],
        child: MaterialApp(
          theme: buildTidariumTheme(Brightness.light),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加课程'), findsOneWidget);
  });
}
