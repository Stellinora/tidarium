import 'package:flutter/material.dart';

import '../course_palette.dart';
import '../model/course.dart';

class TimetableCourseBlock extends StatelessWidget {
  const TimetableCourseBlock({
    super.key,
    required this.course,
    required this.onTap,
  });

  final Course course;
  final VoidCallback onTap;

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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!narrow && constraints.maxHeight >= 42)
                    Text(
                      '${course.startSection}-${course.endSection}节',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      course.name,
                      maxLines: compactHeight ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: narrow ? 10 : 12,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (!compactHeight && !narrow && course.teacher.isNotEmpty)
                    Text(
                      course.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        color: foreground.withValues(alpha: 0.85),
                      ),
                    ),
                  if (!compactHeight && !narrow && course.location.isNotEmpty)
                    Text(
                      '@${course.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
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
