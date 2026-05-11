import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../domain/tutor_profile_model.dart';
import 'marketplace_providers.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/subject_chip.dart';
import 'widgets/tutor_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({this.initialSubjectId, super.key});

  final String? initialSubjectId;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  late final TextEditingController _searchController;

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
  void initState() {
    super.initState();
    final initialSubjectId = widget.initialSubjectId;
    if (initialSubjectId != null && initialSubjectId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(marketplaceFilterProvider.notifier).setSubject(initialSubjectId);
      });
    }

    _searchController = TextEditingController()
      ..addListener(() {
        ref.read(marketplaceSearchQueryProvider.notifier).state = _searchController.text;
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorsAsync = ref.watch(filteredTutorsProvider);
    final subjectsAsync = ref.watch(activeSubjectsProvider);
    final filter = ref.watch(marketplaceFilterProvider);
    final query = ref.watch(marketplaceSearchQueryProvider).trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver un tuteur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg),
                  ),
                ),
                builder: (_) => const FilterBottomSheet(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un tuteur ou une matière',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(marketplaceSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            AppSpacing.gapSm,
            if (query.isEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisir une matière',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppSpacing.gapSm,
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Résultats pour "$query"',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ),
              AppSpacing.gapSm,
            ],
            subjectsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (subjects) {
                // Top matières populaires à afficher
                const popularSubjectIds = ['mathematics', 'french', 'english', 'physics'];
                final popularSubjects = subjects
                    .where((s) => popularSubjectIds.contains(s['id']))
                    .toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SubjectChip(
                        label: 'Toutes',
                        isSelected: filter.subjectId == null,
                        onTap: () => ref.read(marketplaceFilterProvider.notifier).setSubject(null),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ...popularSubjects.map((subject) {
                        final id = subject['id'] ?? '';
                        final name = subject['name'] ?? id;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: SubjectChip(
                            label: name,
                            isSelected: filter.subjectId == id,
                            onTap: () =>
                                ref.read(marketplaceFilterProvider.notifier).setSubject(id),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            if (filter.isActive) ...[
              AppSpacing.gapSm,
              Row(
                children: [
                  Text(
                    'Filtres actifs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(marketplaceFilterProvider.notifier).resetAll(),
                    child: const Text('Effacer'),
                  ),
                ],
              ),
            ],
            AppSpacing.gapSm,
            Expanded(
              child: tutorsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur de chargement: $e')),
                data: (tutors) {
                  final filtered = tutors.where((tutor) {
                    if (query.isEmpty) return true;
                    final matchesName = tutor.fullName.toLowerCase().contains(query);
                    final matchesSubject = tutor.subjects.any(
                      (subjectId) => _subjectLabel(subjectId).toLowerCase().contains(query),
                    );
                    return matchesName || matchesSubject;
                  }).toList();

                  if (query.isEmpty) {
                    if (filtered.isEmpty) {
                      return const Center(child: Text('Aucun tuteur trouvé'));
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => AppSpacing.gapMd,
                      itemBuilder: (context, index) => TutorCard(tutor: filtered[index]),
                    );
                  }

                  // Mode recherche : montrer les résultats groupés
                  final tutorMatches = filtered.where((t) => t.fullName.toLowerCase().contains(query)).toList();
                  final subjectMatches = <String, List<TutorProfileModel>>{};
                  for (final tutor in filtered) {
                    for (final subjectId in tutor.subjects) {
                      final label = _subjectLabel(subjectId);
                      if (label.toLowerCase().contains(query)) {
                        subjectMatches.putIfAbsent(label, () => []).add(tutor);
                      }
                    }
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: AppColors.grey200),
                          AppSpacing.gapMd,
                          const Text('Aucun résultat trouvé'),
                          AppSpacing.gapSm,
                          Text(
                            'Essayez un autre tuteur ou une autre matière',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    children: [
                      if (tutorMatches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Text(
                            'Tuteurs (${tutorMatches.length})',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...tutorMatches.map((tutor) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: TutorCard(tutor: tutor),
                        )),
                        if (subjectMatches.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Divider(),
                          ),
                      ],
                      if (subjectMatches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Text(
                            'Tuteurs par matière (${subjectMatches.length})',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...subjectMatches.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Chip(
                                  label: Text(entry.key),
                                  backgroundColor: AppColors.primary.withAlpha(25),
                                ),
                              ),
                              ...entry.value.take(3).map((tutor) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: TutorCard(tutor: tutor),
                              )),
                              if (entry.value.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                                  child: Text(
                                    '+${entry.value.length - 3} autre${entry.value.length - 3 > 1 ? 's' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}