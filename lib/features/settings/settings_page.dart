import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_providers.dart';
import '../timetable/timetable_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginRegistryProvider).all;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('课程表'),
            subtitle: const Text('学期、节次与显示设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TimetableSettingsPage(),
              ),
            ),
          ),
          const Divider(),
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
