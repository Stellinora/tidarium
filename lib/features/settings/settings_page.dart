import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_providers.dart';
import '../timetable/timetable_manager_page.dart';
import '../timetable/timetable_providers.dart';
import '../timetable/timetable_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginRegistryProvider).all;
    final timetable = ref.watch(timetableProvider);
    final timetableCount = ref
        .watch(timetableLibraryProvider)
        .timetables
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: const Text('课表管理'),
            subtitle: Text('共 $timetableCount 张课表 · 切换、新建、重命名或删除'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TimetableManagerPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('当前课表设置'),
            subtitle: Text('当前：${timetable.config.name} · 学期、显示、作息与导入'),
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
