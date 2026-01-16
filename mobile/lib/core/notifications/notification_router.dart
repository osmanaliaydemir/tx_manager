import 'package:tx_manager_mobile/core/router/app_router.dart';

class NotificationRouter {
  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final postId = parts.sublist(1).join(':');

    if (type == 'reminder') {
      appRouter.go('/approval?postId=$postId');
      return;
    }

    // For published/failed, land on home.
    if (type == 'published' || type == 'failed') {
      appRouter.go('/home');
    }
  }
}
