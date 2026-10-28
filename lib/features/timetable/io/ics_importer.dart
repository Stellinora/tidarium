import '../model/course.dart';
import '../model/time_slot.dart';
import '../model/timetable_data.dart';
import '../timetable_time.dart';

class IcsImportPreview {
  const IcsImportPreview({
    required this.courses,
    required this.skipped,
    required this.semesterStart,
    required this.totalWeeks,
    required this.eventCount,
    required this.matchedEventCount,
    required this.usedInferredSemesterStart,
  });

  final List<Course> courses;
  final List<String> skipped;
  final DateTime semesterStart;
  final int totalWeeks;
  final int eventCount;
  final int matchedEventCount;
  final bool usedInferredSemesterStart;

  int get skippedEventCount => eventCount - matchedEventCount;
}

IcsImportPreview parseIcsImport(
  String content, {
  required TimetableData data,
  int colorCount = 12,
}) {
  final parsed = _parseEvents(content);
  final config = data.config;
  final firstWeekday = config.firstWeekday;

  if (parsed.events.isEmpty) {
    throw const FormatException('没有找到可导入的日历事件');
  }

  final inferredStart = startOfWeek(
    parsed.events
        .map((event) => event.start)
        .reduce((a, b) => a.isBefore(b) ? a : b),
    firstWeekday: firstWeekday,
  );
  final semesterStart = config.semesterStart ?? inferredStart;

  final slotByNumber = {for (final slot in data.timeSlots) slot.number: slot};
  final grouped = <String, _GroupedCourse>{};
  final skipped = <String>[...parsed.skipped];
  var maxWeek = 1;
  var matched = 0;

  for (final event in parsed.events) {
    final week = weekNumberFor(
      event.start,
      semesterStart,
      firstWeekday: firstWeekday,
    );
    if (week == null || week < 1 || week > 60) {
      _skip(skipped, event, '不在学期周次范围内');
      continue;
    }

    final startMinutes = event.start.hour * 60 + event.start.minute;
    final endMinutes = event.end.hour * 60 + event.end.minute;
    final startSlot = _findStartSlot(slotByNumber.values, startMinutes);
    final endSlot = _findEndSlot(slotByNumber.values, endMinutes);
    if (startSlot == null || endSlot == null) {
      _skip(skipped, event, '时间与现有节次不匹配');
      continue;
    }
    if (endMinutes <= startMinutes) {
      _skip(skipped, event, '结束时间不晚于开始时间');
      continue;
    }

    maxWeek = week > maxWeek ? week : maxWeek;
    matched += 1;

    final teacher = _extractTeacher(event.description);
    final name = event.summary.trim().isEmpty ? '未命名课程' : event.summary.trim();
    final location = event.location.trim();
    final key = [
      name,
      teacher,
      location,
      event.start.weekday,
      startSlot.number,
      endSlot.number,
    ].join('\u0001');

    final groupedCourse = grouped.putIfAbsent(
      key,
      () => _GroupedCourse(
        name: name,
        teacher: teacher,
        location: location,
        day: event.start.weekday,
        startSection: startSlot.number,
        endSection: endSlot.number,
      ),
    );
    groupedCourse.weeks.add(week);
  }

  final namesToColors = <String, int>{};
  var nextColor = 0;
  final courses = <Course>[];

  for (final entry in grouped.entries) {
    final groupedCourse = entry.value;
    final color = namesToColors.putIfAbsent(groupedCourse.name, () {
      final value = colorCount <= 0 ? 0 : nextColor % colorCount;
      nextColor += 1;
      return value;
    });

    courses.add(
      Course(
        id: _stableId(entry.key),
        name: groupedCourse.name,
        day: groupedCourse.day,
        startSection: groupedCourse.startSection,
        endSection: groupedCourse.endSection,
        weeks: groupedCourse.weeks,
        colorIndex: color,
        teacher: groupedCourse.teacher,
        location: groupedCourse.location,
      ),
    );
  }

  courses.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;
    final byStart = a.startSection.compareTo(b.startSection);
    if (byStart != 0) return byStart;
    return a.name.compareTo(b.name);
  });

  return IcsImportPreview(
    courses: courses,
    skipped: skipped,
    semesterStart: semesterStart,
    totalWeeks: maxWeek > config.totalWeeks ? maxWeek : config.totalWeeks,
    eventCount: parsed.events.length,
    matchedEventCount: matched,
    usedInferredSemesterStart: config.semesterStart == null,
  );
}

class _GroupedCourse {
  _GroupedCourse({
    required this.name,
    required this.teacher,
    required this.location,
    required this.day,
    required this.startSection,
    required this.endSection,
  });

  final String name;
  final String teacher;
  final String location;
  final int day;
  final int startSection;
  final int endSection;
  final Set<int> weeks = {};
}

class _ParsedEvent {
  _ParsedEvent({
    required this.summary,
    required this.location,
    required this.description,
    required this.start,
    required this.end,
  });

  final String summary;
  final String location;
  final String description;
  final DateTime start;
  final DateTime end;
}

class _ParseResult {
  _ParseResult({required this.events, required this.skipped});

  final List<_ParsedEvent> events;
  final List<String> skipped;
}

_ParseResult _parseEvents(String content) {
  final lines = _unfoldLines(content);
  final events = <_ParsedEvent>[];
  final skipped = <String>[];
  var inEvent = false;

  var summary = '';
  var location = '';
  var description = '';
  String? uid;
  _IcsDateProperty? startProperty;
  _IcsDateProperty? endProperty;
  String? rrule;

  for (final line in lines) {
    final upper = line.toUpperCase();
    if (upper == 'BEGIN:VEVENT') {
      inEvent = true;
      summary = '';
      location = '';
      description = '';
      uid = null;
      startProperty = null;
      endProperty = null;
      rrule = null;
      continue;
    }
    if (upper == 'END:VEVENT') {
      if (inEvent) {
        _finalizeEvent(
          summary: summary,
          location: location,
          description: description,
          startProperty: startProperty,
          endProperty: endProperty,
          rrule: rrule,
          uid: uid,
          events: events,
          skipped: skipped,
        );
      }
      inEvent = false;
      continue;
    }
    if (!inEvent) continue;

    final property = _parseProperty(line);
    if (property == null) continue;

    switch (property.name) {
      case 'SUMMARY':
        summary = _unescapeText(property.value);
      case 'LOCATION':
        location = _unescapeText(property.value);
      case 'DESCRIPTION':
        description = _unescapeText(property.value);
      case 'UID':
        uid = property.value;
      case 'DTSTART':
        startProperty = _IcsDateProperty.from(property);
      case 'DTEND':
        endProperty = _IcsDateProperty.from(property);
      case 'RRULE':
        rrule = property.value;
    }
  }

  return _ParseResult(events: events, skipped: skipped);
}

void _finalizeEvent({
  required String summary,
  required String location,
  required String description,
  required _IcsDateProperty? startProperty,
  required _IcsDateProperty? endProperty,
  required String? rrule,
  required String? uid,
  required List<_ParsedEvent> events,
  required List<String> skipped,
}) {
  final start = startProperty?.toDateTime();
  if (start == null) {
    skipped.add('${_shortName(summary, uid)}：缺少开始时间或为全天事件');
    return;
  }

  final end =
      endProperty?.toDateTime() ?? start.add(const Duration(minutes: 45));
  if (!end.isAfter(start)) {
    skipped.add('${_shortName(summary, uid)}：结束时间不晚于开始时间');
    return;
  }

  final occurrences = _expandOccurrences(
    start: start,
    end: end,
    rrule: rrule,
    summary: summary,
  );
  if (occurrences == null) {
    skipped.add('${_shortName(summary, uid)}：不支持该重复规则');
    return;
  }

  for (final occurrence in occurrences) {
    events.add(
      _ParsedEvent(
        summary: summary,
        location: location,
        description: description,
        start: occurrence.start,
        end: occurrence.end,
      ),
    );
  }
}

class _Occurrence {
  const _Occurrence({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

List<_Occurrence>? _expandOccurrences({
  required DateTime start,
  required DateTime end,
  required String? rrule,
  required String summary,
}) {
  if (rrule == null || rrule.trim().isEmpty) {
    return [_Occurrence(start: start, end: end)];
  }

  final parts = <String, String>{};
  for (final part in rrule.split(';')) {
    final index = part.indexOf('=');
    if (index <= 0) continue;
    parts[part.substring(0, index).toUpperCase()] = part.substring(index + 1);
  }

  if ((parts['FREQ'] ?? '').toUpperCase() != 'WEEKLY') return null;
  if (parts.containsKey('BYDAY')) {
    final byDay = parts['BYDAY']!.toUpperCase();
    if (byDay != _weekdayCode(start.weekday)) return null;
  }

  final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
  final count = int.tryParse(parts['COUNT'] ?? '');
  final until = _parseUntil(parts['UNTIL']);
  final duration = end.difference(start);
  final result = <_Occurrence>[];
  var current = start;
  var index = 0;

  while (index < 200) {
    if (until != null && current.isAfter(until)) break;
    result.add(_Occurrence(start: current, end: current.add(duration)));
    index += 1;
    if (count != null && index >= count) break;
    current = current.add(Duration(days: 7 * interval));
    if (count == null && until == null && index >= 52) break;
  }

  return result;
}

String _weekdayCode(int weekday) {
  const codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  return codes[weekday - 1];
}

DateTime? _parseUntil(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.length == 8) {
    final date = _parseDateOnly(raw);
    return date?.add(const Duration(hours: 23, minutes: 59, seconds: 59));
  }
  return _parseDateTime(raw);
}

DateTime? _parseDateOnly(String raw) {
  if (raw.length != 8) return null;
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

class _IcsProperty {
  const _IcsProperty({
    required this.name,
    required this.value,
    this.params = const {},
  });

  final String name;
  final String value;
  final Map<String, String> params;
}

_IcsProperty? _parseProperty(String line) {
  final colon = line.indexOf(':');
  if (colon <= 0) return null;

  final head = line.substring(0, colon);
  final value = line.substring(colon + 1);
  final segments = head.split(';');
  final name = segments.first.toUpperCase();
  final params = <String, String>{};

  for (final segment in segments.skip(1)) {
    final index = segment.indexOf('=');
    if (index <= 0) continue;
    params[segment.substring(0, index).toUpperCase()] = segment.substring(
      index + 1,
    );
  }

  return _IcsProperty(name: name, value: value, params: params);
}

class _IcsDateProperty {
  const _IcsDateProperty({required this.value, required this.params});

  final String value;
  final Map<String, String> params;

  factory _IcsDateProperty.from(_IcsProperty property) {
    return _IcsDateProperty(value: property.value, params: property.params);
  }

  DateTime? toDateTime() {
    if (params['VALUE']?.toUpperCase() == 'DATE') return null;
    if (value.length == 8) return null;

    final parsed = _parseDateTime(value);
    if (parsed == null) return null;

    final isUtc =
        value.toUpperCase().endsWith('Z') ||
        (params['TZID']?.toUpperCase() == 'UTC');
    return isUtc ? parsed.toLocal() : parsed;
  }
}

DateTime? _parseDateTime(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9T]'), '');
  if (cleaned.length < 15) return null;
  final year = int.tryParse(cleaned.substring(0, 4));
  final month = int.tryParse(cleaned.substring(4, 6));
  final day = int.tryParse(cleaned.substring(6, 8));
  final hour = int.tryParse(cleaned.substring(9, 11));
  final minute = int.tryParse(cleaned.substring(11, 13));
  final second = int.tryParse(cleaned.substring(13, 15));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

List<String> _unfoldLines(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final result = <String>[];
  for (final line in normalized.split('\n')) {
    if (result.isNotEmpty && (line.startsWith(' ') || line.startsWith('\t'))) {
      result[result.length - 1] += line.substring(1);
    } else if (line.isNotEmpty) {
      result.add(line);
    }
  }
  return result;
}

String _unescapeText(String value) {
  return value.replaceAllMapped(RegExp(r'\\([\\;,nN])'), (match) {
    switch (match.group(1)) {
      case 'n':
      case 'N':
        return '\n';
      case ',':
        return ',';
      case ';':
        return ';';
      case '\\':
        return '\\';
      default:
        return match.group(0)!;
    }
  });
}

String _extractTeacher(String description) {
  final match = RegExp(
    r'(?:教师|Teacher)\s*[：:]\s*(.+)',
    caseSensitive: false,
  ).firstMatch(description);
  return match?.group(1)?.split('\n').first.trim() ?? '';
}

String _shortName(String summary, String? uid) {
  final name = summary.trim().isEmpty ? (uid ?? '未命名事件') : summary.trim();
  return name.length > 24 ? '${name.substring(0, 24)}…' : name;
}

void _skip(List<String> skipped, _ParsedEvent event, String reason) {
  if (skipped.length >= 100) return;
  skipped.add('${_shortName(event.summary, null)}：$reason');
}

TimeSlot? _findStartSlot(Iterable<TimeSlot> slots, int minutes) {
  for (final slot in slots) {
    if (slot.startMinutes == minutes) return slot;
  }
  for (final slot in slots) {
    if (slot.startMinutes <= minutes && minutes < slot.endMinutes) return slot;
  }
  return null;
}

TimeSlot? _findEndSlot(Iterable<TimeSlot> slots, int minutes) {
  for (final slot in slots) {
    if (slot.endMinutes == minutes) return slot;
  }
  for (final slot in slots) {
    if (slot.startMinutes < minutes && minutes <= slot.endMinutes) return slot;
  }
  return null;
}

String _stableId(String input) {
  var hash = 0x811c9dc5;
  for (final code in input.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return 'ics_${hash.toRadixString(16).padLeft(8, '0')}';
}
