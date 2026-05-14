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
            onPressed: () => context.go('/student/booking'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DiagnosticEntryCard(onStart: () => context.go('/diagnostic')),
            AppSpacing.gapLg,
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
                  icon: Icons.quiz_outlined,
                  label: 'Diagnostic',
                  color: AppColors.secondaryDark,
                  onTap: () => context.go('/diagnostic'),
                ),
                _QuickAction(
                  icon: Icons.video_call_outlined,
                  label: 'Mes sessions',
                  color: AppColors.info,
                  onTap: () => context.go('/student/booking'),
                ),
                _QuickAction(
                  icon: Icons.group_outlined,
                  label: 'Mes sessions groupe',
                  color: AppColors.primary,
                  onTap: () => context.push('/student/my-group-sessions'),
                ),
                _QuickAction(
                  icon: Icons.person_outline,
                  label: 'Mon profil',
                  color: AppColors.tutorAccent,
                  onTap: () => context.push('/student/profile/edit'),
                ),
              ],
            ),
            AppSpacing.gapLg,

            // Upcoming sessions placeholder
            Text('Prochaines sessions', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,
            _EmptySessionsCard(onBookNow: () => context.go('/student/booking')),
          ],
        ),
      ),

    );
  }
}

class _DiagnosticEntryCard extends StatelessWidget {
  const _DiagnosticEntryCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(32),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Évaluation diagnostique',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      'Lancez votre diagnostic pour personnaliser votre parcours d’apprentissage.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Lancer le diagnostic',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
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
        border: Border.all(color: color.withAlpha(60), width: 0.5),
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
  const _EmptySessionsCard({required this.onBookNow});

  final VoidCallback onBookNow;
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
        TextButton(onPressed: onBookNow, child: const Text('Réserver maintenant')),
      ],
    ),
  );
}
