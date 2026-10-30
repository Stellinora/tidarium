import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/wakeup_import_target.dart';
import 'import_providers.dart';
import 'models/wakeup_school.dart';
import 'school_selection_page.dart';
import 'web_import_page.dart';

class WakeUpSchoolSelectionPage extends ConsumerStatefulWidget {
  const WakeUpSchoolSelectionPage({super.key});

  @override
  ConsumerState<WakeUpSchoolSelectionPage> createState() =>
      _WakeUpSchoolSelectionPageState();
}

class _WakeUpSchoolSelectionPageState
    extends ConsumerState<WakeUpSchoolSelectionPage> {
  List<WakeUpSchool> _schools = const [];
  var _loading = true;
  String? _error;
  String _query = '';
  String? _openingSchool;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schools = await ref
          .read(wakeUpSchoolRepositoryProvider)
          .loadSchools();
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

  List<WakeUpSchool> get _filteredSchools {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _schools;
    return _schools
        .where((school) {
          return school.name.toLowerCase().contains(query) ||
              school.initial.toLowerCase().contains(query) ||
              school.type.toLowerCase().contains(query) ||
              school.url.toString().toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  int get _supportedCount =>
      _schools.where((school) => school.canImport).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('WakeUp 学校库')),
      body: Column(
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
          if (!_loading && _error == null)
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
                      '共 ${_schools.length} 所学校，其中 $_supportedCount 所'
                      '可使用正方/青果/URP/超星通用适配器。登录仍在学校网页完成。',
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
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

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

    final supported = schools.where((school) => school.canImport).toList();
    final unsupported = schools.where((school) => !school.canImport).toList();
    final entries = <Object>[
      if (supported.isNotEmpty) '可直接导入（${supported.length}）',
      ...supported,
      if (unsupported.isNotEmpty) '其他学校（暂不支持自动解析）',
      ...unsupported,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              entry,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final school = entry as WakeUpSchool;
        final opening = _openingSchool == school.name;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          enabled: !opening,
          leading: CircleAvatar(
            child: Text(school.initial == '#' ? '?' : school.initial),
          ),
          title: Text(school.name),
          subtitle: Text(
            '${school.typeLabel} · ${school.url}',
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

  Future<void> _openSchool(WakeUpSchool school) async {
    if (!school.canImport) {
      await _showUnsupported(school);
      return;
    }

    setState(() => _openingSchool = school.name);
    try {
      final target = await resolveWakeUpImportTarget(
        school: school,
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
      if (mounted) setState(() => _openingSchool = null);
    }
  }

  Future<void> _showUnsupported(WakeUpSchool school) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('暂不支持该校'),
        content: Text(
          '「${school.name}」使用的 WakeUp 类型为 ${school.typeLabel}'
          '（${school.type}），首版暂未实现专用解析器。\n\n'
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
        MaterialPageRoute<void>(builder: (_) => const SchoolSelectionPage()),
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
