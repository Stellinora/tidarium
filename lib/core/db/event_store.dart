import 'dart:async';

import '../model/standard_event.dart';

abstract interface class EventStore {
  Future<List<StandardEvent>> all();

  Stream<List<StandardEvent>> watchAll();

  Future<void> upsertAll(Iterable<StandardEvent> events);

  Future<void> clear();
}

class InMemoryEventStore implements EventStore {
  final Map<String, StandardEvent> _events = {};
  final _controller = StreamController<List<StandardEvent>>.broadcast();

  @override
  Future<List<StandardEvent>> all() async {
    return _events.values.toList(growable: false);
  }

  @override
  Stream<List<StandardEvent>> watchAll() async* {
    yield await all();
    yield* _controller.stream;
  }

  @override
  Future<void> upsertAll(Iterable<StandardEvent> events) async {
    for (final event in events) {
      _events[event.id] = event;
    }
    _emit();
  }

  @override
  Future<void> clear() async {
    _events.clear();
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_events.values.toList(growable: false));
    }
  }
}
