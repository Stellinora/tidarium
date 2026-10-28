import 'model/course.dart';
import 'model/time_slot.dart';
import 'model/timetable_config.dart';

class SlotPlanResult {
  const SlotPlanResult({
    required this.slots,
    required this.courses,
    this.error,
  });

  final List<TimeSlot> slots;
  final List<Course> courses;
  final String? error;

  bool get ok => error == null;
}

abstract final class TimeSlotPlan {
  static String? validate({
    required TimeSlot slot,
    required List<TimeSlot> existing,
    int? editingNumber,
  }) {
    if (slot.startMinutes < 0 || slot.startMinutes >= 24 * 60) {
      return '开始时间无效';
    }
    if (slot.endMinutes <= slot.startMinutes || slot.endMinutes > 24 * 60) {
      return '结束时间必须晚于开始时间';
    }

    for (final other in existing) {
      if (other.number == editingNumber) continue;
      final overlaps =
          slot.startMinutes < other.endMinutes &&
          other.startMinutes < slot.endMinutes;
      if (overlaps) {
        return '与第 ${other.number} 节时间重叠';
      }
    }
    return null;
  }

  static TimeSlot buildNewSlot({
    required List<TimeSlot> slots,
    required TimetableConfig config,
  }) {
    final lastEnd = slots.isEmpty
        ? 8 * 60
        : slots.map((slot) => slot.endMinutes).reduce((a, b) => a > b ? a : b);
    final suggestedStart = slots.isEmpty
        ? lastEnd
        : lastEnd + config.defaultBreakMinutes;
    final start = suggestedStart.clamp(0, 24 * 60 - 2).toInt();
    final end = (start + config.defaultClassMinutes)
        .clamp(start + 1, 24 * 60)
        .toInt();

    return TimeSlot(
      number:
          (slots
              .map((slot) => slot.number)
              .fold<int>(0, (a, b) => a > b ? a : b)) +
          1,
      startMinutes: start,
      endMinutes: end,
    );
  }

  static SlotPlanResult add({
    required List<TimeSlot> slots,
    required List<Course> courses,
    required TimeSlot slot,
  }) {
    final error = validate(slot: slot, existing: slots);
    if (error != null) {
      return SlotPlanResult(slots: slots, courses: courses, error: error);
    }

    final newSlots = _renumber([...slots, slot]);
    final remapped = remapCourses(
      courses: courses,
      oldSlots: slots,
      newSlots: newSlots,
    );
    if (remapped == null) {
      return const SlotPlanResult(
        slots: [],
        courses: [],
        error: '新增节次后无法重新映射课程时间',
      );
    }

    return SlotPlanResult(slots: newSlots, courses: remapped);
  }

  static SlotPlanResult update({
    required List<TimeSlot> slots,
    required TimeSlot slot,
  }) {
    final error = validate(
      slot: slot,
      existing: slots,
      editingNumber: slot.number,
    );
    if (error != null) {
      return SlotPlanResult(slots: slots, courses: const [], error: error);
    }

    final next = [
      for (final existing in slots)
        if (existing.number == slot.number) slot else existing,
    ]..sort((a, b) => a.number.compareTo(b.number));

    return SlotPlanResult(slots: next, courses: const []);
  }

  static SlotPlanResult remove({
    required List<TimeSlot> slots,
    required List<Course> courses,
    required int number,
  }) {
    final usedCount = usageCount(courses, number);
    if (usedCount > 0) {
      return SlotPlanResult(
        slots: slots,
        courses: courses,
        error: '第 $number 节正被 $usedCount 门课程使用，请先调整课程',
      );
    }

    final oldSlots = [...slots];
    final remaining = slots.where((slot) => slot.number != number).toList();
    final newSlots = _renumber(remaining);
    final remapped = remapCourses(
      courses: courses,
      oldSlots: oldSlots,
      newSlots: newSlots,
    );
    if (remapped == null) {
      return const SlotPlanResult(
        slots: [],
        courses: [],
        error: '删除节次后无法重新映射课程时间',
      );
    }

    return SlotPlanResult(slots: newSlots, courses: remapped);
  }

  static int usageCount(List<Course> courses, int number) {
    return courses.where((course) {
      return course.startSection <= number && course.endSection >= number;
    }).length;
  }

  static List<Course>? remapCourses({
    required List<Course> courses,
    required List<TimeSlot> oldSlots,
    required List<TimeSlot> newSlots,
  }) {
    final oldByNumber = {for (final slot in oldSlots) slot.number: slot};
    final result = <Course>[];

    for (final course in courses) {
      final oldStart = oldByNumber[course.startSection];
      final oldEnd = oldByNumber[course.endSection];
      if (oldStart == null || oldEnd == null) {
        result.add(course);
        continue;
      }

      final newStart = _findStartSlot(newSlots, oldStart.startMinutes);
      final newEnd = _findEndSlot(newSlots, oldEnd.endMinutes);
      if (newStart == null || newEnd == null) {
        return null;
      }

      result.add(
        course.copyWith(
          startSection: newStart.number,
          endSection: newEnd.number,
        ),
      );
    }

    return result;
  }

  static TimeSlot? _findStartSlot(List<TimeSlot> slots, int minutes) {
    for (final slot in slots) {
      if (slot.startMinutes == minutes) return slot;
    }
    for (final slot in slots) {
      if (slot.startMinutes <= minutes && minutes < slot.endMinutes) {
        return slot;
      }
    }
    return null;
  }

  static TimeSlot? _findEndSlot(List<TimeSlot> slots, int minutes) {
    for (final slot in slots) {
      if (slot.endMinutes == minutes) return slot;
    }
    for (final slot in slots) {
      if (slot.startMinutes < minutes && minutes <= slot.endMinutes) {
        return slot;
      }
    }
    return null;
  }

  static List<TimeSlot> _renumber(List<TimeSlot> slots) {
    final sorted = [...slots]
      ..sort((a, b) {
        final byStart = a.startMinutes.compareTo(b.startMinutes);
        if (byStart != 0) return byStart;
        final byEnd = a.endMinutes.compareTo(b.endMinutes);
        if (byEnd != 0) return byEnd;
        return a.number.compareTo(b.number);
      });

    return [
      for (var index = 0; index < sorted.length; index++)
        sorted[index].copyWith(number: index + 1),
    ];
  }
}
