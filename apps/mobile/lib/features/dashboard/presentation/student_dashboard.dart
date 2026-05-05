import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/presentation/auth_providers.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${user?.displayName ?? 'Étudiant'} 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {/* TODO */},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick actions grid
            Text('Accès rapide', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
              children: [
                _QuickAction(
                  icon: Icons.calendar_today_outlined,
                  label: 'Réserver un cours',
                  color: AppColors.primary,
                  onTap: () => context.go('/student/booking'),
                ),
                _QuickAction(
                  icon: Icons.smart_toy_outlined,
                  label: 'Tuteur IA',
                  color: AppColors.studentAccent,
                  onTap: () => context.go('/student/ai-tutor'),
                ),
                _QuickAction(
                  icon: Icons.bar_chart_outlined,
                  label: 'Mes progrès',
                  color: AppColors.success,
                  onTap: () => context.push('/student/progress'),
                ),
                _QuickAction(
                  icon: Icons.video_call_outlined,
                  label: 'Mes sessions',
                  color: AppColors.info,
                  onTap: () {/* TODO: upcoming sessions */},
                ),
              ],
            ),
            AppSpacing.gapLg,

            // Upcoming sessions placeholder
            Text('Prochaines sessions', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,
            const _EmptySessionsCard(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Réserver'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'IA'),
          NavigationDestination(icon: Icon(Icons.person_outlined), label: 'Profil'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 1: context.go('/student/booking'); break;
            case 2: context.go('/student/ai-tutor'); break;
          }
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withAlpha(60)),
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          AppSpacing.gapSm,
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    ),
  );
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.cardPadding,
    decoration: BoxDecoration(
      color: AppColors.grey100,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      children: [
        const Icon(Icons.event_available_outlined, size: 48, color: AppColors.grey400),
        AppSpacing.gapSm,
        Text('Aucune session à venir', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600)),
        TextButton(onPressed: () {}, child: const Text('Réserver maintenant')),
      ],
    ),
  );
}
