import 'package:isar/isar.dart';

part 'tag.g.dart';

@collection
class Tag {
  Tag({
    this.id = Isar.autoIncrement,
    required this.name,
    this.color = 0xFF9E9E9E,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Id id;
  String name;
  int color; // ARGB
  DateTime createdAt;
  DateTime updatedAt;
}

