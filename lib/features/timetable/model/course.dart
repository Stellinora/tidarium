class Course {
  const Course({
    required this.id,
    required this.name,
    required this.day,
    required this.startSection,
    required this.endSection,
    required this.weeks,
    required this.colorIndex,
    this.teacher = '',
    this.location = '',
    this.remark = '',
  });

  factory Course.fromJson(Map<String, Object?> json) {
    final rawWeeks = json['weeks'];
    final weeks = <int>{};
    if (rawWeeks is List) {
      for (final value in rawWeeks) {
        if (value is num) {
          weeks.add(value.toInt());
        } else if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) weeks.add(parsed);
        }
      }
    }

    return Course(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名课程',
      day: (json['day'] as num?)?.toInt() ?? 1,
      startSection: (json['startSection'] as num?)?.toInt() ?? 1,
      endSection: (json['endSection'] as num?)?.toInt() ?? 1,
      weeks: weeks,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      teacher: json['teacher'] as String? ?? '',
      location: json['location'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final int day;
  final int startSection;
  final int endSection;
  final Set<int> weeks;
  final int colorIndex;
  final String teacher;
  final String location;
  final String remark;

  int get sectionCount => endSection - startSection + 1;

  Course copyWith({
    String? id,
    String? name,
    int? day,
    int? startSection,
    int? endSection,
    Set<int>? weeks,
    int? colorIndex,
    String? teacher,
    String? location,
    String? remark,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      day: day ?? this.day,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      weeks: weeks ?? this.weeks,
      colorIndex: colorIndex ?? this.colorIndex,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      remark: remark ?? this.remark,
    );
  }

  Map<String, Object?> toJson() {
    final sortedWeeks = weeks.toList()..sort();

    return {
      'id': id,
      'name': name,
      'day': day,
      'startSection': startSection,
      'endSection': endSection,
      'weeks': sortedWeeks,
      'colorIndex': colorIndex,
      'teacher': teacher,
      'location': location,
      'remark': remark,
    };
  }
}
