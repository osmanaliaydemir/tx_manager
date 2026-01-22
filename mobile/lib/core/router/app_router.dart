import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_manager_mobile/presentation/auth/login_screen.dart';
import 'package:tx_manager_mobile/presentation/auth/auth_webview.dart';
import 'package:tx_manager_mobile/presentation/tweet/tweet_screen.dart';
import 'package:tx_manager_mobile/presentation/splash/splash_screen.dart';

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
    GoRoute(path: '/home', builder: (context, state) => const TweetScreen()),
  ],
);
