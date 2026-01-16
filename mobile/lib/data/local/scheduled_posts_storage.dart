import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:tx_manager_mobile/data/models/scheduled_post_model.dart';

class ScheduledPostsStorage {
  static const String _fileName = 'scheduled_posts.json';
  static const String _localPrefix = 'local-';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<ScheduledPostModel>> loadPosts() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList
          .map(
            (json) => ScheduledPostModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading scheduled posts: $e');
      return [];
    }
  }

  Future<void> savePosts(List<ScheduledPostModel> posts) async {
    try {
      final file = await _getFile();
      final jsonList = posts.map((post) => post.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving scheduled posts: $e');
      rethrow;
    }
  }

  Future<void> clearPosts() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing scheduled posts: $e');
    }
  }

  Future<void> upsertLocal({
    required String id,
    required String content,
    required DateTime scheduledForLocal,
  }) async {
    final now = DateTime.now();
    final post = ScheduledPostModel(
      id: id,
      content: content,
      scheduledFor: scheduledForLocal,
      createdAt: now,
      status: '1',
    );

    final existing = await loadPosts();
    final updated = [post, ...existing.where((p) => p.id != id)];
    await savePosts(updated);
  }

  Future<void> removeById(String id) async {
    final existing = await loadPosts();
    final updated = existing.where((p) => p.id != id).toList();
    await savePosts(updated);
  }

  Future<void> mergeRemote(List<ScheduledPostModel> remote) async {
    // Keep local-only optimistic items until they are explicitly removed.
    final existing = await loadPosts();
    final localOnly = existing
        .where((p) => p.id.startsWith(_localPrefix))
        .toList();

    final merged = [
      ...localOnly,
      ...remote.where((r) => !localOnly.any((l) => l.id == r.id)),
    ];
    await savePosts(merged);
  }
}
