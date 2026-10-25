import '../model/standard_event.dart';

enum AuthState { unknown, valid, expired, kicked }

enum PluginPermission { network, aiCloud, aiLocal, submitActions }

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    this.version = '0.0.0',
    this.permissions = const {},
  });

  final String id;
  final String name;
  final String version;
  final Set<PluginPermission> permissions;
}

abstract interface class DataSourcePlugin {
  PluginManifest get manifest;

  AuthState get authState;

  Future<AuthState> authenticate();

  Future<List<StandardEvent>> fetchEvents();
}
