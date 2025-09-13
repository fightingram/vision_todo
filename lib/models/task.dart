import 'package:isar/isar.dart';

part 'task.g.dart';

// 未着手(todo), 進行中(doing), 完了(done)
enum TaskStatus { todo, doing, done }

@collection
class Task {
  Task({
    this.id = Isar.autoIncrement,
    required this.title,
    this.priority = 1,
    this.dueAt,
    this.shortTermId,
    this.archived = false,
    this.status = TaskStatus.todo,
    this.doneAt,
    this.triagedWeekStart,
    this.plannedWeekStart,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Id id;
  String title;
  int priority; // 0..3
  DateTime? dueAt;
  int? shortTermId;
  bool archived;
  @Enumerated(EnumType.name)
  TaskStatus status;
  DateTime? doneAt;
  // The Monday (week start) when this task was last triaged
  DateTime? triagedWeekStart;
  // If planned for a week, stores that week's Monday (week start)
  DateTime? plannedWeekStart;
  DateTime createdAt;
  DateTime updatedAt;
}
