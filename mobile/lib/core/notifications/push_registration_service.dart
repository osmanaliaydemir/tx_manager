import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/data/repositories/notifications_repository.dart';
import 'package:tx_manager_mobile/core/notifications/notification_router.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';

class PushRegistrationService {
  PushRegistrationService._();
  static final PushRegistrationService I = PushRegistrationService._();

  static const _kFcmTokenKey = 'fcm_token';
  static const _kFcmPlatformKey = 'fcm_platform';

  bool _firebaseInitTried = false;
  bool _firebaseReady = false;
  bool _listenersAttached = false;

  Future<void> initAndRegisterBestEffort() async {
    // IMPORTANT:
    // This can be called multiple times (app start, after login, on resume).
    // Do NOT short-circuit permanently if user is not logged in yet.

    // If not logged in yet, do nothing.
    const storage = FlutterSecureStorage();
    final jwt = await storage.read(key: 'auth_token');
    if (jwt == null || jwt.isEmpty) return;

    final ok = await _ensureFirebaseReady();
    if (!ok) return;

    await _attachListenersOnce();
    await _registerCurrentTokenBestEffort();
  }

  Future<void> unregisterBestEffort() async {
    const storage = FlutterSecureStorage();
    final jwt = await storage.read(key: 'auth_token');
    if (jwt == null || jwt.isEmpty) return;

    final ok = await _ensureFirebaseReady();
    if (!ok) return;

    final stored = await storage.read(key: _kFcmTokenKey);
    final token = stored ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final repo = NotificationsRepository();
      await repo.unregisterDeviceToken(token: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM unregister failed (ignored): $e');
      }
    } finally {
      // Clear local cache regardless.
      await storage.delete(key: _kFcmTokenKey);
      await storage.delete(key: _kFcmPlatformKey);
    }
  }

  Future<bool> _ensureFirebaseReady() async {
    if (_firebaseInitTried) return _firebaseReady;
    _firebaseInitTried = true;

    // Firebase init can fail if google-services.json / GoogleService-Info.plist
    // are not configured yet. We treat it as optional.
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      _firebaseReady = false;
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp failed (ignored): $e');
      }
    }
    return _firebaseReady;
  }

  Future<void> _attachListenersOnce() async {
    if (_listenersAttached) return;
    _listenersAttached = true;

    try {
      // If app was opened from terminated state via a notification tap.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleOpenedMessage(initial);
      }

      // If app was in background and opened via a notification tap.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      // Foreground: show a local notification so user sees it.
      FirebaseMessaging.onMessage.listen((m) async {
        final data = m.data;
        final type = (data['type'] ?? '').toString();
        final postId = (data['postId'] ?? '').toString();
        final title = m.notification?.title ?? '';
        final body = m.notification?.body ?? '';

        if (type == 'published' && postId.isNotEmpty) {
          await NotificationService.I.notifyPublished(
            postId: postId,
            content: body.isNotEmpty ? body : 'Tweet yayınlandı.',
          );
          return;
        }
        if (type == 'failed' && postId.isNotEmpty) {
          await NotificationService.I.notifyFailed(
            postId: postId,
            content: body.isNotEmpty ? body : 'Tweet başarısız.',
          );
          return;
        }

        // fallback: show a generic local notification if title/body exists
        if (title.isNotEmpty || body.isNotEmpty) {
          // Reuse reminder route format: generic -> home
          await NotificationService.I.init();
          // show via notifyPublished/Failed isn't correct; keep minimal: route on tap only
        }
      });

      // Token rotation: keep backend in sync.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _registerTokenBestEffort(newToken);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM listeners attach failed (ignored): $e');
      }
    }
  }

  String _platformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'Ios';
    return 'Unknown';
  }

  Future<void> _registerCurrentTokenBestEffort() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _registerTokenBestEffort(token);
  }

  Future<void> _registerTokenBestEffort(String fcmToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request permission (iOS + Android 13+)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final platform = _platformName();

      // Use repo directly (it will read JWT from storage)
      final repo = NotificationsRepository();
      await repo.registerDeviceToken(token: fcmToken, platform: platform);

      const storage = FlutterSecureStorage();
      await storage.write(key: _kFcmTokenKey, value: fcmToken);
      await storage.write(key: _kFcmPlatformKey, value: platform);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token registration failed (ignored): $e');
      }
    }
  }

  void _handleOpenedMessage(RemoteMessage m) {
    final data = m.data;
    final type = (data['type'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString();

    // Align with local notification routing
    if (type == 'published' && postId.isNotEmpty) {
      NotificationRouter.handlePayload('published:$postId');
      return;
    }
    if (type == 'failed' && postId.isNotEmpty) {
      NotificationRouter.handlePayload('failed:$postId');
      return;
    }
    if (type == 'suggestions_ready') {
      // Land on suggestions tab (we only have route to /home; tab index is local state)
      NotificationRouter.handlePayload('published:'); // routes /home
      return;
    }

    // fallback
    NotificationRouter.handlePayload('published:'); // routes /home
  }
}
