import '../timetable_time.dart';

class TimetableConfig {
  const TimetableConfig({
    this.name = '我的课表',
    this.semesterStart,
    this.totalWeeks = 20,
    this.showWeekends = false,
    this.showTeacher = true,
    this.showLocation = true,
    this.courseNameFontSize = 12,
    this.courseInfoFontSize = 9.5,
    this.sectionLabelFontSize = 9,
    this.weekdayHeaderFontSize = 14,
    this.dateFontSize = 10,
    this.timeSlotFontSize = 11,
    this.timeTextFontSize = 9,
    this.weekTitleFontSize = 16,
    this.hintFontSize = 12,
    this.backgroundImagePath,
    this.backgroundImageOpacity = 0.35,
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
      showTeacher: json['showTeacher'] as bool? ?? true,
      showLocation: json['showLocation'] as bool? ?? true,
      courseNameFontSize: _fontSize(json['courseNameFontSize'], 12),
      courseInfoFontSize: _fontSize(json['courseInfoFontSize'], 9.5),
      sectionLabelFontSize: _fontSize(json['sectionLabelFontSize'], 9),
      weekdayHeaderFontSize: _fontSize(json['weekdayHeaderFontSize'], 14),
      dateFontSize: _fontSize(json['dateFontSize'], 10),
      timeSlotFontSize: _fontSize(json['timeSlotFontSize'], 11),
      timeTextFontSize: _fontSize(json['timeTextFontSize'], 9),
      weekTitleFontSize: _fontSize(json['weekTitleFontSize'], 16),
      hintFontSize: _fontSize(json['hintFontSize'], 12),
      backgroundImagePath: json['backgroundImagePath'] as String?,
      backgroundImageOpacity:
          ((json['backgroundImageOpacity'] as num?)?.toDouble() ?? 0.35)
              .clamp(0.0, 1.0)
              .toDouble(),
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
  final bool showTeacher;
  final bool showLocation;
  final double courseNameFontSize;
  final double courseInfoFontSize;
  final double sectionLabelFontSize;
  final double weekdayHeaderFontSize;
  final double dateFontSize;
  final double timeSlotFontSize;
  final double timeTextFontSize;
  final double weekTitleFontSize;
  final double hintFontSize;
  final String? backgroundImagePath;
  final double backgroundImageOpacity;
  final int firstWeekday;
  final int defaultClassMinutes;
  final int defaultBreakMinutes;

  TimetableConfig copyWith({
    String? name,
    DateTime? semesterStart,
    int? totalWeeks,
    bool? showWeekends,
    bool? showTeacher,
    bool? showLocation,
    double? courseNameFontSize,
    double? courseInfoFontSize,
    double? sectionLabelFontSize,
    double? weekdayHeaderFontSize,
    double? dateFontSize,
    double? timeSlotFontSize,
    double? timeTextFontSize,
    double? weekTitleFontSize,
    double? hintFontSize,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? backgroundImageOpacity,
    int? firstWeekday,
    int? defaultClassMinutes,
    int? defaultBreakMinutes,
  }) {
    return TimetableConfig(
      name: name ?? this.name,
      semesterStart: semesterStart ?? this.semesterStart,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      showWeekends: showWeekends ?? this.showWeekends,
      showTeacher: showTeacher ?? this.showTeacher,
      showLocation: showLocation ?? this.showLocation,
      courseNameFontSize: courseNameFontSize ?? this.courseNameFontSize,
      courseInfoFontSize: courseInfoFontSize ?? this.courseInfoFontSize,
      sectionLabelFontSize: sectionLabelFontSize ?? this.sectionLabelFontSize,
      weekdayHeaderFontSize:
          weekdayHeaderFontSize ?? this.weekdayHeaderFontSize,
      dateFontSize: dateFontSize ?? this.dateFontSize,
      timeSlotFontSize: timeSlotFontSize ?? this.timeSlotFontSize,
      timeTextFontSize: timeTextFontSize ?? this.timeTextFontSize,
      weekTitleFontSize: weekTitleFontSize ?? this.weekTitleFontSize,
      hintFontSize: hintFontSize ?? this.hintFontSize,
      backgroundImagePath: clearBackgroundImage
          ? null
          : backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageOpacity:
          backgroundImageOpacity ?? this.backgroundImageOpacity,
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
      'showTeacher': showTeacher,
      'showLocation': showLocation,
      'courseNameFontSize': courseNameFontSize,
      'courseInfoFontSize': courseInfoFontSize,
      'sectionLabelFontSize': sectionLabelFontSize,
      'weekdayHeaderFontSize': weekdayHeaderFontSize,
      'dateFontSize': dateFontSize,
      'timeSlotFontSize': timeSlotFontSize,
      'timeTextFontSize': timeTextFontSize,
      'weekTitleFontSize': weekTitleFontSize,
      'hintFontSize': hintFontSize,
      'backgroundImagePath': backgroundImagePath,
      'backgroundImageOpacity': backgroundImageOpacity,
      'firstWeekday': firstWeekday,
      'defaultClassMinutes': defaultClassMinutes,
      'defaultBreakMinutes': defaultBreakMinutes,
    };
  }
}

double _fontSize(Object? value, double fallback) {
  return ((value as num?)?.toDouble() ?? fallback).clamp(7.0, 32.0).toDouble();
}
