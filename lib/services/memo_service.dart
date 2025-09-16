import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MemoService {
  MemoService();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/memos.json');
    if (!await f.exists()) {
      await f.create(recursive: true);
      await f.writeAsString(jsonEncode(<String, Map<String, String>>{}));
    }
    return f;
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _file();
      final txt = await f.readAsString();
      final json = jsonDecode(txt);
      if (json is Map<String, dynamic>) return json;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(data));
  }

  Future<String?> getMemo(String type, int id) async {
    final data = await _readAll();
    final typeMap = data[type];
    if (typeMap is Map<String, dynamic>) {
      final v = typeMap['$id'];
      if (v is String) return v;
    }
    return null;
  }

  Future<void> saveMemo(String type, int id, String? text) async {
    final data = await _readAll();
    final typeMap = (data[type] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    if (text != null && text.trim().isNotEmpty) {
      typeMap['$id'] = text.trim();
    } else {
      typeMap.remove('$id');
    }
    if (typeMap.isEmpty) {
      data.remove(type);
    } else {
      data[type] = typeMap;
    }
    await _writeAll(data);
  }
}

