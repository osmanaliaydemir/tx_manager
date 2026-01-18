import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum OutboxActionType {
  createPost,
  createThread,
  updatePost,
  deletePost,
  cancelSchedule,
  acceptSuggestion,
  rejectSuggestion,
}

class OutboxAction {
  final String id;
  final String idempotencyKey;
  final OutboxActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAtUtc;
  final int retryCount;
  final DateTime nextAttemptAtUtc;
  final DateTime? lastAttemptAtUtc;
  final String? lastError;
  final bool isDeadLettered;

  OutboxAction({
    required this.id,
    required this.idempotencyKey,
    required this.type,
    required this.payload,
    required this.createdAtUtc,
    required this.retryCount,
    required this.nextAttemptAtUtc,
    required this.lastAttemptAtUtc,
    required this.lastError,
    required this.isDeadLettered,
  });

  OutboxAction copyWith({
    int? retryCount,
    DateTime? nextAttemptAtUtc,
    DateTime? lastAttemptAtUtc,
    String? lastError,
    bool? isDeadLettered,
  }) {
    return OutboxAction(
      id: id,
      idempotencyKey: idempotencyKey,
      type: type,
      payload: payload,
      createdAtUtc: createdAtUtc,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
      lastAttemptAtUtc: lastAttemptAtUtc ?? this.lastAttemptAtUtc,
      lastError: lastError ?? this.lastError,
      isDeadLettered: isDeadLettered ?? this.isDeadLettered,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'idempotencyKey': idempotencyKey,
    'type': type.name,
    'payload': payload,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'retryCount': retryCount,
    'nextAttemptAtUtc': nextAttemptAtUtc.toIso8601String(),
    'lastAttemptAtUtc': lastAttemptAtUtc?.toIso8601String(),
    'lastError': lastError,
    'isDeadLettered': isDeadLettered,
  };

  static OutboxAction fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] ?? '').toString();
    final type = OutboxActionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => OutboxActionType.createPost,
    );

    return OutboxAction(
      id: (json['id'] ?? '').toString(),
      idempotencyKey: (json['idempotencyKey'] ?? '').toString(),
      type: type,
      payload: Map<String, dynamic>.from((json['payload'] ?? {}) as Map),
      createdAtUtc:
          DateTime.tryParse((json['createdAtUtc'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      retryCount: (json['retryCount'] as int?) ?? 0,
      nextAttemptAtUtc:
          DateTime.tryParse((json['nextAttemptAtUtc'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      lastAttemptAtUtc: DateTime.tryParse(
        (json['lastAttemptAtUtc'] ?? '').toString(),
      ),
      lastError: (json['lastError'] ?? '').toString().isEmpty
          ? null
          : (json['lastError'] ?? '').toString(),
      isDeadLettered: (json['isDeadLettered'] as bool?) ?? false,
    );
  }
}

class OutboxStore {
  static const _fileName = 'tx_outbox.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<OutboxAction>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) return [];
      final list = (jsonDecode(txt) as List).cast<dynamic>();
      return list
          .whereType<Map>()
          .map((e) => OutboxAction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<OutboxAction> items) async {
    final f = await _file();
    final txt = jsonEncode(items.map((e) => e.toJson()).toList());
    await f.writeAsString(txt, flush: true);
  }

  Future<void> clear() async {
    await save(const []);
  }

  Future<void> removeById(String id) async {
    final items = await load();
    await save(items.where((x) => x.id != id).toList());
  }
}

class OutboxProcessor {
  final OutboxStore _store;
  bool _flushing = false;
  static const int maxRetriesBeforeDeadLetter = 20;

  OutboxProcessor(this._store);

  String newIdempotencyKey() {
    final rand = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch;
    final b = rand.nextInt(1 << 32);
    final c = rand.nextInt(1 << 32);
    return '$a-$b-$c';
  }

  String _newId() =>
      'obx-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Duration _backoff(int retryCount) {
    // 1s, 2s, 4s ... capped 5m + jitter
    final base = min(300, 1 << min(8, retryCount)); // seconds
    final jitter = Random.secure().nextInt(500); // ms
    return Duration(seconds: base) + Duration(milliseconds: jitter);
  }

  Future<void> enqueue(
    OutboxActionType type,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final now = DateTime.now().toUtc();
    final key = (idempotencyKey ?? payload['idempotencyKey']?.toString().trim())
        .toString();
    final effectiveKey = key.isNotEmpty ? key : newIdempotencyKey();

    // Keep payload consistent for executors.
    payload['idempotencyKey'] = effectiveKey;

    final action = OutboxAction(
      id: _newId(),
      idempotencyKey: effectiveKey,
      type: type,
      payload: payload,
      createdAtUtc: now,
      retryCount: 0,
      nextAttemptAtUtc: now,
      lastAttemptAtUtc: null,
      lastError: null,
      isDeadLettered: false,
    );

    final items = await _store.load();
    await _store.save([action, ...items]);
  }

  Future<void> flushBestEffort({
    required Future<void> Function(OutboxAction action) execute,
  }) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final now = DateTime.now().toUtc();
      var items = await _store.load();
      if (items.isEmpty) return;

      // Process oldest-first for predictability.
      items.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));

      final remaining = <OutboxAction>[];
      for (final item in items) {
        if (item.nextAttemptAtUtc.isAfter(now)) {
          remaining.add(item);
          continue;
        }
        if (item.isDeadLettered) {
          remaining.add(item);
          continue;
        }

        try {
          await execute(item);
          // success: drop it
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final err = status != null ? 'HTTP $status' : (e.type.toString());

          // If it's a permanent-ish client error, dead-letter instead of looping.
          final isPermanent4xx =
              status != null &&
              status >= 400 &&
              status < 500 &&
              status != 409 &&
              status != 429;

          final next = item.retryCount + 1;
          final shouldDeadLetter =
              isPermanent4xx || next >= maxRetriesBeforeDeadLetter;

          final updated = item.copyWith(
            retryCount: next,
            lastAttemptAtUtc: now,
            lastError: err,
            isDeadLettered: shouldDeadLetter,
            nextAttemptAtUtc: shouldDeadLetter
                ? now.add(const Duration(days: 3650))
                : now.add(_backoff(next)),
          );
          remaining.add(updated);
        } catch (_) {
          // non-network: also backoff (MVP). Later we can dead-letter.
          final next = item.retryCount + 1;
          final shouldDeadLetter = next >= maxRetriesBeforeDeadLetter;
          final updated = item.copyWith(
            retryCount: next,
            lastAttemptAtUtc: now,
            lastError: 'UNKNOWN_ERROR',
            isDeadLettered: shouldDeadLetter,
            nextAttemptAtUtc: shouldDeadLetter
                ? now.add(const Duration(days: 3650))
                : now.add(_backoff(next)),
          );
          remaining.add(updated);
        }
      }

      await _store.save(remaining);
    } finally {
      _flushing = false;
    }
  }

  Future<void> retryOne({
    required String actionId,
    required Future<void> Function(OutboxAction action) execute,
  }) async {
    final now = DateTime.now().toUtc();
    final items = await _store.load();
    final idx = items.indexWhere((x) => x.id == actionId);
    if (idx < 0) return;

    final item = items[idx];
    // If dead-lettered, allow manual retry anyway.
    if (!item.isDeadLettered && item.nextAttemptAtUtc.isAfter(now)) return;

    try {
      await execute(item);
      // success: remove
      final remaining = items.where((x) => x.id != actionId).toList();
      await _store.save(remaining);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final err = status != null ? 'HTTP $status' : (e.type.toString());
      final next = item.retryCount + 1;
      final updated = item.copyWith(
        retryCount: next,
        lastAttemptAtUtc: now,
        lastError: err,
        isDeadLettered: false,
        nextAttemptAtUtc: now.add(_backoff(next)),
      );
      final newItems = [...items]..[idx] = updated;
      await _store.save(newItems);
    } catch (_) {
      final next = item.retryCount + 1;
      final updated = item.copyWith(
        retryCount: next,
        lastAttemptAtUtc: now,
        lastError: 'UNKNOWN_ERROR',
        isDeadLettered: false,
        nextAttemptAtUtc: now.add(_backoff(next)),
      );
      final newItems = [...items]..[idx] = updated;
      await _store.save(newItems);
    }
  }
}

final outboxStoreProvider = Provider<OutboxStore>((ref) => OutboxStore());
final outboxProcessorProvider = Provider<OutboxProcessor>(
  (ref) => OutboxProcessor(ref.read(outboxStoreProvider)),
);

final outboxCountProvider = StreamProvider<int>((ref) async* {
  final store = ref.read(outboxStoreProvider);
  int? last;

  // Emit immediately
  final first = (await store.load()).length;
  last = first;
  yield first;

  // Poll (MVP). Later we can migrate to DB stream or event-driven updates.
  await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
    final count = (await store.load()).length;
    if (count != last) {
      last = count;
      yield count;
    }
  }
});

final outboxItemsProvider = StreamProvider<List<OutboxAction>>((ref) async* {
  final store = ref.read(outboxStoreProvider);
  String? lastHash;

  // Emit immediately
  final first = await store.load();
  lastHash = jsonEncode(first.map((e) => e.toJson()).toList());
  yield first;

  await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
    final items = await store.load();
    final hash = jsonEncode(items.map((e) => e.toJson()).toList());
    if (hash != lastHash) {
      lastHash = hash;
      yield items;
    }
  }
});
