import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/tutor_profile_model.dart';
import 'subject_chip.dart';

class TutorCard extends StatelessWidget {
  const TutorCard({required this.tutor, super.key});

  final TutorProfileModel tutor;

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
  Widget build(BuildContext context) {
    final initials = tutor.fullName.trim().isEmpty
        ? 'TU'
        : tutor.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.substring(0, 1).toUpperCase())
            .join();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tutor.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (tutor.isVerified) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Container(
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
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
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(
                  child: Text(
                    tutor.formattedRate,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  tutor.ratingLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/student/marketplace/${tutor.uid}'),
                child: const Text('Voir le profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}