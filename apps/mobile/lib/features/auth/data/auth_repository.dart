import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/auth_user.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthRepository
//
// All Firebase Auth calls go through this class.
// Never expose FirebaseAuth directly to presentation layer.
// ─────────────────────────────────────────────────────────────────────────────
class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth      = auth,
        _firestore = firestore;

  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;

  // ── Auth state ─────────────────────────────────────────────────────────────
  Stream<AuthUser?> authStateChanges() {
    return _auth.idTokenChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _fetchProfile(firebaseUser.uid);
    });
  }

  Future<AuthUser?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _fetchProfile(firebaseUser.uid);
  }

  // ── Sign in ────────────────────────────────────────────────────────────────
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email:    email,
      password: password,
    );
    // Force token refresh so the latest custom claims (role) are available
    await credential.user!.getIdToken(true);
    return _fetchProfile(credential.user!.uid);
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email:    email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    // onUserCreate Cloud Function will create the Firestore profile.
    // Wait briefly to let the trigger complete before first fetch.
    await Future.delayed(const Duration(seconds: 2));
    await credential.user!.getIdToken(true);
    return _fetchProfile(credential.user!.uid);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    final signedInWithGoogle = _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;

    if (signedInWithGoogle) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Web requires a configured client ID for GoogleSignIn initialization.
        // FirebaseAuth.signOut is sufficient for non-Google sessions and as a fallback.
      }
    }
    await _auth.signOut();
  }

  // ── Password reset ─────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  Future<AuthUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Connexion Google annulée');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await userCred.user!.getIdToken(true);
    // Ensure Firestore profile exists (first Google sign-in)
    final doc = await _firestore.collection('users').doc(userCred.user!.uid).get();
    if (!doc.exists) {
      await Future.delayed(const Duration(seconds: 2)); // wait for onUserCreate trigger
      await userCred.user!.getIdToken(true);
    }
    return _fetchProfile(userCred.user!.uid);
  }

  // ── Phone: send OTP ────────────────────────────────────────────────────────
  Future<ConfirmationResult> sendPhoneOtp(String phoneNumber) {
    return _auth.signInWithPhoneNumber(phoneNumber);
  }

  // ── Phone: verify OTP ─────────────────────────────────────────────────────
  Future<AuthUser> verifyPhoneOtp({
    required ConfirmationResult confirmationResult,
    required String smsCode,
  }) async {
    final userCred = await confirmationResult.confirm(smsCode);
    await userCred.user!.getIdToken(true);
    final doc = await _firestore.collection('users').doc(userCred.user!.uid).get();
    if (!doc.exists) {
      await Future.delayed(const Duration(seconds: 2));
      await userCred.user!.getIdToken(true);
    }
    return _fetchProfile(userCred.user!.uid);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<AuthUser> _fetchProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('Profil utilisateur introuvable');
    return AuthUser.fromFirestore(doc.data()!);
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth:      ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});
