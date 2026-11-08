import 'package:flutter/material.dart';

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('鸣谢')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Tidarium 的教务导入能力依赖以下课程表项目与社区数据。感谢所有维护者与适配器作者。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _CreditCard(
            icon: Icons.table_chart_outlined,
            title: '拾光课程表',
            subtitle: 'ShiGuangSchedule',
            description: '通用教务系统适配器与脚本仓库（MIT）。',
            url: 'https://github.com/ShiGuangSchedule/shiguang_warehouse',
          ),
          const SizedBox(height: 12),
          _CreditCard(
            icon: Icons.school_outlined,
            title: 'WakeUp 课程表',
            subtitle: 'OpenWakeUp',
            description: '学校名称、网址与教务类型等元数据（AGPL-3.0-only）。'
                'Tidarium 仅使用事实性学校元数据，不包含其解析器代码。',
            url: 'https://github.com/LonelyMarch/OpenWakeUp',
          ),
          const SizedBox(height: 20),
          Text(
            '以上项目与 Tidarium 无隶属关系，相关版权归各自作者所有。'
            '如权利人认为使用方式需要调整，请通过仓库 Issue 联系。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
