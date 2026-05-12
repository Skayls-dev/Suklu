import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fcm_token_service.dart';
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
    _saveFcmTokenIfAuthenticated();
    notifyListeners();
  }

  Future<void> register(String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).registerWithEmail(
        email: email, password: password, displayName: displayName,
      ),
    );
    _saveFcmTokenIfAuthenticated();
    notifyListeners();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
    _saveFcmTokenIfAuthenticated();
    notifyListeners();
  }

  Future<dynamic> sendPhoneOtp(String phoneNumber) {
    return ref.read(authRepositoryProvider).sendPhoneOtp(phoneNumber);
  }

  Future<void> verifyPhoneOtp({
    required dynamic confirmationResult,
    required String smsCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyPhoneOtp(
        confirmationResult: confirmationResult,
        smsCode:            smsCode,
      ),
    );
    _saveFcmTokenIfAuthenticated();
    notifyListeners();
  }

  /// Uploads [imageBytes] to Firebase Storage and updates the profile photo URL.
  /// Returns the new download URL.
  Future<String> uploadProfilePhoto({
    required Uint8List imageBytes,
    required String extension,
  }) async {
    final uid = state.value?.uid;
    if (uid == null) throw Exception('Non authentifié');

    final url = await ref.read(authRepositoryProvider).uploadProfilePhoto(
      uid: uid,
      imageBytes: imageBytes,
      extension: extension,
    );

    // Update local state with new photoUrl
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(photoUrl: url));
      notifyListeners();
    }

    return url;
  }

  void _saveFcmTokenIfAuthenticated() {    if (kIsWeb) {
      return;
    }

    final uid = state.value?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    unawaited(
      ref.read(fcmTokenServiceProvider).initAndSave(uid).catchError((Object error) {
        debugPrint('FCM token init failed after auth: $error');
      }),
    );
  }
}

// Internal stream provider — converts the Firestore-enriched auth stream
final authStreamProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
