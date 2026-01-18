import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/data/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/notifications/push_registration_service.dart';

class AuthWebView extends ConsumerStatefulWidget {
  const AuthWebView({super.key});

  @override
  ConsumerState<AuthWebView> createState() => _AuthWebViewState();
}

class _AuthWebViewState extends ConsumerState<AuthWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('txmanager://')) {
              final uri = Uri.parse(request.url);

              if (uri.host == 'auth-success') {
                final token = uri.queryParameters['token'];
                final hasStrategyText =
                    uri.queryParameters['hasStrategy'] ?? '';
                final hasStrategy =
                    hasStrategyText.toLowerCase() == 'true' ||
                    hasStrategyText == '1';

                if (token != null && token.isNotEmpty) {
                  _handleSuccess(token, hasStrategy);
                  return NavigationDecision.prevent;
                }
              } else if (uri.host == 'auth-error') {
                // Handle error
                final msg = uri.queryParameters['message'];
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Auth Error: $msg")));
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConstants.loginUrl));
  }

  Future<void> _handleSuccess(String jwt, bool hasStrategy) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'auth_token', value: jwt);

    // Best-effort: store client timezone on backend for future calendar/UX
    final tzName = DateTime.now().timeZoneName;
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    await ref
        .read(userRepositoryProvider)
        .updateTimezone(
          timeZoneName: tzName,
          timeZoneOffsetMinutes: tzOffsetMinutes,
        );

    // Best-effort: now that user is logged in, register push token (FCM) if configured.
    await PushRegistrationService.I.initAndRegisterBestEffort();

    if (mounted) {
      if (hasStrategy) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("X Login")),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
