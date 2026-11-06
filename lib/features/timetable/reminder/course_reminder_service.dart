import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../model/timetable_data.dart';
import '../timetable_time.dart';
import 'course_reminder_schedule.dart';

class CourseReminderService {
  CourseReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'course_reminders';
  static const channelName = '上课提醒';
  static const channelDescription = '课程开始前的本地通知';
  static const _timezoneChannel = MethodChannel(
    'io.github.stellinora.tidarium/timezone',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final reported = await _timezoneChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
      if (reported == null || reported.isEmpty) {
        throw StateError('The device did not report a timezone.');
      }
      final timezone = switch (reported) {
        'GMT' || 'UTC' => 'Etc/GMT',
        _ => reported,
      };
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (error) {
      debugPrint('Unable to resolve local timezone: $error');
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_course'),
      ),
    );
    if (initialized == false) {
      throw StateError('Local notifications could not be initialized.');
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;

    final notificationsGranted =
        await android.requestNotificationsPermission() ?? true;
    if (!notificationsGranted) return false;

    try {
      await android.requestExactAlarmsPermission();
    } catch (error) {
      debugPrint('Unable to request exact alarm permission: $error');
    }
    return true;
  }

  Future<int> schedule(
    TimetableData data, {
    DateTime? now,
    int horizonDays = 21,
  }) async {
    await initialize();
    await _plugin.cancelAll();

    if (!data.config.reminderEnabled) return 0;

    final occurrences = buildCourseReminderOccurrences(
      data: data,
      from: now ?? DateTime.now(),
      horizonDays: horizonDays,
    );
    if (occurrences.isEmpty) return 0;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExact =
        await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    var scheduled = 0;
    for (final occurrence in occurrences) {
      try {
        await _scheduleOccurrence(occurrence, scheduleMode);
        scheduled += 1;
      } catch (error) {
        debugPrint(
          'Unable to schedule reminder for ${occurrence.course.name}: $error',
        );
      }
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> _scheduleOccurrence(
    CourseReminderOccurrence occurrence,
    AndroidScheduleMode mode,
  ) {
    final startMinutes =
        occurrence.startsAt.hour * 60 + occurrence.startsAt.minute;
    final details = <String>[
      '${formatMinuteOfDay(startMinutes)} 上课',
      if (occurrence.course.location.trim().isNotEmpty)
        occurrence.course.location.trim(),
      if (occurrence.course.teacher.trim().isNotEmpty)
        occurrence.course.teacher.trim(),
    ].join(' · ');

    return _plugin.zonedSchedule(
      id: occurrence.notificationId,
      title: occurrence.course.name,
      body: details,
      scheduledDate: tz.TZDateTime.from(occurrence.remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.event,
          autoCancel: true,
          ticker: '上课提醒',
        ),
      ),
      androidScheduleMode: mode,
      payload: 'course:${occurrence.course.id}',
    );
  }
}
