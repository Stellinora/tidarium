import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/course.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/model/timetable_library.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';

Course _course({String id = 'c1', String name = '高等数学'}) {
  return Course(
    id: id,
    name: name,
    day: 1,
    startSection: 1,
    endSection: 2,
    weeks: {1, 2, 3},
    colorIndex: 2,
    teacher: '张老师',
    location: 'A101',
  );
}

void main() {
  group('TimetableData JSON', () {
    test('round-trips config, slots and courses', () {
      final data = TimetableData(
        config: TimetableConfig(
          name: '测试课表',
          semesterStart: DateTime(2026, 9, 2),
          totalWeeks: 16,
          showWeekends: true,
          showTeacher: false,
          showLocation: false,
          courseNameFontSize: 15,
          courseInfoFontSize: 10.5,
          sectionLabelFontSize: 8,
          weekdayHeaderFontSize: 16,
          dateFontSize: 11,
          timeSlotFontSize: 12,
          timeTextFontSize: 8.5,
          weekTitleFontSize: 18,
          hintFontSize: 13,
          backgroundImagePath: '/tmp/background.jpg',
          backgroundImageOpacity: 0.6,
          firstWeekday: DateTime.sunday,
        ),
        timeSlots: defaultTimeSlots,
        courses: [_course()],
      );

      final restored = TimetableData.fromJson(data.toJson());

      expect(restored.config.name, '测试课表');
      expect(restored.config.semesterStart, DateTime(2026, 9, 2));
      expect(restored.config.totalWeeks, 16);
      expect(restored.config.showWeekends, isTrue);
      expect(restored.config.showTeacher, isFalse);
      expect(restored.config.showLocation, isFalse);
      expect(restored.config.courseNameFontSize, 15);
      expect(restored.config.courseInfoFontSize, 10.5);
      expect(restored.config.sectionLabelFontSize, 8);
      expect(restored.config.weekdayHeaderFontSize, 16);
      expect(restored.config.dateFontSize, 11);
      expect(restored.config.timeSlotFontSize, 12);
      expect(restored.config.timeTextFontSize, 8.5);
      expect(restored.config.weekTitleFontSize, 18);
      expect(restored.config.hintFontSize, 13);
      expect(restored.config.backgroundImagePath, '/tmp/background.jpg');
      expect(restored.config.backgroundImageOpacity, 0.6);
      expect(restored.config.firstWeekday, DateTime.sunday);
      expect(restored.timeSlots, hasLength(defaultTimeSlots.length));
      expect(
        restored.timeSlots.first.startMinutes,
        defaultTimeSlots.first.startMinutes,
      );
      expect(restored.courses.single.name, '高等数学');
      expect(restored.courses.single.weeks, {1, 2, 3});
      expect(restored.courses.single.teacher, '张老师');
    });

    test('falls back to defaults for an empty payload', () {
      final data = TimetableData.fromJson(const {});

      expect(data.timeSlots, hasLength(defaultTimeSlots.length));
      expect(data.courses, isEmpty);
      expect(data.config.totalWeeks, 20);
      expect(data.config.showTeacher, isTrue);
      expect(data.config.showLocation, isTrue);
      expect(data.config.courseNameFontSize, 12);
      expect(data.config.courseInfoFontSize, 9.5);
      expect(data.config.backgroundImagePath, isNull);
      expect(data.config.backgroundImageOpacity, 0.35);
    });
  });

  group('TimetableLibrary JSON', () {
    test('round-trips multiple timetables and the active id', () {
      final first = TimetableData(
        id: 'first',
        config: const TimetableConfig(name: '第一课表'),
        timeSlots: defaultTimeSlots,
        courses: [_course()],
      );
      final second = TimetableData(
        id: 'second',
        config: const TimetableConfig(name: '第二课表'),
        timeSlots: defaultTimeSlots,
        courses: const [],
      );
      final library = TimetableLibrary(
        activeId: 'second',
        timetables: [first, second],
      );

      final restored = TimetableLibrary.fromJson(library.toJson());

      expect(restored.activeId, 'second');
      expect(restored.timetables, hasLength(2));
      expect(restored.active.config.name, '第二课表');
      expect(restored.find('first')!.courses, hasLength(1));
    });

    test('migrates a legacy single-timetable payload', () {
      final data = TimetableData(
        config: const TimetableConfig(name: '旧课表'),
        timeSlots: defaultTimeSlots,
        courses: [_course()],
      );

      final library = TimetableLibrary.fromJson(data.toJson());

      expect(library.activeId, 'main');
      expect(library.timetables, hasLength(1));
      expect(library.active.config.name, '旧课表');
      expect(library.active.courses, hasLength(1));
    });
  });

  group('TimetableController', () {
    late InMemoryTimetableStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryTimetableStore();
      container = ProviderContainer(
        overrides: [
          initialTimetableProvider.overrideWithValue(
            TimetableData.initial(now: DateTime(2026, 9, 2)),
          ),
          timetableStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
    });

    test('adds, updates and removes courses while persisting', () async {
      final notifier = container.read(timetableLibraryProvider.notifier);

      await notifier.addCourse(_course());
      expect(container.read(timetableProvider).courses, hasLength(1));
      expect((await store.load())!.courses, hasLength(1));

      await notifier.updateCourse(_course(name: '线性代数'));
      expect(container.read(timetableProvider).courses.single.name, '线性代数');
      expect((await store.load())!.courses.single.name, '线性代数');

      await notifier.removeCourse('c1');
      expect(container.read(timetableProvider).courses, isEmpty);
      expect((await store.load())!.courses, isEmpty);
    });

    test('updates config and time slots', () async {
      final notifier = container.read(timetableLibraryProvider.notifier);

      await notifier.updateConfig(
        container
            .read(timetableProvider)
            .config
            .copyWith(totalWeeks: 18, showWeekends: true),
      );
      expect(container.read(timetableProvider).config.totalWeeks, 18);
      expect(container.read(timetableProvider).config.showWeekends, isTrue);

      final first = container.read(timetableProvider).timeSlots.first;
      await notifier.updateTimeSlot(
        first.copyWith(startMinutes: 7 * 60 + 30, endMinutes: 8 * 60 + 15),
      );
      expect(
        container.read(timetableProvider).timeSlots.first.startMinutes,
        450,
      );
      expect((await store.load())!.timeSlots.first.startMinutes, 450);
    });

    test('creates, switches, renames and deletes timetables', () async {
      final notifier = container.read(timetableLibraryProvider.notifier);

      await notifier.addTimetable(name: '第二课表');
      var library = container.read(timetableLibraryProvider);
      expect(library.timetables, hasLength(2));
      expect(library.active.config.name, '第二课表');
      final secondId = library.activeId;

      await notifier.addCourse(_course());
      expect(container.read(timetableProvider).courses, hasLength(1));

      await notifier.selectTimetable('main');
      library = container.read(timetableLibraryProvider);
      expect(library.activeId, 'main');
      expect(container.read(timetableProvider).courses, isEmpty);

      await notifier.renameTimetable(secondId, '实验课表');
      expect(
        container.read(timetableLibraryProvider).find(secondId)!.config.name,
        '实验课表',
      );

      await notifier.deleteTimetable(secondId);
      expect(container.read(timetableLibraryProvider).timetables, hasLength(1));
    });

    test('selected week follows today by default', () {
      expect(container.read(selectedWeekProvider), isNull);

      container.read(selectedWeekProvider.notifier).select(5);
      expect(container.read(selectedWeekProvider), 5);

      container.read(selectedWeekProvider.notifier).followToday();
      expect(container.read(selectedWeekProvider), isNull);
    });
  });
}
