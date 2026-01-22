import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_manager_mobile/presentation/auth/login_screen.dart';
import 'package:tx_manager_mobile/presentation/auth/auth_webview.dart';
import 'package:tx_manager_mobile/presentation/dashboard/dashboard_screen.dart';
import 'package:tx_manager_mobile/presentation/onboarding/onboarding_screen.dart';
import 'package:tx_manager_mobile/presentation/splash/splash_screen.dart';
import 'package:tx_manager_mobile/presentation/notifications/approval_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/auth_webview',
      builder: (context, state) => const AuthWebView(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/approval',
      builder: (context, state) {
        final postId = state.uri.queryParameters['postId'] ?? '';
        return ApprovalScreen(postId: postId);
      },
    ),
  ],
);
