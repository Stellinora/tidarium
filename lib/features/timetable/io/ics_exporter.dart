import 'dart:convert';

import '../model/course.dart';
import '../model/timetable_data.dart';
import '../timetable_time.dart';

class IcsExport {
  const IcsExport({required this.content, required this.fileName});

  final String content;
  final String fileName;
}

IcsExport buildIcsExport(
  TimetableData data, {
  int? alarmMinutes,
  DateTime? now,
}) {
  final config = data.config;
  final semesterStart = config.semesterStart;
  if (semesterStart == null) {
    throw const FormatException('请先在课表设置中填写学期开始日期');
  }

  final slotByNumber = {for (final slot in data.timeSlots) slot.number: slot};
  final events = <_IcsEvent>[];

  for (final course in data.courses) {
    final startSlot = slotByNumber[course.startSection];
    final endSlot = slotByNumber[course.endSection];
    if (startSlot == null || endSlot == null) continue;

    for (final week in course.weeks.toList()..sort()) {
      if (week < 1 || week > config.totalWeeks) continue;
      if (course.day < 1 || course.day > 7) continue;

      final date = dateOfWeekday(
        week,
        course.day,
        semesterStart: semesterStart,
        firstWeekday: config.firstWeekday,
      );
      final start = date.add(Duration(minutes: startSlot.startMinutes));
      final end = date.add(Duration(minutes: endSlot.endMinutes));
      if (!end.isAfter(start)) continue;

      events.add(_IcsEvent(course: course, week: week, start: start, end: end));
    }
  }

  events.sort((a, b) => a.start.compareTo(b.start));

  final stamp = _formatUtc(now ?? DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Tidarium//ZH',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_escapeText(config.name)}',
    'BEGIN:VTIMEZONE',
    'TZID:Asia/Shanghai',
    'BEGIN:STANDARD',
    'DTSTART:19700101T000000Z',
    'TZOFFSETFROM:+0800',
    'TZOFFSETTO:+0800',
    'END:STANDARD',
    'END:VTIMEZONE',
  ];

  for (final event in events) {
    final course = event.course;
    lines
      ..add('BEGIN:VEVENT')
      ..add(
        'UID:tidarium-${_safeUid(course.id)}-${event.week}-'
        '${_formatDate(event.start)}@tidarium',
      )
      ..add('DTSTAMP:$stamp')
      ..add('DTSTART;TZID=Asia/Shanghai:${_formatLocal(event.start)}')
      ..add('DTEND;TZID=Asia/Shanghai:${_formatLocal(event.end)}')
      ..add('SUMMARY:${_escapeText(course.name)}')
      ..add('X-TIDARIUM-WEEK:${event.week}');

    if (course.location.isNotEmpty) {
      lines.add('LOCATION:${_escapeText(course.location)}');
    }
    if (course.teacher.isNotEmpty) {
      lines.add('DESCRIPTION:${_escapeText('教师：${course.teacher}')}');
    }
    if (alarmMinutes != null && alarmMinutes >= 0 && alarmMinutes <= 60) {
      lines
        ..add('BEGIN:VALARM')
        ..add('ACTION:DISPLAY')
        ..add('DESCRIPTION:课程提醒')
        ..add('TRIGGER:-PT${alarmMinutes}M')
        ..add('END:VALARM');
    }
    lines.add('END:VEVENT');
  }

  lines.add('END:VCALENDAR');

  final nowDate = now ?? DateTime.now();
  final fileName =
      'Tidarium-${nowDate.year}${_two(nowDate.month)}${_two(nowDate.day)}-'
      '${_two(nowDate.hour)}${_two(nowDate.minute)}.ics';

  return IcsExport(
    content: '${lines.map(_foldLine).join('\r\n')}\r\n',
    fileName: fileName,
  );
}

class _IcsEvent {
  const _IcsEvent({
    required this.course,
    required this.week,
    required this.start,
    required this.end,
  });

  final Course course;
  final int week;
  final DateTime start;
  final DateTime end;
}

String _formatLocal(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${_two(value.month)}${_two(value.day)}T'
      '${_two(value.hour)}${_two(value.minute)}${_two(value.second)}';
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${_two(value.month)}${_two(value.day)}';
}

String _formatUtc(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '${_two(utc.month)}${_two(utc.day)}T'
      '${_two(utc.hour)}${_two(utc.minute)}${_two(utc.second)}Z';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _safeUid(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return cleaned.isEmpty ? 'course' : cleaned;
}

String _escapeText(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n');
}

String _foldLine(String line) {
  const maxBytes = 73;
  final output = StringBuffer();
  final current = StringBuffer();
  var currentBytes = 0;

  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final characterBytes = utf8.encode(character).length;
    if (currentBytes + characterBytes > maxBytes && current.isNotEmpty) {
      output
        ..write(current)
        ..write('\r\n ');
      current.clear();
      currentBytes = 0;
    }
    current.write(character);
    currentBytes += characterBytes;
  }

  output.write(current);
  return output.toString();
}
