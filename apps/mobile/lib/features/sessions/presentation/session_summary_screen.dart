import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';

final sessionSummaryProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, sessionId) {
  final fs = ref.watch(firestoreProvider);
  return fs.collection('sessions').doc(sessionId).snapshots();
});

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionSummaryProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Résumé IA de session')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (doc) {
          if (!doc.exists) {
            return const Center(child: Text('Session introuvable'));
          }

          final data = doc.data() ?? {};
          final summary = data['aiSummary'] as Map<String, dynamic>?;
          final subject = (data['subjectId'] ?? 'Matière').toString();
          final gradeLevel = (data['gradeLevel'] ?? 'Niveau').toString();
          final duration = (data['durationMinutes'] as num?)?.toInt() ?? 60;

          if (summary == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Le résumé IA est en cours de génération...'),
                ],
              ),
            );
          }

          final topicsCovered = (summary['topics_covered'] as List?)?.map((e) => e.toString()).toList() ?? const [];
          final mastered = (summary['key_concepts_mastered'] as List?)?.map((e) => e.toString()).toList() ?? const [];
          final gaps = (summary['learning_gaps'] as List?)?.map((e) => e.toString()).toList() ?? const [];
          final exercises = (summary['recommended_exercises'] as List?)?.cast<Map>() ?? const [];
          final nextSession = (summary['next_session_suggestion'] ?? '').toString();
          final encouragement = (summary['encouragement_message'] ?? '').toString();

          return SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$subject · $gradeLevel · ${duration}min',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Généré par IA'),
                      backgroundColor: AppColors.info.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                _SectionChips(title: 'Points couverts', icon: Icons.menu_book_outlined, values: topicsCovered),
                AppSpacing.gapLg,
                _SectionList(
                  title: 'Concepts maîtrisés',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  values: mastered,
                ),
                AppSpacing.gapLg,
                _SectionList(
                  title: 'Points à retravailler',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.warning,
                  values: gaps,
                ),
                AppSpacing.gapLg,
                Text('Exercices recommandés', style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapSm,
                ...exercises.map((raw) {
                  final ex = Map<String, dynamic>.from(raw);
                  return Card(
                    child: Padding(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (ex['title'] ?? 'Exercice').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text((ex['description'] ?? '').toString()),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(label: Text((ex['difficulty'] ?? 'moyen').toString())),
                              Chip(label: Text('~${ex['estimated_duration_minutes'] ?? 15}min')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                AppSpacing.gapLg,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(nextSession),
                ),
                AppSpacing.gapMd,
                Center(
                  child: Text(
                    encouragement,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                AppSpacing.gapLg,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/student/progress'),
                    child: const Text('Voir ma progression'),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/student/marketplace'),
                  child: const Text('Réserver une prochaine session'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.title,
    required this.icon,
    required this.values,
  });

  final String title;
  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map((item) => Chip(label: Text(item), backgroundColor: Colors.blue.shade50))
              .toList(),
        ),
      ],
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        ...values.map((item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.circle, size: 10, color: color),
              title: Text(item),
            )),
      ],
    );
  }
}
