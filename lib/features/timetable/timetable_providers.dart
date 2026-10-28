import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/timetable_store.dart';
import 'model/course.dart';
import 'model/time_slot.dart';
import 'model/timetable_config.dart';
import 'model/timetable_data.dart';

final initialTimetableProvider = Provider<TimetableData>(
  (ref) => TimetableData.initial(),
);

final timetableStoreProvider = Provider<TimetableStore>(
  (ref) => InMemoryTimetableStore(),
);

var _courseIdSeed = 0;

String newCourseId() {
  _courseIdSeed += 1;
  return 'course_${DateTime.now().microsecondsSinceEpoch}_$_courseIdSeed';
}

class TimetableController extends Notifier<TimetableData> {
  Future<void> _pendingSave = Future<void>.value();

  @override
  TimetableData build() => ref.watch(initialTimetableProvider);

  Future<void> addCourse(Course course) {
    return _commit(state.copyWith(courses: [...state.courses, course]));
  }

  Future<void> updateCourse(Course course) {
    final next = [
      for (final existing in state.courses)
        if (existing.id == course.id) course else existing,
    ];
    return _commit(state.copyWith(courses: next));
  }

  Future<void> removeCourse(String courseId) {
    final next = state.courses
        .where((course) => course.id != courseId)
        .toList();
    return _commit(state.copyWith(courses: next));
  }

  Future<void> clearCourses() {
    return _commit(state.copyWith(courses: const []));
  }

  Future<void> updateConfig(TimetableConfig config) {
    return _commit(state.copyWith(config: config));
  }

  Future<void> updateTimeSlot(TimeSlot slot) {
    final next = [
      for (final existing in state.timeSlots)
        if (existing.number == slot.number) slot else existing,
    ];
    return _commit(state.copyWith(timeSlots: next));
  }

  Future<void> replaceTimeSlots(List<TimeSlot> slots) {
    return _commit(state.copyWith(timeSlots: List.unmodifiable(slots)));
  }

  Future<void> replaceSchedule({
    TimetableConfig? config,
    List<TimeSlot>? timeSlots,
    List<Course>? courses,
  }) {
    return _commit(
      state.copyWith(
        config: config,
        timeSlots: timeSlots == null ? null : List.unmodifiable(timeSlots),
        courses: courses == null ? null : List.unmodifiable(courses),
      ),
    );
  }

  Future<void> _commit(TimetableData data) {
    state = data;
    final store = ref.read(timetableStoreProvider);

    _pendingSave = _pendingSave.then((_) async {
      try {
        await store.save(data);
      } catch (error) {
        debugPrint('Timetable persistence failed: $error');
      }
    });

    return _pendingSave;
  }
}

final timetableProvider = NotifierProvider<TimetableController, TimetableData>(
  TimetableController.new,
);

class SelectedWeekController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int week) => state = week;

  void followToday() => state = null;
}

final selectedWeekProvider = NotifierProvider<SelectedWeekController, int?>(
  SelectedWeekController.new,
);
