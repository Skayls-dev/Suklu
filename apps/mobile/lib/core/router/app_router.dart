import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_tutor/presentation/ai_tutor_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/dashboard/presentation/parent_dashboard.dart';
import '../../features/dashboard/presentation/student_dashboard.dart';
import '../../features/dashboard/presentation/tutor_dashboard.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/payments/presentation/payment_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/sessions/presentation/session_screen.dart';
import 'route_guards.dart';

// ─────────────────────────────────────────────────────────────────────────────
// routerProvider
//
// GoRouter instance that refreshes whenever the auth state changes.
// Role-based navigation is handled by the redirect callback.
// ─────────────────────────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) => routeGuard(ref, state),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/splash',   builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // ── Student shell ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(path: '/student/dashboard', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/student/booking',   builder: (_, __) => const BookingScreen()),
          GoRoute(
            path: '/student/session/:sessionId',
            builder: (_, s) => SessionScreen(sessionId: s.pathParameters['sessionId']!),
          ),
          GoRoute(path: '/student/ai-tutor',  builder: (_, __) => const AiTutorScreen()),
          GoRoute(path: '/student/progress',  builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/student/payment',   builder: (_, __) => const PaymentScreen()),
        ],
      ),

      // ── Tutor shell ────────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _TutorShell(child: child),
        routes: [
          GoRoute(path: '/tutor/dashboard', builder: (_, __) => const TutorDashboard()),
          GoRoute(
            path: '/tutor/session/:sessionId',
            builder: (_, s) => SessionScreen(sessionId: s.pathParameters['sessionId']!),
          ),
        ],
      ),

      // ── Parent shell ───────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _ParentShell(child: child),
        routes: [
          GoRoute(path: '/parent/dashboard', builder: (_, __) => const ParentDashboard()),
          GoRoute(path: '/parent/booking',   builder: (_, __) => const BookingScreen()),
          GoRoute(path: '/parent/payment',   builder: (_, __) => const PaymentScreen()),
          GoRoute(path: '/parent/progress',  builder: (_, __) => const ProgressScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error?.message),
  );
});

// ─── Minimal shell widgets (nav bars added per role) ─────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error, super.key});
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Erreur de navigation: $error')),
  );
}

class _StudentShell extends StatelessWidget {
  const _StudentShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}

class _TutorShell extends StatelessWidget {
  const _TutorShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}

class _ParentShell extends StatelessWidget {
  const _ParentShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
