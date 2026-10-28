import '../timetable_time.dart';

class TimetableConfig {
  const TimetableConfig({
    this.name = '我的课表',
    this.semesterStart,
    this.totalWeeks = 20,
    this.showWeekends = false,
    this.firstWeekday = DateTime.monday,
    this.defaultClassMinutes = 45,
    this.defaultBreakMinutes = 10,
  });

  factory TimetableConfig.fromJson(Map<String, Object?> json) {
    return TimetableConfig(
      name: json['name'] as String? ?? '我的课表',
      semesterStart: parseFullDate(json['semesterStart'] as String?),
      totalWeeks: ((json['totalWeeks'] as num?)?.toInt() ?? 20).clamp(1, 52),
      showWeekends: json['showWeekends'] as bool? ?? false,
      firstWeekday: ((json['firstWeekday'] as num?)?.toInt() ?? 1).clamp(1, 7),
      defaultClassMinutes:
          ((json['defaultClassMinutes'] as num?)?.toInt() ?? 45).clamp(1, 600),
      defaultBreakMinutes:
          ((json['defaultBreakMinutes'] as num?)?.toInt() ?? 10).clamp(0, 600),
    );
  }

  final String name;
  final DateTime? semesterStart;
  final int totalWeeks;
  final bool showWeekends;
  final int firstWeekday;
  final int defaultClassMinutes;
  final int defaultBreakMinutes;

  TimetableConfig copyWith({
    String? name,
    DateTime? semesterStart,
    int? totalWeeks,
    bool? showWeekends,
    int? firstWeekday,
    int? defaultClassMinutes,
    int? defaultBreakMinutes,
  }) {
    return TimetableConfig(
      name: name ?? this.name,
      semesterStart: semesterStart ?? this.semesterStart,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      showWeekends: showWeekends ?? this.showWeekends,
      firstWeekday: firstWeekday ?? this.firstWeekday,
      defaultClassMinutes: defaultClassMinutes ?? this.defaultClassMinutes,
      defaultBreakMinutes: defaultBreakMinutes ?? this.defaultBreakMinutes,
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
      'defaultClassMinutes': defaultClassMinutes,
      'defaultBreakMinutes': defaultBreakMinutes,
    };
  }
}
