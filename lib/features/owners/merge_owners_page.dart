import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../timetable/model/course.dart';
import '../todos/todo_providers.dart';
import 'owner_providers.dart';
import 'owner_sync.dart';

/// 列出「同名 + 同教师」的课程归属，由用户确认后合并。
class MergeOwnersPage extends ConsumerStatefulWidget {
  const MergeOwnersPage({
    super.key,
    required this.profileId,
    required this.courses,
  });

  final String profileId;
  final List<Course> courses;

  @override
  ConsumerState<MergeOwnersPage> createState() => _MergeOwnersPageState();
}

class _MergeOwnersPageState extends ConsumerState<MergeOwnersPage> {
  late OwnerSync _sync;
  List<MergeCandidate> _candidates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sync = OwnerSync(
      ownerStore: ref.read(ownerStoreProvider),
      todoStore: ref.read(todoStoreProvider),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final candidates = await _sync.findMergeCandidates(
      profileId: widget.profileId,
      courses: widget.courses,
    );
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  Future<void> _merge(MergeCandidate candidate) async {
    final target = candidate.owners.first;
    final sources = candidate.owners.skip(1).map((owner) => owner.id).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('合并归属'),
        content: Text(
          '将 ${sources.length + 1} 个「${candidate.name}」合并为一个？\n'
          '合并后待办统一归到「${target.name}」，其余归属归档。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('合并'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _sync.mergeOwners(
      targetId: target.id,
      sourceIds: sources,
      profileId: widget.profileId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已合并')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('合并同名课程')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _candidates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '没有需要合并的课程。\n'
                  '同一老师、同一课程名的理论课与实验课会被列在这里。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '以下课程同名且同教师，可能是一门课拆成了多条。合并前请确认。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final candidate in _candidates)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '教师：${candidate.teacher}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            candidate.owners
                                .map((owner) => owner.name)
                                .join(' / '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: () => _merge(candidate),
                              child: Text('合并 ${candidate.owners.length} 项'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

