import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';

class _LinkedChild {
  const _LinkedChild({
    required this.id,
    required this.fullName,
    required this.gradeLevel,
  });

  final String id;
  final String fullName;
  final String gradeLevel;
}

final _parentLinkedChildrenProvider =
    FutureProvider.autoDispose<List<_LinkedChild>>((ref) async {
  final user = ref.watch(authStateNotifierProvider).value;
  if (user == null) return const [];

  final functions = ref.watch(firebaseFunctionsProvider);
  try {
    final result = await functions
        .httpsCallable('getParentLinkedChildren')
        .call<Map<String, dynamic>>(<String, dynamic>{});

    final rawChildren = (result.data['children'] as List?) ?? const [];
    return rawChildren.whereType<Map>().map((raw) {
      final data = Map<String, dynamic>.from(raw);
      return _LinkedChild(
        id: (data['uid'] ?? '').toString(),
        fullName: (data['fullName'] ?? 'Élève').toString(),
        gradeLevel: (data['gradeLevel'] ?? '—').toString(),
      );
    }).toList();
  } on FirebaseFunctionsException catch (e) {
    // Fallback for local/dev environments where the function is not deployed yet.
    if (e.code != 'not-found' && e.code != 'unimplemented') {
      rethrow;
    }

    final fs = ref.watch(firestoreProvider);
    final parentDoc = await fs.collection('users').doc(user.uid).get();
    final linkedIds = (parentDoc.data()?['linkedStudentIds'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];

    return linkedIds.map((studentId) {
      final shortId = studentId.substring(0, studentId.length > 8 ? 8 : studentId.length);
      return _LinkedChild(
        id: studentId,
        fullName: 'Compte élève lié ($shortId...)',
        gradeLevel: 'Accès profil restreint',
      );
    }).toList();
  }
});

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).value;
    final linkedChildrenAsync = ref.watch(_parentLinkedChildrenProvider);

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
            linkedChildrenAsync.when(
              loading: () => Container(
                width: double.infinity,
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.parentAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.parentAccent.withAlpha(60)),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Container(
                width: double.infinity,
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Text('Impossible de charger les enfants liés: $error'),
              ),
              data: (linkedChildren) {
                if (linkedChildren.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.parentAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.parentAccent.withAlpha(60)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.child_care_outlined,
                          size: 48,
                          color: AppColors.parentAccent,
                        ),
                        AppSpacing.gapSm,
                        Text(
                          'Liez le compte de votre enfant',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        AppSpacing.gapSm,
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.parentAccent,
                          ),
                          icon: const Icon(Icons.link),
                          label: const Text('Lier un compte'),
                          onPressed: () => context.push('/parent/link-request'),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.success.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            linkedChildren.length == 1
                                ? '1 enfant lié'
                                : '${linkedChildren.length} enfants liés',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      AppSpacing.gapSm,
                      for (final child in linkedChildren)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.child_care, color: AppColors.success),
                          title: Text(child.fullName),
                          subtitle: Text('Niveau: ${child.gradeLevel}'),
                        ),
                      AppSpacing.gapSm,
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.go('/parent/progress'),
                            icon: const Icon(Icons.bar_chart_outlined),
                            label: const Text('Voir le progrès'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.parentAccent,
                            ),
                            onPressed: () => context.push('/parent/link-request'),
                            icon: const Icon(Icons.link),
                            label: const Text('Lier un autre compte'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
                _QuickAction(icon: Icons.person_outline,         label: 'Mon profil',        color: AppColors.tutorAccent,    onTap: () => context.push('/parent/profile/edit')),
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
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              AppSpacing.gapSm,
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
