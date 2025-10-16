import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PrefsService {
  PrefsService();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/prefs.json');
    if (!await f.exists()) {
      await f.create(recursive: true);
      await f.writeAsString(jsonEncode(<String, dynamic>{}));
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

  // Walkthrough
  Future<bool> getWalkthroughSeen() async {
    final data = await _readAll();
    final v = data['walkthroughSeen'];
    return v is bool ? v : false;
  }

  Future<void> setWalkthroughSeen(bool seen) async {
    final data = await _readAll();
    data['walkthroughSeen'] = seen;
    await _writeAll(data);
  }
}

