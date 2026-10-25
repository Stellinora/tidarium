import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginRegistryProvider).all;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const ListTile(title: Text('插件'), subtitle: Text('静态注册，按需启用')),
          for (final plugin in plugins)
            ListTile(
              leading: const Icon(Icons.extension_outlined),
              title: Text(plugin.manifest.name),
              subtitle: Text(
                '${plugin.manifest.id} · ${plugin.authState.name} · '
                '${plugin.manifest.permissions.map((permission) => permission.name).join(', ')}',
              ),
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Tidarium'),
            subtitle: Text('时匣 · 一体化日程助手'),
          ),
        ],
      ),
    );
  }
}
