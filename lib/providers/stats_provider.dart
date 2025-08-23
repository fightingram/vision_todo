import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/task.dart';
import 'task_providers.dart';

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
