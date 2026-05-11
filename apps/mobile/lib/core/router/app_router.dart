import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_tutor/presentation/ai_tutor_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/admin_access_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/phone_login_screen.dart';
import '../constants/app_colors.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/booking_detail_screen.dart';
import '../../features/booking/presentation/tutor_agenda_screen.dart';
import '../../features/booking/domain/booking_model.dart';
import '../../features/dashboard/presentation/parent_dashboard.dart';
import '../../features/dashboard/presentation/student_dashboard.dart';
import '../../features/dashboard/presentation/tutor_dashboard.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/marketplace/presentation/tutor_detail_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/diagnostic_screen.dart';
import '../../features/parent_linking/presentation/link_request_screen.dart';
import '../../features/payments/presentation/payment_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/sessions/presentation/session_screen.dart';
import '../widgets/offline_banner.dart';
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
      GoRoute(path: '/login',       builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/phone-login', builder: (_, __) => const PhoneLoginScreen()),
      GoRoute(path: '/register',    builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/admin-access', builder: (_, __) => const AdminAccessScreen()),
      GoRoute(path: '/onboarding',  builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/diagnostic',  builder: (_, __) => const DiagnosticScreen()),

      // ── Student shell ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(path: '/student/dashboard', builder: (_, __) => const StudentDashboard()),
          GoRoute(
            path: '/student/booking',
            builder: (_, s) {
              final extra = s.extra as Map<String, dynamic>?;
              return BookingScreen(
                initialTutorId: extra?['tutorId'] as String?,
                initialSubjectId: extra?['subjectId'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/student/marketplace',
            builder: (_, s) => MarketplaceScreen(
              initialSubjectId: s.uri.queryParameters['subjectId'],
            ),
          ),
          GoRoute(
            path: '/student/marketplace/:tutorId',
            builder: (_, s) => TutorDetailScreen(
              tutorId: s.pathParameters['tutorId']!,
            ),
          ),
          GoRoute(
            path: '/student/booking/:id',
            builder: (_, s) => BookingDetailScreen(
              bookingId: s.pathParameters['id']!,
              booking: s.extra as BookingModel?,
            ),
          ),
          GoRoute(
            path: '/student/session/:bookingId',
            builder: (_, s) => SessionScreen(bookingId: s.pathParameters['bookingId']!),
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
          GoRoute(path: '/tutor/booking', builder: (_, __) => const TutorAgendaScreen()),
          GoRoute(
            path: '/tutor/booking/:id',
            builder: (_, s) => BookingDetailScreen(
              bookingId: s.pathParameters['id']!,
              booking: s.extra as BookingModel?,
            ),
          ),
          GoRoute(path: '/tutor/ai-tutor', builder: (_, __) => const AiTutorScreen()),
          GoRoute(
            path: '/tutor/session/:bookingId',
            builder: (_, s) => SessionScreen(bookingId: s.pathParameters['bookingId']!),
          ),
        ],
      ),

      // ── Parent shell ───────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _ParentShell(child: child),
        routes: [
          GoRoute(path: '/parent/dashboard', builder: (_, __) => const ParentDashboard()),
          GoRoute(path: '/parent/booking',   builder: (_, __) => const BookingScreen()),
          GoRoute(
            path: '/parent/booking/:id',
            builder: (_, s) => BookingDetailScreen(
              bookingId: s.pathParameters['id']!,
              booking: s.extra as BookingModel?,
            ),
          ),
          GoRoute(path: '/parent/payment',   builder: (_, __) => const PaymentScreen()),
          GoRoute(path: '/parent/progress',  builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/parent/link-request', builder: (_, __) => const LinkRequestScreen()),
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
  const _ErrorScreen({this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Erreur de navigation: $error')),
  );
}

class _StudentShell extends ConsumerWidget {
  const _StudentShell({required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/student/booking'))   return 1;
    if (loc.startsWith('/student/marketplace')) return 2;
    if (loc.startsWith('/student/ai-tutor'))  return 3;
    if (loc.startsWith('/student/progress'))  return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/student/dashboard'); break;
            case 1: context.go('/student/booking');   break;
            case 2: context.go('/student/marketplace'); break;
            case 3: context.go('/student/ai-tutor');  break;
            case 4: context.go('/student/progress');  break;
            case 5:
              showModalBottomSheet(
                context: context,
                builder: (_) => _ProfileSheet(ref: ref),
              );
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),       selectedIcon: Icon(Icons.home),       label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Cours'),
          NavigationDestination(icon: Icon(Icons.search_outlined),     selectedIcon: Icon(Icons.search),     label: 'Tuteurs'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined),  selectedIcon: Icon(Icons.smart_toy),  label: 'IA'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),  selectedIcon: Icon(Icons.bar_chart),  label: 'Progrès'),
          NavigationDestination(icon: Icon(Icons.person_outline),      selectedIcon: Icon(Icons.person),     label: 'Profil'),
        ],
      ),
    );
  }
}

class _TutorShell extends ConsumerWidget {
  const _TutorShell({required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tutor/booking'))   return 1;
    if (loc.startsWith('/tutor/ai-tutor'))  return 2;
    if (loc.startsWith('/tutor/session'))   return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.tutorAccent.withValues(alpha: 0.08),
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/tutor/dashboard'); break;
            case 1: context.go('/tutor/booking');   break;
            case 2: context.go('/tutor/ai-tutor');  break;
            case 3:
              showModalBottomSheet(
                context: context,
                builder: (_) => _ProfileSheet(ref: ref),
              );
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),       selectedIcon: Icon(Icons.home),        label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined),  selectedIcon: Icon(Icons.smart_toy),   label: 'IA Tuteur'),
          NavigationDestination(icon: Icon(Icons.person_outline),      selectedIcon: Icon(Icons.person),      label: 'Profil'),
        ],
      ),
    );
  }
}

class _ParentShell extends ConsumerWidget {
  const _ParentShell({required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/parent/booking'))  return 1;
    if (loc.startsWith('/parent/progress')) return 2;
    if (loc.startsWith('/parent/payment'))  return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/parent/dashboard'); break;
            case 1: context.go('/parent/booking');   break;
            case 2: context.go('/parent/progress');  break;
            case 3: context.go('/parent/payment');   break;
            case 4:
              showModalBottomSheet(
                context: context,
                builder: (_) => _ProfileSheet(ref: ref),
              );
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),       selectedIcon: Icon(Icons.home),       label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Cours'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),  selectedIcon: Icon(Icons.bar_chart),  label: 'Progrès'),
          NavigationDestination(icon: Icon(Icons.payment_outlined),    selectedIcon: Icon(Icons.payment),    label: 'Paiements'),
          NavigationDestination(icon: Icon(Icons.person_outline),      selectedIcon: Icon(Icons.person),     label: 'Profil'),
        ],
      ),
    );
  }
}

// ─── Profile / Sign-out bottom sheet ─────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authStateNotifierProvider).value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                (user?.displayName ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(user?.displayName ?? '', style: Theme.of(context).textTheme.titleMedium),
            Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authStateNotifierProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
