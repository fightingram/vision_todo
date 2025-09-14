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
            tooltip: settings.showCompleted ? '未完了のみ' : '完了も表示',
            onPressed: () => ref.read(settingsProvider.notifier).toggleShowCompleted(),
            icon: Icon(settings.showCompleted ? Icons.checklist : Icons.checklist_rtl),
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
        final tasks = tasksAsync.value ?? const <Task>[];
        final children = <Widget>[];

        // Sections for each Term
        for (final l in longs) {
          children.add(_LongFilteredSection(item: l, tagId: tagId, allTasks: tasks));
        }

        // Unlinked tasks section (only when tag filter is not applied)
        if (tagId == null) {
          final unlinked = tasks.where((t) => t.shortTermId == null).toList();
          if (unlinked.isNotEmpty) {
            children.add(_UnlinkedSection(tasks: unlinked));
          }
        }

        if (children.isEmpty) {
          return const Center(child: Text('TODOはありません'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: children,
        );
      },
    );
  }
}

class _UnlinkedSection extends StatelessWidget {
  const _UnlinkedSection({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.link_off),
        title: const Text('紐付けなし'),
        subtitle: Text('TODO ${tasks.length} 件'),
        children: [
          ...tasks
              .map<Widget>((t) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: TaskTile(task: t, showCheckbox: false, showEditMenu: false),
                  ))
              .toList(),
        ],
      ),
    );
  }
}

class _LongFilteredSection extends ConsumerWidget {
  const _LongFilteredSection(
      {required this.item, required this.tagId, required this.allTasks});
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
        final termHasTag =
            tagId == null ? true : tags.any((t) => t.id == tagId);
        if (!termHasTag && tagId != null) {
          return const SizedBox.shrink();
        }

        final filteredTasks =
            allTasks.where((t) => t.shortTermId == item.id).toList();

        return Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.flag_outlined),
            title: InkWell(
              onTap: () {
                context.push('/todo/term/${item.id}', extra: item.title);
              },
              child: Text(item.title),
            ),
            subtitle: Text('TODO ${filteredTasks.length} 件'),
            children: [
              // Achieve button moved to Term detail page
              if (filteredTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('該当のTODOはありません'),
                )
              else
                ...filteredTasks
                    .map<Widget>((t) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: TaskTile(task: t, showCheckbox: false, showEditMenu: false),
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
                final tasks = tasksAsync.value ?? const <Task>[];
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
