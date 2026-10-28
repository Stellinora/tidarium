import 'course.dart';

class MergedCourseBlock {
  const MergedCourseBlock({
    required this.course,
    required this.startSection,
    required this.endSection,
    required this.columnIndex,
    required this.columnCount,
  });

  final Course course;
  final int startSection;
  final int endSection;
  final int columnIndex;
  final int columnCount;

  int get sectionSpan => endSection - startSection + 1;

  double get leftFraction => columnIndex / columnCount;

  double get widthFraction => 1 / columnCount;
}
