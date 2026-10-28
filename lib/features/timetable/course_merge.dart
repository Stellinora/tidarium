import 'model/course.dart';
import 'model/merged_course_block.dart';

List<MergedCourseBlock> mergeCoursesForWeek(
  List<Course> courses,
  int week, {
  int? maxSection,
}) {
  final active = <Course>[];
  for (final course in courses) {
    if (!course.weeks.contains(week)) continue;
    if (course.day < 1 || course.day > 7) continue;
    if (course.startSection < 1 || course.endSection < course.startSection) {
      continue;
    }
    if (maxSection != null && course.startSection > maxSection) continue;

    final start = course.startSection;
    final end = maxSection == null
        ? course.endSection
        : course.endSection.clamp(start, maxSection);
    active.add(
      start == course.startSection && end == course.endSection
          ? course
          : course.copyWith(endSection: end),
    );
  }

  active.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;
    final byStart = a.startSection.compareTo(b.startSection);
    if (byStart != 0) return byStart;
    final byLength = b.sectionCount.compareTo(a.sectionCount);
    if (byLength != 0) return byLength;
    return a.name.compareTo(b.name);
  });

  final byDay = <int, List<Course>>{};
  for (final course in active) {
    byDay.putIfAbsent(course.day, () => []).add(course);
  }

  final result = <MergedCourseBlock>[];
  final days = byDay.keys.toList()..sort();

  for (final day in days) {
    final clusters = _cluster(byDay[day]!);

    for (final cluster in clusters) {
      final ordered = cluster.toList()
        ..sort((a, b) {
          final byStart = a.startSection.compareTo(b.startSection);
          if (byStart != 0) return byStart;
          final byLength = b.sectionCount.compareTo(a.sectionCount);
          if (byLength != 0) return byLength;
          return a.name.compareTo(b.name);
        });

      final columnEnds = <int>[];
      final columnOf = <String, int>{};

      for (final course in ordered) {
        var assigned = -1;
        for (var index = 0; index < columnEnds.length; index++) {
          if (columnEnds[index] < course.startSection) {
            assigned = index;
            columnEnds[index] = course.endSection;
            break;
          }
        }
        if (assigned == -1) {
          columnEnds.add(course.endSection);
          assigned = columnEnds.length - 1;
        }
        columnOf[course.id] = assigned;
      }

      final columnCount = columnEnds.length;
      for (final course in ordered) {
        result.add(
          MergedCourseBlock(
            course: course,
            startSection: course.startSection,
            endSection: course.endSection,
            columnIndex: columnOf[course.id] ?? 0,
            columnCount: columnCount,
          ),
        );
      }
    }
  }

  result.sort((a, b) {
    final byDay = a.course.day.compareTo(b.course.day);
    if (byDay != 0) return byDay;
    final byStart = a.startSection.compareTo(b.startSection);
    if (byStart != 0) return byStart;
    return a.columnIndex.compareTo(b.columnIndex);
  });

  return List.unmodifiable(result);
}

List<List<Course>> _cluster(List<Course> courses) {
  final clusters = <List<Course>>[];

  for (final course in courses) {
    final overlapping = <List<Course>>[];
    for (final cluster in clusters) {
      if (cluster.any((other) => _overlaps(other, course))) {
        overlapping.add(cluster);
      }
    }

    if (overlapping.isEmpty) {
      clusters.add([course]);
      continue;
    }

    final merged = <Course>[course];
    for (final cluster in overlapping) {
      merged.addAll(cluster);
      clusters.remove(cluster);
    }
    clusters.add(merged);
  }

  return clusters;
}

bool _overlaps(Course a, Course b) {
  return a.startSection <= b.endSection && b.startSection <= a.endSection;
}
