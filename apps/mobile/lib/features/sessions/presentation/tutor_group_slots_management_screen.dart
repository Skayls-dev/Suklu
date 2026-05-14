import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────
final _tutorGroupSlotsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('group_session_slots')
      .where('tutorId', isEqualTo: uid)
      .orderBy('scheduledAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final _enrollmentsForSlotProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, slotId) async {
    if (slotId.isEmpty) return [];
    final fs = ref.watch(firestoreProvider);
    final snap = await fs
        .collection('group_enrollments')
        .where('slotId', isEqualTo: slotId)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  },
);

final _studentProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, studentId) async {
    if (studentId.isEmpty) return null;
    final fs = ref.watch(firestoreProvider);
    final snap = await fs.collection('users').doc(studentId).get();
    return snap.exists ? (snap.data() ?? {}) : null;
  },
);

final _subjectProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, subjectId) async {
    if (subjectId.isEmpty) return null;
    final fs = ref.watch(firestoreProvider);
    final snap = await fs.collection('subjects').doc(subjectId).get();
    return snap.exists ? (snap.data() ?? {}) : null;
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class TutorGroupSlotsManagementScreen extends ConsumerWidget {
  const TutorGroupSlotsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(_tutorGroupSlotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes sessions de groupe'),
        backgroundColor: AppColors.tutorAccent,
        foregroundColor: Colors.white,
      ),
      body: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (slots) {
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule_outlined, size: 64, color: Colors.grey.shade400),
                    AppSpacing.gapMd,
                    Text(
                      'Aucune session de groupe créée',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'Créez une nouvelle session pour commencer!',
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
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _GroupSlotCard(
              slot: slots[index],
              ref: ref,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group slot card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupSlotCard extends ConsumerWidget {
  const _GroupSlotCard({
    required this.slot,
    required this.ref,
  });

  final Map<String, dynamic> slot;
  final WidgetRef ref;

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Ouvert';
      case 'full':
        return 'Complet';
      case 'cancelled':
        return 'Annulé';
      case 'completed':
        return 'Complété';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'full':
        return Colors.orange;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotId = slot['id']?.toString() ?? '';
    final subjectId = slot['subjectId']?.toString() ?? '';
    final gradeLevel = slot['gradeLevel']?.toString() ?? '—';
    final scheduledAt = _toDate(slot['scheduledAt']);
    final durationMinutes = (slot['durationMinutes'] as num?)?.toInt() ?? 60;
    final status = slot['status']?.toString() ?? 'open';
    final current = (slot['currentParticipants'] as num?)?.toInt() ?? 0;
    final max = (slot['maxParticipants'] as num?)?.toInt() ?? 1;

    final subjectAsync = ref.watch(_subjectProvider(subjectId));
    final enrollmentsAsync = ref.watch(_enrollmentsForSlotProvider(slotId));

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
            AppSpacing.gapMd,

            // Participants
            Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.grey600),
                const SizedBox(width: 6),
                Expanded(
                  child: LinearProgressIndicator(
                    value: max > 0 ? (current / max).clamp(0.0, 1.0) : 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$current/$max',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            AppSpacing.gapMd,

            // Participants list
            enrollmentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Participants: chargement...', style: TextStyle(fontSize: 12)),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Erreur participants', style: TextStyle(fontSize: 12)),
              ),
              data: (enrollments) {
                if (enrollments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucun participant', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Participants (${enrollments.length}):',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...enrollments.map((enrollment) {
                      final studentId = enrollment['studentId']?.toString() ?? '';
                      final enrollmentStatus = enrollment['status']?.toString() ?? '';
                      final studentAsync = ref.watch(_studentProfileProvider(studentId));

                      return studentAsync.when(
                        loading: () => Text(studentId, style: const TextStyle(fontSize: 11)),
                        error: (_, __) => Text(studentId, style: const TextStyle(fontSize: 11)),
                        data: (student) {
                          final name = (student?['displayName'] ?? student?['email'] ?? studentId).toString();
                          final statusIcon = enrollmentStatus == 'paid' ? '✓' : '⏳';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '  • $name ($statusIcon)',
                              style: TextStyle(
                                fontSize: 11,
                                color: enrollmentStatus == 'paid' ? Colors.green : Colors.orange,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
            AppSpacing.gapMd,

            // Price
            Text(
              'Prix: ${slot['pricePerStudent']} ${slot['currency'] ?? 'XOF'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            AppSpacing.gapMd,

            // Action buttons
            if (status != 'cancelled' && status != 'completed')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showCancelConfirmation(context, ref, slotId, status),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler cette session'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSlot(BuildContext context, WidgetRef ref, String slotId) async {
    final fs = ref.read(firestoreProvider);

    try {
      final batch = fs.batch();
      final slotRef = fs.collection('group_session_slots').doc(slotId);
      batch.update(slotRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final enrollmentsSnap = await fs
          .collection('group_enrollments')
          .where('slotId', isEqualTo: slotId)
          .get();

      for (final doc in enrollmentsSnap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        if (status != 'cancelled' && status != 'completed') {
          batch.update(doc.reference, {
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session annulée. Les participants ont été marqués annulés.'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(_tutorGroupSlotsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCancelConfirmation(BuildContext context, WidgetRef ref, String slotId, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cette session?'),
        content: const Text(
          'Les participants seront notifiés et recevront un remboursement complet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non, garder'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _cancelSlot(context, ref, slotId);
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}
