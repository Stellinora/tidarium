import 'dart:convert';

import '../model/course.dart';
import '../model/time_slot.dart';
import '../model/timetable_config.dart';
import '../timetable_time.dart';

class ImportedCourses {
  const ImportedCourses({required this.courses, required this.warnings});

  final List<Course> courses;
  final List<String> warnings;
}

List<TimeSlot> parseImportedTimeSlots(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('节次数据格式不正确');
  }

  final slots = <TimeSlot>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final number = _int(item['number']);
    final start = _time(item['startTime']);
    final end = _time(item['endTime']);
    if (number == null || start == null || end == null) continue;
    if (end <= start) {
      throw FormatException('第 $number 节结束时间不晚于开始时间');
    }
    final alias = _string(item['alias']);
    slots.add(
      TimeSlot(
        number: number,
        startMinutes: start,
        endMinutes: end,
        alias: alias.isEmpty
            ? null
            : alias.length > 5
            ? alias.substring(0, 5)
            : alias,
      ),
    );
  }

  slots.sort((a, b) => a.number.compareTo(b.number));
  for (var index = 0; index < slots.length; index++) {
    if (slots[index].number != index + 1) {
      throw const FormatException('节次编号不连续');
    }
    if (index > 0 && slots[index].startMinutes < slots[index - 1].endMinutes) {
      throw const FormatException('节次时间存在重叠');
    }
  }

  return slots;
}

TimetableConfig parseImportedConfig(String raw, TimetableConfig base) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('课表配置格式不正确');
  }

  final startDate = parseFullDate(_string(decoded['semesterStartDate']));
  final totalWeeks = _int(decoded['semesterTotalWeeks']);
  final classDuration = _int(decoded['defaultClassDuration']);
  final breakDuration = _int(decoded['defaultBreakDuration']);
  final firstDay = _int(decoded['firstDayOfWeek']);

  return base.copyWith(
    semesterStart: startDate ?? base.semesterStart,
    totalWeeks: totalWeeks == null
        ? base.totalWeeks
        : totalWeeks.clamp(1, 52).toInt(),
    defaultClassMinutes: classDuration == null
        ? base.defaultClassMinutes
        : classDuration.clamp(1, 600).toInt(),
    defaultBreakMinutes: breakDuration == null
        ? base.defaultBreakMinutes
        : breakDuration.clamp(0, 600).toInt(),
    firstWeekday: firstDay == null
        ? base.firstWeekday
        : firstDay.clamp(1, 7).toInt(),
  );
}

ImportedCourses parseImportedCourses(
  String raw, {
  required TimetableConfig config,
  required List<TimeSlot> slots,
  int colorCount = 12,
}) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('课程数据格式不正确');
  }

  final warnings = <String>[];
  final courses = <Course>[];
  final nameColors = <String, int>{};
  var nextColor = 0;
  var index = 0;

  for (final item in decoded) {
    if (item is! Map) continue;
    index += 1;

    final name = _string(item['name']).isEmpty
        ? '未命名课程'
        : _string(item['name']);
    final day = _int(item['day']);
    if (day == null || day < 1 || day > 7) {
      _warn(warnings, '$name：星期无效');
      continue;
    }

    final startSection = _int(item['startSection']);
    final endSection = _int(item['endSection']);
    final isCustomTime = item['isCustomTime'] == true;
    int? resolvedStart = startSection;
    int? resolvedEnd = endSection;

    if (isCustomTime) {
      final startTime = _time(item['customStartTime']);
      final endTime = _time(item['customEndTime']);
      if (startTime == null || endTime == null || endTime <= startTime) {
        _warn(warnings, '$name：自定义时间无效');
        continue;
      }
      final startSlot = _findStartSlot(slots, startTime);
      final endSlot = _findEndSlot(slots, endTime);
      if (startSlot == null || endSlot == null) {
        _warn(warnings, '$name：自定义时间与现有节次不匹配');
        continue;
      }
      resolvedStart = startSlot.number;
      resolvedEnd = endSlot.number;
    }

    if (resolvedStart == null ||
        resolvedEnd == null ||
        resolvedStart < 1 ||
        resolvedEnd < resolvedStart ||
        resolvedEnd > slots.length) {
      _warn(warnings, '$name：节次范围无效');
      continue;
    }

    final rawWeeks = item['weeks'];
    final weeks = <int>{};
    if (rawWeeks is List) {
      for (final value in rawWeeks) {
        final week = _int(value);
        if (week != null && week >= 1 && week <= config.totalWeeks) {
          weeks.add(week);
        }
      }
    }
    if (weeks.isEmpty) {
      weeks.addAll([
        for (var week = 1; week <= config.totalWeeks; week++) week,
      ]);
    }

    final color = nameColors.putIfAbsent(name, () {
      final value = colorCount <= 0 ? 0 : nextColor % colorCount;
      nextColor += 1;
      return value;
    });

    courses.add(
      Course(
        id: _stableId(
          '$index|$name|$day|$resolvedStart|$resolvedEnd|${weeks.join(',')}',
        ),
        name: name,
        day: day,
        startSection: resolvedStart,
        endSection: resolvedEnd,
        weeks: weeks,
        colorIndex: color,
        teacher: _string(item['teacher']),
        location: _string(item['position']),
        remark: _string(item['remark']).length > 300
            ? _string(item['remark']).substring(0, 300)
            : _string(item['remark']),
      ),
    );
  }

  return ImportedCourses(courses: courses, warnings: warnings);
}

int maxSectionInImportedCourses(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return 0;

  var maxSection = 0;
  for (final item in decoded) {
    if (item is! Map) continue;
    if (item['isCustomTime'] == true) continue;
    final end = _int(item['endSection']);
    if (end != null && end > maxSection) maxSection = end;
  }
  return maxSection;
}

List<TimeSlot> extendTimeSlotsForSections({
  required List<TimeSlot> slots,
  required int requiredSections,
  required TimetableConfig config,
}) {
  if (requiredSections <= slots.length) return slots;

  final result = [...slots];
  var nextNumber = result.isEmpty ? 1 : result.last.number + 1;
  var nextStart = result.isEmpty
      ? 8 * 60
      : result.last.endMinutes + config.defaultBreakMinutes;

  while (result.length < requiredSections) {
    if (nextStart >= 24 * 60 - 1) break;
    final start = nextStart;
    final end = (start + config.defaultClassMinutes)
        .clamp(start + 1, 24 * 60)
        .toInt();
    result.add(
      TimeSlot(number: nextNumber, startMinutes: start, endMinutes: end),
    );
    nextNumber += 1;
    nextStart = end + config.defaultBreakMinutes;
  }

  return result;
}

TimeSlot? _findStartSlot(List<TimeSlot> slots, int minutes) {
  for (final slot in slots) {
    if (slot.startMinutes == minutes) return slot;
  }
  for (final slot in slots) {
    if (slot.startMinutes <= minutes && minutes < slot.endMinutes) return slot;
  }
  return null;
}

TimeSlot? _findEndSlot(List<TimeSlot> slots, int minutes) {
  for (final slot in slots) {
    if (slot.endMinutes == minutes) return slot;
  }
  for (final slot in slots) {
    if (slot.startMinutes < minutes && minutes <= slot.endMinutes) return slot;
  }
  return null;
}

int? _time(Object? value) {
  final text = _string(value);
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return null;
  final minutes = parseMinuteOfDay(text);
  if (minutes < 0 || minutes >= 24 * 60) return null;
  return minutes;
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _string(Object? value) => value?.toString().trim() ?? '';

void _warn(List<String> warnings, String message) {
  if (warnings.length >= 50) return;
  warnings.add(message);
}

String _stableId(String input) {
  var hash = 0x811c9dc5;
  for (final code in input.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return 'import_${hash.toRadixString(16).padLeft(8, '0')}';
}
