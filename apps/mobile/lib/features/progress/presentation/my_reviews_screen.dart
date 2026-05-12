import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

final myTutorReviewsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null) {
    return const Stream.empty();
  }

  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('reviews')
      .where('targetId', isEqualTo: uid)
      .where('targetRole', isEqualTo: 'student')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs);
});

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTutorReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes évaluations reçues')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune évaluation pour le moment.\n'
                  'Complétez vos premières sessions pour recevoir des retours de vos tuteurs.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = reviews[index].data();
              final rating = (data['rating'] as num?)?.toDouble() ?? 0;
              final comment = (data['comment'] ?? '').toString();
              final subject = (data['subjectId'] ?? 'Matière').toString();
              final rawDate = data['createdAt'];
              final date = rawDate is Timestamp
                  ? DateFormat('dd/MM/yyyy').format(rawDate.toDate())
                  : 'Date inconnue';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$subject · $date'),
                subtitle: Text(comment),
                trailing: Text('${rating.toStringAsFixed(1)} ★'),
              );
            },
          );
        },
      ),
    );
  }
}
