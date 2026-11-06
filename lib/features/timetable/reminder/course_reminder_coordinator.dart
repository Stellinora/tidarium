import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../timetable_providers.dart';
import 'course_reminder_service.dart';

final courseReminderServiceProvider = Provider<CourseReminderService>(
  (ref) => CourseReminderService(),
);

final courseReminderCoordinatorProvider = Provider<CourseReminderCoordinator>((
  ref,
) {
  final coordinator = CourseReminderCoordinator(ref);
  ref.listen(timetableLibraryProvider, (previous, next) {
    coordinator.scheduleActive();
  });
  coordinator.scheduleActive();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class CourseReminderCoordinator {
  CourseReminderCoordinator(this._ref);

  final Ref _ref;
  Future<void> _pending = Future<void>.value();
  var _disposed = false;

  void scheduleActive() {
    if (_disposed) return;
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        final data = _ref.read(timetableLibraryProvider).active;
        final count = await _ref
            .read(courseReminderServiceProvider)
            .schedule(data);
        debugPrint(
          'Scheduled $count course reminders for ${data.config.name}.',
        );
      } catch (error) {
        debugPrint('Course reminder scheduling failed: $error');
      }
    });
  }

  Future<void> flush() => _pending;

  void dispose() {
    _disposed = true;
  }
}
