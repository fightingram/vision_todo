import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/dream.dart';
// Unified: stop importing LongTerm/ShortTerm directly
import '../../models/task.dart';
import '../../models/tag.dart';
import '../../providers/term_providers.dart';
import '../../providers/task_providers.dart';
import '../../repositories/term_repositories.dart';

class NewItemDialog extends ConsumerStatefulWidget {
  const NewItemDialog({super.key});

  @override
  ConsumerState<NewItemDialog> createState() => _NewItemDialogState();
}

enum _ItemType { dream, term, task }

class _NewItemDialogState extends ConsumerState<NewItemDialog> {
  _ItemType type = _ItemType.task;
  final titleCtrl = TextEditingController();
  int priority = 1;
  DateTime? dueAt;
  int? dreamId;
  int? termId;

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsProvider).value ?? const <Dream>[];
    final terms = ref.watch(allTopTermsProvider).value ?? const <Term>[];

    final filteredTerms = terms;

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
      } else if (type == _ItemType.term) {
        if (dreamId == null) return;
        await ref.read(termRepoProvider).addTerm(
            title: t, dreamId: dreamId!, priority: priority, dueAt: dueAt);
      } else {
        final repo = ref.read(taskRepoProvider);
        await repo.add(Task(
            title: t, priority: priority, dueAt: dueAt, shortTermId: termId));
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
              DropdownMenuItem(value: _ItemType.term, child: Text('Term')),
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
          if (type == _ItemType.term) ...[
            DropdownButtonFormField<int?>(
              value: dreamId,
              decoration: const InputDecoration(labelText: '夢 (親)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('未選択')),
                ...dreams.map(
                    (d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
              ],
              onChanged: (v) => setState(() {
                dreamId = v;
              }),
            ),
          ],
          if (type == _ItemType.task) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: termId,
              decoration: const InputDecoration(labelText: 'Term (親, 任意)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('未選択')),
                ...filteredTerms.map(
                    (g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
              ],
              onChanged: (v) => setState(() => termId = v),
            ),
          ],
          if (type != _ItemType.dream) ...[
            const SizedBox(height: 12),
            const Text('優先度'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('低'),
                    selected: priority == 0,
                    onSelected: (_) => setState(() => priority = 0)),
                ChoiceChip(
                    label: const Text('中'),
                    selected: priority == 1,
                    onSelected: (_) => setState(() => priority = 1)),
                ChoiceChip(
                    label: const Text('高'),
                    selected: priority == 2,
                    onSelected: (_) => setState(() => priority = 2)),
                ChoiceChip(
                    label: const Text('最優先'),
                    selected: priority == 3,
                    onSelected: (_) => setState(() => priority = 3)),
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
                  onSelected: (_) => setState(() =>
                      dueAt = DateTime.now().add(const Duration(days: 1))),
                ),
                ChoiceChip(
                  label: const Text('週末'),
                  selected: false,
                  onSelected: (_) {
                    final now = DateTime.now();
                    final toAdd = 6 - now.weekday; // Saturday
                    setState(() => dueAt =
                        DateTime(now.year, now.month, now.day)
                            .add(Duration(days: toAdd.clamp(0, 6))));
                  },
                ),
                ChoiceChip(
                  label: const Text('来週'),
                  selected: false,
                  onSelected: (_) {
                    final now = DateTime.now();
                    final nextWeek = DateTime(now.year, now.month, now.day)
                        .add(Duration(days: 7 - (now.weekday - 1)));
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(onPressed: onSubmit, child: const Text('作成')),
      ],
    );
  }
}
