import 'timetable_data.dart';

class TimetableLibrary {
  const TimetableLibrary({
    required this.activeId,
    required this.timetables,
    String? primaryId,
    // ignore: prefer_initializing_formals
  }) : _primaryId = primaryId;

  final String? _primaryId;

  factory TimetableLibrary.initial({DateTime? now}) {
    return TimetableLibrary.single(TimetableData.initial(now: now));
  }

  factory TimetableLibrary.single(TimetableData data) {
    return TimetableLibrary(
      activeId: data.id,
      timetables: [data],
      primaryId: data.id,
    );
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
      final requestedPrimaryId = json['primaryId']?.toString();
      final primaryId =
          timetables.any((timetable) => timetable.id == requestedPrimaryId)
          ? requestedPrimaryId
          : activeId;
      return TimetableLibrary(
        activeId: activeId,
        timetables: List.unmodifiable(timetables),
        primaryId: primaryId,
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

  /// 主课表。新任务默认落在这里；删除它时顺延到剩下的第一张。
  /// 旧数据没有该字段时回落到 activeId。
  String get primaryId {
    final candidate = _primaryId;
    if (candidate != null &&
        timetables.any((timetable) => timetable.id == candidate)) {
      return candidate;
    }
    return activeId;
  }

  TimetableData get primary {
    return timetables.firstWhere(
      (timetable) => timetable.id == primaryId,
      orElse: () => active,
    );
  }

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
    String? primaryId,
  }) {
    return TimetableLibrary(
      activeId: activeId ?? this.activeId,
      timetables: timetables ?? this.timetables,
      primaryId: primaryId ?? this.primaryId,
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
      primaryId: primaryId,
    );
  }

  TimetableLibrary remove(String id) {
    final remaining = timetables
        .where((timetable) => timetable.id != id)
        .toList(growable: false);
    if (remaining.isEmpty) return this;

    final nextPrimary = primaryId == id ? remaining.first.id : primaryId;
    return TimetableLibrary(
      activeId: activeId == id ? remaining.first.id : activeId,
      timetables: List.unmodifiable(remaining),
      primaryId: nextPrimary,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 3,
      'activeId': activeId,
      'primaryId': primaryId,
      'timetables': [for (final timetable in timetables) timetable.toJson()],
    };
  }
}


