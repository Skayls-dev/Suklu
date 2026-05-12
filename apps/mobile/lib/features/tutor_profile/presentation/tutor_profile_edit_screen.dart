import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../marketplace/domain/available_slot_model.dart';
import '../../marketplace/domain/tutor_profile_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider — stream own tutor profile from Firestore
// ─────────────────────────────────────────────────────────────────────────────
final _ownTutorProfileProvider = StreamProvider.autoDispose<TutorProfileModel?>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection('tutor_profiles')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? TutorProfileModel.fromFirestore(snap) : null);
});

// ─────────────────────────────────────────────────────────────────────────────
// TutorProfileEditScreen
// ─────────────────────────────────────────────────────────────────────────────
class TutorProfileEditScreen extends ConsumerStatefulWidget {
  const TutorProfileEditScreen({super.key});

  @override
  ConsumerState<TutorProfileEditScreen> createState() => _TutorProfileEditScreenState();
}

class _TutorProfileEditScreenState extends ConsumerState<TutorProfileEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loaded = false;
  bool _saving = false;

  // ── Bio & rates ──────────────────────────────────────────────────────────
  final _bioCtrl           = TextEditingController();
  final _experienceCtrl    = TextEditingController();
  final _rateCtrl          = TextEditingController();

  // ── Subjects & grades ────────────────────────────────────────────────────
  final List<String> _selectedSubjects    = [];
  final List<String> _selectedGrades      = [];

  // ── Diplomas ─────────────────────────────────────────────────────────────
  final List<String> _diplomas            = [];
  final _diplomaCtrl = TextEditingController();

  // ── Availability ─────────────────────────────────────────────────────────
  final List<AvailableSlotModel> _slots   = [];

  // ──────────────────────────────────────────────────────────────────────────

  static const _allSubjects = [
    'Mathématiques', 'Physique', 'Chimie', 'Physique-Chimie', 'SVT',
    'Biologie', 'Français', 'Anglais', 'Espagnol', 'Histoire-Géographie',
    'Philosophie', 'Informatique', 'Économie', 'Comptabilité',
  ];

  static const _allGrades = [
    '6ème', '5ème', '4ème', '3ème', 'Seconde', 'Première', 'Terminale',
    'Licence 1', 'Licence 2', 'Licence 3', 'Master 1', 'Master 2',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bioCtrl.dispose();
    _experienceCtrl.dispose();
    _rateCtrl.dispose();
    _diplomaCtrl.dispose();
    super.dispose();
  }

  void _loadFromProfile(TutorProfileModel profile) {
    if (_loaded) return;
    _loaded = true;
    _bioCtrl.text        = profile.bio;
    _experienceCtrl.text = profile.yearsExperience.toString();
    _rateCtrl.text       = profile.hourlyRate.round().toString();
    _selectedSubjects
      ..clear()
      ..addAll(profile.subjects);
    _selectedGrades
      ..clear()
      ..addAll(profile.gradeLevels);
    _diplomas
      ..clear()
      ..addAll(profile.diplomas);
    _slots
      ..clear()
      ..addAll(profile.availableSlots);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_ownTutorProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (profile) {
        if (profile != null) _loadFromProfile(profile);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon profil tuteur'),
            backgroundColor: AppColors.tutorAccent,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Bio'),
                Tab(icon: Icon(Icons.subject, size: 20), text: 'Matières'),
                Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Diplômes'),
                Tab(icon: Icon(Icons.calendar_today_outlined, size: 20), text: 'Disponibilités'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _BioTab(
                bioCtrl: _bioCtrl,
                experienceCtrl: _experienceCtrl,
                rateCtrl: _rateCtrl,
              ),
              _SubjectsTab(
                allSubjects: _allSubjects,
                allGrades: _allGrades,
                selectedSubjects: _selectedSubjects,
                selectedGrades: _selectedGrades,
                onChanged: () => setState(() {}),
              ),
              _DiplomasTab(
                diplomas: _diplomas,
                diplomaCtrl: _diplomaCtrl,
                onChanged: () => setState(() {}),
              ),
              _AvailabilityTab(
                slots: _slots,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tutorAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Enregistrer les modifications'),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final uid = ref.read(authStateNotifierProvider).value?.uid;
    if (uid == null) return;

    final bio        = _bioCtrl.text.trim();
    final experience = int.tryParse(_experienceCtrl.text.trim()) ?? 0;
    final rate       = double.tryParse(_rateCtrl.text.trim()) ?? 0;

    if (bio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La bio ne peut pas être vide')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(firestoreProvider).collection('tutor_profiles').doc(uid).update({
        'bio':             bio,
        'yearsExperience': experience,
        'hourlyRate':      rate,
        'subjects':        List<String>.from(_selectedSubjects),
        'gradeLevels':     List<String>.from(_selectedGrades),
        'diplomas':        List<String>.from(_diplomas),
        'availableSlots':  _slots
            .map((s) => {
              'dayOfWeek': s.dayOfWeek,
              'startHour': s.startHour,
              'endHour':   s.endHour,
            })
            .toList(),
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour ✓'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Bio, expérience & tarif
// ─────────────────────────────────────────────────────────────────────────────
class _BioTab extends StatelessWidget {
  const _BioTab({
    required this.bioCtrl,
    required this.experienceCtrl,
    required this.rateCtrl,
  });

  final TextEditingController bioCtrl;
  final TextEditingController experienceCtrl;
  final TextEditingController rateCtrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapMd,
          TextField(
            controller: bioCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Décrivez votre expérience, votre méthode d\'enseignement...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          AppSpacing.gapLg,
          Text('Informations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: experienceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Années d\'expérience',
                    prefixIcon: const Icon(Icons.work_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: TextField(
                  controller: rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Tarif horaire (XOF)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Matières & niveaux
// ─────────────────────────────────────────────────────────────────────────────
class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab({
    required this.allSubjects,
    required this.allGrades,
    required this.selectedSubjects,
    required this.selectedGrades,
    required this.onChanged,
  });

  final List<String> allSubjects;
  final List<String> allGrades;
  final List<String> selectedSubjects;
  final List<String> selectedGrades;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matières enseignées',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${selectedSubjects.length} sélectionnée(s)', style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
          AppSpacing.gapMd,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allSubjects.map((subject) {
              final selected = selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: selected,
                selectedColor: AppColors.tutorAccent.withAlpha(40),
                checkmarkColor: AppColors.tutorAccent,
                side: BorderSide(
                  color: selected ? AppColors.tutorAccent : Colors.grey.shade300,
                ),
                onSelected: (val) {
                  if (val) {
                    selectedSubjects.add(subject);
                  } else {
                    selectedSubjects.remove(subject);
                  }
                  onChanged();
                },
              );
            }).toList(),
          ),
          AppSpacing.gapXl,
          Text(
            'Niveaux',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${selectedGrades.length} sélectionné(s)', style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
          AppSpacing.gapMd,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allGrades.map((grade) {
              final selected = selectedGrades.contains(grade);
              return FilterChip(
                label: Text(grade),
                selected: selected,
                selectedColor: AppColors.primary.withAlpha(40),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: selected ? AppColors.primary : Colors.grey.shade300,
                ),
                onSelected: (val) {
                  if (val) {
                    selectedGrades.add(grade);
                  } else {
                    selectedGrades.remove(grade);
                  }
                  onChanged();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Diplômes
// ─────────────────────────────────────────────────────────────────────────────
class _DiplomasTab extends StatelessWidget {
  const _DiplomasTab({
    required this.diplomas,
    required this.diplomaCtrl,
    required this.onChanged,
  });

  final List<String> diplomas;
  final TextEditingController diplomaCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: diplomaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex : Master Mathématiques – UCAD Dakar',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _add(context),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _add(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tutorAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (diplomas.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Aucun diplôme ajouté', style: TextStyle(color: AppColors.grey600)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: diplomas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.school_outlined, color: AppColors.tutorAccent),
                title: Text(diplomas[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    diplomas.removeAt(i);
                    onChanged();
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _add(BuildContext context) {
    final text = diplomaCtrl.text.trim();
    if (text.isEmpty) return;
    diplomas.add(text);
    diplomaCtrl.clear();
    onChanged();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Disponibilités
// ─────────────────────────────────────────────────────────────────────────────
class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({
    required this.slots,
    required this.onChanged,
  });

  final List<AvailableSlotModel> slots;
  final VoidCallback onChanged;

  static const _days = [
    (1, 'Lundi'), (2, 'Mardi'), (3, 'Mercredi'), (4, 'Jeudi'),
    (5, 'Vendredi'), (6, 'Samedi'), (7, 'Dimanche'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.grey600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tapez sur un créneau pour le supprimer. Ajoutez des créneaux via le bouton +.',
                  style: const TextStyle(color: AppColors.grey600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: slots.isEmpty
              ? const Center(
                  child: Text('Aucune disponibilité définie', style: TextStyle(color: AppColors.grey600)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _days.map<Widget>((day) {
                    final daySlots = slots.where((s) => s.dayOfWeek == day.$1).toList();
                    if (daySlots.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(day.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: daySlots.map((slot) {
                              return InkWell(
                                onTap: () {
                                  slots.remove(slot);
                                  onChanged();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_fmtHour(slot.startHour)} – ${_fmtHour(slot.endHour)}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.close, size: 14, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un créneau'),
            onPressed: () => _showAddSlotDialog(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}h00';

  Future<void> _showAddSlotDialog(BuildContext context) async {
    int selectedDay = 1;
    int startHour   = 9;
    int endHour     = 12;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un créneau'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day picker
              DropdownButtonFormField<int>(
                value: selectedDay,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Jour',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _days
                    .map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedDay = v ?? 1),
              ),
              const SizedBox(height: 16),
              // Time range
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: startHour,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Début',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: List.generate(18, (i) => i + 6)
                          .map((h) => DropdownMenuItem(value: h, child: Text('${h}h00')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => startHour = v ?? 9),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: endHour,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Fin',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: List.generate(18, (i) => i + 7)
                          .map((h) => DropdownMenuItem(value: h, child: Text('${h}h00')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => endHour = v ?? 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (endHour <= startHour) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('L\'heure de fin doit être après l\'heure de début')),
                  );
                  return;
                }
                slots.add(AvailableSlotModel(
                  dayOfWeek: selectedDay,
                  startHour: startHour,
                  endHour:   endHour,
                ));
                onChanged();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
