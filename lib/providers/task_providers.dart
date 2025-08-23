import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/task.dart';
import '../providers/db_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/task_repository.dart';
import '../utils/date_utils.dart' as du;

final taskRepoProvider = Provider<TaskRepository>((ref) {
  final db = ref.read(isarServiceProvider);
  return TaskRepository(db);
});

final tasksStreamProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final repo = ref.read(taskRepoProvider);
  final showCompleted = ref.watch(settingsProvider.select((s) => s.showCompleted));
  return repo.watchAll(includeDone: showCompleted);
});

class SectionedTasks {
  const SectionedTasks({
    required this.today,
    required this.tomorrow,
    required this.thisWeek,
    required this.none,
  });
  final List<Task> today;
  final List<Task> tomorrow;
  final List<Task> thisWeek;
  final List<Task> none;
}

// Sorting: Pinned(omit MVP) > priority desc > due asc > createdAt asc
int _taskCompare(Task a, Task b) {
  final byPriority = b.priority.compareTo(a.priority);
  if (byPriority != 0) return byPriority;
  final ad = a.dueAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
  final bd = b.dueAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
  final byDue = ad.compareTo(bd);
  if (byDue != 0) return byDue;
  return a.createdAt.compareTo(b.createdAt);
}

final sectionedTasksProvider = Provider.autoDispose<SectionedTasks>((ref) {
  final list = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  if (list.isEmpty) return const SectionedTasks(today: [], tomorrow: [], thisWeek: [], none: []);
  final now = DateTime.now();
  final startOfWeek = du.startOfWeek(now, ref.read(settingsProvider).weekStart);
  final endOfWeek = du.endOfWeek(now, ref.read(settingsProvider).weekStart);

  final today = <Task>[];
  final tomorrow = <Task>[];
  final thisWeek = <Task>[];
  final none = <Task>[];

  for (final t in list) {
    if (t.dueAt == null) {
      none.add(t);
      continue;
    }
    if (du.isSameDate(t.dueAt!, now)) {
      today.add(t);
    } else if (du.isSameDate(t.dueAt!, now.add(const Duration(days: 1)))) {
      tomorrow.add(t);
    } else if (t.dueAt!.isAfter(now) && !t.dueAt!.isAfter(endOfWeek) && !t.dueAt!.isBefore(startOfWeek)) {
      thisWeek.add(t);
    } else {
      // If dueAt is in the past, treat as Today section to surface
      if (t.dueAt!.isBefore(now)) {
        today.add(t);
      } else {
        thisWeek.add(t);
      }
    }
  }

  today.sort(_taskCompare);
  tomorrow.sort(_taskCompare);
  thisWeek.sort(_taskCompare);
  none.sort(_taskCompare);

  return SectionedTasks(today: today, tomorrow: tomorrow, thisWeek: thisWeek, none: none);
});

