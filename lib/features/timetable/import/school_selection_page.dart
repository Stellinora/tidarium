import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapter_selection_page.dart';
import 'import_providers.dart';
import 'models/school_models.dart';

class SchoolSelectionPage extends ConsumerStatefulWidget {
  const SchoolSelectionPage({super.key});

  @override
  ConsumerState<SchoolSelectionPage> createState() =>
      _SchoolSelectionPageState();
}

class _SchoolSelectionPageState extends ConsumerState<SchoolSelectionPage> {
  List<SchoolEntry> _schools = const [];
  var _loading = true;
  String? _error;
  var _query = '';

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
      final schools = await ref
          .read(adapterRepositoryProvider)
          .loadSchools(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _schools = schools;
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

  List<SchoolEntry> get _filteredSchools {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _schools;
    return _schools
        .where((school) {
          return school.name.toLowerCase().contains(query) ||
              school.initial.toLowerCase().contains(query) ||
              school.id.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择学校'),
        actions: [
          IconButton(
            tooltip: '刷新适配器仓库',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索学校名称、拼音首字母或 ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '适配器来自拾光课程表仓库（MIT），首次加载需要联网。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(theme)),
        ],
      ),
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

    final schools = _filteredSchools;
    if (schools.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? '仓库里还没有学校' : '没有找到匹配的学校',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: schools.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final school = schools[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CircleAvatar(
            child: Text(
              school.initial.isEmpty
                  ? school.name.substring(0, 1)
                  : school.initial.substring(0, 1),
            ),
          ),
          title: Text(school.name),
          subtitle: Text(school.id),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdapterSelectionPage(school: school),
            ),
          ),
        );
      },
    );
  }
}
