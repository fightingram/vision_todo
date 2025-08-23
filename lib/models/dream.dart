import 'package:isar/isar.dart';

part 'dream.g.dart';

@collection
class Dream {
  Dream({
    this.id = Isar.autoIncrement,
    required this.title,
    this.priority = 1,
    this.dueAt,
    this.color = 0xFF90CAF9,
    this.archived = false,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Id id;
  String title;
  int priority; // 0..3
  DateTime? dueAt;
  int color; // ARGB
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;
}
