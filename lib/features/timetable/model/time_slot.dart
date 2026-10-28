class TimeSlot {
  const TimeSlot({
    required this.number,
    required this.startMinutes,
    required this.endMinutes,
    this.alias,
  });

  factory TimeSlot.fromJson(Map<String, Object?> json) {
    return TimeSlot(
      number: (json['number'] as num?)?.toInt() ?? 1,
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 8 * 60,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 8 * 60 + 45,
      alias: json['alias'] as String?,
    );
  }

  final int number;
  final int startMinutes;
  final int endMinutes;
  final String? alias;

  TimeSlot copyWith({
    int? number,
    int? startMinutes,
    int? endMinutes,
    String? alias,
  }) {
    return TimeSlot(
      number: number ?? this.number,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      alias: alias ?? this.alias,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'number': number,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'alias': alias,
    };
  }
}
