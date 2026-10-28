import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/timetable_store.dart';
import 'model/course.dart';
import 'model/time_slot.dart';
import 'model/timetable_config.dart';
import 'model/timetable_data.dart';
import 'model/timetable_library.dart';

final initialTimetableProvider = Provider<TimetableData>(
  (ref) => TimetableData.initial(),
);

final initialTimetableLibraryProvider = Provider<TimetableLibrary?>(
  (ref) => null,
);

final timetableStoreProvider = Provider<TimetableStore>(
  (ref) => InMemoryTimetableStore(),
);

var _courseIdSeed = 0;

String newCourseId() {
  _courseIdSeed += 1;
  return 'course_${DateTime.now().microsecondsSinceEpoch}_$_courseIdSeed';
}

var _timetableIdSeed = 0;

String _newTimetableId() {
  _timetableIdSeed += 1;
  return 'table_${DateTime.now().microsecondsSinceEpoch}_$_timetableIdSeed';
}

class TimetableLibraryController extends Notifier<TimetableLibrary> {
  Future<void> _pendingSave = Future<void>.value();

  @override
  TimetableLibrary build() {
    final saved = ref.watch(initialTimetableLibraryProvider);
    if (saved != null) return saved;
    return TimetableLibrary.single(ref.watch(initialTimetableProvider));
  }

  Future<void> addCourse(Course course) {
    return _updateActive(
      (data) => data.copyWith(courses: [...data.courses, course]),
    );
  }

  Future<void> updateCourse(Course course) {
    return _updateActive(
      (data) => data.copyWith(
        courses: [
          for (final existing in data.courses)
            if (existing.id == course.id) course else existing,
        ],
      ),
    );
  }

  Future<void> removeCourse(String courseId) {
    return _updateActive(
      (data) => data.copyWith(
        courses: data.courses.where((course) => course.id != courseId).toList(),
      ),
    );
  }

  Future<void> clearCourses() {
    return _updateActive((data) => data.copyWith(courses: const []));
  }

  Future<void> updateConfig(TimetableConfig config) {
    return _updateActive((data) => data.copyWith(config: config));
  }

  Future<void> updateTimeSlot(TimeSlot slot) {
    return _updateActive(
      (data) => data.copyWith(
        timeSlots: [
          for (final existing in data.timeSlots)
            if (existing.number == slot.number) slot else existing,
        ],
      ),
    );
  }

  Future<void> replaceTimeSlots(List<TimeSlot> slots) {
    return _updateActive(
      (data) => data.copyWith(timeSlots: List.unmodifiable(slots)),
    );
  }

  Future<void> replaceSchedule({
    TimetableConfig? config,
    List<TimeSlot>? timeSlots,
    List<Course>? courses,
  }) {
    return _updateActive(
      (data) => data.copyWith(
        config: config,
        timeSlots: timeSlots == null ? null : List.unmodifiable(timeSlots),
        courses: courses == null ? null : List.unmodifiable(courses),
      ),
    );
  }

  Future<void> addTimetable({String? name}) async {
    final trimmedName = name?.trim() ?? '';
    final data = TimetableData.initial(
      id: _newTimetableId(),
      name: trimmedName.isEmpty
          ? '课表 ${state.timetables.length + 1}'
          : trimmedName,
    );
    await _commit(state.add(data));
    ref.read(selectedWeekProvider.notifier).followToday();
  }

  Future<void> selectTimetable(String id) async {
    if (state.find(id) == null || state.activeId == id) return;
    await _commit(state.copyWith(activeId: id));
    ref.read(selectedWeekProvider.notifier).followToday();
  }

  Future<void> renameTimetable(String id, String name) async {
    final trimmedName = name.trim();
    final target = state.find(id);
    if (trimmedName.isEmpty || target == null) return;
    await _commit(
      state.replace(
        target.copyWith(config: target.config.copyWith(name: trimmedName)),
      ),
    );
  }

  Future<void> deleteTimetable(String id) async {
    if (state.timetables.length <= 1 || state.find(id) == null) return;
    final wasActive = state.activeId == id;
    await _commit(state.remove(id));
    if (wasActive) {
      ref.read(selectedWeekProvider.notifier).followToday();
    }
  }

  Future<void> _updateActive(
    TimetableData Function(TimetableData data) update,
  ) {
    return _commit(state.replace(update(state.active)));
  }

  Future<void> _commit(TimetableLibrary library) {
    state = library;
    final store = ref.read(timetableStoreProvider);

    _pendingSave = _pendingSave.then((_) async {
      try {
        await store.saveLibrary(library);
      } catch (error) {
        debugPrint('Timetable persistence failed: $error');
      }
    });

    return _pendingSave;
  }
}

final timetableLibraryProvider =
    NotifierProvider<TimetableLibraryController, TimetableLibrary>(
      TimetableLibraryController.new,
    );

final timetableProvider = Provider<TimetableData>(
  (ref) => ref.watch(timetableLibraryProvider).active,
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
