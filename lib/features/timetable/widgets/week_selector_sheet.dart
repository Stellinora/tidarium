import 'package:flutter/material.dart';

Future<void> showWeekSelectorSheet(
  BuildContext context, {
  required int totalWeeks,
  required int? currentWeek,
  required int selectedWeek,
  required ValueChanged<int> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final weeks = [for (var week = 1; week <= totalWeeks; week++) week];

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('选择周次', style: theme.textTheme.titleLarge),
                    ),
                    if (currentWeek != null)
                      TextButton(
                        onPressed: () {
                          onSelected(currentWeek);
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('回到本周'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final week in weeks)
                          _WeekChip(
                            week: week,
                            selected: week == selectedWeek,
                            current: week == currentWeek,
                            onTap: () {
                              onSelected(week);
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                if (currentWeek == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '先在课表设置里填写学期开始日期，才能自动定位到本周。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.week,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final int week;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        width: 52,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : current
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            '$week',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
