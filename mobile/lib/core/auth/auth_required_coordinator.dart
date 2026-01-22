import 'package:flutter/foundation.dart';
import 'package:tx_manager_mobile/core/auth/auth_required_dialog.dart';
import 'package:tx_manager_mobile/core/router/app_router.dart';

class AuthRequiredCoordinator {
  AuthRequiredCoordinator._();
  static final AuthRequiredCoordinator I = AuthRequiredCoordinator._();

  bool _showing = false;
  DateTime? _lastShownAt;

  Future<void> handle({int? statusCode}) async {
    // Debounce: multiple parallel 401s can happen during refreshes.
    final now = DateTime.now();
    if (_showing) return;
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 3)) {
      return;
    }

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    _showing = true;
    _lastShownAt = now;
    try {
      final goLogin = await showAuthRequiredDialog(
        ctx,
        message:
            'Oturum süresi doldu (${statusCode ?? 401}). '
            'Devam etmek için tekrar giriş yapmalısın.',
      );
      if (goLogin) {
        // Navigate without needing a BuildContext.
        appRouter.push('/auth_webview');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthRequiredCoordinator.handle failed: $e');
      }
    } finally {
      _showing = false;
    }
  }
}
