import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapter_selection_page.dart';
import 'data/wakeup_import_target.dart';
import 'import_providers.dart';
import 'models/school_models.dart';
import 'models/wakeup_school.dart';
import 'school_selection_page.dart';
import 'web_import_page.dart';

class UnifiedSchoolSelectionPage extends ConsumerStatefulWidget {
  const UnifiedSchoolSelectionPage({super.key});

  @override
  ConsumerState<UnifiedSchoolSelectionPage> createState() =>
      _UnifiedSchoolSelectionPageState();
}

class _UnifiedSchoolSelectionPageState
    extends ConsumerState<UnifiedSchoolSelectionPage> {
  List<_UnifiedSchool> _schools = const [];
  var _loading = true;
  var _onlineLoading = false;
  var _onlineFailed = false;
  String? _error;
  String _query = '';
  String? _opening;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _onlineLoading = true;
      _onlineFailed = false;
      _error = null;
    });

    var wakeUpSchools = const <WakeUpSchool>[];
    Object? wakeUpError;
    try {
      wakeUpSchools = await ref
          .read(wakeUpSchoolRepositoryProvider)
          .loadSchools();
    } catch (error) {
      wakeUpError = error;
    }

    if (!mounted) return;
    if (wakeUpSchools.isNotEmpty) {
      setState(() {
        _schools = _merge(const <SchoolEntry>[], wakeUpSchools);
        _loading = false;
        _error = null;
      });
    }

    var onlineSchools = const <SchoolEntry>[];
    Object? onlineError;
    try {
      final schools = await ref
          .read(adapterRepositoryProvider)
          .loadSchools(forceRefresh: forceRefresh);
      onlineSchools = schools
          .where((school) => !_isGenericSchool(school))
          .toList(growable: false);
    } catch (error) {
      onlineError = error;
    }

    if (!mounted) return;
    if (onlineSchools.isNotEmpty) {
      setState(() {
        _schools = _merge(onlineSchools, wakeUpSchools);
        _loading = false;
        _onlineLoading = false;
        _onlineFailed = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _onlineLoading = false;
      _onlineFailed = onlineError != null;
      if (_schools.isEmpty) {
        _loading = false;
        _error = wakeUpError == null && onlineError == null
            ? '学校清单为空'
            : '学校数据加载失败：${wakeUpError ?? onlineError}';
      }
    });
  }

  List<_UnifiedSchool> _merge(
    List<SchoolEntry> onlineSchools,
    List<WakeUpSchool> wakeUpSchools,
  ) {
    final byName = <String, _UnifiedSchool>{};

    for (final school in onlineSchools) {
      final initial = school.initial.trim();
      byName[_nameKey(school.name)] = _UnifiedSchool(
        name: school.name,
        initial: initial.isEmpty ? _fallbackInitial(school.name) : initial,
        online: school,
      );
    }

    for (final school in wakeUpSchools) {
      final key = _nameKey(school.name);
      final existing = byName[key];
      if (existing == null) {
        byName[key] = _UnifiedSchool(
          name: school.name,
          initial: school.initial,
          wakeUp: school,
        );
        continue;
      }
      byName[key] = _UnifiedSchool(
        name: existing.name,
        initial: existing.initial == '#' ? school.initial : existing.initial,
        online: existing.online,
        wakeUp: school,
      );
    }

    final schools = byName.values.toList(growable: false);
    schools.sort((a, b) {
      final byRank = _initialRank(a.initial).compareTo(_initialRank(b.initial));
      if (byRank != 0) return byRank;
      final byInitial = a.initial.compareTo(b.initial);
      if (byInitial != 0) return byInitial;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(schools);
  }

  List<_UnifiedSchool> get _filteredSchools {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _schools;
    return _schools
        .where((school) => school.searchText.contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索学校'),
        actions: [
          IconButton(
            tooltip: '刷新学校数据',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _schools.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: '搜索学校名称、类型或网址',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _onlineFailed
                      ? '在线学校数据加载失败，当前仅显示本地学校；点右上角刷新重试。'
                      : '共 ${_schools.length} 所学校，可直接搜索并导入。登录仍在学校网页完成。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_onlineLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildList(theme)),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    final schools = _filteredSchools;
    if (schools.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? '学校清单为空' : '没有找到匹配的学校',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: schools.length,
      itemBuilder: (context, index) {
        final school = schools[index];
        final opening = _opening == school.name;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          enabled: !opening,
          leading: CircleAvatar(
            child: Text(school.initial == '#' ? '?' : school.initial),
          ),
          title: Text(school.name),
          subtitle: Text(
            school.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: opening
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _buildBadge(theme, school.canImport),
          onTap: () => _openSchool(school),
        );
      },
    );
  }

  Widget _buildBadge(ThemeData theme, bool canImport) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: canImport
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        canImport ? '可导入' : '暂不支持',
        style: theme.textTheme.labelSmall?.copyWith(
          color: canImport
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _openSchool(_UnifiedSchool school) async {
    final online = school.online;
    if (online != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdapterSelectionPage(school: online),
        ),
      );
      return;
    }

    final wakeUp = school.wakeUp;
    if (wakeUp == null) return;
    if (!wakeUp.canImport) {
      await _showUnsupported(wakeUp);
      return;
    }

    setState(() => _opening = school.name);
    try {
      final target = await resolveWakeUpImportTarget(
        school: wakeUp,
        repository: ref.read(adapterRepositoryProvider),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WebImportPage(
            school: target.school,
            adapter: target.adapter,
            localScript: target.localScript,
          ),
        ),
      );
    } catch (error) {
      _toast('打开导入页失败：$error');
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _showUnsupported(WakeUpSchool school) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('暂不支持该校'),
        content: Text(
          '「${school.name}」的类型为 ${school.typeLabel}（${school.type}），'
          '暂时没有可用的自动解析器。\n\n'
          '可以复制学校网址，或前往通用教务系统手动选择相近类型。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('copy'),
            child: const Text('复制网址'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('generic'),
            child: const Text('去通用教务'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: school.url.toString()));
      _toast('学校网址已复制');
      return;
    }
    if (action == 'generic') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const SchoolSelectionPage(mode: SchoolLibraryMode.generic),
        ),
      );
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnifiedSchool {
  const _UnifiedSchool({
    required this.name,
    required this.initial,
    this.online,
    this.wakeUp,
  });

  final String name;
  final String initial;
  final SchoolEntry? online;
  final WakeUpSchool? wakeUp;

  bool get canImport => online != null || (wakeUp?.canImport ?? false);

  String get subtitle {
    final wake = wakeUp;
    if (wake != null) return '${wake.typeLabel} · ${wake.url}';
    return '学校专属适配';
  }

  String get searchText => [
    name,
    initial,
    online?.id ?? '',
    wakeUp?.type ?? '',
    wakeUp?.url.toString() ?? '',
  ].join(' ').toLowerCase();
}

String _nameKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

String _fallbackInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '#' : trimmed.substring(0, 1).toUpperCase();
}

int _initialRank(String initial) => initial == '#' ? 1 : 0;

bool _isGenericSchool(SchoolEntry school) {
  return const {
    'zhengfang_jiaowu',
    'chaoxing_jiaowu',
    'qingguo_jiaowu',
    'urp_jiaowu',
    'GLOBAL_TOOLS',
  }.contains(school.id);
}
