import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/application_repository.dart';
import '../domain/application_model.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final ownApplicationProvider = StreamProvider.autoDispose.family<TutorApplicationModel?, String>(
  (ref, userId) => ref.watch(applicationRepositoryProvider).watchOwnApplication(userId),
);

// ─────────────────────────────────────────────────────────────────────────────
// TutorApplicationScreen
//
// Allows a user to submit a tutor application. Walks through:
//   Step 1 — Personal info & bio
//   Step 2 — Subjects & grade levels
//   Step 3 — Document upload (CV + ID)
// ─────────────────────────────────────────────────────────────────────────────
class TutorApplicationScreen extends ConsumerStatefulWidget {
  const TutorApplicationScreen({super.key});

  @override
  ConsumerState<TutorApplicationScreen> createState() => _TutorApplicationScreenState();
}

class _TutorApplicationScreenState extends ConsumerState<TutorApplicationScreen> {
  final _pageCtrl       = PageController();
  int   _currentStep    = 0;

  final _fullNameCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _bioCtrl        = TextEditingController();
  final _countryCtrl    = TextEditingController();

  final List<String> _selectedSubjects    = [];
  final List<String> _selectedGradeLevels = [];

  // In production, set these after real Firebase Storage uploads
  String? _cvStoragePath;
  String? _idStoragePath;

  bool _isSubmitting = false;

  static const _availableSubjects = [
    'Mathématiques', 'Physique-Chimie', 'SVT', 'Français',
    'Anglais', 'Histoire-Géographie', 'Philosophie', 'Informatique',
  ];

  static const _availableGrades = [
    '6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Terminale',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_cvStoragePath == null || _idStoragePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez téléverser votre CV et pièce d\'identité')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(applicationRepositoryProvider).submitApplication(
        fullName:       _fullNameCtrl.text.trim(),
        phoneNumber:    _phoneCtrl.text.trim(),
        subjects:       _selectedSubjects,
        gradeLevels:    _selectedGradeLevels,
        bio:            _bioCtrl.text.trim(),
        cvStoragePath:  _cvStoragePath!,
        idStoragePath:  _idStoragePath!,
        country:        _countryCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée ! Nous vous contacterons dans 48-72h.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devenir tuteur')),
      body: Column(
        children: [
          // Step indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: AppColors.grey200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.tutorAccent),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1PersonalInfo(
                  fullNameCtrl: _fullNameCtrl,
                  phoneCtrl: _phoneCtrl,
                  bioCtrl: _bioCtrl,
                  countryCtrl: _countryCtrl,
                  onNext: () {
                    setState(() => _currentStep = 1);
                    _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                _Step2Subjects(
                  subjects: _availableSubjects,
                  grades: _availableGrades,
                  selectedSubjects: _selectedSubjects,
                  selectedGrades: _selectedGradeLevels,
                  onSelectionChanged: setState,
                  onBack: () { setState(() => _currentStep = 0); _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
                  onNext: () { setState(() => _currentStep = 2); _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
                ),
                _Step3Documents(
                  cvStoragePath: _cvStoragePath,
                  idStoragePath: _idStoragePath,
                  isSubmitting: _isSubmitting,
                  onCvUpload: (path) => setState(() => _cvStoragePath = path),
                  onIdUpload: (path) => setState(() => _idStoragePath = path),
                  onBack: () { setState(() => _currentStep = 1); _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step widgets ──────────────────────────────────────────────────────────────

class _Step1PersonalInfo extends StatelessWidget {
  const _Step1PersonalInfo({
    required this.fullNameCtrl,
    required this.phoneCtrl,
    required this.bioCtrl,
    required this.countryCtrl,
    required this.onNext,
  });

  final TextEditingController fullNameCtrl, phoneCtrl, bioCtrl, countryCtrl;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Informations personnelles', style: Theme.of(context).textTheme.titleLarge),
      AppSpacing.gapLg,
      TextFormField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
      AppSpacing.gapMd,
      TextFormField(controller: phoneCtrl,    decoration: const InputDecoration(labelText: 'Téléphone')),
      AppSpacing.gapMd,
      TextFormField(controller: countryCtrl,  decoration: const InputDecoration(labelText: 'Pays')),
      AppSpacing.gapMd,
      TextFormField(
        controller: bioCtrl,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Présentation (biographie)'),
      ),
      AppSpacing.gapLg,
      ElevatedButton(onPressed: onNext, child: const Text('Suivant →')),
    ]),
  );
}

class _Step2Subjects extends StatelessWidget {
  const _Step2Subjects({
    required this.subjects,
    required this.grades,
    required this.selectedSubjects,
    required this.selectedGrades,
    required this.onSelectionChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<String> subjects, grades, selectedSubjects, selectedGrades;
  final Function(void Function()) onSelectionChanged;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Matières & niveaux', style: Theme.of(context).textTheme.titleLarge),
      AppSpacing.gapMd,
      Text('Matières enseignées', style: Theme.of(context).textTheme.titleSmall),
      AppSpacing.gapSm,
      Wrap(spacing: 8, runSpacing: 8, children: subjects.map((s) {
        final selected = selectedSubjects.contains(s);
        return FilterChip(
          label: Text(s),
          selected: selected,
          onSelected: (_) => onSelectionChanged(() {
            selected ? selectedSubjects.remove(s) : selectedSubjects.add(s);
          }),
        );
      }).toList()),
      AppSpacing.gapMd,
      Text('Niveaux scolaires', style: Theme.of(context).textTheme.titleSmall),
      AppSpacing.gapSm,
      Wrap(spacing: 8, runSpacing: 8, children: grades.map((g) {
        final selected = selectedGrades.contains(g);
        return FilterChip(
          label: Text(g),
          selected: selected,
          onSelected: (_) => onSelectionChanged(() {
            selected ? selectedGrades.remove(g) : selectedGrades.add(g);
          }),
        );
      }).toList()),
      AppSpacing.gapLg,
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: onBack, child: const Text('← Retour'))),
        AppSpacing.gapMd,
        Expanded(child: ElevatedButton(
          onPressed: selectedSubjects.isEmpty ? null : onNext,
          child: const Text('Suivant →'),
        )),
      ]),
    ]),
  );
}

class _Step3Documents extends StatelessWidget {
  const _Step3Documents({
    required this.cvStoragePath,
    required this.idStoragePath,
    required this.isSubmitting,
    required this.onCvUpload,
    required this.onIdUpload,
    required this.onBack,
    required this.onSubmit,
  });

  final String? cvStoragePath, idStoragePath;
  final bool    isSubmitting;
  final ValueChanged<String> onCvUpload, onIdUpload;
  final VoidCallback onBack, onSubmit;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Documents justificatifs', style: Theme.of(context).textTheme.titleLarge),
      AppSpacing.gapSm,
      Text(
        'Vos documents sont chiffrés et ne seront vus que par notre équipe de vérification.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
      ),
      AppSpacing.gapLg,
      _DocUploadTile(
        title:     'CV / Curriculum Vitae',
        subtitle:  'PDF ou Word',
        uploaded:  cvStoragePath != null,
        onTap: () {
          // TODO: implement real file picker + Firebase Storage upload
          // Then call onCvUpload('gs://suklu-prod.appspot.com/applications/.../cv.pdf')
          onCvUpload('gs://suklu-prod.appspot.com/mock/cv.pdf');
        },
      ),
      AppSpacing.gapMd,
      _DocUploadTile(
        title:    'Pièce d\'identité nationale',
        subtitle: 'CNI, passeport ou carte consulaire (PDF/JPG)',
        uploaded:  idStoragePath != null,
        onTap: () {
          onIdUpload('gs://suklu-prod.appspot.com/mock/id.pdf');
        },
      ),
      AppSpacing.gapXl,
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: isSubmitting ? null : onBack, child: const Text('← Retour'))),
        AppSpacing.gapMd,
        Expanded(child: ElevatedButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Envoyer ma demande'),
        )),
      ]),
    ]),
  );
}

class _DocUploadTile extends StatelessWidget {
  const _DocUploadTile({required this.title, required this.subtitle, required this.uploaded, required this.onTap});
  final String title, subtitle; final bool uploaded; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      side: BorderSide(color: uploaded ? AppColors.success : AppColors.grey200),
    ),
    leading: CircleAvatar(
      backgroundColor: uploaded ? AppColors.success.withAlpha(30) : AppColors.grey100,
      child: Icon(uploaded ? Icons.check : Icons.upload_file_outlined,
          color: uploaded ? AppColors.success : AppColors.grey600),
    ),
    title: Text(title),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: TextButton(onPressed: onTap, child: Text(uploaded ? 'Modifier' : 'Ajouter')),
  );
}
