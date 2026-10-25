import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../settings/settings_page.dart';
import 'home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final registry = ref.watch(pluginRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tidarium · 时匣'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final plugin in registry.all)
                    Chip(
                      avatar: const Icon(Icons.extension, size: 16),
                      label: Text(plugin.manifest.name),
                    ),
                ],
              ),
            ),
            Expanded(
              child: events.when(
                data: (items) => items.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = items[index];
                          final dueTime = event.dueTime;
                          return Card(
                            child: ListTile(
                              title: Text(event.title),
                              subtitle: Text(event.source),
                              trailing: dueTime == null
                                  ? null
                                  : Text(
                                      DateFormat.MMMd().add_Hm().format(
                                        dueTime,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('读取失败：$error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('还没有日程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('接入插件后开始同步', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
