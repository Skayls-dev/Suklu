import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/marketplace_filter.dart';
import '../domain/tutor_profile_model.dart';

class MarketplaceRepository {
  MarketplaceRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  List<TutorProfileModel> _applyClientFilters(
    List<TutorProfileModel> tutors,
    MarketplaceFilter filter,
  ) {
    var result = tutors.where((tutor) {
      if (!tutor.isActive) return false;
      if (filter.verifiedOnly && !tutor.isVerified) return false;
      if (filter.country != null && tutor.country != filter.country) return false;
      if (filter.maxHourlyRate != null && tutor.hourlyRate > filter.maxHourlyRate!) {
        return false;
      }
      if (filter.subjectId != null && !tutor.subjects.contains(filter.subjectId)) {
        return false;
      }
      if (filter.gradeLevel != null && !tutor.gradeLevels.contains(filter.gradeLevel)) {
        return false;
      }
      return true;
    }).toList();

    result.sort((a, b) => b.rating.compareTo(a.rating));
    if (result.length > 20) {
      result = result.take(20).toList();
    }
    return result;
  }

  Stream<List<TutorProfileModel>> watchTutors(MarketplaceFilter filter) async* {
    Query<Map<String, dynamic>> query = _firestore
        .collection('tutor_profiles')
        .where('isActive', isEqualTo: true);

    final hasMaxRate = filter.maxHourlyRate != null;

    if (filter.verifiedOnly) {
      query = query.where('isVerified', isEqualTo: true);
    }

    if (filter.country != null) {
      query = query.where('country', isEqualTo: filter.country);
    }

    if (hasMaxRate) {
      query = query.where('hourlyRate', isLessThanOrEqualTo: filter.maxHourlyRate);
    }

    final hasSubject = filter.subjectId != null;
    final hasGrade = filter.gradeLevel != null;

    if (hasSubject) {
      // Requires composite index: subjects ASC, rating DESC — see firestore.indexes.json
      query = query.where('subjects', arrayContains: filter.subjectId);
    } else if (hasGrade) {
      // Requires composite index: gradeLevels ASC, rating DESC — see firestore.indexes.json
      query = query.where('gradeLevels', arrayContains: filter.gradeLevel);
    }

    // Raison : Firestore n'autorise pas deux arrayContains sur des champs différents.
    try {
      if (hasMaxRate) {
        // Raison : Firestore impose un orderBy sur le champ de comparaison (hourlyRate)
        // quand un filtre <= est appliqué.
        query = query
            .orderBy('hourlyRate')
            .orderBy('rating', descending: true);
      } else {
        query = query.orderBy('rating', descending: true);
      }

      await for (final snap in query.limit(20).snapshots()) {
        final tutors = snap.docs.map(TutorProfileModel.fromFirestore).where((tutor) {
          final matchesGrade = !hasGrade || tutor.gradeLevels.contains(filter.gradeLevel);
          final matchesSubject = !hasSubject || tutor.subjects.contains(filter.subjectId);
          return matchesGrade && matchesSubject;
        }).toList();
        yield tutors;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // Fallback sans index composite: on filtre et trie côté client.
      final fallbackQuery = _firestore
          .collection('tutor_profiles')
          .where('isActive', isEqualTo: true)
          .limit(200);

      await for (final snap in fallbackQuery.snapshots()) {
        final allTutors = snap.docs.map(TutorProfileModel.fromFirestore).toList();
        yield _applyClientFilters(allTutors, filter);
      }
    }
  }

  Future<TutorProfileModel?> fetchTutorProfile(String tutorId) async {
    final doc = await _firestore.collection('tutor_profiles').doc(tutorId).get();
    if (doc.exists) {
      return TutorProfileModel.fromFirestore(doc);
    }

    final byUid = await _firestore
        .collection('tutor_profiles')
        .where('uid', isEqualTo: tutorId)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) {
      return TutorProfileModel.fromFirestore(byUid.docs.first);
    }

    final byUserId = await _firestore
        .collection('tutor_profiles')
        .where('userId', isEqualTo: tutorId)
        .limit(1)
        .get();
    if (byUserId.docs.isEmpty) return null;
    return TutorProfileModel.fromFirestore(byUserId.docs.first);
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(
    firestore: ref.watch(firestoreProvider),
  );
});