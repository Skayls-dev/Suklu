import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

// ── Progress data model ───────────────────────────────────────────────────────
class _ProgressData {
  const _ProgressData({
    required this.sessions,
    required this.hours,
    required this.quizzes,
    required this.subjectProgress,
  });
  final int sessions;
  final double hours;
  final int quizzes;
  final Map<String, double> subjectProgress; // subject → 0.0-1.0
}

// ── Provider ──────────────────────────────────────────────────────────────────
final _progressProvider = FutureProvider.autoDispose<_ProgressData>((ref) async {
  final uid  = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null) return const _ProgressData(sessions: 0, hours: 0, quizzes: 0, subjectProgress: {});

  final fs = ref.read(firestoreProvider);

  // Completed bookings for this student
  final bookingsSnap = await fs
      .collection('bookings')
      .where('studentId', isEqualTo: uid)
      .where('status', isEqualTo: 'completed')
      .get();

  final bookings = bookingsSnap.docs.map((d) => d.data()).toList();
  final sessions = bookings.length;
  final totalMinutes = bookings.fold<int>(0, (sum, b) => sum + ((b['durationMinutes'] as num?)?.toInt() ?? 0));
  final hours = totalMinutes / 60.0;

  // Count sessions per subject
  final subjectCounts = <String, int>{};
  for (final b in bookings) {
    final s = b['subjectId'] as String? ?? 'Autre';
    subjectCounts[s] = (subjectCounts[s] ?? 0) + 1;
  }
  final maxCount = subjectCounts.values.fold(0, (m, v) => v > m ? v : m);
  final subjectProgress = subjectCounts.map((k, v) =>
      MapEntry(k, maxCount > 0 ? v / maxCount : 0.0));

  // Successful quizzes in ai_logs
  final quizSnap = await fs
      .collection('ai_logs')
      .where('userId', isEqualTo: uid)
      .where('type', isEqualTo: 'quiz')
      .where('success', isEqualTo: true)
      .get();
  final quizzes = quizSnap.docs.length;

  return _ProgressData(
    sessions: sessions,
    hours: hours,
    quizzes: quizzes,
    subjectProgress: subjectProgress,
  );
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes progrès')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data: (data) => SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall stats
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Sessions',
                  value: '${data.sessions}',
                  icon: Icons.video_call_outlined,
                  color: AppColors.info,
                )),
                AppSpacing.gapMd,
                Expanded(child: _StatCard(
                  label: 'Heures',
                  value: data.hours.toStringAsFixed(1),
                  icon: Icons.schedule_outlined,
                  color: AppColors.primary,
                )),
                AppSpacing.gapMd,
                Expanded(child: _StatCard(
                  label: 'Quiz réussis',
                  value: '${data.quizzes}',
                  icon: Icons.check_circle_outlined,
                  color: AppColors.success,
                )),
              ]),
              AppSpacing.gapLg,

              Text('Matières', style: Theme.of(context).textTheme.titleLarge),
              AppSpacing.gapMd,

              if (data.subjectProgress.isEmpty)
                Center(
                  child: Text(
                    'Les données de progression s\'affichent ici\naprès votre première session.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
                  ),
                )
              else
                ...data.subjectProgress.entries.map((e) =>
                  _SubjectProgressCard(subject: e.key, progress: e.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label, value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Column(children: [
      Icon(icon, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey600), textAlign: TextAlign.center),
    ]),
  );
}

class _SubjectProgressCard extends StatelessWidget {
  const _SubjectProgressCard({required this.subject, required this.progress});
  final String subject;
  final double progress; // 0.0–1.0

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Padding(
      padding: AppSpacing.cardPadding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(subject, style: Theme.of(context).textTheme.titleSmall),
          Text('${(progress * 100).toInt()}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.grey200,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 8,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ]),
    ),
  );
}
