import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/location_display.dart';

void main() {
  test('splits a teaching building location into three parts', () {
    final parsed = parseLocation('第1教研楼东301');

    expect(parsed.isStructured, isTrue);
    expect(parsed.building, '第1教研楼');
    expect(parsed.direction, '东');
    expect(parsed.room, '301');
    expect(parsed.parts, ['第1教研楼', '东', '301']);
  });

  test('supports short and direction-first formats', () {
    expect(parseLocation('1教东301').parts, ['1教', '东', '301']);
    expect(parseLocation('东301').parts, ['东', '301']);
    expect(parseLocation('A楼302').parts, ['A楼', '302']);
  });

  test('keeps unknown locations unstructured', () {
    final parsed = parseLocation('线上教学');

    expect(parsed.isStructured, isFalse);
    expect(parsed.parts, ['线上教学']);
  });
}
