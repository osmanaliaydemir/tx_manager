import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial delay for branding
    await Future.delayed(const Duration(seconds: 1));

    const storage = FlutterSecureStorage();
    final userId = await storage.read(key: 'auth_token');

    if (!mounted) return;

    if (userId != null) {
      // User is logged in.
      try {
        // We can't easily check strategy existence without an API call.
        // Let's assume Home, and if Home fails to load data due to missing strategy, it handles it?
        // Or simply: Go to Home. If user came back, they likely finished onboarding.
        // If not, Home will show empty state.

        // Let's try to be smart:
        // We check if we have a strategy saved locally or check via API?
        // Let's just go to /home for now to solve the immediate "login every time" issue.
        context.go('/home');
      } catch (e) {
        context.go('/login');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: 16),
            Text(
              "Asistan",
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
