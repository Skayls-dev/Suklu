import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/presentation/auth_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes progrès')),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall stats
            Row(children: [
              Expanded(child: _StatCard(label: 'Sessions',    value: '—', icon: Icons.video_call_outlined,  color: AppColors.info)),
              AppSpacing.gapMd,
              Expanded(child: _StatCard(label: 'Heures',      value: '—', icon: Icons.schedule_outlined,     color: AppColors.primary)),
              AppSpacing.gapMd,
              Expanded(child: _StatCard(label: 'Quiz réussis', value: '—', icon: Icons.check_circle_outlined, color: AppColors.success)),
            ]),
            AppSpacing.gapLg,

            Text('Matières', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,

            const _SubjectProgressCard(subject: 'Mathématiques',  progress: 0.0),
            const _SubjectProgressCard(subject: 'Physique-Chimie', progress: 0.0),
            const _SubjectProgressCard(subject: 'Français',        progress: 0.0),
            const _SubjectProgressCard(subject: 'Anglais',         progress: 0.0),

            AppSpacing.gapLg,
            // TODO: wired assessment results from Firestore
            Center(
              child: Text(
                'Les données de progression s\'affichent ici\naprès votre première session.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
              ),
            ),
          ],
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
