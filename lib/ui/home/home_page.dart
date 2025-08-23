import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/db_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../widgets/character_band.dart';
import '../widgets/quick_add_bar.dart';
import '../widgets/task_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: settings.showCompleted ? '未完了のみ' : '完了も表示',
            onPressed: () => ref.read(settingsProvider.notifier).toggleShowCompleted(),
            icon: Icon(settings.showCompleted ? Icons.checklist : Icons.checklist_rtl),
          ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => LayoutBuilder(
          builder: (context, constraints) {
            final bandHeight = constraints.maxHeight * 0.20;
            final sectioned = ref.watch(sectionedTasksProvider);
            return Column(
              children: [
                SizedBox(height: bandHeight, child: const CharacterBand()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _Section(title: '今日', tasks: sectioned.today),
                      _Section(title: '明日', tasks: sectioned.tomorrow),
                      _Section(title: '今週', tasks: sectioned.thisWeek),
                      _Section(title: '期限なし', tasks: sectioned.none),
                      const SizedBox(height: 12),
                      const QuickAddBar(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tasks});
  final String title;
  final List tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title == '今日' ? '今日のTODOはありません' : 'タスクはありません',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...tasks.map<Widget>((t) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: TaskTile(task: t))).toList(),
      ],
    );
  }
}
