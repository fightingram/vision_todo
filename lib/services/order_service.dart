import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OrderService {
  OrderService();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/orders.json');
    if (!await f.exists()) {
      await f.create(recursive: true);
      await f.writeAsString(jsonEncode(<String, List<int>>{}));
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

  Future<List<int>> getOrder(String key) async {
    final data = await _readAll();
    final v = data[key];
    if (v is List) {
      return v.whereType<num>().map((e) => e.toInt()).toList();
    }
    return <int>[];
  }

  Future<void> setOrder(String key, List<int> ids) async {
    final data = await _readAll();
    data[key] = ids;
    await _writeAll(data);
  }
}

