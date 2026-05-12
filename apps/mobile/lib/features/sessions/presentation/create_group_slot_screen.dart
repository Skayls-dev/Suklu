import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';

final _subjectsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('subjects').where('isActive', isEqualTo: true).get();
  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

final _groupPricingEstimateProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final fs = ref.watch(firestoreProvider);
  final snap = await fs.collection('platform_config').doc('global').get();
  final data = snap.data() ?? <String, dynamic>{};

  final pricing = Map<String, dynamic>.from(data['pricing'] as Map? ?? {});
  final flatRates = Map<String, dynamic>.from(pricing['flatRates'] as Map? ?? {});
  final xofRaw = Map<String, dynamic>.from(flatRates['XOF'] as Map? ?? {});

  int estimateFor(int minutes) {
    final key = minutes.toString();
    final base = (xofRaw[key] as num?)?.toInt() ?? 0;
    return ((base * 0.75) / 100).ceil() * 100;
  }

  return {
    '30': estimateFor(30),
    '60': estimateFor(60),
    '90': estimateFor(90),
  };
});

class CreateGroupSlotScreen extends ConsumerStatefulWidget {
  const CreateGroupSlotScreen({super.key});

  @override
  ConsumerState<CreateGroupSlotScreen> createState() => _CreateGroupSlotScreenState();
}

class _CreateGroupSlotScreenState extends ConsumerState<CreateGroupSlotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _subjectId;
  String? _gradeLevel;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  int _durationMinutes = 60;
  double _maxParticipants = 6;
  bool _submitting = false;

  static const _gradeLevels = ['3eme', 'Seconde', 'Premiere', 'Terminale'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createGroupSlot');
      await callable.call(<String, dynamic>{
        'subjectId': _subjectId,
        'gradeLevel': _gradeLevel,
        'scheduledAt': _scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': _durationMinutes,
        'maxParticipants': _maxParticipants.round(),
        'description': _descriptionController.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session de groupe créée !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(_subjectsListProvider);
    final estimateAsync = ref.watch(_groupPricingEstimateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle session de groupe')),
      body: Padding(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              subjectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur matières: $e'),
                data: (subjects) => DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _subjectId,
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: subjects
                      .map((s) => DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text('${s['icon'] ?? ''} ${s['name'] ?? s['id']}'),
                          ))
                      .toList(),
                  validator: (v) => v == null ? 'Requis' : null,
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ),
              AppSpacing.gapMd,
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _gradeLevel,
                decoration: const InputDecoration(labelText: 'Niveau'),
                items: _gradeLevels
                    .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                    .toList(),
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _gradeLevel = v),
              ),
              AppSpacing.gapMd,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(DateFormat('dd/MM/yyyy HH:mm').format(_scheduledAt)),
                subtitle: const Text('Date et heure du créneau'),
                trailing: TextButton(onPressed: _pickDateTime, child: const Text('Changer')),
              ),
              AppSpacing.gapSm,
              Text('Durée', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 30, label: Text('30 min')),
                  ButtonSegment<int>(value: 60, label: Text('60 min')),
                  ButtonSegment<int>(value: 90, label: Text('90 min')),
                ],
                selected: {_durationMinutes},
                onSelectionChanged: (values) => setState(() => _durationMinutes = values.first),
              ),
              AppSpacing.gapMd,
              Text('Capacité: ${_maxParticipants.round()} élèves'),
              Slider(
                value: _maxParticipants,
                min: 2,
                max: 20,
                divisions: 18,
                label: _maxParticipants.round().toString(),
                onChanged: (v) => setState(() => _maxParticipants = v),
              ),
              AppSpacing.gapMd,
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'Objectif de la session, prérequis, etc.',
                ),
              ),
              AppSpacing.gapMd,
              estimateAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (estimate) {
                  final key = _durationMinutes.toString();
                  final price = estimate[key] ?? 0;
                  final formatted = NumberFormat('#,###', 'fr_FR').format(price);
                  return Text(
                    'Prix estimé : $formatted XOF / élève (réduction groupe 25%)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey600,
                        ),
                  );
                },
              ),
              AppSpacing.gapLg,
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Créer la session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
