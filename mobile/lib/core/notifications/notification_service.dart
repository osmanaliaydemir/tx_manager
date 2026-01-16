import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tx_manager_mobile/core/notifications/notification_router.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService I = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'tx_manager';
  static const String _channelName = 'TX Manager';
  static const String _channelDesc = 'Tweet scheduling notifications';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(
      tz.getLocation('UTC'),
    ); // schedule with absolute UTC time

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        NotificationRouter.handlePayload(response.payload);
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  int _stableId(String postId, int typeSalt) {
    // Deterministic int id derived from GUID string
    final hex = postId.replaceAll('-', '');
    final head = hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
    final base = int.tryParse(head, radix: 16) ?? 0;
    return (base & 0x7FFFFFFF) + typeSalt;
  }

  Future<void> scheduleReminder({
    required String postId,
    required DateTime scheduledForLocal,
    Duration remindBefore = const Duration(minutes: 5),
  }) async {
    await init();

    final now = DateTime.now();
    final fireLocal = scheduledForLocal.subtract(remindBefore);
    if (fireLocal.isBefore(now.add(const Duration(seconds: 10)))) {
      // Too late to remind
      return;
    }

    final fireUtc = fireLocal.toUtc();
    final when = tz.TZDateTime.from(fireUtc, tz.getLocation('UTC'));

    final id = _stableId(postId, 10);
    await _plugin.zonedSchedule(
      id,
      'Yayınlama yaklaşıyor',
      'Tweet 5 dk sonra yayınlanacak.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Avoid exact-alarm permission requirements; reminder doesn't need exact timing.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'reminder:$postId',
    );
  }

  Future<void> cancelReminder(String postId) async {
    await init();
    await _plugin.cancel(_stableId(postId, 10));
  }

  Future<void> notifyPublished({
    required String postId,
    required String content,
  }) async {
    await init();
    final id = _stableId(postId, 20);
    await _plugin.show(
      id,
      'Tweet yayınlandı',
      content,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'published:$postId',
    );
  }

  Future<void> notifyFailed({
    required String postId,
    required String content,
    String? failureCode,
  }) async {
    await init();
    final id = _stableId(postId, 30);
    final msg = failureCode != null && failureCode.isNotEmpty
        ? '$failureCode: $content'
        : content;
    await _plugin.show(
      id,
      'Tweet başarısız',
      msg,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'failed:$postId',
    );
  }
}
