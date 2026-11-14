import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_settings.dart';
import '../../core/ai/llm_client.dart';
import '../../core/ai/local_ocr.dart';
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
  String _stage = '准备中…';
  int _done = 0;
  double _elapsedSeconds = 0;
  Timer? _ticker;
  DateTime _startedAt = DateTime.now();

  List<ImportDraft> _drafts = const [];
  List<Owner> _owners = const [];
  final Map<String, Owner> _ownerById = {};
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _ownerLabel(ImportDraft draft) {
    final owner = draft.ownerId == null ? null : _ownerById[draft.ownerId];
    if (owner == null) {
      return draft.warnings.contains('归属待选')
          ? '归属待选'
          : draft.kind.label;
    }
    return '${owner.name} · ${owner.kind.label}';
  }

  Future<void> _run() async {
    _ticker?.cancel();
    setState(() {
      _parsing = true;
      _error = null;
      _notConfigured = false;
      _drafts = const [];
      _selected.clear();
      _done = 0;
      _elapsedSeconds = 0;
      _stage = '读取配置…';
    });

    final settings = await _settingsRepo.load();
    if (!settings.isReadyForVision && !LocalOcrEngine.isSupported) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _notConfigured = true;
      });
      return;
    }

    final apiKey = await _settingsRepo.readApiKey();
    final profileId = ref.read(timetableLibraryProvider).activeId;
    final owners = await ref.read(ownerStoreProvider).all(profileId);
    if (!mounted) return;

    _ownerById
      ..clear()
      ..addEntries(owners.map((owner) => MapEntry(owner.id, owner)));
    _owners = owners;

    final quota = AiQuota();
    final client = OpenAiCompatLlmClient();
    final parser = ImportParser(client: client, quota: quota);
    final pipeline = ImportPipeline(client: client, parser: parser, quota: quota);

    final profileName = ref.read(timetableProvider).config.name;
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds =
            DateTime.now().difference(_startedAt).inMilliseconds / 1000;
      });
    });

    final results = await _runLimited(
      widget.images,
      2,
      (image) async {
        final result = await pipeline.parseImage(
          intake: image,
          settings: settings,
          apiKey: apiKey,
          profileName: profileName,
          owners: owners,
        );
        if (mounted) {
          setState(() {
            _done += 1;
            _stage = _done >= widget.images.length ? '整理完成' : '识别中 $_done/${widget.images.length}';
          });
        }
        return result;
      },
    );

    _ticker?.cancel();
    if (!mounted) return;

    final drafts = <ImportDraft>[];
    final errors = <String>[];
    for (final result in results) {
      if (result.isSuccess) {
        drafts.addAll(result.drafts);
      } else if (result.error != null) {
        errors.add(result.error!);
      }
    }

    setState(() {
      _parsing = false;
      _drafts = List.unmodifiable(drafts);
      _selected.clear();
      _error = errors.isEmpty ? null : errors.first;
    });
  }

  Future<List<ParseResult>> _runLimited(
    List<ImageIntake> items,
    int limit,
    Future<ParseResult> Function(ImageIntake) task,
  ) async {
    final results = List<ParseResult?>.filled(items.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next;
        next += 1;
        if (index >= items.length) return;
        results[index] = await task(items[index]);
      }
    }

    await Future.wait(
      List.generate(math.min(limit, items.length), (_) => worker()),
    );
    return results.whereType<ParseResult>().toList(growable: false);
  }

  Future<void> _commit() async {
    final chosen = _drafts
        .where((draft) => _selected.contains(draft.id))
        .toList(growable: false);
    if (chosen.isEmpty) return;

    final missingTime = chosen.where((draft) => draft.dueAt == null).length;
    var fillMissing = false;
    if (missingTime > 0) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('有的事项没有时间'),
          content: Text(
            '选中的 ${chosen.length} 条里有 $missingTime 条没识别到截止时间。'
            '要按今天 23:59 写入，还是先返回补时间？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('返回补时间'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('按今天 23:59 写入'),
            ),
          ],
        ),
      );
      if (choice != true || !mounted) return;
      fillMissing = true;
    }

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
      fillMissingDueWithToday: fillMissing,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final parts = <String>['已写入 ${result.inserted} 条'];
    if (result.skippedDuplicates > 0) {
      parts.add('跳过 ${result.skippedDuplicates} 条重复');
    }
    if (result.skippedNoTime > 0) {
      parts.add('${result.skippedNoTime} 条缺时间未写入');
    }
    messenger.showSnackBar(SnackBar(content: Text(parts.join('，'))));
  }

  Future<void> _openDraft(ImportDraft draft, {required bool edit}) async {
    final updated = await showModalBottomSheet<ImportDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DraftDetailSheet(
        draft: draft,
        ownerLabel: _ownerLabel(draft),
        owners: _owners,
        startInEditMode: edit,
      ),
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
      body: Stack(
        children: [
          if (widget.images.isNotEmpty)
            Positioned.fill(
              child: _PreviewBackground(bytes: widget.images.first.bytes),
            ),
          SafeArea(
            child: LayoutBuilder(
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
                          onPressed: () {
                            setState(() {
                              if (_selected.length == _drafts.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(_drafts.map((draft) => draft.id));
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
          ),
        ],
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
              '$_stage · ${_elapsedSeconds.toStringAsFixed(1)}s',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${widget.images.length} 张截图',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            const Text('还没有可用的识别方式'),
            const SizedBox(height: 8),
            Text(
              '本地 OCR 不可用，请到「设置 → AI 服务」配置视觉模型后再试。',
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
        if (maxHeight >= 400)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '共 ${_drafts.length} 条，默认不勾选；点一行查看，点铅笔编辑',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final draft in _drafts)
          _DraftRow(
            draft: draft,
            ownerLabel: _ownerLabel(draft),
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
            onOpen: () => _openDraft(draft, edit: false),
            onEdit: () => _openDraft(draft, edit: true),
          ),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.ownerLabel,
    required this.compact,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
  });

  final ImportDraft draft;
  final String ownerLabel;
  final bool compact;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unassigned = draft.ownerId == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 56,
            child: Checkbox(
              value: selected,
              onChanged: (value) => onToggle(value ?? false),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: unassigned
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DraftDetailSheet extends StatefulWidget {
  const _DraftDetailSheet({
    required this.draft,
    required this.ownerLabel,
    required this.owners,
    required this.startInEditMode,
  });

  final ImportDraft draft;
  final String ownerLabel;
  final List<Owner> owners;
  final bool startInEditMode;

  @override
  State<_DraftDetailSheet> createState() => _DraftDetailSheetState();
}

class _DraftDetailSheetState extends State<_DraftDetailSheet> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.draft.title);
  late DateTime _dueAt;
  late OwnerKind _kind = widget.draft.kind;
  String? _ownerId;
  bool _hasDue = false;
  late bool _editing;

  @override
  void initState() {
    super.initState();
    final due = widget.draft.dueAt;
    _hasDue = due != null;
    _editing = widget.startInEditMode;
    _ownerId = widget.draft.ownerId;
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
    Navigator.of(context).pop(
      widget.draft.copyWith(
        title: title,
        dueAt: _hasDue ? _dueAt : null,
        clearDueAt: !_hasDue,
        kind: _kind,
        ownerId: _ownerId,
        clearOwnerId: _ownerId == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final timeText = widget.draft.dueAt == null
        ? '未设置'
        : DateFormat('yyyy年M月d日 HH:mm').format(widget.draft.dueAt!);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing ? '编辑待办' : '待办详情',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (!_editing) ...[
              _InfoRow(label: '归属', value: widget.ownerLabel, theme: theme),
              const SizedBox(height: 8),
              _InfoRow(label: '标题', value: widget.draft.title, theme: theme),
              const SizedBox(height: 8),
              _InfoRow(label: '截止', value: timeText, theme: theme),
              if (widget.draft.materials.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  label: '材料',
                  value: widget.draft.materials.join('、'),
                  theme: theme,
                ),
              ],
              if (widget.draft.source.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  label: '来源',
                  value: widget.draft.source,
                  theme: theme,
                ),
              ],
              const SizedBox(height: 8),
              _InfoRow(
                label: '置信度',
                value: '${(widget.draft.confidence * 100).round()}%',
                theme: theme,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(widget.draft.copyWith(title: '')),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('编辑'),
                  ),
                ],
              ),
            ] else ...[
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
              DropdownButtonFormField<String?>(
                initialValue: _ownerId,
                decoration: const InputDecoration(
                  labelText: '归属',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('不指定（按类型回落）'),
                  ),
                  for (final owner in widget.owners)
                    DropdownMenuItem<String?>(
                      value: owner.id,
                      child: Text(
                        '${owner.name} · ${owner.kind.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _ownerId = value),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(widget.draft.copyWith(title: '')),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('完成')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
/// 用分享进来的截图做淡背景，确认页不再是纯白板。
class _PreviewBackground extends StatelessWidget {
  const _PreviewBackground({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.12,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: 0.72),
                  surface.withValues(alpha: 0.94),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

