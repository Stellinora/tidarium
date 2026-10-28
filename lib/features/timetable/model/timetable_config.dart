import '../timetable_time.dart';

class TimetableConfig {
  const TimetableConfig({
    this.name = '我的课表',
    this.semesterStart,
    this.totalWeeks = 20,
    this.showWeekends = false,
    this.firstWeekday = DateTime.monday,
  });

  factory TimetableConfig.fromJson(Map<String, Object?> json) {
    return TimetableConfig(
      name: json['name'] as String? ?? '我的课表',
      semesterStart: parseFullDate(json['semesterStart'] as String?),
      totalWeeks: ((json['totalWeeks'] as num?)?.toInt() ?? 20).clamp(1, 52),
      showWeekends: json['showWeekends'] as bool? ?? false,
      firstWeekday: ((json['firstWeekday'] as num?)?.toInt() ?? 1).clamp(1, 7),
    );
  }

  final String name;
  final DateTime? semesterStart;
  final int totalWeeks;
  final bool showWeekends;
  final int firstWeekday;

  TimetableConfig copyWith({
    String? name,
    DateTime? semesterStart,
    int? totalWeeks,
    bool? showWeekends,
    int? firstWeekday,
  }) {
    return TimetableConfig(
      name: name ?? this.name,
      semesterStart: semesterStart ?? this.semesterStart,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      showWeekends: showWeekends ?? this.showWeekends,
      firstWeekday: firstWeekday ?? this.firstWeekday,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'semesterStart': semesterStart == null
          ? null
          : formatFullDate(semesterStart!),
      'totalWeeks': totalWeeks,
      'showWeekends': showWeekends,
      'firstWeekday': firstWeekday,
    };
  }
}
