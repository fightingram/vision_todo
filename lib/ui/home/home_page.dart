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
import '../widgets/gradient_card.dart';
import '../theme/design_tokens.dart';


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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text('夢', style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
    final gs = [DT.goalTeal, DT.goalIndigo, DT.goalAmber, DT.goalSalmon];
    final grad = gs[title.hashCode.abs() % gs.length];
    return SizedBox(
      width: 240,
      child: GradientCard(
        gradient: LinearGradient(colors: grad, begin: Alignment.centerLeft, end: Alignment.centerRight),
        onTap: onTap,
        title: title,
        subtitle: '完了 TODO $doneCount件',
        decoration: const Icon(Icons.auto_awesome, size: 32, color: Colors.white),
      ),
    );
  }
}

class _WeeklySection extends ConsumerStatefulWidget {
  const _WeeklySection({required this.title, required this.tasks, required this.weekStart});
  final String title;
  final List<Task> tasks;
  final DateTime weekStart;

  @override
  ConsumerState<_WeeklySection> createState() => _WeeklySectionState();
}

class _WeeklySectionState extends ConsumerState<_WeeklySection> {
  late List<int> _termOrder; // ordered term ids
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _termOrder = [];
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant _WeeklySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart || oldWidget.tasks != widget.tasks) {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    final grouped = _groupByTerm(widget.tasks);
    final key = 'home_week_terms_${widget.weekStart.millisecondsSinceEpoch}';
    final saved = await ref.read(orderServiceProvider).getOrder(key);
    final existing = grouped.keys.toSet();
    final ordered = <int>[];
    // keep saved order that still exists
    for (final id in saved) {
      if (existing.remove(id)) ordered.add(id);
    }
    // append new ids
    ordered.addAll(existing);
    setState(() {
      _termOrder = ordered;
      _loaded = true;
    });
  }

  Map<int, List<Task>> _groupByTerm(List<Task> tasks) {
    final grouped = <int, List<Task>>{};
    for (final t in tasks) {
      final id = t.shortTermId;
      if (id != null) (grouped[id] ??= <Task>[]).add(t);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByTerm(widget.tasks);
    final unlinked = widget.tasks.where((t) => t.shortTermId == null).toList();

    final sections = <Widget>[];
    sections.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
    ));

    if (widget.tasks.isEmpty) {
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('タスクはありません', style: Theme.of(context).textTheme.bodySmall),
      ));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections);
    }

    final termIds = _loaded ? _termOrder : grouped.keys.toList();

    sections.add(
      ReorderableListView.builder(
        key: ValueKey('home_terms_${widget.weekStart.millisecondsSinceEpoch}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: termIds.length,
        onReorder: (oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final id = termIds.removeAt(oldIndex);
            termIds.insert(newIndex, id);
          });
          final key = 'home_week_terms_${widget.weekStart.millisecondsSinceEpoch}';
          await ref.read(orderServiceProvider).setOrder(key, termIds);
          setState(() => _termOrder = List.of(termIds));
        },
        itemBuilder: (context, i) {
          final id = termIds[i];
          final items = grouped[id] ?? const <Task>[];
          return Container(
            key: ValueKey('home_term_$id'),
            child: _HomeTermTasksSection(termId: id, items: items, weekStart: widget.weekStart),
          );
        },
      ),
    );

    if (unlinked.isNotEmpty) {
      sections.add(_HomeUnlinkedTasksSection(items: unlinked, weekStart: widget.weekStart));
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
        final top = _items.take(3).toList();
        return Container(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: term == null ? null : () => context.push('/todo/term/${term.id}', extra: term.title),
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600, color: DT.textSecondary),
                        ),
                      ),
                    ),
                    Text('TODO ${_items.length} 件', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                if (top.isEmpty)
                  const Text('該当のTODOはありません')
                else
                  // Hierarchical child container with left guide line and reorder (long-press)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: DT.borderSubtle, width: 2)),
                    ),
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            chipTheme: Theme.of(context).chipTheme.copyWith(
                                  side: BorderSide.none,
                                  labelStyle: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: DT.textPrimary),
                                ),
                          ),
                          child: ReorderableListView.builder(
                            key: ValueKey('home_term_top_${widget.termId}_${widget.weekStart.millisecondsSinceEpoch}'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: top.length,
                            onReorder: (oldIndex, newIndex) async {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = top.removeAt(oldIndex);
                              top.insert(newIndex, item);
                              // reflect into full list: top first, then rest keeping order
                              final rest = _items.where((e) => !top.contains(e)).toList();
                              _items = [...top, ...rest];
                            });
                            final key = 'home_week_term_${widget.termId}_${widget.weekStart.millisecondsSinceEpoch}';
                            await ref.read(orderServiceProvider).setOrder(
                              key,
                              _items.map((e) => e.id).toList(),
                            );
                          },
                          itemBuilder: (context, i) => Align(
                            key: ValueKey('home_term_top_item_${top[i].id}'),
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ActionChip(
                                label: Text(top[i].title, overflow: TextOverflow.ellipsis),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onPressed: () => context.push('/todo/task/${top[i].id}', extra: top[i].title),
                              ),
                            ),
                          ),
                          ),
                        ),
                        if (_items.length > top.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: ActionChip(
                              label: Text('すべて表示 (${_items.length})'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: term == null ? null : () => context.push('/todo/term/${term.id}', extra: term.title),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
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
    final top = _items.take(3).toList();
    return Container(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_off),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '紐付けなし',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600, color: DT.textSecondary),
                  ),
                ),
                Text('TODO ${_items.length} 件', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (top.isEmpty)
              const Text('該当のTODOはありません')
            else
              Theme(
                data: Theme.of(context).copyWith(
                  chipTheme: Theme.of(context).chipTheme.copyWith(
                        side: BorderSide.none,
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: DT.textPrimary),
                      ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableListView.builder(
                      key: ValueKey('home_unlinked_top_${widget.weekStart.millisecondsSinceEpoch}'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: top.length,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = top.removeAt(oldIndex);
                          top.insert(newIndex, item);
                          final rest = _items.where((e) => !top.contains(e)).toList();
                          _items = [...top, ...rest];
                        });
                        final key = 'home_week_unlinked_${widget.weekStart.millisecondsSinceEpoch}';
                        await ref.read(orderServiceProvider).setOrder(
                          key,
                          _items.map((e) => e.id).toList(),
                        );
                      },
                      itemBuilder: (context, i) => Align(
                        key: ValueKey('home_unlinked_top_item_${top[i].id}'),
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ActionChip(
                            label: Text(top[i].title, overflow: TextOverflow.ellipsis),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: () => context.push('/todo/task/${top[i].id}', extra: top[i].title),
                          ),
                        ),
                      ),
                    ),
                    if (_items.length > top.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: ActionChip(
                          label: Text('すべて表示 (${_items.length})'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onPressed: () => context.push('/todo'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
