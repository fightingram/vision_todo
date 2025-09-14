import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/db_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/term_providers.dart';
import '../../providers/stats_provider.dart';
import 'package:go_router/go_router.dart';
import '../../utils/date_utils.dart' as du;
import '../widgets/add_item_flow.dart';
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
          await AddItemFlow.show(context, ref);
        },
        child: const Icon(Icons.add),
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => LayoutBuilder(
          builder: (context, constraints) {
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
                const _DreamsHeaderStrip(),
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

class _DreamsHeaderStrip extends ConsumerWidget {
  const _DreamsHeaderStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsProvider).value ?? const [];
    final doneCounts = ref.watch(dreamDoneCountsProvider);

    if (dreams.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('夢', style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: dreams.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = dreams[index];
              final count = doneCounts[d.id] ?? 0;
              return _DreamCard(
                title: d.title,
                color: Color(d.color),
                doneCount: count,
                onTap: () => context.push('/maps/dream/${d.id}', extra: d.title),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DreamCard extends StatelessWidget {
  const _DreamCard({required this.title, required this.color, required this.doneCount, this.onTap});
  final String title;
  final Color color;
  final int doneCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16),
                    const SizedBox(width: 6),
                    Text('完了 TODO $doneCount件', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
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
