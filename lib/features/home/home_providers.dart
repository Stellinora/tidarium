import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/event_store.dart';
import '../../core/model/standard_event.dart';
import '../../core/plugin/plugin_registry.dart';

final eventStoreProvider = Provider<EventStore>((ref) => InMemoryEventStore());

final pluginRegistryProvider = Provider<PluginRegistry>(
  (ref) => PluginRegistry(),
);

final eventsProvider = FutureProvider<List<StandardEvent>>(
  (ref) => ref.watch(eventStoreProvider).all(),
);
