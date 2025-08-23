import 'package:isar/isar.dart';

part 'task.g.dart';

enum TaskStatus { todo, done }

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
  DateTime createdAt;
  DateTime updatedAt;
}
