import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/dream.dart';
import '../models/long_term.dart';
import '../models/short_term.dart';
import '../models/task.dart';
import '../models/tag.dart';

class IsarService {
  Isar? _isar;
  Isar get isar => _isar!;

  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DreamSchema, LongTermSchema, ShortTermSchema, TaskSchema, TagSchema],
      directory: dir.path,
      inspector: false,
    );
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
