import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tx_manager_mobile/data/models/tweet_template_model.dart';

class TweetTemplatesStorage {
  static const String _fileName = 'tweet_templates.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<TweetTemplateModel>> loadTemplates() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final contents = await file.readAsString();
      if (contents.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList
          .map((j) => TweetTemplateModel.fromJson(j as Map<String, dynamic>))
          .where((t) => t.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error loading templates: $e');
      return [];
    }
  }

  Future<void> saveTemplates(List<TweetTemplateModel> templates) async {
    final file = await _getFile();
    final jsonList = templates.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> addTemplate(TweetTemplateModel template) async {
    final templates = await loadTemplates();
    templates.insert(0, template);
    await saveTemplates(templates);
  }

  Future<void> deleteTemplate(String id) async {
    final templates = await loadTemplates();
    templates.removeWhere((t) => t.id == id);
    await saveTemplates(templates);
  }
}
