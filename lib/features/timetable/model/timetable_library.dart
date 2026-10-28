import 'timetable_data.dart';

class TimetableLibrary {
  const TimetableLibrary({required this.activeId, required this.timetables});

  factory TimetableLibrary.initial({DateTime? now}) {
    return TimetableLibrary.single(TimetableData.initial(now: now));
  }

  factory TimetableLibrary.single(TimetableData data) {
    return TimetableLibrary(activeId: data.id, timetables: [data]);
  }

  factory TimetableLibrary.fromJson(Map<String, Object?> json) {
    final rawTimetables = json['timetables'];
    if (rawTimetables is List) {
      final timetables = <TimetableData>[];
      for (final entry in rawTimetables) {
        if (entry is Map) {
          timetables.add(TimetableData.fromJson(entry.cast<String, Object?>()));
        }
      }
      if (timetables.isEmpty) return TimetableLibrary.initial();

      final requestedActiveId = json['activeId']?.toString();
      final activeId =
          timetables.any((timetable) => timetable.id == requestedActiveId)
          ? requestedActiveId!
          : timetables.first.id;
      return TimetableLibrary(
        activeId: activeId,
        timetables: List.unmodifiable(timetables),
      );
    }

    // Migrate the single-timetable file written by older versions.
    if (json.containsKey('config') ||
        json.containsKey('timeSlots') ||
        json.containsKey('courses')) {
      return TimetableLibrary.single(TimetableData.fromJson(json));
    }

    return TimetableLibrary.initial();
  }

  final String activeId;
  final List<TimetableData> timetables;

  TimetableData get active {
    return timetables.firstWhere(
      (timetable) => timetable.id == activeId,
      orElse: () => timetables.first,
    );
  }

  TimetableData? find(String id) {
    for (final timetable in timetables) {
      if (timetable.id == id) return timetable;
    }
    return null;
  }

  TimetableLibrary copyWith({
    String? activeId,
    List<TimetableData>? timetables,
  }) {
    return TimetableLibrary(
      activeId: activeId ?? this.activeId,
      timetables: timetables ?? this.timetables,
    );
  }

  TimetableLibrary replace(TimetableData data) {
    return copyWith(
      timetables: List.unmodifiable([
        for (final timetable in timetables)
          if (timetable.id == data.id) data else timetable,
      ]),
    );
  }

  TimetableLibrary add(TimetableData data) {
    return TimetableLibrary(
      activeId: data.id,
      timetables: List.unmodifiable([...timetables, data]),
    );
  }

  TimetableLibrary remove(String id) {
    final remaining = timetables
        .where((timetable) => timetable.id != id)
        .toList(growable: false);
    if (remaining.isEmpty) return this;

    return TimetableLibrary(
      activeId: activeId == id ? remaining.first.id : activeId,
      timetables: List.unmodifiable(remaining),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 2,
      'activeId': activeId,
      'timetables': [for (final timetable in timetables) timetable.toJson()],
    };
  }
}
