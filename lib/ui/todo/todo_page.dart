import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
// Unified Term UI
import '../../models/task.dart';
import '../../repositories/term_repositories.dart';
import '../../providers/db_provider.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/settings_provider.dart';
// Repositories are used via providers; direct imports not needed
import '../widgets/task_tile.dart';
import '../../models/tag.dart';
import 'term_todo_page.dart';
import 'package:go_router/go_router.dart';
import '../../providers/order_provider.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO'),
        actions: [
          IconButton(
            tooltip: 'フィルター',
            onPressed: () => _openTodoFilter(context, ref),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) => const _TodoTree(),
      ),
    );
  }
}

class _TodoTree extends ConsumerStatefulWidget {
  const _TodoTree();
  @override
  ConsumerState<_TodoTree> createState() => _TodoTreeState();
}

class _TodoTreeState extends ConsumerState<_TodoTree>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];

    final dreamTabs = [
      const Tab(icon: Icon(Icons.bedtime_outlined), text: '夢: すべて'),
      ...dreams.map(
          (d) => Tab(icon: const Icon(Icons.bedtime_outlined), text: d.title)),
    ];
    final tagTabs = [
      const Tab(icon: Icon(Icons.label_outline), text: 'タグ: すべて'),
      ...tags
          .map((t) => Tab(icon: const Icon(Icons.label_outline), text: t.name)),
    ];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: DefaultTabController(
        length: dreamTabs.length,
        child: Builder(
          builder: (context) {
            final dreamCtrl = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: dreamCtrl,
              builder: (context, _) {
                final dreamIndex = dreamCtrl.index;
                final selectedDreamId =
                    dreamIndex == 0 ? null : dreams[dreamIndex - 1].id;
                return Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        isScrollable: true,
                        tabs: dreamTabs,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                    Expanded(
                      child: DefaultTabController(
                        length: tagTabs.length,
                        child: Builder(
                          builder: (context2) {
                            final tagCtrl = DefaultTabController.of(context2);
                            return AnimatedBuilder(
                              animation: tagCtrl,
                              builder: (context, __) {
                                final tagIndex = tagCtrl.index;
                                final selectedTagId = tagIndex == 0
                                    ? null
                                    : tags[tagIndex - 1].id;
                                return Column(
                                  children: [
                                    Material(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      child: TabBar(
                                        isScrollable: true,
                                        tabs: tagTabs,
                                        labelPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12),
                                      ),
                                    ),
                                    Expanded(
                                      child: _FilteredTodosView(
                                        dreamId: selectedDreamId,
                                        tagId: selectedTagId,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<void> _openTodoFilter(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final initialStatuses = Set<TaskStatus>.from(settings.statusFilter);
  final initialPrios = Set<int>.from(settings.priorityFilter);

  String priorityLabel(int p) {
    switch (p) {
      case 3:
        return '最優先';
      case 2:
        return '高';
      case 1:
        return '中';
      default:
        return '低';
    }
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final statuses = Set<TaskStatus>.from(initialStatuses);
      final prios = Set<int>.from(initialPrios);
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list),
                      const SizedBox(width: 8),
                      const Text('フィルター', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          statuses.clear();
                          prios.clear();
                          setState(() {});
                        },
                        child: const Text('クリア'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('ステータス'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('未着手'),
                        selected: statuses.contains(TaskStatus.todo),
                        onSelected: (v) => setState(() {
                          v ? statuses.add(TaskStatus.todo) : statuses.remove(TaskStatus.todo);
                        }),
                      ),
                      FilterChip(
                        label: const Text('進行中'),
                        selected: statuses.contains(TaskStatus.doing),
                        onSelected: (v) => setState(() {
                          v ? statuses.add(TaskStatus.doing) : statuses.remove(TaskStatus.doing);
                        }),
                      ),
                      FilterChip(
                        label: const Text('完了'),
                        selected: statuses.contains(TaskStatus.done),
                        onSelected: (v) => setState(() {
                          v ? statuses.add(TaskStatus.done) : statuses.remove(TaskStatus.done);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('優先度'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(4, (i) => i)
                        .map((p) => FilterChip(
                              label: Text(priorityLabel(p)),
                              selected: prios.contains(p),
                              onSelected: (v) => setState(() {
                                v ? prios.add(p) : prios.remove(p);
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('閉じる'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final notifier = ref.read(settingsProvider.notifier);
                          notifier.setStatusFilter(statuses);
                          notifier.setPriorityFilter(prios);
                          Navigator.pop(context);
                        },
                        child: const Text('適用'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _FilteredTodosView extends ConsumerStatefulWidget {
  const _FilteredTodosView({required this.dreamId, required this.tagId});
  final int? dreamId;
  final int? tagId;

  @override
  ConsumerState<_FilteredTodosView> createState() => _FilteredTodosViewState();
}

class _FilteredTodosViewState extends ConsumerState<_FilteredTodosView> {
  List<Term> _termItems = const [];

  Future<void> _loadOrder(List<Term> source) async {
    final service = ref.read(orderServiceProvider);
    final key = 'todo_terms_d${widget.dreamId ?? 0}_t${widget.tagId ?? 0}';
    final order = await service.getOrder(key);
    final map = {for (final t in source) t.id: t};
    final ordered = <Term>[];
    for (final id in order) {
      final t = map.remove(id);
      if (t != null) ordered.add(t);
    }
    ordered.addAll(map.values);
    setState(() => _termItems = ordered);
  }

  @override
  Widget build(BuildContext context) {
    final longsAsync = ref.watch(termsByDreamProvider(widget.dreamId));
    final filteredTasks = ref.watch(filteredTasksProvider);
    return longsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みエラー: $e')),
      data: (longs) {
        final tasks = filteredTasks;
        if (_termItems.length != longs.length || !_sameIds(_termItems, longs)) {
          _loadOrder(longs);
        }

        // Unlinked tasks section (only when tag filter is not applied)
        Widget? unlinkedWidget;
        if (widget.tagId == null) {
          final unlinked = tasks.where((t) => t.shortTermId == null).toList();
          if (unlinked.isNotEmpty) {
            unlinkedWidget = _UnlinkedSection(tasks: unlinked, dreamId: widget.dreamId, tagId: widget.tagId);
          }
        }

        if (_termItems.isEmpty && unlinkedWidget == null) {
          return const Center(child: Text('TODOはありません'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_termItems.isNotEmpty)
              ReorderableListView.builder(
                key: ValueKey('todo_terms_d${widget.dreamId ?? 0}_t${widget.tagId ?? 0}'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _termItems.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _termItems.removeAt(oldIndex);
                    _termItems.insert(newIndex, item);
                  });
                  final key = 'todo_terms_d${widget.dreamId ?? 0}_t${widget.tagId ?? 0}';
                  await ref.read(orderServiceProvider).setOrder(
                        key,
                        _termItems.map((e) => e.id).toList(),
                      );
                },
                itemBuilder: (context, i) => Container(
                  key: ValueKey('todo_term_entry_${_termItems[i].id}'),
                  child: _LongFilteredSection(item: _termItems[i], tagId: widget.tagId, allTasks: tasks),
                ),
              ),
            if (unlinkedWidget != null) unlinkedWidget,
          ],
        );
      },
    );
  }

  bool _sameIds<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ai = (a[i] as dynamic).id as int;
      final bi = (b[i] as dynamic).id as int;
      if (ai != bi) return false;
    }
    return true;
  }
}

class _UnlinkedSection extends ConsumerStatefulWidget {
  const _UnlinkedSection({required this.tasks, required this.dreamId, required this.tagId});
  final List<Task> tasks;
  final int? dreamId;
  final int? tagId;

  @override
  ConsumerState<_UnlinkedSection> createState() => _UnlinkedSectionState();
}

class _UnlinkedSectionState extends ConsumerState<_UnlinkedSection> {
  late List<Task> _items;

  @override
  void initState() {
    super.initState();
    _items = const [];
    _load();
  }

  @override
  void didUpdateWidget(covariant _UnlinkedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks.length != widget.tasks.length || !_sameIds(oldWidget.tasks, widget.tasks)) {
      _load();
    }
  }

  bool _sameIds(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _load() async {
    final service = ref.read(orderServiceProvider);
    final key = 'todo_unlinked_d${widget.dreamId ?? 0}_t${widget.tagId ?? 0}';
    final order = await service.getOrder(key);
    final map = {for (final t in widget.tasks) t.id: t};
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
    final key = 'todo_unlinked_d${widget.dreamId ?? 0}_t${widget.tagId ?? 0}';
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.link_off),
        title: const Text('紐付けなし'),
        subtitle: Text('TODO ${_items.length} 件'),
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('TODOはありません'),
            )
          else
            ReorderableListView.builder(
              key: ValueKey(key),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                await ref.read(orderServiceProvider).setOrder(
                      key,
                      _items.map((e) => e.id).toList(),
                    );
              },
              itemBuilder: (context, i) => Card(
                key: ValueKey('todo_unlinked_${_items[i].id}'),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TaskTile(task: _items[i], showCheckbox: false, showEditMenu: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _LongFilteredSection extends ConsumerStatefulWidget {
  const _LongFilteredSection(
      {required this.item, required this.tagId, required this.allTasks});
  final Term item;
  final int? tagId;
  final List<Task> allTasks;

  @override
  ConsumerState<_LongFilteredSection> createState() => _LongFilteredSectionState();
}

class _LongFilteredSectionState extends ConsumerState<_LongFilteredSection> {
  List<Task> _items = const [];

  Future<void> _load(List<Task> source) async {
    final service = ref.read(orderServiceProvider);
    final key = 'todo_term_${widget.item.id}_tag_${widget.tagId ?? 0}';
    final order = await service.getOrder(key);
    final map = {for (final t in source) t.id: t};
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
    // Show tasks linked directly to this Term
    return FutureBuilder(
      future: ref.read(termRepoProvider).loadTags(widget.item),
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];
        final termHasTag =
            widget.tagId == null ? true : tags.any((t) => t.id == widget.tagId);
        if (!termHasTag && widget.tagId != null) {
          return const SizedBox.shrink();
        }

        final filteredTasks =
            widget.allTasks.where((t) => t.shortTermId == widget.item.id).toList();
        // Load order once per build with current filtered set
        if (_items.length != filteredTasks.length || !_sameIds(_items, filteredTasks)) {
          // Async load; will setState when ready
          _load(filteredTasks);
        }

        return Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.flag_outlined),
            title: InkWell(
              onTap: () {
                context.push('/todo/term/${widget.item.id}', extra: widget.item.title);
              },
              child: Text(widget.item.title),
            ),
            subtitle: Text('TODO ${_items.length} 件'),
            children: [
              // Achieve button moved to Term detail page
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('該当のTODOはありません'),
                )
              else
                ReorderableListView.builder(
                  key: ValueKey('todo_term_${widget.item.id}_tag_${widget.tagId ?? 0}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _items.removeAt(oldIndex);
                      _items.insert(newIndex, item);
                    });
                    final key = 'todo_term_${widget.item.id}_tag_${widget.tagId ?? 0}';
                    await ref.read(orderServiceProvider).setOrder(
                          key,
                          _items.map((e) => e.id).toList(),
                        );
                  },
                  itemBuilder: (context, i) => Card(
                    key: ValueKey('todo_term_${widget.item.id}_${_items[i].id}'),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: TaskTile(task: _items[i], showCheckbox: false, showEditMenu: false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _sameIds(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

class _DreamNode extends ConsumerWidget {
  const _DreamNode({required this.dream});
  final Dream dream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final longsAsync = ref.watch(termsByDreamProvider(dream.id));
    return Card(
      child: ExpansionTile(
        title: Text(dream.title),
        // 新規作成は右上ボタンに集約
        children: [
          longsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('エラー: $e'),
            ),
            data: (items) => Column(
              children: items.map((lt) => _LongNode(item: lt)).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class _LongNode extends ConsumerWidget {
  const _LongNode({required this.item});
  final Term item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(termsByParentProvider(item.id));
    final tasks = ref.watch(filteredTasksProvider);
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
      child: Card(
        child: ExpansionTile(
          title: InkWell(
            onTap: () {
              context.push('/todo/term/${item.id}', extra: item.title);
            },
            child: Text(item.title),
          ),
          // 新規作成は右上ボタンに集約。表示はこの目標配下のTODOのみ。
          children: [
            shortsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('エラー: $e'),
              ),
              data: (shorts) {
                final shortIds = shorts.map((s) => s.id).toSet();
                final filtered = tasks
                    .where((t) =>
                        t.shortTermId != null &&
                        shortIds.contains(t.shortTermId))
                    .toList();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('TODOはありません'),
                  );
                }
                return Column(
                  children: filtered
                      .map<Widget>((t) => Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: TaskTile(task: t, showCheckbox: false, showEditMenu: false),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
