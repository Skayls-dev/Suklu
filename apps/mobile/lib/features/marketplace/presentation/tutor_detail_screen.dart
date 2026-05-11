import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'marketplace_providers.dart';
import 'widgets/availability_grid.dart';
import 'widgets/subject_chip.dart';

class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({required this.tutorId, super.key});

  final String tutorId;

  String _subjectLabel(String subjectId) => switch (subjectId) {
        'mathematics' => 'Mathématiques',
        'physics' => 'Physique',
        'chemistry' => 'Chimie',
        'french' => 'Français',
        'english' => 'Anglais',
        'history_geography' => 'Histoire-Géo',
        'biology' => 'Biologie',
        'philosophy' => 'Philosophie',
        _ => subjectId,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorAsync = ref.watch(tutorProfileProvider(tutorId));
    final selectedSubjectId = ref.watch(marketplaceFilterProvider).subjectId;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil du tuteur')),
      body: tutorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur de chargement: $e')),
        data: (tutor) {
          if (tutor == null) {
            return const Center(child: Text('Profil introuvable'));
          }

          final initials = tutor.fullName.trim().isEmpty
              ? 'TU'
              : tutor.fullName
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((part) => part.substring(0, 1).toUpperCase())
                  .join();

          return SafeArea(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Center(
                          child: Text(
                            tutor.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (tutor.isVerified) ...[
                          AppSpacing.gapSm,
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(24),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                              child: const Text(
                                '✓ Vérifié',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        AppSpacing.gapSm,
                        Center(
                          child: Text(
                            tutor.ratingLabel,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.grey600,
                                ),
                          ),
                        ),
                        AppSpacing.gapLg,
                        Card(
                          color: AppColors.primary.withAlpha(18),
                          child: Padding(
                            padding: AppSpacing.cardPadding,
                            child: Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: AppColors.primary),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    tutor.formattedRate,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.gapLg,
                        Text('À propos', style: Theme.of(context).textTheme.titleLarge),
                        AppSpacing.gapSm,
                        Text(tutor.bio.isEmpty ? 'Aucune biographie renseignée.' : tutor.bio),
                        AppSpacing.gapLg,
                        Text('Matières', style: Theme.of(context).textTheme.titleLarge),
                        AppSpacing.gapSm,
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: tutor.subjects
                              .map(
                                (subject) => IgnorePointer(
                                  child: SubjectChip(
                                    label: _subjectLabel(subject),
                                    isSelected: false,
                                    onTap: () {},
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        AppSpacing.gapLg,
                        Text('Niveaux', style: Theme.of(context).textTheme.titleLarge),
                        AppSpacing.gapSm,
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: tutor.gradeLevels
                              .map(
                                (level) => IgnorePointer(
                                  child: SubjectChip(
                                    label: level,
                                    isSelected: false,
                                    onTap: () {},
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        AppSpacing.gapLg,
                        Text('Diplômes', style: Theme.of(context).textTheme.titleLarge),
                        AppSpacing.gapSm,
                        ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: tutor.diplomas.length,
                          itemBuilder: (context, index) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.school_outlined),
                            title: Text(tutor.diplomas[index]),
                          ),
                        ),
                        AppSpacing.gapLg,
                        Text('Disponibilités', style: Theme.of(context).textTheme.titleLarge),
                        AppSpacing.gapSm,
                        AvailabilityGrid(availableSlots: tutor.availableSlots),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(
                        '/student/booking',
                        extra: {
                          'tutorId': tutorId,
                          if (selectedSubjectId != null) 'subjectId': selectedSubjectId,
                        },
                      ),
                      child: const Text('Réserver une session'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}