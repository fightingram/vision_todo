import 'package:isar/isar.dart';
import 'tag.dart';

part 'long_term.g.dart';

@collection
class LongTerm {
  LongTerm({
    this.id = Isar.autoIncrement,
    required this.title,
    this.dreamId,
    this.priority = 1,
    this.dueAt,
    this.archived = false,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Id id;
  String title;
  int? dreamId;
  int priority; // 0..3
  DateTime? dueAt;
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;

  // Many-to-many: LongTerm <-> Tag
  final tags = IsarLinks<Tag>();
}
