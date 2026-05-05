import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/application_model.dart';

class ApplicationRepository {
  ApplicationRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  // ── Submit tutor application ───────────────────────────────────────────────
  // The caller must have already uploaded documents to Firebase Storage and
  // passes the gs:// Storage paths here. Never pass binary data — call
  // FirebaseStorage.instance.ref().putFile() in the presentation layer first.
  Future<String> submitApplication({
    required String       fullName,
    required String       phoneNumber,
    required List<String> subjects,
    required List<String> gradeLevels,
    required String       bio,
    required String       cvStoragePath,
    required String       idStoragePath,
    required String       country,
    List<String>          diplomas       = const [],
    int                   yearsExperience = 0,
  }) async {
    final result = await _functions
        .httpsCallable('submitApplication')
        .call<Map<String, dynamic>>({
      'fullName':        fullName,
      'phoneNumber':     phoneNumber,
      'subjects':        subjects,
      'gradeLevels':     gradeLevels,
      'bio':             bio,
      'cvStoragePath':   cvStoragePath,
      'idStoragePath':   idStoragePath,
      'country':         country,
      'diplomas':        diplomas,
      'yearsExperience': yearsExperience,
    });
    return result.data['applicationId'] as String;
  }

  // ── Watch own application ──────────────────────────────────────────────────
  Stream<TutorApplicationModel?> watchOwnApplication(String userId) {
    return _firestore
        .collection('tutor_applications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : TutorApplicationModel.fromFirestore(snap.docs.first));
  }
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});
