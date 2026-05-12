import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers for enrolled sessions
// ─────────────────────────────────────────────────────────────────────────────
final _studentEnrollmentsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('group_enrollments')
      .where('studentId', isEqualTo: uid)
      .orderBy('enrolledAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final _slotDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, slotId) async {
  if (slotId.isEmpty) return null;
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('group_session_slots').doc(slotId).get();
  if (!snap.exists) return null;
  final data = snap.data() ?? {};
  return {'id': snap.id, ...data};
});

final _tutorProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, tutorId) async {
  if (tutorId.isEmpty) return null;
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('tutor_profiles').doc(tutorId).get();
  return snap.exists ? (snap.data() ?? {}) : null;
});

final _subjectProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, subjectId) async {
  if (subjectId.isEmpty) return null;
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('subjects').doc(subjectId).get();
  return snap.exists ? (snap.data() ?? {}) : null;
});

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class MyGroupSessionsScreen extends ConsumerWidget {
  const MyGroupSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(_studentEnrollmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes sessions de groupe'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: enrollmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (enrollments) {
          if (enrollments.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade400),
                    AppSpacing.gapMd,
                    Text(
                      'Aucune session de groupe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'Parcourez les sessions disponibles et inscrivez-vous!',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.pagePadding,
            itemCount: enrollments.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _EnrollmentCard(
              enrollment: enrollments[index],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enrollment card
// ─────────────────────────────────────────────────────────────────────────────
class _EnrollmentCard extends ConsumerWidget {
  const _EnrollmentCard({required this.enrollment});

  final Map<String, dynamic> enrollment;

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending_payment':
        return 'En attente de paiement';
      case 'paid':
        return 'Confirmé ✓';
      case 'completed':
        return 'Complété ✓';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return Colors.orange;
      case 'paid':
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_payment':
        return Icons.hourglass_bottom;
      case 'paid':
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotId = enrollment['slotId']?.toString() ?? '';
    final status = enrollment['status']?.toString() ?? '';
    final enrolledAt = _toDate(enrollment['enrolledAt']);

    final slotAsync = ref.watch(_slotDetailProvider(slotId));

    return slotAsync.when(
      loading: () => const Card(child: LinearProgressIndicator()),
      error: (e, _) => Card(child: Padding(padding: AppSpacing.cardPadding, child: Text('Erreur: $e'))),
      data: (slot) {
        if (slot == null) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Session supprimée')));
        }

        final tutorId = slot['tutorId']?.toString() ?? '';
        final subjectId = slot['subjectId']?.toString() ?? '';
        final gradeLevel = slot['gradeLevel']?.toString() ?? '—';
        final scheduledAt = _toDate(slot['scheduledAt']);
        final durationMinutes = (slot['durationMinutes'] as num?)?.toInt() ?? 60;

        final tutorAsync = ref.watch(_tutorProfileProvider(tutorId));
        final subjectAsync = ref.watch(_subjectProvider(subjectId));

        return Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: subjectAsync.when(
                        loading: () => const Text('Chargement...'),
                        error: (_, __) => Text(subjectId),
                        data: (subject) {
                          final icon = (subject?['icon'] ?? '').toString();
                          final name = (subject?['name'] ?? subjectId).toString();
                          return Text(
                            '$icon $name · $gradeLevel',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    Chip(
                      avatar: Icon(_getStatusIcon(status), size: 16),
                      label: Text(_getStatusLabel(status), style: const TextStyle(fontSize: 12)),
                      backgroundColor: _getStatusColor(status).withAlpha(30),
                      labelStyle: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                AppSpacing.gapMd,

                // Date & time
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.grey600),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('d MMM yyyy', 'fr_FR').format(scheduledAt),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time_outlined, size: 16, color: AppColors.grey600),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('HH:mm').format(scheduledAt)} ($durationMinutes min)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                AppSpacing.gapSm,

                // Tutor
                tutorAsync.when(
                  loading: () => const Text('Tuteur: chargement...', style: TextStyle(fontSize: 13)),
                  error: (_, __) => const Text('Tuteur indisponible', style: TextStyle(fontSize: 13)),
                  data: (tutor) {
                    final fullName = (tutor?['fullName'] ?? tutorId).toString();
                    final rating = (tutor?['rating'] as num?)?.toDouble() ?? 0.0;
                    return Text(
                      'Tuteur: $fullName · ${rating.toStringAsFixed(1)} ★',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    );
                  },
                ),
                AppSpacing.gapMd,

                // Enrollment date
                Text(
                  'Inscrit le ${DateFormat('d MMM yyyy à HH:mm', 'fr_FR').format(enrolledAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
