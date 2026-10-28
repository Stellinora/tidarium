import '../timetable_time.dart';
import 'course.dart';
import 'time_slot.dart';
import 'timetable_config.dart';

const List<TimeSlot> defaultTimeSlots = [
  TimeSlot(number: 1, startMinutes: 8 * 60, endMinutes: 8 * 60 + 45),
  TimeSlot(number: 2, startMinutes: 8 * 60 + 50, endMinutes: 9 * 60 + 35),
  TimeSlot(number: 3, startMinutes: 9 * 60 + 50, endMinutes: 10 * 60 + 35),
  TimeSlot(number: 4, startMinutes: 10 * 60 + 40, endMinutes: 11 * 60 + 25),
  TimeSlot(number: 5, startMinutes: 11 * 60 + 30, endMinutes: 12 * 60 + 15),
  TimeSlot(number: 6, startMinutes: 14 * 60, endMinutes: 14 * 60 + 45),
  TimeSlot(number: 7, startMinutes: 14 * 60 + 50, endMinutes: 15 * 60 + 35),
  TimeSlot(number: 8, startMinutes: 15 * 60 + 45, endMinutes: 16 * 60 + 30),
  TimeSlot(number: 9, startMinutes: 16 * 60 + 35, endMinutes: 17 * 60 + 20),
  TimeSlot(number: 10, startMinutes: 18 * 60 + 30, endMinutes: 19 * 60 + 15),
  TimeSlot(number: 11, startMinutes: 19 * 60 + 20, endMinutes: 20 * 60 + 5),
  TimeSlot(number: 12, startMinutes: 20 * 60 + 10, endMinutes: 20 * 60 + 55),
  TimeSlot(number: 13, startMinutes: 21 * 60 + 10, endMinutes: 21 * 60 + 55),
];

class TimetableData {
  const TimetableData({
    this.id = 'main',
    required this.config,
    required this.timeSlots,
    required this.courses,
  });

  factory TimetableData.initial({
    DateTime? now,
    String id = 'main',
    String? name,
  }) {
    final today = now ?? DateTime.now();

    return TimetableData(
      id: id,
      config: TimetableConfig(
        name: name ?? '我的课表',
        semesterStart: startOfWeek(today),
      ),
      timeSlots: defaultTimeSlots,
      courses: const [],
    );
  }

  factory TimetableData.fromJson(Map<String, Object?> json) {
    final rawSlots = json['timeSlots'];
    final slots = <TimeSlot>[];
    if (rawSlots is List) {
      for (final entry in rawSlots) {
        if (entry is Map) {
          slots.add(TimeSlot.fromJson(entry.cast<String, Object?>()));
        }
      }
    }

    final rawCourses = json['courses'];
    final courses = <Course>[];
    if (rawCourses is List) {
      for (final entry in rawCourses) {
        if (entry is Map) {
          courses.add(Course.fromJson(entry.cast<String, Object?>()));
        }
      }
    }

    final rawConfig = json['config'];

    return TimetableData(
      id: json['id'] as String? ?? 'main',
      config: rawConfig is Map
          ? TimetableConfig.fromJson(rawConfig.cast<String, Object?>())
          : const TimetableConfig(),
      timeSlots: _normalizeSlots(slots),
      courses: List.unmodifiable(courses),
    );
  }

  final String id;
  final TimetableConfig config;
  final List<TimeSlot> timeSlots;
  final List<Course> courses;

  TimetableData copyWith({
    String? id,
    TimetableConfig? config,
    List<TimeSlot>? timeSlots,
    List<Course>? courses,
  }) {
    return TimetableData(
      id: id ?? this.id,
      config: config ?? this.config,
      timeSlots: timeSlots ?? this.timeSlots,
      courses: courses ?? this.courses,
    );
  }

  List<Course> coursesForWeek(int week) {
    return courses
        .where((course) => course.weeks.contains(week))
        .toList(growable: false);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'config': config.toJson(),
      'timeSlots': [for (final slot in timeSlots) slot.toJson()],
      'courses': [for (final course in courses) course.toJson()],
    };
  }

  static List<TimeSlot> _normalizeSlots(List<TimeSlot> slots) {
    if (slots.isEmpty) return defaultTimeSlots;
    final sorted = slots.toList()..sort((a, b) => a.number.compareTo(b.number));
    return List.unmodifiable(sorted);
  }
}
