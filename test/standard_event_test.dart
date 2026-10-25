import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/model/standard_event.dart';

void main() {
  test('StandardEvent round-trips through JSON', () {
    final event = StandardEvent(
      id: 'chaoxing:1',
      type: EventType.assignment,
      title: '高等数学作业',
      dueTime: DateTime.utc(2026, 10, 30, 12),
      source: 'chaoxing',
    );

    final restored = StandardEvent.fromJson(event.toJson());

    expect(restored.id, event.id);
    expect(restored.type, event.type);
    expect(restored.title, event.title);
    expect(restored.dueTime, event.dueTime);
    expect(restored.source, event.source);
  });

  test('StandardEvent uses the documented online_session wire name', () {
    final event = StandardEvent(
      id: 'mooc:1',
      type: EventType.onlineSession,
      title: '直播课',
      source: 'mooc',
    );

    expect(event.toJson()['type'], 'online_session');
  });

  test('StandardEvent tolerates unknown event types', () {
    final restored = StandardEvent.fromJson(const {
      'id': 'x',
      'type': 'unknown',
      'title': 't',
      'source': 's',
    });

    expect(restored.type, EventType.assignment);
  });
}
