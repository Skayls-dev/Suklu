import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/presentation/auth_providers.dart';

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.parentAccent,
        title: Text('Bonjour, ${user?.displayName ?? 'Parent'} 👋'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Link child CTA (if no children linked yet)
            Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.parentAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.parentAccent.withAlpha(60)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.child_care_outlined, size: 48, color: AppColors.parentAccent),
                  AppSpacing.gapSm,
                  Text('Liez le compte de votre enfant',
                      style: Theme.of(context).textTheme.titleMedium),
                  AppSpacing.gapSm,
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.parentAccent),
                    icon: const Icon(Icons.link),
                    label: const Text('Lier un compte'),
                    onPressed: () {/* TODO: link child account flow */},
                  ),
                ],
              ),
            ),
            AppSpacing.gapLg,

            Text('Actions rapides', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapMd,
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
              children: [
                _QuickAction(icon: Icons.calendar_today_outlined, label: 'Réserver un cours', color: AppColors.primary,        onTap: () => context.go('/parent/booking')),
                _QuickAction(icon: Icons.bar_chart_outlined,     label: 'Progrès',           color: AppColors.success,        onTap: () => context.go('/parent/progress')),
                _QuickAction(icon: Icons.receipt_long_outlined,  label: 'Paiements',         color: AppColors.parentAccent,   onTap: () => context.go('/parent/payment')),
                _QuickAction(icon: Icons.support_agent_outlined, label: 'Assistance',        color: AppColors.info,           onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 32),
        AppSpacing.gapSm,
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}
