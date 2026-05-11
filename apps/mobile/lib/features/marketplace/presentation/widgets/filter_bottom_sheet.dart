import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../marketplace_providers.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  String? _selectedSubjectId;
  String? _selectedGradeLevel;
  bool _verifiedOnly = false;
  double _maxRate = 50000;
  bool _limitRate = false;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(marketplaceFilterProvider);
    _selectedSubjectId = filter.subjectId;
    _selectedGradeLevel = filter.gradeLevel;
    _verifiedOnly = filter.verifiedOnly;
    _limitRate = filter.maxHourlyRate != null;
    _maxRate = filter.maxHourlyRate ?? 50000;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(activeSubjectsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtrer les tuteurs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            AppSpacing.gapMd,
            subjectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur matières: $e'),
              data: (subjects) => DropdownButtonFormField<String>(
                value: _selectedSubjectId ?? '',
                decoration: const InputDecoration(labelText: 'Matière'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Toutes les matières')),
                  ...subjects.map(
                    (subject) => DropdownMenuItem(
                      value: subject['id']!,
                      child: Text(subject['name']!),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSubjectId = value == null || value.isEmpty ? null : value;
                  });
                },
              ),
            ),
            AppSpacing.gapMd,
            DropdownButtonFormField<String>(
              value: _selectedGradeLevel ?? '',
              decoration: const InputDecoration(labelText: 'Niveau'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tous les niveaux')),
                ...[
                  DropdownMenuItem(value: '6ème', child: Text('6ème')),
                  DropdownMenuItem(value: '5ème', child: Text('5ème')),
                  DropdownMenuItem(value: '4ème', child: Text('4ème')),
                  DropdownMenuItem(value: '3ème', child: Text('3ème')),
                  DropdownMenuItem(value: 'Seconde', child: Text('Seconde')),
                  DropdownMenuItem(value: 'Première', child: Text('Première')),
                  DropdownMenuItem(value: 'Terminale', child: Text('Terminale')),
                  DropdownMenuItem(value: 'Licence 1', child: Text('Licence 1')),
                  DropdownMenuItem(value: 'Licence 2', child: Text('Licence 2')),
                ],
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGradeLevel = value == null || value.isEmpty ? null : value;
                });
              },
            ),
            AppSpacing.gapMd,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tuteurs vérifiés uniquement'),
              value: _verifiedOnly,
              onChanged: (value) => setState(() => _verifiedOnly = value),
            ),
            AppSpacing.gapSm,
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Limiter le tarif maximum'),
              value: _limitRate,
              onChanged: (value) => setState(() => _limitRate = value ?? false),
            ),
            Slider(
              value: _maxRate,
              min: 0,
              max: 50000,
              divisions: 100,
              label: '${_maxRate.round()} XOF',
              onChanged: _limitRate
                  ? (value) => setState(() => _maxRate = value)
                  : null,
            ),
            Text('Tarif max: ${_maxRate.round()} XOF'),
            AppSpacing.gapLg,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(marketplaceFilterProvider.notifier).resetAll();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final notifier = ref.read(marketplaceFilterProvider.notifier);
                      notifier.setSubject(_selectedSubjectId);
                      notifier.setGradeLevel(_selectedGradeLevel);
                      notifier.setVerifiedOnly(_verifiedOnly);
                      notifier.setMaxRate(_limitRate ? _maxRate : null);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}