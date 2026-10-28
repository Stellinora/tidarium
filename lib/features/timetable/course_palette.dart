import 'package:flutter/material.dart';

class CourseColorPair {
  const CourseColorPair({required this.light, required this.dark});

  final Color light;
  final Color dark;
}

const List<CourseColorPair> courseColors = [
  CourseColorPair(light: Color(0xFFFFCC99), dark: Color(0xFF663300)),
  CourseColorPair(light: Color(0xFFFFE699), dark: Color(0xFF664D00)),
  CourseColorPair(light: Color(0xFFE6FF99), dark: Color(0xFF4D6600)),
  CourseColorPair(light: Color(0xFFCCFF99), dark: Color(0xFF336600)),
  CourseColorPair(light: Color(0xFF99FFB3), dark: Color(0xFF00661A)),
  CourseColorPair(light: Color(0xFF99FFE6), dark: Color(0xFF00664D)),
  CourseColorPair(light: Color(0xFF99FFFF), dark: Color(0xFF006666)),
  CourseColorPair(light: Color(0xFF99E6FF), dark: Color(0xFF004D66)),
  CourseColorPair(light: Color(0xFFB399FF), dark: Color(0xFF1A0066)),
  CourseColorPair(light: Color(0xFFFF99E6), dark: Color(0xFF66004D)),
  CourseColorPair(light: Color(0xFFFF99CC), dark: Color(0xFF660033)),
  CourseColorPair(light: Color(0xFFFF99B3), dark: Color(0xFF66001A)),
];

int normalizeColorIndex(int index) {
  if (courseColors.isEmpty) return 0;
  return index.abs() % courseColors.length;
}

Color courseColor(int index, Brightness brightness) {
  final pair = courseColors[normalizeColorIndex(index)];
  return brightness == Brightness.dark ? pair.dark : pair.light;
}

Color onCourseColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}
