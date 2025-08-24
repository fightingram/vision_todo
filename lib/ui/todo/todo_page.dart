import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
// Unified Term UI
import '../../models/task.dart';
import '../../repositories/term_repositories.dart';
import '../../providers/db_provider.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
// Repositories are used via providers; direct imports not needed
import '../widgets/task_tile.dart';
import '../../models/tag.dart';
import 'term_todo_page.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO'),
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

class _TodoTreeState extends ConsumerState<_TodoTree> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];

    final dreamTabs = [
      const Tab(icon: Icon(Icons.bedtime_outlined), text: '夢: すべて'),
      ...dreams.map((d) => Tab(icon: const Icon(Icons.bedtime_outlined), text: d.title)),
    ];
    final tagTabs = [
      const Tab(icon: Icon(Icons.label_outline), text: 'タグ: すべて'),
      ...tags.map((t) => Tab(icon: const Icon(Icons.label_outline), text: t.name)),
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
                final selectedDreamId = dreamIndex == 0 ? null : dreams[dreamIndex - 1].id;
                return Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        isScrollable: true,
                        tabs: dreamTabs,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                                final selectedTagId = tagIndex == 0 ? null : tags[tagIndex - 1].id;
                                return Column(
                                  children: [
                                    Material(
                                      color: Theme.of(context).colorScheme.surface,
                                      child: TabBar(
                                        isScrollable: true,
                                        tabs: tagTabs,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
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

class _FilteredTodosView extends ConsumerWidget {
  const _FilteredTodosView({required this.dreamId, required this.tagId});
  final int? dreamId;
  final int? tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final longsAsync = ref.watch(termsByDreamProvider(dreamId));
    final tasksAsync = ref.watch(tasksStreamProvider);
    return longsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みエラー: $e')),
      data: (longs) {
        if (longs.isEmpty) {
          return const Center(child: Text('該当のTermはありません'));
        }
        final tasks = tasksAsync.value ?? const <Task>[];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: longs
              .map((l) => _LongFilteredSection(
                    item: l,
                    tagId: tagId,
                    allTasks: tasks,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _LongFilteredSection extends ConsumerWidget {
  const _LongFilteredSection({required this.item, required this.tagId, required this.allTasks});
  final Term item;
  final int? tagId;
  final List<Task> allTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show tasks linked directly to this Term
    return FutureBuilder(
      future: ref.read(termRepoProvider).loadTags(item),
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];
        final goalHasTag = tagId == null ? true : tags.any((t) => t.id == tagId);
        if (!goalHasTag && tagId != null) {
          return const SizedBox.shrink();
        }

        final filteredTasks = allTasks.where((t) => t.shortTermId == item.id).toList();

        return Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.flag_outlined),
            title: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TermTodoPage(goalId: item.id, goalTitle: item.title),
                  ),
                );
              },
              child: Text(item.title),
            ),
            subtitle: Text('TODO ${filteredTasks.length} 件'),
            children: [
          // Term actions row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: Text(item.archived ? '達成済み' : '達成'),
                      onPressed: item.archived
                          ? null
                          : () async {
                              await ref.read(termRepoProvider).archiveTerm(item, archived: true);
                            },
                    ),
                  ],
                ),
              ),
              if (filteredTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('該当のTODOはありません'),
                )
              else
                ...filteredTasks
                    .map<Widget>((t) => Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: TaskTile(task: t),
                        ))
                    .toList(),
            ],
          ),
        );
      },
    );
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
    final tasksAsync = ref.watch(tasksStreamProvider);
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
      child: Card(
        child: ExpansionTile(
          title: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TermTodoPage(goalId: item.id, goalTitle: item.title),
                ),
              );
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
                final tasks = tasksAsync.value ?? const <Task>[];
                final filtered = tasks.where((t) => t.shortTermId != null && shortIds.contains(t.shortTermId)).toList();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('TODOはありません'),
                  );
                }
                return Column(
                  children: filtered
                      .map<Widget>((t) => Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: TaskTile(task: t),
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

 
