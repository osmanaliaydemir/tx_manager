import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/router/app_router.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tx_manager_mobile/l10n/app_localizations.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/notifications/push_registration_service.dart';

import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SECURITY: never bypass TLS certificate validation in release builds.
  if (!kReleaseMode) {
    HttpOverrides.global = MyHttpOverrides();
  }
  await NotificationService.I.init();
  // Best-effort: registers FCM token if Firebase is configured.
  await PushRegistrationService.I.initAndRegisterBestEffort();
  runApp(const ProviderScope(child: TXManagerApp()));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class TXManagerApp extends ConsumerWidget {
  const TXManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TX Asistan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
    );
  }
}
