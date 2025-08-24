import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
import '../../models/long_term.dart';
import '../../models/task.dart';
import '../../providers/db_provider.dart';
import '../../providers/goal_providers.dart';
import '../../providers/task_providers.dart';
// Repositories are used via providers; direct imports not needed
import '../widgets/task_tile.dart';
import '../../models/tag.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO'),
        actions: [
          IconButton(
            tooltip: '新規作成',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const _NewItemDialog(),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
          )
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
    final longsAsync = ref.watch(longTermsByDreamProvider(dreamId));
    final tasksAsync = ref.watch(tasksStreamProvider);
    return longsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みエラー: $e')),
      data: (longs) {
        if (longs.isEmpty) {
          return const Center(child: Text('該当の目標はありません'));
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
  final LongTerm item;
  final int? tagId;
  final List<Task> allTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show tasks linked directly to this Goal (LongTerm.id)
    return FutureBuilder(
      future: item.tags.load(),
      builder: (context, _) {
        final goalHasTag = tagId == null ? true : item.tags.any((t) => t.id == tagId);
        if (!goalHasTag && tagId != null) {
          return const SizedBox.shrink();
        }

        final filteredTasks = allTasks.where((t) => t.shortTermId == item.id).toList();

        return Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text(item.title),
            subtitle: Text('TODO ${filteredTasks.length} 件'),
            children: [
              // Goal actions row
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
                              final repo = ref.read(longTermRepoProvider);
                              item.archived = true;
                              await repo.put(item);
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
    final longsAsync = ref.watch(longTermsByDreamProvider(dream.id));
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
  final LongTerm item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(shortTermsByLongProvider(item.id));
    final tasksAsync = ref.watch(tasksStreamProvider);
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
      child: Card(
        child: ExpansionTile(
          title: Text(item.title),
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

class _NewItemDialog extends ConsumerStatefulWidget {
  const _NewItemDialog();
  @override
  ConsumerState<_NewItemDialog> createState() => _NewItemDialogState();
}

enum _ItemType { dream, long, task }

class _NewItemDialogState extends ConsumerState<_NewItemDialog> {
  _ItemType type = _ItemType.task;
  final titleCtrl = TextEditingController();
  int priority = 1;
  DateTime? dueAt;
  int? dreamId;
  int? longId;

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final longs = ref.watch(allLongTermsProvider).value ?? const <LongTerm>[];

    // For task creation we don't link to Dream; keep dream only for creating Goals.
    final filteredLongs = longs;

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        initialDate: dueAt ?? DateTime.now(),
      );
      if (picked != null) setState(() => dueAt = picked);
    }

    Future<void> onSubmit() async {
      final t = titleCtrl.text.trim();
      if (t.isEmpty) return;
      if (type == _ItemType.dream) {
        await ref.read(dreamRepoProvider).put(Dream(title: t));
      } else if (type == _ItemType.long) {
        // Enforce: Goal must belong to a Dream
        if (dreamId == null) return;
        await ref.read(longTermRepoProvider).put(LongTerm(title: t, dreamId: dreamId, priority: priority, dueAt: dueAt));
      } else {
        // Creating TODO: link directly to Goal (LongTerm) by storing its id.
        final repo = ref.read(taskRepoProvider);
        await repo.add(Task(title: t, priority: priority, dueAt: dueAt, shortTermId: longId));
      }
      if (context.mounted) Navigator.pop(context);
    }

    return AlertDialog(
      scrollable: true,
      title: const Text('新規作成'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('分類'),
            const SizedBox(height: 8),
            DropdownButtonFormField<_ItemType>(
              value: type,
              items: const [
                DropdownMenuItem(value: _ItemType.dream, child: Text('夢')),
                DropdownMenuItem(value: _ItemType.long, child: Text('目標')),
                DropdownMenuItem(value: _ItemType.task, child: Text('TODO')),
              ],
              onChanged: (v) => setState(() => type = v ?? _ItemType.task),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'タイトル'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            if (type == _ItemType.long) ...[
              DropdownButtonFormField<int?>(
                value: dreamId,
                decoration: const InputDecoration(labelText: '夢 (親)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未選択')),
                  ...dreams.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
                ],
                onChanged: (v) => setState(() {
                  dreamId = v;
                }),
              ),
            ],
            if (type == _ItemType.task) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: longId,
                decoration: const InputDecoration(labelText: '目標 (親, 任意)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未選択')),
                  ...filteredLongs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.title))),
                ],
                onChanged: (v) => setState(() => longId = v),
              ),
            ],
            // 夢には優先度・期限は不要のため、Dream選択時は非表示
            if (type != _ItemType.dream) ...[
              const SizedBox(height: 12),
            const Text('優先度'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('低'), selected: priority == 0, onSelected: (_) => setState(() => priority = 0)),
                ChoiceChip(label: const Text('中'), selected: priority == 1, onSelected: (_) => setState(() => priority = 1)),
                ChoiceChip(label: const Text('高'), selected: priority == 2, onSelected: (_) => setState(() => priority = 2)),
                ChoiceChip(label: const Text('最優先'), selected: priority == 3, onSelected: (_) => setState(() => priority = 3)),
              ],
            ),
              const SizedBox(height: 12),
              const Text('期限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                ChoiceChip(
                  label: const Text('なし'),
                  selected: dueAt == null,
                  onSelected: (_) => setState(() => dueAt = null),
                ),
                ChoiceChip(
                  label: const Text('今日'),
                  selected: false,
                  onSelected: (_) => setState(() => dueAt = DateTime.now()),
                ),
                ChoiceChip(
                  label: const Text('明日'),
                  selected: false,
                  onSelected: (_) => setState(() => dueAt = DateTime.now().add(const Duration(days: 1))),
                ),
                ChoiceChip(
                  label: const Text('週末'),
                  selected: false,
                  onSelected: (_) {
                    final now = DateTime.now();
                    final toAdd = 6 - now.weekday; // Sat as weekend
                    setState(() => dueAt = DateTime(now.year, now.month, now.day).add(Duration(days: toAdd.clamp(0, 6))));
                  },
                ),
                ChoiceChip(
                  label: const Text('来週'),
                  selected: false,
                  onSelected: (_) {
                    final now = DateTime.now();
                    final nextWeek = DateTime(now.year, now.month, now.day).add(Duration(days: 7 - (now.weekday - 1)));
                    setState(() => dueAt = nextWeek);
                  },
                ),
                ActionChip(label: const Text('日付指定'), onPressed: pickDate),
              ],
            ),
            ],
          ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(onPressed: onSubmit, child: const Text('作成')),
      ],
    );
  }
}
