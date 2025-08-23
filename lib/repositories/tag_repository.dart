import 'package:isar/isar.dart';

import '../models/tag.dart';
import '../services/isar_service.dart';

class TagRepository {
  TagRepository(this._db);
  final IsarService _db;

  Isar get _isar => _db.isar;

  Stream<List<Tag>> watchAll() {
    return _isar.tags.where().sortByName().watch(fireImmediately: true);
  }

  Future<void> put(Tag tag) async {
    tag.updatedAt = DateTime.now();
    await _isar.writeTxn(() async => _isar.tags.put(tag));
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async => _isar.tags.delete(id));
  }
}

