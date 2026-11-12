import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_settings.dart';
import '../../core/ai/llm_client.dart';
import '../intake/image_intake.dart';
import '../owners/model/owner.dart';
import '../owners/owner_providers.dart';
import '../settings/ai_settings_page.dart';
import '../tags/tag_providers.dart';
import '../timetable/timetable_providers.dart';
import '../todos/todo_providers.dart';
import 'draft_committer.dart';
import 'import_parser.dart';
import 'import_pipeline.dart';
import 'model/import_draft.dart';

/// 截屏分享后的确认页：解析、逐条确认、写入当前课表。
class ImportConfirmPage extends ConsumerStatefulWidget {
  const ImportConfirmPage({
    super.key,
    required this.images,
    this.settingsRepository,
  });

  final List<ImageIntake> images;
  final AiSettingsRepository? settingsRepository;

  @override
  ConsumerState<ImportConfirmPage> createState() => _ImportConfirmPageState();
}

class _ImportConfirmPageState extends ConsumerState<ImportConfirmPage> {
  late final AiSettingsRepository _settingsRepo =
      widget.settingsRepository ?? AiSettingsRepository();

  bool _parsing = true;
  bool _notConfigured = false;
  bool _committing = false;
  String? _error;

  List<ImportDraft> _drafts = const [];
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _parsing = true;
      _error = null;
      _notConfigured = false;
    });

    final settings = await _settingsRepo.load();
    if (!settings.isReadyForVision) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _notConfigured = true;
      });
      return;
    }

    final apiKey = await _settingsRepo.readApiKey();
    final quota = AiQuota();
    final client = OpenAiCompatLlmClient();
    final parser = ImportParser(client: client, quota: quota);
    final pipeline = ImportPipeline(client: client, parser: parser, quota: quota);

    final profileName = ref.read(timetableProvider).config.name;
    final drafts = <ImportDraft>[];
    final errors = <String>[];

    for (final image in widget.images) {
      final result = await pipeline.parseImage(
        intake: image,
        settings: settings,
        apiKey: apiKey,
        profileName: profileName,
      );
      if (result.isSuccess) {
        drafts.addAll(result.drafts);
      } else if (result.error != null) {
        errors.add(result.error!);
      }
    }

    if (!mounted) return;
    setState(() {
      _parsing = false;
      _drafts = List.unmodifiable(drafts);
      _selected.clear();
      _error = errors.isEmpty ? null : errors.first;
    });
  }

  Future<void> _commit() async {
    final chosen = _drafts
        .where((draft) => _selected.contains(draft.id))
        .toList(growable: false);
    if (chosen.isEmpty) return;

    setState(() => _committing = true);

    final profileId = ref.read(timetableLibraryProvider).activeId;
    final committer = DraftCommitter(
      todos: ref.read(todoStoreProvider),
      tags: ref.read(tagStoreProvider),
      owners: ref.read(ownerStoreProvider),
    );
    final result = await committer.commit(
      drafts: chosen,
      profileId: profileId,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已写入 ${result.inserted} 条'
          '${result.skippedDuplicates > 0 ? '，跳过 ${result.skippedDuplicates} 条重复' : ''}',
        ),
      ),
    );
  }

  Future<void> _editDraft(ImportDraft draft) async {
    final updated = await showModalBottomSheet<ImportDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DraftDetailSheet(draft: draft),
    );
    if (updated == null || !mounted) return;

    setState(() {
      if (updated.title.isEmpty) {
        _drafts = _drafts.where((item) => item.id != draft.id).toList();
        _selected.remove(draft.id);
        return;
      }
      _drafts = [
        for (final item in _drafts)
          if (item.id == draft.id) updated else item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入确认'),
        actions: [
          if (!_parsing)
            IconButton(
              tooltip: '重新解析',
              onPressed: _run,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Column(
            children: [
              Expanded(
                child: _buildBody(theme, compact, constraints.maxHeight),
              ),
              if (!_parsing && !_notConfigured && _drafts.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _drafts.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    if (_selected.length == _drafts.length) {
                                      _selected.clear();
                                    } else {
                                      _selected
                                        ..clear()
                                        ..addAll(
                                          _drafts.map((draft) => draft.id),
                                        );
                                    }
                                  });
                                },
                          child: Text(
                            _selected.length == _drafts.length ? '全不选' : '全选',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _selected.isEmpty || _committing
                                ? null
                                : _commit,
                            child: Text(
                              _committing
                                  ? '写入中…'
                                  : '确认 ${_selected.length} 条',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool compact, double maxHeight) {
    if (_parsing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '正在识别 ${widget.images.length} 张截图…',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_notConfigured) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text('还没有配置视觉模型'),
            const SizedBox(height: 8),
            Text(
              '在「设置 → AI 服务」里填好服务商、Key 与视觉模型后，再分享截图。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiSettingsPage(),
                ),
              ),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
    }

    if (_drafts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有识别出待办'),
            const SizedBox(height: 8),
            Text(
              _error ?? '换一张更清晰的截图，或直接在首页手动添加。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 8, compact ? 12 : 16, 8),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (maxHeight < 400)
          const SizedBox.shrink()
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '共 ${_drafts.length} 条，默认不勾选；检查后再写入',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final draft in _drafts)
          _DraftRow(
            draft: draft,
            compact: compact,
            selected: _selected.contains(draft.id),
            onToggle: (value) {
              setState(() {
                if (value) {
                  _selected.add(draft.id);
                } else {
                  _selected.remove(draft.id);
                }
              });
            },
            onTap: () => _editDraft(draft),
          ),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.compact,
    required this.selected,
    required this.onToggle,
    required this.onTap,
  });

  final ImportDraft draft;
  final bool compact;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = draft.dueAt == null
        ? '时间待补'
        : DateFormat('MM-dd HH:mm').format(draft.dueAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => onToggle(value ?? false),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeLabel · ${draft.kind.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: draft.dueAt == null
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftDetailSheet extends StatefulWidget {
  const _DraftDetailSheet({required this.draft});

  final ImportDraft draft;

  @override
  State<_DraftDetailSheet> createState() => _DraftDetailSheetState();
}

class _DraftDetailSheetState extends State<_DraftDetailSheet> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.draft.title);
  late DateTime _dueAt;
  late OwnerKind _kind = widget.draft.kind;
  bool _hasDue = false;
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    final due = widget.draft.dueAt;
    _hasDue = due != null;
    final now = DateTime.now();
    _dueAt = due ?? DateTime(now.year, now.month, now.day, 23, 59);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择截止日期',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
      helpText: '选择截止时间',
    );
    if (!mounted) return;
    setState(() {
      _hasDue = true;
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _dueAt.hour,
        time?.minute ?? _dueAt.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    final updated = widget.draft.copyWith(
      title: title,
      dueAt: _hasDue ? _dueAt : null,
      clearDueAt: !_hasDue,
      kind: _kind,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('确认这一条', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('截止时间'),
              subtitle: Text(
                _hasDue
                    ? DateFormat('yyyy年M月d日 HH:mm').format(_dueAt)
                    : '未设置（不会写入）',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasDue)
                    IconButton(
                      tooltip: '清除时间',
                      onPressed: () => setState(() => _hasDue = false),
                      icon: const Icon(Icons.close),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: _pickDueAt,
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<OwnerKind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: '归属类型',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final kind in OwnerKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _kind = value);
              },
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('更多'),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              initiallyExpanded: _showMore,
              onExpansionChanged: (value) => _showMore = value,
              children: [
                Text(
                  '来源：${widget.draft.source.isEmpty ? '未识别' : widget.draft.source}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '置信度：${(widget.draft.confidence * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
                if (widget.draft.materials.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '材料：${widget.draft.materials.join('、')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    widget.draft.copyWith(title: ''),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('完成')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


