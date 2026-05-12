import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/weekly_sessions_chart.dart';
import '../domain/parent_analytics_model.dart';
import 'parent_analytics_providers.dart';

class ParentAnalyticsScreen extends ConsumerWidget {
  const ParentAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProfilesProvider);
    final selectedChild = ref.watch(selectedChildProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progression enfant')),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Text('Aucun enfant lié à ce compte parent.'),
            );
          }

          if (selectedChild == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedChildProvider.notifier).state = children.first.uid;
            });
          }

          final childId = selectedChild ?? children.first.uid;
          final activeChild = children.firstWhere(
            (c) => c.uid == childId,
            orElse: () => children.first,
          );

          final analyticsAsync = ref.watch(parentAnalyticsProvider(activeChild.uid));
          final reviewsAsync = ref.watch(childRecentReviewsProvider(activeChild.uid));
          final summariesAsync = ref.watch(childSessionSummariesProvider(activeChild.uid));

          return analyticsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur analytics: $e')),
            data: (analytics) {
              final hours = analytics.totalMinutes / 60;
              final subjects = analytics.subjectBreakdown.values.toList()
                ..sort((a, b) => b.sessionCount.compareTo(a.sessionCount));
              final maxSessionCount = subjects.isEmpty
                  ? 1
                  : subjects.map((s) => s.sessionCount).reduce((a, b) => a > b ? a : b);

              return SingleChildScrollView(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enfant', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final child in children)
                          ChoiceChip(
                            label: Text('${child.fullName} · ${child.gradeLevel}'),
                            selected: child.uid == activeChild.uid,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (_) {
                              ref.read(selectedChildProvider.notifier).state = child.uid;
                            },
                          ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Sessions',
                            value: '${analytics.totalSessions}',
                            icon: Icons.video_call_outlined,
                            color: AppColors.info,
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: _StatCard(
                            label: 'Heures',
                            value: hours.toStringAsFixed(1),
                            icon: Icons.schedule_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: _StatCard(
                            label: 'Quiz réussis',
                            value: '${analytics.quizzesCompleted}',
                            icon: Icons.check_circle_outlined,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    Text('Activité des 8 dernières semaines', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: WeeklySessionsChart(dataPoints: analytics.weeklySessionCounts),
                    ),
                    AppSpacing.gapLg,
                    Text('Progression par matière', style: Theme.of(context).textTheme.titleMedium),
                    AppSpacing.gapSm,
                    if (subjects.isEmpty)
                      const Text('Aucune donnée matière pour cet enfant.')
                    else
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          final ratio = maxSessionCount == 0
                              ? 0.0
                              : (subject.sessionCount / maxSessionCount).clamp(0.0, 1.0);
                          return InkWell(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            onTap: () => _showSubjectTopics(context, subject),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(color: AppColors.grey200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.menu_book_outlined, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(subject.subjectId)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(value: ratio, minHeight: 8),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${subject.sessionCount} sessions · ${subject.totalMinutes} min · ${subject.averageRating.toStringAsFixed(1)} ★ moy',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.grey600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    AppSpacing.gapLg,
                    Text('Dernières notes du tuteur', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    reviewsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur reviews: $e'),
                      data: (docs) {
                        if (docs.isEmpty) {
                          return const Text('Aucune note tuteur pour le moment.');
                        }
                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data();
                            final rating = (data['rating'] as num?)?.toDouble() ?? 0;
                            final comment = (data['comment'] ?? '').toString();
                            final createdAt = data['createdAt'];
                            final date = createdAt is Timestamp
                                ? DateFormat('dd/MM/yyyy').format(createdAt.toDate())
                                : 'Date inconnue';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(date),
                                subtitle: Text(
                                  comment,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text('${rating.toStringAsFixed(1)} ★'),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    AppSpacing.gapLg,
                    Text('Derniers résumés IA', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    summariesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur résumés: $e'),
                      data: (docs) {
                        if (docs.isEmpty) {
                          return const Text('Aucun résumé IA disponible pour le moment.');
                        }

                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data();
                            final summary = (data['aiSummary'] as Map<String, dynamic>? ?? {});
                            final gaps = (summary['learning_gaps'] as List?)
                                    ?.map((e) => e.toString())
                                    .toList() ??
                                const <String>[];
                            final exercises = (summary['recommended_exercises'] as List?)
                                    ?.cast<Map>()
                                    .map((e) => (e['title'] ?? 'Exercice').toString())
                                    .toList() ??
                                const <String>[];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: AppSpacing.cardPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${(data['subjectId'] ?? 'Matière').toString()} · ${(data['endedAt'] is Timestamp) ? DateFormat('dd/MM/yyyy').format((data['endedAt'] as Timestamp).toDate()) : 'Date inconnue'}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(gaps.take(2).join(' · ${gaps.length > 2 ? '...' : ''}')),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: exercises.take(2).map((title) => Chip(label: Text(title))).toList(),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => context.push('/parent/session-summary/${doc.id}'),
                                        child: const Text('Voir le résumé complet'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showSubjectTopics(BuildContext context, SubjectStats stats) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(stats.subjectId, style: Theme.of(context).textTheme.titleLarge),
              AppSpacing.gapMd,
              Text('Sujets terminés', style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapSm,
              if (stats.topicsCompleted.isEmpty)
                const Text('Aucun sujet terminé')
              else
                ...stats.topicsCompleted.map((topic) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      title: Text(topic),
                    )),
              AppSpacing.gapMd,
              Text('Sujets en cours', style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapSm,
              if (stats.topicsInProgress.isEmpty)
                const Text('Aucun sujet en cours')
              else
                ...stats.topicsInProgress.map((topic) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.timelapse, color: AppColors.warning),
                      title: Text(topic),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
