import '../../core/model/standard_event.dart';
import '../../core/plugin/plugin.dart';

class ChaoxingPlugin implements DataSourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'chaoxing',
    name: '学习通',
    permissions: {PluginPermission.network, PluginPermission.aiCloud},
  );

  @override
  AuthState get authState => AuthState.unknown;

  @override
  Future<AuthState> authenticate() async => AuthState.expired;

  @override
  Future<List<StandardEvent>> fetchEvents() async => const [];
}
