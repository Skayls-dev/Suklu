import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/diagnostic_result.dart';

class DiagnosticResultCard extends StatelessWidget {
  const DiagnosticResultCard({required this.summary, super.key});

  final DiagnosticSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(summary.levelIcon, color: summary.levelColor, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Niveau estimé',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      summary.estimatedLevel.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: summary.levelColor),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 28),
            _ResultSection(
              title: '✅ Points forts',
              icon: Icons.check_circle_outline,
              items: summary.strengths,
              color: Colors.green.shade700,
              emptyLabel: 'Aucun point fort identifié pour l\'instant',
            ),
            const SizedBox(height: 16),
            _ResultSection(
              title: '⚠️ Lacunes à travailler',
              icon: Icons.warning_amber_outlined,
              items: summary.gaps,
              color: Colors.orange.shade700,
              emptyLabel: 'Aucune lacune majeure détectée',
            ),
            const SizedBox(height: 16),
            _ResultSection(
              title: '📚 Sujets recommandés',
              icon: Icons.menu_book_outlined,
              items: summary.recommendedTopics,
              color: AppColors.primary,
              emptyLabel: 'Aucune recommandation spécifique',
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.color,
    required this.emptyLabel,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        AppSpacing.gapSm,
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic, color: AppColors.grey600),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    avatar: Icon(Icons.circle, size: 10, color: color),
                    label: Text(item),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
