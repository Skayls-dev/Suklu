import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// routeGuard
//
// Called on every navigation attempt by GoRouter's redirect callback.
// Returns null to allow navigation, or a path string to redirect.
// ─────────────────────────────────────────────────────────────────────────────
String? routeGuard(Ref ref, GoRouterState state) {
  final authState = ref.read(authStateNotifierProvider);
  final location  = state.uri.path;

  final isLoading     = authState.isLoading;
  final isLoggedIn    = authState.value != null;
  final role          = authState.value?.role;

  if (isLoading) return location == '/splash' ? null : '/splash';

  final isAuthRoute = location == '/login' ||
      location == '/register';

  // ── On splash but auth resolved → redirect appropriately ─────────────────
  if (location == '/splash') {
    if (!isLoggedIn) return '/login';
    return _homeForRole(role?.toFirestoreString());
  }

  // ── Not logged in: send to login ──────────────────────────────────────────
  if (!isLoggedIn && !isAuthRoute) return '/login';

  // ── Logged in: skip auth routes ───────────────────────────────────────────
  if (isLoggedIn && isAuthRoute) {
    return _homeForRole(role?.toFirestoreString());
  }

  // ── Role-based route protection ────────────────────────────────────────────
  if (isLoggedIn && role != null) {
    final roleStr        = role.toFirestoreString();
    final inStudentRoute = location.startsWith('/student');
    final inTutorRoute   = location.startsWith('/tutor');
    final inParentRoute  = location.startsWith('/parent');

    if (inStudentRoute && roleStr != 'student')            return _homeForRole(roleStr);
    if (inTutorRoute   && roleStr != 'tutor')              return _homeForRole(roleStr);
    if (inParentRoute  && roleStr != 'parent')             return _homeForRole(roleStr);
  }

  return null; // Allow
}

String? _homeForRole(String? role) => switch (role) {
  'student'        => '/student/dashboard',
  'tutor'          => '/tutor/dashboard',
  'parent'         => '/parent/dashboard',
  'academic_staff' => '/student/dashboard', // TODO: staff dashboard
  'super_admin'    => '/student/dashboard', // TODO: admin panel route
  _                => '/onboarding',
};
