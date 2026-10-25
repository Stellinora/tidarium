import '../model/standard_event.dart';

abstract interface class EventStore {
  Future<List<StandardEvent>> all();

  Future<void> upsertAll(Iterable<StandardEvent> events);

  Future<void> clear();
}

class InMemoryEventStore implements EventStore {
  final Map<String, StandardEvent> _events = {};

  @override
  Future<List<StandardEvent>> all() async {
    return _events.values.toList(growable: false);
  }

  @override
  Future<void> upsertAll(Iterable<StandardEvent> events) async {
    for (final event in events) {
      _events[event.id] = event;
    }
  }

  @override
  Future<void> clear() async {
    _events.clear();
  }
}
