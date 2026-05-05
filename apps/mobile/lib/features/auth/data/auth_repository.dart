import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<void> signOut() => _auth.signOut();

  // ── Password reset ─────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

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
