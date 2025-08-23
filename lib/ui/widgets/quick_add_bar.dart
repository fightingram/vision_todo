import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/task_providers.dart';

class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({super.key, this.shortTermId});
  final int? shortTermId;

  @override
  ConsumerState<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<QuickAddBar> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> _submit() async {
    final text = controller.text.trim();
    if (text.isEmpty || loading) return;
    setState(() => loading = true);
    try {
      final repo = ref.read(taskRepoProvider);
      final t = await repo.addQuick(text);
      if (widget.shortTermId != null) {
        t.shortTermId = widget.shortTermId;
        await repo.update(t);
      }
      controller.clear();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'クイック追加…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: loading ? null : _submit,
          icon: const Icon(Icons.add),
          label: const Text('追加'),
        ),
      ],
    );
  }
}
