import '../../plugins/chaoxing/chaoxing_plugin.dart';
import '../../plugins/mooc/mooc_plugin.dart';
import 'plugin.dart';

class PluginRegistry {
  PluginRegistry({List<DataSourcePlugin>? plugins})
    : _plugins = List.unmodifiable(plugins ?? _builtIns());

  final List<DataSourcePlugin> _plugins;

  List<DataSourcePlugin> get all => _plugins;

  DataSourcePlugin? byId(String id) {
    for (final plugin in _plugins) {
      if (plugin.manifest.id == id) {
        return plugin;
      }
    }
    return null;
  }

  static List<DataSourcePlugin> _builtIns() {
    return [ChaoxingPlugin(), MoocPlugin()];
  }
}
