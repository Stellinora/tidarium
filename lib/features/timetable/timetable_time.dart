import 'model/time_slot.dart';

const List<String> weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayName(int weekday) {
  final index = weekday.clamp(1, 7) - 1;
  return weekdayNames[index];
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatMinuteOfDay(int minutes) {
  final normalized = minutes.clamp(0, 24 * 60 - 1);
  return '${twoDigits(normalized ~/ 60)}:${twoDigits(normalized % 60)}';
}

int parseMinuteOfDay(String text) {
  final parts = text.split(':');
  if (parts.length != 2) return 0;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return hour * 60 + minute;
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime addCalendarDays(DateTime date, int days) {
  final shifted = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: days));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

DateTime startOfWeek(DateTime date, {int firstWeekday = DateTime.monday}) {
  final safeFirst = firstWeekday.clamp(1, 7);
  final offset = (date.weekday - safeFirst + 7) % 7;
  return addCalendarDays(dateOnly(date), -offset);
}

int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

int? weekNumberFor(
  DateTime target,
  DateTime? semesterStart, {
  int firstWeekday = DateTime.monday,
}) {
  if (semesterStart == null) return null;
  final alignedStart = startOfWeek(semesterStart, firstWeekday: firstWeekday);
  final alignedTarget = startOfWeek(target, firstWeekday: firstWeekday);
  return daysBetween(alignedStart, alignedTarget) ~/ 7 + 1;
}

DateTime weekStartDate(
  int weekNumber, {
  required DateTime semesterStart,
  int firstWeekday = DateTime.monday,
}) {
  final alignedStart = startOfWeek(semesterStart, firstWeekday: firstWeekday);
  return addCalendarDays(alignedStart, (weekNumber - 1) * 7);
}

DateTime dateOfWeekday(
  int weekNumber,
  int weekday, {
  required DateTime semesterStart,
  int firstWeekday = DateTime.monday,
}) {
  final weekStart = weekStartDate(
    weekNumber,
    semesterStart: semesterStart,
    firstWeekday: firstWeekday,
  );
  final offset = (weekday.clamp(1, 7) - firstWeekday.clamp(1, 7) + 7) % 7;
  return addCalendarDays(weekStart, offset);
}

int displayIndexOfWeekday(int weekday, int firstWeekday) {
  return (weekday.clamp(1, 7) - firstWeekday.clamp(1, 7) + 7) % 7;
}

int weekdayAtDisplayIndex(int index, int firstWeekday) {
  return (firstWeekday.clamp(1, 7) - 1 + index) % 7 + 1;
}

List<int> orderedWeekdays({
  required int firstWeekday,
  required bool showWeekends,
}) {
  final days = [
    for (var index = 0; index < 7; index++)
      weekdayAtDisplayIndex(index, firstWeekday),
  ];
  if (showWeekends) return days;
  return days.where((day) => day <= 5).toList(growable: false);
}

String formatShortDate(DateTime date) => '${date.month}/${date.day}';

String formatFullDate(DateTime date) =>
    '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';

DateTime? parseFullDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

int? currentSectionNumber(List<TimeSlot> slots, DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  for (final slot in slots) {
    if (minutes >= slot.startMinutes && minutes < slot.endMinutes) {
      return slot.number;
    }
  }
  return null;
}

String formatWeeks(Set<int> weeks) {
  if (weeks.isEmpty) return '未选择周次';
  final sorted = weeks.toList()..sort();
  final ranges = <String>[];
  var start = sorted.first;
  var previous = sorted.first;

  for (final week in sorted.skip(1)) {
    if (week == previous + 1) {
      previous = week;
      continue;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
    start = week;
    previous = week;
  }
  ranges.add(start == previous ? '$start' : '$start-$previous');

  return '${ranges.join(', ')} 周';
}
