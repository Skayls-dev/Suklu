import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

final groupSessionSlotsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('group_session_slots')
      .where('status', isEqualTo: 'open')
      .where('scheduledAt', isGreaterThan: Timestamp.now())
      .orderBy('scheduledAt')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final _tutorProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, tutorId) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('tutor_profiles').doc(tutorId).get();
  return snap.exists ? snap.data() : null;
});

final _subjectProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, subjectId) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('subjects').doc(subjectId).get();
  return snap.exists ? snap.data() : null;
});

final _myEnrollmentProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, slotId) async {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null || slotId.isEmpty) return null;
  
  final fs = ref.watch(firestoreProvider);
  final snap = await fs
      .collection('group_enrollments')
      .where('slotId', isEqualTo: slotId)
      .where('studentId', isEqualTo: uid)
      .limit(1)
      .get();
  
  return snap.docs.isNotEmpty ? {'id': snap.docs.first.id, ...snap.docs.first.data()} : null;
});

class GroupSessionsScreen extends ConsumerWidget {
  const GroupSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSlots = ref.watch(groupSessionSlotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sessions de groupe')),
      body: asyncSlots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (slots) {
          if (slots.isEmpty) {
            return const Center(
              child: Text('Aucune session de groupe ouverte pour le moment.'),
            );
          }

          return ListView.separated(
            padding: AppSpacing.pagePadding,
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _GroupSlotCard(slot: slots[index]),
          );
        },
      ),
    );
  }
}

class _GroupSlotCard extends ConsumerWidget {
  const _GroupSlotCard({required this.slot});

  final Map<String, dynamic> slot;

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  String _formatXof(dynamic value) {
    final number = (value is num) ? value.toInt() : 0;
    final f = NumberFormat('#,###', 'fr_FR');
    return '${f.format(number)} XOF';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorId = slot['tutorId']?.toString() ?? '';
    final subjectId = slot['subjectId']?.toString() ?? '';
    final gradeLevel = slot['gradeLevel']?.toString() ?? '—';
    final dt = _toDate(slot['scheduledAt']);
    final current = (slot['currentParticipants'] as num?)?.toInt() ?? 0;
    final max = (slot['maxParticipants'] as num?)?.toInt() ?? 1;
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final slotStatus = slot['status']?.toString() ?? 'open';

    final tutorAsync = ref.watch(_tutorProfileProvider(tutorId));
    final subjectAsync = ref.watch(_subjectProvider(subjectId));
    final enrollmentAsync = ref.watch(_myEnrollmentProvider(slot['id'] as String? ?? ''));

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            subjectAsync.when(
              loading: () => const Text('Chargement matière...'),
              error: (_, __) => Text('Matière: $subjectId'),
              data: (subject) {
                final icon = (subject?['icon'] ?? '').toString();
                final name = (subject?['name'] ?? subjectId).toString();
                return Text(
                  '$icon $name · $gradeLevel',
                  style: Theme.of(context).textTheme.titleMedium,
                );
              },
            ),
            AppSpacing.gapSm,
            Text(
              DateFormat('EEE d MMM yyyy · HH:mm', 'fr_FR').format(dt),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            AppSpacing.gapSm,
            tutorAsync.when(
              loading: () => const Text('Tuteur: chargement...'),
              error: (_, __) => const Text('Tuteur indisponible'),
              data: (tutor) {
                final fullName = (tutor?['fullName'] ?? tutorId).toString();
                final rating = (tutor?['rating'] as num?)?.toDouble() ?? 0.0;
                return Text('Tuteur: $fullName · ${rating.toStringAsFixed(1)} ★');
              },
            ),
            AppSpacing.gapSm,
            Text('$current/$max inscrits'),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: ratio, minHeight: 8),
            AppSpacing.gapMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatXof(slot['pricePerStudent']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                enrollmentAsync.when(
                  loading: () => FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(backgroundColor: Colors.grey),
                    child: const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                  error: (_, __) => FilledButton(
                    onPressed: current < max && slotStatus == 'open' ? () => _enroll(context) : null,
                    child: const Text('S\'inscrire'),
                  ),
                  data: (enrollment) {
                    if (enrollment != null) {
                      final status = enrollment['status']?.toString() ?? '';
                      final statusLabel = status == 'pending_payment' ? 'En attente' : 'Inscrit ✓';
                      return Chip(
                        label: Text(statusLabel, style: const TextStyle(fontSize: 12)),
                        backgroundColor: status == 'pending_payment' ? Colors.orange.withAlpha(30) : AppColors.success.withAlpha(30),
                        labelStyle: TextStyle(
                          color: status == 'pending_payment' ? Colors.orange : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return FilledButton(
                      onPressed: current < max && slotStatus == 'open' ? () => _enroll(context) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: current >= max || slotStatus != 'open' ? Colors.grey : AppColors.primary,
                      ),
                      child: Text(
                        current >= max ? 'Complet' : slotStatus != 'open' ? 'Fermé' : 'S\'inscrire',
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enroll(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('enrollInGroupSession');
      final response = await callable.call(<String, dynamic>{'slotId': slot['id']});
      final data = Map<String, dynamic>.from(response.data as Map);

      if (!context.mounted) return;
      final enrollmentId = data['enrollmentId']?.toString() ?? '';
      final price = data['pricePerStudent']?.toString() ?? '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inscription créée (#$enrollmentId) · Paiement: $price XOF'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Inscription impossible: $e'),
        ),
      );
    }
  }
}
