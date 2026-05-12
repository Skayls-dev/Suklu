import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/student_profile_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider — stream own student profile from Firestore
// ─────────────────────────────────────────────────────────────────────────────
final _ownStudentProfileProvider = StreamProvider.autoDispose<StudentProfileModel?>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  final fullName = ref.watch(authStateNotifierProvider).value?.displayName ?? '';
  if (uid == null) return const Stream.empty();
  
  return ref
      .watch(firestoreProvider)
      .collection('student_profiles')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists 
          ? StudentProfileModel.fromFirestore(snap) 
          : StudentProfileModel.empty(uid, fullName));
});

// ─────────────────────────────────────────────────────────────────────────────
// StudentProfileEditScreen
// ─────────────────────────────────────────────────────────────────────────────
class StudentProfileEditScreen extends ConsumerStatefulWidget {
  const StudentProfileEditScreen({super.key});

  @override
  ConsumerState<StudentProfileEditScreen> createState() => _StudentProfileEditScreenState();
}

class _StudentProfileEditScreenState extends ConsumerState<StudentProfileEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loaded = false;
  bool _saving = false;

  // ── Subjects & grades ────────────────────────────────────────────────────
  final List<String> _selectedSubjects    = [];
  final List<String> _selectedGrades      = [];

  // ── Goals & preferences ──────────────────────────────────────────────────
  final _goalsCtrl              = TextEditingController();
  final _preferencesCtrl        = TextEditingController();

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
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _goalsCtrl.dispose();
    _preferencesCtrl.dispose();
    super.dispose();
  }

  void _loadFromProfile(StudentProfileModel profile) {
    if (_loaded) return;
    _loaded = true;
    _selectedSubjects
      ..clear()
      ..addAll(profile.subjects);
    _selectedGrades
      ..clear()
      ..addAll(profile.gradeLevels);
    _goalsCtrl.text    = profile.goals;
    _preferencesCtrl.text = profile.learningPreferences;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_ownStudentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (profile) {
        if (profile != null) _loadFromProfile(profile);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon profil étudiant'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.subject, size: 20), text: 'Matières'),
                Tab(icon: Icon(Icons.lightbulb_outline, size: 20), text: 'Objectifs'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _SubjectsTab(
                allSubjects: _allSubjects,
                allGrades: _allGrades,
                selectedSubjects: _selectedSubjects,
                selectedGrades: _selectedGrades,
                onChanged: () => setState(() {}),
              ),
              _GoalsTab(
                goalsCtrl: _goalsCtrl,
                preferencesCtrl: _preferencesCtrl,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Enregistrer mon profil'),
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

    setState(() => _saving = true);
    try {
      await ref.read(firestoreProvider).collection('student_profiles').doc(uid).set({
        'uid':                   uid,
        'fullName':              ref.read(authStateNotifierProvider).value?.displayName ?? '',
        'subjects':              List<String>.from(_selectedSubjects),
        'gradeLevels':           List<String>.from(_selectedGrades),
        'goals':                 _goalsCtrl.text.trim(),
        'learningPreferences':   _preferencesCtrl.text.trim(),
        'updatedAt':             FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
// Tab 1 — Matières & niveaux
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
            'Matières qui vous intéressent',
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
                selectedColor: AppColors.primary.withAlpha(40),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: selected ? AppColors.primary : Colors.grey.shade300,
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
            'Votre niveau scolaire',
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
                selectedColor: AppColors.info.withAlpha(40),
                checkmarkColor: AppColors.info,
                side: BorderSide(
                  color: selected ? AppColors.info : Colors.grey.shade300,
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
// Tab 2 — Objectifs & préférences d'apprentissage
// ─────────────────────────────────────────────────────────────────────────────
class _GoalsTab extends StatelessWidget {
  const _GoalsTab({
    required this.goalsCtrl,
    required this.preferencesCtrl,
  });

  final TextEditingController goalsCtrl;
  final TextEditingController preferencesCtrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mes objectifs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapMd,
          TextField(
            controller: goalsCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Ex : Améliorer mes notes en maths, préparer mon bac, renforcer en anglais...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          AppSpacing.gapLg,
          Text('Mes préférences d\'apprentissage', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapMd,
          TextField(
            controller: preferencesCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Ex : Je préfère les cours interactifs, j\'aime les exercices pratiques, je suis plus à l\'aise en soirée...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }
}
