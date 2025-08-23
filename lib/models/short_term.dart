import 'package:isar/isar.dart';
import 'tag.dart';

part 'short_term.g.dart';

@collection
class ShortTerm {
  ShortTerm({
    this.id = Isar.autoIncrement,
    required this.title,
    this.longTermId,
    this.priority = 1,
    this.dueAt,
    this.archived = false,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Id id;
  String title;
  int? longTermId;
  int priority; // 0..3
  DateTime? dueAt;
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;

  // Many-to-many: ShortTerm <-> Tag
  final tags = IsarLinks<Tag>();
}
