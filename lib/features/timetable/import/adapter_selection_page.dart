import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_providers.dart';
import 'models/school_models.dart';
import 'web_import_page.dart';

class AdapterSelectionPage extends ConsumerStatefulWidget {
  const AdapterSelectionPage({super.key, required this.school});

  final SchoolEntry school;

  @override
  ConsumerState<AdapterSelectionPage> createState() =>
      _AdapterSelectionPageState();
}

class _AdapterSelectionPageState extends ConsumerState<AdapterSelectionPage> {
  List<SchoolAdapter> _adapters = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final adapters = await ref
          .read(adapterRepositoryProvider)
          .loadAdapters(widget.school, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _adapters = adapters;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school.name),
        actions: [
          IconButton(
            tooltip: '刷新适配器',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_adapters.isEmpty) {
      return Center(
        child: Text(
          '这个学校还没有适配器',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _adapters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final adapter = _adapters[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    WebImportPage(school: widget.school, adapter: adapter),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          adapter.adapterName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _categoryLabel(adapter.category),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (adapter.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      adapter.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        adapter.maintainer.isEmpty
                            ? '维护者未知'
                            : adapter.maintainer,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _categoryLabel(String category) {
    return switch (category.toUpperCase()) {
      'BACHELOR_AND_ASSOCIATE' => '本科/专科',
      'POSTGRADUATE' => '研究生',
      'GENERAL_TOOL' => '通用工具',
      _ => '其他',
    };
  }
}
