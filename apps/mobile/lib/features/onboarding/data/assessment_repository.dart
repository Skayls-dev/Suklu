import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/assessment_model.dart';

class AssessmentRepository {
  AssessmentRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<String> saveAssessment(AssessmentModel assessment) async {
    final ref = _firestore.collection('assessments').doc();
    await ref.set(assessment.copyWith(id: ref.id).toFirestore());
    return ref.id;
  }

  Stream<List<AssessmentModel>> watchAssessmentsForStudent(String studentId) {
    return _firestore
        .collection('assessments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AssessmentModel.fromFirestore(doc))
              .toList(),
        );
  }
}

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepository(
    firestore: ref.watch(firestoreProvider),
  );
});
