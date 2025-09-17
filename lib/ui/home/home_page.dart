import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/db_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/order_provider.dart';
import '../../providers/term_providers.dart';
import '../../providers/stats_provider.dart';
import 'package:go_router/go_router.dart';
import '../../utils/date_utils.dart' as du;
import '../widgets/add_item_flow.dart';
import '../widgets/task_tile.dart';
import '../../models/task.dart';
import '../../repositories/term_repositories.dart';


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
                      _WeeklySection(
                        title: '今週',
                        tasks: thisWeek,
                        weekStart: weekStart,
                      ),
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

class _WeeklySection extends ConsumerWidget {
  const _WeeklySection({required this.title, required this.tasks, required this.weekStart});
  final String title;
  final List<Task> tasks;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <int, List<Task>>{};
    final unlinked = <Task>[];
    for (final t in tasks) {
      final id = t.shortTermId;
      if (id == null) {
        unlinked.add(t);
      } else {
        (grouped[id] ??= <Task>[]).add(t);
      }
    }

    final sections = <Widget>[];
    sections.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ));

    if (tasks.isEmpty) {
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('タスクはありません', style: Theme.of(context).textTheme.bodySmall),
      ));
    } else {
      // Term sections
      for (final entry in grouped.entries) {
        sections.add(_HomeTermTasksSection(
          termId: entry.key,
          items: entry.value,
          weekStart: weekStart,
        ));
      }
      // Unlinked section
      if (unlinked.isNotEmpty) {
        sections.add(_HomeUnlinkedTasksSection(items: unlinked, weekStart: weekStart));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }
}

class _HomeTermTasksSection extends ConsumerStatefulWidget {
  const _HomeTermTasksSection({required this.termId, required this.items, required this.weekStart});
  final int termId;
  final List<Task> items;
  final DateTime weekStart;

  @override
  ConsumerState<_HomeTermTasksSection> createState() => _HomeTermTasksSectionState();
}

class _HomeTermTasksSectionState extends ConsumerState<_HomeTermTasksSection> {
  late List<Task> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant _HomeTermTasksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIds(oldWidget.items, widget.items)) {
      _items = List.of(widget.items);
      _loadOrder();
    }
  }

  bool _sameIds(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadOrder() async {
    final key = 'home_week_term_${widget.termId}_${widget.weekStart.millisecondsSinceEpoch}';
    final order = await ref.read(orderServiceProvider).getOrder(key);
    final map = {for (final t in _items) t.id: t};
    final ordered = <Task>[];
    for (final id in order) {
      final t = map.remove(id);
      if (t != null) ordered.add(t);
    }
    ordered.addAll(map.values);
    setState(() => _items = ordered);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Term?>(
      future: ref.read(termRepoProvider).getById(widget.termId),
      builder: (context, snap) {
        final term = snap.data;
        final title = term?.title ?? '目標';
        return Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.flag_outlined),
            title: InkWell(
              onTap: term == null
                  ? null
                  : () => context.push('/todo/term/${term.id}', extra: term.title),
              child: Text(title),
            ),
            subtitle: Text('TODO ${_items.length} 件'),
            children: [
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('該当のTODOはありません'),
                )
              else
                ReorderableListView.builder(
                  key: ValueKey('home_week_term_${widget.termId}_${widget.weekStart.millisecondsSinceEpoch}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _items.removeAt(oldIndex);
                      _items.insert(newIndex, item);
                    });
                    final key = 'home_week_term_${widget.termId}_${widget.weekStart.millisecondsSinceEpoch}';
                    await ref.read(orderServiceProvider).setOrder(
                          key,
                          _items.map((e) => e.id).toList(),
                        );
                  },
                  itemBuilder: (context, i) => Card(
                    key: ValueKey('home_week_task_${_items[i].id}'),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: TaskTile(task: _items[i], showCheckbox: false, showEditMenu: false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeUnlinkedTasksSection extends ConsumerStatefulWidget {
  const _HomeUnlinkedTasksSection({required this.items, required this.weekStart});
  final List<Task> items;
  final DateTime weekStart;

  @override
  ConsumerState<_HomeUnlinkedTasksSection> createState() => _HomeUnlinkedTasksSectionState();
}

class _HomeUnlinkedTasksSectionState extends ConsumerState<_HomeUnlinkedTasksSection> {
  late List<Task> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant _HomeUnlinkedTasksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIds(oldWidget.items, widget.items)) {
      _items = List.of(widget.items);
      _loadOrder();
    }
  }

  bool _sameIds(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadOrder() async {
    final key = 'home_week_unlinked_${widget.weekStart.millisecondsSinceEpoch}';
    final order = await ref.read(orderServiceProvider).getOrder(key);
    final map = {for (final t in _items) t.id: t};
    final ordered = <Task>[];
    for (final id in order) {
      final t = map.remove(id);
      if (t != null) ordered.add(t);
    }
    ordered.addAll(map.values);
    setState(() => _items = ordered);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.link_off),
        title: const Text('紐付けなし'),
        subtitle: Text('TODO ${_items.length} 件'),
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('該当のTODOはありません'),
            )
          else
            ReorderableListView.builder(
              key: ValueKey('home_week_unlinked_${widget.weekStart.millisecondsSinceEpoch}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                final key = 'home_week_unlinked_${widget.weekStart.millisecondsSinceEpoch}';
                await ref.read(orderServiceProvider).setOrder(
                      key,
                      _items.map((e) => e.id).toList(),
                    );
              },
              itemBuilder: (context, i) => Card(
                key: ValueKey('home_week_unlinked_${_items[i].id}'),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TaskTile(task: _items[i], showCheckbox: false, showEditMenu: false),
              ),
            ),
        ],
      ),
    );
  }
}
