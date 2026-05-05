import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

// ─────────────────────────────────────────────────────────────────────────────
// authStateNotifierProvider
//
// Wraps the auth state stream in an AsyncNotifier.
// GoRouter uses the notifier as a ChangeNotifier (via ChangeNotifierAdapter)
// to refresh routes when auth state changes.
// ─────────────────────────────────────────────────────────────────────────────
final authStateNotifierProvider =
    AsyncNotifierProvider<AuthStateNotifier, AuthUser?>(() {
  return AuthStateNotifier();
});

class AuthStateNotifier extends AsyncNotifier<AuthUser?>
    with ChangeNotifier {
  @override
  Future<AuthUser?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    // Subscribe to the auth stream; each emission rebuilds this provider
    ref.listen(
      authStreamProvider,
      (_, next) {
        state = next;
        notifyListeners(); // tells GoRouter to re-evaluate routes
      },
    );
    return repo.currentUser();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmail(
        email: email, password: password,
      ),
    );
    notifyListeners();
  }

  Future<void> register(String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).registerWithEmail(
        email: email, password: password, displayName: displayName,
      ),
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
    notifyListeners();
  }
}

// Internal stream provider — converts the Firestore-enriched auth stream
final authStreamProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
