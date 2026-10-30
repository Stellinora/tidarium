import 'package:flutter/material.dart';

import '../course_palette.dart';
import '../model/course.dart';

class TimetableCourseBlock extends StatelessWidget {
  const TimetableCourseBlock({
    super.key,
    required this.course,
    required this.onTap,
    this.showTeacher = true,
    this.showLocation = true,
    this.courseNameFontSize = 12,
    this.courseInfoFontSize = 9.5,
    this.sectionLabelFontSize = 9,
  });

  final Course course;
  final VoidCallback onTap;
  final bool showTeacher;
  final bool showLocation;
  final double courseNameFontSize;
  final double courseInfoFontSize;
  final double sectionLabelFontSize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = courseColor(course.colorIndex, brightness);
    final foreground = onCourseColor(background);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: foreground.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 96;
              final narrow = constraints.maxWidth < 56;
              final showDetails = showTeacher || showLocation;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!narrow && constraints.maxHeight >= 42)
                    Text(
                      '${course.startSection}-${course.endSection}时段',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: sectionLabelFontSize,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      course.name,
                      maxLines: compactHeight && showDetails
                          ? 1
                          : (compactHeight ? 2 : 3),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: narrow
                            ? (courseNameFontSize - 2).clamp(7, 32).toDouble()
                            : courseNameFontSize,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (showTeacher && course.teacher.isNotEmpty)
                    Text(
                      course.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: courseInfoFontSize,
                        height: 1.15,
                        color: foreground.withValues(alpha: 0.85),
                      ),
                    ),
                  if (showLocation && course.location.isNotEmpty)
                    Text(
                      '@${course.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: courseInfoFontSize,
                        height: 1.15,
                        color: foreground.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
