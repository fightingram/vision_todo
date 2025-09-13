import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/db_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../../utils/date_utils.dart' as du;
import '../widgets/character_band.dart';
import '../widgets/new_item_dialog.dart';
import '../widgets/task_tile.dart';


class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // 起動時の仕分け表示はApp側で行うため、Homeではトリガーしない
  }

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(isarInitProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            tooltip: settings.showCompleted ? '未完了のみ' : '完了も表示',
            onPressed: () => ref.read(settingsProvider.notifier).toggleShowCompleted(),
            icon: Icon(settings.showCompleted ? Icons.checklist : Icons.checklist_rtl),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新規作成',
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const NewItemDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => LayoutBuilder(
          builder: (context, constraints) {
            final bandHeight = constraints.maxHeight * 0.20;
            final tasks = ref.watch(tasksStreamProvider).value ?? const [];
            final weekStart = du.startOfWeek(DateTime.now(), settings.weekStart);
            final thisWeek = tasks
                .where((t) => t.plannedWeekStart != null && du.isSameDate(t.plannedWeekStart!, weekStart))
                .toList()
              ..sort((a, b) {
                final byPriority = b.priority.compareTo(a.priority);
                if (byPriority != 0) return byPriority;
                final ad = a.dueAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
                final bd = b.dueAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
                final byDue = ad.compareTo(bd);
                if (byDue != 0) return byDue;
                return a.createdAt.compareTo(b.createdAt);
              });
            return Column(
              children: [
                SizedBox(height: bandHeight, child: const CharacterBand()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _Section(title: '今週', tasks: thisWeek),
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
          ...tasks
              .map<Widget>((t) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: TaskTile(task: t, showCheckbox: false, showEditMenu: false),
                  ))
              .toList(),
      ],
    );
  }
}
