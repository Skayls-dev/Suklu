import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

final userStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final fs = ref.watch(firestoreProvider);
  const roles = ['student', 'parent', 'tutor', 'academic_staff', 'super_admin'];

  final result = <String, int>{};
  for (final role in roles) {
    final snap = await fs.collection('users').where('role', isEqualTo: role).count().get();
    result[role] = snap.count ?? 0;
  }

  return result;
});

final monthlyRevenueProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);

  final snap = await fs
      .collection('payments')
      .where('status', isEqualTo: 'success')
      .where('processedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('processedAt', isLessThan: Timestamp.fromDate(end))
      .limit(500)
      .get();

  final totals = <String, double>{};
  for (final doc in snap.docs) {
    final data = doc.data();
    final currency = (data['currency'] ?? 'XOF').toString().toUpperCase();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    totals[currency] = (totals[currency] ?? 0) + amount;
  }

  return totals;
});

final monthlySessionsProvider = FutureProvider.autoDispose<int>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);

  final snap = await fs
      .collection('sessions')
      .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
      .count()
      .get();

  return snap.count ?? 0;
});

final pendingApplicationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs
      .collection('tutor_applications')
      .where('status', isEqualTo: 'pending_document_review')
      .count()
      .get();
  return snap.count ?? 0;
});

final pendingFlaggedCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs
      .collection('flagged_content')
      .where('status', isEqualTo: 'pending_review')
      .count()
      .get();
  return snap.count ?? 0;
});
