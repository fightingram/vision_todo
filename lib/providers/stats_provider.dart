import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/task.dart';
import 'task_providers.dart';
import '../repositories/term_repositories.dart';
import 'term_providers.dart';

class Counters {
  const Counters({required this.week, required this.month, required this.total});
  final int week;
  final int month;
  final int total;
}

final tasksAllStreamProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  return ref.read(taskRepoProvider).watchAll(includeDone: true);
});

final countersProvider = Provider.autoDispose<Counters>((ref) {
  final tasks = ref.watch(tasksAllStreamProvider).value ?? const <Task>[];
  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final startOfMonth = DateTime(now.year, now.month);

  int week = 0, month = 0, total = 0;
  for (final t in tasks) {
    if (t.status == TaskStatus.done && t.doneAt != null) {
      total++;
      if (!t.doneAt!.isBefore(startOfWeek)) week++;
      if (!t.doneAt!.isBefore(startOfMonth)) month++;
    }
  }
  return Counters(week: week, month: month, total: total);
});

// Map of Dream.id -> count of completed tasks linked via ShortTerm -> LongTerm -> Dream
final dreamDoneCountsProvider = Provider.autoDispose<Map<int, int>>((ref) {
  final tasks = ref.watch(tasksAllStreamProvider).value ?? const <Task>[];
  final childTerms = ref.watch(allChildTermsProvider).value ?? const <Term>[];
  final topTerms = ref.watch(allTopTermsProvider).value ?? const <Term>[];

  // Map Term.id (both ShortTerm and LongTerm) to Dream.id
  final termToDream = <int, int>{};
  for (final t in topTerms) {
    if (t.dreamId != null) termToDream[t.id] = t.dreamId!; // LongTerm -> Dream
  }
  for (final t in childTerms) {
    if (t.dreamId != null) termToDream[t.id] = t.dreamId!; // ShortTerm -> Dream (via parent)
  }

  final counts = <int, int>{};
  for (final tk in tasks) {
    if (tk.status == TaskStatus.done && tk.shortTermId != null) {
      final did = termToDream[tk.shortTermId!];
      if (did != null) counts[did] = (counts[did] ?? 0) + 1;
    }
  }
  return counts;
});
