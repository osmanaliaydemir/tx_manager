import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class NotifiedPostsStorage {
  static const String _fileName = 'notified_posts.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<Set<String>> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};
      final contents = await file.readAsString();
      if (contents.isEmpty) return {};
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((e) => e.toString()).toSet();
    } catch (e) {
      debugPrint('Error loading notified posts: $e');
      return {};
    }
  }

  Future<void> _save(Set<String> keys) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(keys.toList()));
  }

  Future<bool> has(String key) async {
    final keys = await _load();
    return keys.contains(key);
  }

  Future<void> add(String key) async {
    final keys = await _load();
    if (keys.add(key)) {
      await _save(keys);
    }
  }
}
