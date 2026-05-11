import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/progress_record.dart';

class ProgressRepository {
  ProgressRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<ProgressRecord>> getStudentProgress(String studentId) {
    return _firestore
        .collection('progress')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ProgressRecord.fromFirestore(doc)).toList());
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(firestore: ref.watch(firestoreProvider));
});

final studentProgressProvider =
    StreamProvider.autoDispose.family<List<ProgressRecord>, String>((ref, studentId) {
  return ref.watch(progressRepositoryProvider).getStudentProgress(studentId);
});
