import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
// Unified Term entity: UI no longer references Short/Long models directly
import '../../providers/term_providers.dart';
import '../../models/tag.dart';
import 'tags_page.dart';
import '../../providers/db_provider.dart';
import '../../providers/task_providers.dart';
import '../../repositories/term_repositories.dart';

class TermsPage extends ConsumerWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(isarInitProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms'),
        actions: [
          IconButton(
            tooltip: 'タグ管理',
            icon: const Icon(Icons.label_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsPage()),
              );
            },
          ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('DB初期化エラー: $e')),
        data: (_) {
          final dreamsAsync = ref.watch(dreamsProvider);
          return dreamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('読み込みエラー: $e')),
            data: (dreams) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final title = await _askTitle(context, '夢を追加');
                          if (title != null) {
                            await ref.read(dreamRepoProvider).put(Dream(title: title));
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('夢を追加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: dreams.isEmpty
                        ? const Center(child: Text('まだTermがありません'))
                        : ListView.builder(
                            itemCount: dreams.length,
                            itemBuilder: (context, i) => DreamTile(dream: dreams[i]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DreamTile extends ConsumerWidget {
  const DreamTile({super.key, required this.dream});
  final Dream dream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final longTermsAsync = ref.watch(termsByDreamProvider(dream.id));
    return Card(
      child: ExpansionTile(
        title: Text(dream.title),
        subtitle: const Text('直近30日の完了数: —'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final title = await _askTitle(context, 'Termを追加');
                if (title != null) {
                  await ref.read(termRepoProvider).addTerm(title: title, dreamId: dream.id);
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'archive') {
                  dream.archived = true;
                  await ref.read(dreamRepoProvider).put(dream);
                } else if (v == 'unarchive') {
                  dream.archived = false;
                  await ref.read(dreamRepoProvider).put(dream);
                } else if (v == 'delete') {
                  await ref.read(dreamRepoProvider).delete(dream.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: dream.archived ? 'unarchive' : 'archive', child: Text(dream.archived ? 'アーカイブ解除' : 'アーカイブ')),
                const PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
          ],
        ),
        children: [
          longTermsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('エラー: $e'),
            ),
            data: (items) => Column(
              children: items.map((g) => TermTile(item: g)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TermTile extends ConsumerWidget {
  const TermTile({super.key, required this.item});
  final Term item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(termsByParentProvider(item.id));
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
      child: Card(
        child: ExpansionTile(
          title: Text(item.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TODOはTODOタブから管理'),
              const SizedBox(height: 4),
              _GoalTagChips(item: item),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'タグを編集',
                icon: const Icon(Icons.label),
                onPressed: () => _editGoalTags(context, ref, item),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final title = await _askTitle(context, 'Termを追加');
                  if (title != null) {
                    final dreamId = item.dreamId ?? (await ref.read(longTermRepoProvider).getById(item.id))?.dreamId;
                    if (dreamId == null) return;
                    await ref.read(termRepoProvider).addTerm(title: title, dreamId: dreamId, parentGoalId: item.id);
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'archive') {
                    await ref.read(termRepoProvider).archiveTerm(item, archived: true);
                  } else if (v == 'unarchive') {
                    await ref.read(termRepoProvider).archiveTerm(item, archived: false);
                  } else if (v == 'delete') {
                    await ref.read(termRepoProvider).deleteTerm(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: item.archived ? 'unarchive' : 'archive', child: Text(item.archived ? 'アーカイブ解除' : 'アーカイブ')),
                  const PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ],
          ),
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
              data: (items) => Column(
              children: items.map((s) => TermChildTile(item: s)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TermChildTile extends ConsumerWidget {
  const TermChildTile({super.key, required this.item});
  final Term item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('タップで配下TODOのCRUD'),
          const SizedBox(height: 4),
          _GoalTagChips(item: item),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'タグを編集',
            icon: const Icon(Icons.label),
            onPressed: () => _editGoalTags(context, ref, item),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await ref.read(termRepoProvider).archiveTerm(item, archived: true);
              } else if (v == 'unarchive') {
                await ref.read(termRepoProvider).archiveTerm(item, archived: false);
              } else if (v == 'delete') {
                await ref.read(termRepoProvider).deleteTerm(item);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: item.archived ? 'unarchive' : 'archive', child: Text(item.archived ? 'アーカイブ解除' : 'アーカイブ')),
              const PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      onTap: () => showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => TermDetailSheet(goalId: item.id, title: item.title),
      ),
    );
  }
}

class _GoalTagChips extends ConsumerWidget {
  const _GoalTagChips({required this.item});
  final Term item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(termRepoProvider).loadTags(item),
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];
        if (tags.isEmpty) {
          return Text('タグなし', style: Theme.of(context).textTheme.bodySmall);
        }
        return Wrap(
          spacing: 8,
          runSpacing: -8,
          children: tags
              .map((t) => Chip(
                    label: Text(t.name),
                    backgroundColor: Color(t.color).withOpacity(0.15),
                    side: BorderSide(color: Color(t.color).withOpacity(0.4)),
                  ))
              .toList(),
        );
      },
    );
  }
}

Future<void> _editGoalTags(BuildContext context, WidgetRef ref, Term item) async {
  final selected = await ref.read(termRepoProvider).loadTags(item);
  final allTags = await ref.read(tagRepoProvider).watchAll().first;
  final result = await showDialog<List<Tag>>(
    context: context,
    builder: (context) => _TagPickerDialog(allTags: allTags, initial: selected),
  );
  if (result != null) {
    await ref.read(termRepoProvider).setTags(item, result);
  }
}

class _TagPickerDialog extends StatefulWidget {
  const _TagPickerDialog({required this.allTags, required this.initial});
  final List<Tag> allTags;
  final List<Tag> initial;

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initial.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タグを選択'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: widget.allTags.isEmpty
            ? const Center(child: Text('タグがありません。右上から作成してください。'))
            : ListView(
                children: widget.allTags
                    .map((t) => CheckboxListTile(
                          value: _selectedIds.contains(t.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(t.id);
                              } else {
                                _selectedIds.remove(t.id);
                              }
                            });
                          },
                          title: Text(t.name),
                          secondary: CircleAvatar(backgroundColor: Color(t.color)),
                        ))
                    .toList(),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            final result = widget.allTags.where((t) => _selectedIds.contains(t.id)).toList();
            Navigator.pop(context, result);
          },
          child: const Text('保存'),
        )
      ],
    );
  }
}

class TermDetailSheet extends ConsumerWidget {
  const TermDetailSheet({super.key, required this.goalId, required this.title});
  final int goalId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using providers directly in the sheet via a new Consumer for tasks
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, controller) {
        return _TermDetailList(goalId: goalId, title: title, controller: controller);
      },
    );
  }
}

class _TermDetailList extends ConsumerWidget {
  const _TermDetailList({required this.goalId, required this.title, required this.controller});
  final int goalId;
  final String title;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepo = ref.read(taskRepoProvider);
    final stream = taskRepo.watchByGoal(goalId);
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_task),
                    onPressed: () async {
                      final title = await _askTitle(context, 'TODOを追加');
                      if (title != null) {
                        final t = await taskRepo.addQuick(title);
                        t.shortTermId = goalId; // unified: tasks link to goalId
                        await taskRepo.update(t);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (context, i) => Dismissible(
                    key: ValueKey(items[i].id),
                    background: Container(color: Colors.redAccent),
                    onDismissed: (_) => taskRepo.delete(items[i].id),
                    child: ListTile(
                      title: Text(items[i].title),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => taskRepo.delete(items[i].id),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<String?> _askTitle(BuildContext context, String title) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'タイトル'),
        onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('追加')),
      ],
    ),
  );
}
