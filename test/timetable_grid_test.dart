import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/course_merge.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/widgets/timetable_grid.dart';
import 'package:tidarium/ui/theme.dart';

Course _course({
  required String id,
  required String name,
  required int day,
  String teacher = '',
  String location = '',
  int startSection = 1,
  int endSection = 2,
}) {
  return Course(
    id: id,
    name: name,
    day: day,
    startSection: startSection,
    endSection: endSection,
    weeks: const {1},
    colorIndex: 0,
    teacher: teacher,
    location: location,
  );
}

Widget _grid({
  required List<Course> courses,
  bool showTeacher = true,
  bool showLocation = true,
  LocationDisplayMode locationDisplayMode = LocationDisplayMode.full,
  bool showWeekends = false,
  double width = 500,
}) {
  return MaterialApp(
    theme: buildTidariumTheme(Brightness.light),
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 600,
        child: TimetableGrid(
          config: TimetableConfig(
            semesterStart: null,
            totalWeeks: 20,
            showWeekends: showWeekends,
            showTeacher: showTeacher,
            showLocation: showLocation,
            locationDisplayMode: locationDisplayMode,
          ),
          timeSlots: defaultTimeSlots,
          blocks: mergeCoursesForWeek(courses, 1),
          weekNumber: 1,
          todayWeekday: null,
          currentSection: null,
          onCourseTap: (_) {},
          onCellTap: (_, _) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('places courses in their weekday columns', (tester) async {
    final courses = [
      _course(id: 'monday', name: '周一课程', day: 1),
      _course(id: 'tuesday', name: '周二课程', day: 2),
    ];
    final blocks = mergeCoursesForWeek(courses, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTidariumTheme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 600,
            child: TimetableGrid(
              config: const TimetableConfig(
                semesterStart: null,
                totalWeeks: 20,
              ),
              timeSlots: defaultTimeSlots,
              blocks: blocks,
              weekNumber: 1,
              todayWeekday: null,
              currentSection: null,
              onCourseTap: (_) {},
              onCellTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monday = tester.getRect(find.byKey(const ValueKey<String>('monday')));
    final tuesday = tester.getRect(
      find.byKey(const ValueKey<String>('tuesday')),
    );

    expect(monday.width, lessThan(120));
    expect(tuesday.width, lessThan(120));
    expect(tuesday.left, greaterThan(monday.left + 50));
    expect(tuesday.left, greaterThan(monday.right));
  });

  testWidgets('honors teacher and location visibility', (tester) async {
    final courses = [
      _course(
        id: 'course',
        name: '高等数学',
        day: 1,
        teacher: '张老师',
        location: 'A101',
      ),
    ];

    await tester.pumpWidget(_grid(courses: courses));
    await tester.pumpAndSettle();
    expect(find.text('张老师'), findsOneWidget);
    expect(find.text('@A101'), findsOneWidget);

    await tester.pumpWidget(
      _grid(courses: courses, showTeacher: false, showLocation: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('张老师'), findsNothing);
    expect(find.text('@A101'), findsNothing);
  });

  testWidgets('shows teacher and location on a compact one-section block', (
    tester,
  ) async {
    final courses = [
      _course(
        id: 'compact',
        name: '短课程',
        day: 1,
        teacher: '李老师',
        location: 'B202',
        startSection: 1,
        endSection: 1,
      ),
    ];

    await tester.pumpWidget(_grid(courses: courses));
    await tester.pumpAndSettle();

    expect(find.text('李老师'), findsOneWidget);
    expect(find.text('@B202'), findsOneWidget);
  });

  testWidgets('renders a structured location in three parts', (tester) async {
    final courses = [
      _course(
        id: 'structured',
        name: '实验课',
        day: 1,
        teacher: '赵老师',
        location: '第1教研楼东301',
      ),
    ];

    await tester.pumpWidget(
      _grid(
        courses: courses,
        locationDisplayMode: LocationDisplayMode.structured,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第1教研楼'), findsOneWidget);
    expect(find.text('东'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
  });

  testWidgets('shows details in a narrow seven-day grid', (tester) async {
    final courses = [
      _course(
        id: 'narrow',
        name: '窄屏课程',
        day: 1,
        teacher: '王老师',
        location: 'C303',
        startSection: 1,
        endSection: 1,
      ),
    ];

    await tester.pumpWidget(
      _grid(courses: courses, showWeekends: true, width: 320),
    );
    await tester.pumpAndSettle();

    expect(find.text('王老师'), findsOneWidget);
    expect(find.text('@C303'), findsOneWidget);
  });
}
