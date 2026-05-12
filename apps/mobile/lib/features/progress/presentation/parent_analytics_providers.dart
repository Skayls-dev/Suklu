import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/parent_analytics_repository.dart';
import '../domain/parent_analytics_model.dart';

class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.fullName,
    required this.gradeLevel,
    this.avatarUrl,
  });

  final String uid;
  final String fullName;
  final String gradeLevel;
  final String? avatarUrl;
}

final selectedChildProvider = StateProvider<String?>((_) => null);

final childrenProfilesProvider = FutureProvider.autoDispose<List<StudentProfile>>((ref) async {
  final authUser = ref.watch(authStateNotifierProvider).value;
  if (authUser == null) return const [];

  final fs = ref.watch(firestoreProvider);
  final parentDoc = await fs.collection('users').doc(authUser.uid).get();
  final linkedIds = (parentDoc.data()?['linkedStudentIds'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];

  if (linkedIds.isEmpty) return const [];

  final futures = linkedIds.map((studentId) => fs.collection('users').doc(studentId).get());
  final docs = await Future.wait(futures);

  return docs
      .where((doc) => doc.exists)
      .map((doc) {
        final data = doc.data()!;
        return StudentProfile(
          uid: doc.id,
          fullName: (data['fullName'] ?? data['displayName'] ?? 'Élève').toString(),
          gradeLevel: (data['gradeLevel'] ?? '—').toString(),
          avatarUrl: data['avatarUrl']?.toString(),
        );
      })
      .toList();
});

final parentAnalyticsProvider = FutureProvider.autoDispose
    .family<ParentAnalyticsData, String>((ref, studentId) {
  return ref.watch(parentAnalyticsRepositoryProvider).getChildAnalytics(studentId);
});

final activeChildAnalyticsProvider = Provider<AsyncValue<ParentAnalyticsData>>((ref) {
  final selectedChildId = ref.watch(selectedChildProvider);
  if (selectedChildId == null) {
    return const AsyncValue.data(ParentAnalyticsData(
      studentId: '',
      totalSessions: 0,
      totalMinutes: 0,
      quizzesCompleted: 0,
      averageRating: 0,
      subjectBreakdown: {},
      weeklySessionCounts: [],
      topicsCompleted: [],
      topicsInProgress: [],
    ));
  }
  return ref.watch(parentAnalyticsProvider(selectedChildId));
});

final childRecentReviewsProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, studentId) {
  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('reviews')
      .where('studentId', isEqualTo: studentId)
      .orderBy('createdAt', descending: true)
      .limit(3)
      .snapshots()
      .map((snap) => snap.docs);
});

final childSessionSummariesProvider = FutureProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, studentId) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs
      .collection('sessions')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'completed')
      .where('aiSummary', isNotEqualTo: null)
      .orderBy('aiSummary')
      .orderBy('endedAt', descending: true)
      .limit(3)
      .get();
  return snap.docs;
});
