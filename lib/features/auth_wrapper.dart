import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_s.dart';
import 'auth.dart';
import 'home.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

// This state manages app lifecycle to re-trigger biometric lock when app resumes.
class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().checkBiometrics();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = context.read<AuthService>();
    if (authProvider.isAuthenticated && state == AppLifecycleState.resumed) {
      // If an auth flow (biometric prompt) is running, skip locking to avoid the
      // pause/resume race. Also skip if unlocked very recently.
      if (!authProvider.authInProgress &&
          !authProvider.wasUnlockedRecently(const Duration(seconds: 3))) {
        authProvider.lockApp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthService>();

    if (!authProvider.isAuthenticated) {
      // If user is not logged in via Firebase, show the login screen.
      return const LoginScreen();
    }

    if (authProvider.isCheckingBiometrics) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.isAppLocked && authProvider.canCheckBiometrics) {
      return Scaffold(
        backgroundColor: Colors.teal.shade900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated lock icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1 + (0.1 * value),
                    child: Icon(
                      Icons.lock,
                      size: 80,
                      color: Colors.tealAccent.shade100,
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // Title
              Text(
                'Vault Locked',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent.shade100,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use biometrics to unlock your vault',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.tealAccent.shade100.withValues(alpha: 0.8),
                ),
              ),

              const SizedBox(height: 40),

              // Shiny fingerprint button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.shade100,
                  foregroundColor: Colors.teal.shade900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 6,
                  shadowColor: Colors.tealAccent.shade100.withValues(
                    alpha: 0.6,
                  ),
                ),
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text(
                  'Unlock with Biometrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await authProvider.authenticateWithBiometrics();
                },
              ),
            ],
          ),
        ),
      );
    }

    // If authenticated and unlocked, show the home screen.
    return const HomeScreen();
  }
}
