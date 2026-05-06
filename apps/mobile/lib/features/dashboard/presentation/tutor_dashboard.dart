import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/presentation/auth_providers.dart';

class TutorDashboard extends ConsumerWidget {
  const TutorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tutorAccent,
        title: Text('Bonjour, ${user?.displayName ?? 'Tuteur'} 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/tutor/booking'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Sessions ce mois',  value: '—', color: AppColors.tutorAccent)),
                AppSpacing.gapMd,
                Expanded(child: _StatCard(label: 'Étudiants actifs',  value: '—', color: AppColors.success)),
                AppSpacing.gapMd,
                Expanded(child: _StatCard(label: 'Revenus (XOF)',     value: '—', color: AppColors.secondary)),
              ],
            ),
            AppSpacing.gapLg,

            Text('Actions', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,

            _ActionTile(
              icon:    Icons.quiz_outlined,
              title:   'Générer un quiz',
              color:   AppColors.tutorAccent,
              onTap:   () => context.go('/tutor/ai-tutor'),
            ),
            _ActionTile(
              icon:    Icons.schedule_outlined,
              title:   'Gérer mon agenda',
              color:   AppColors.primary,
              onTap:   () => context.go('/tutor/booking'),
            ),
            _ActionTile(
              icon:    Icons.video_call_outlined,
              title:   'Démarrer une session',
              color:   AppColors.info,
              onTap:   () => context.go('/tutor/session/demo'),
            ),

            AppSpacing.gapLg,
            Text('Demandes de réservation', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Aucune demande en attente', style: TextStyle(color: AppColors.grey600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label, value;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey600), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.color, required this.onTap});
  final IconData icon; final String title; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
