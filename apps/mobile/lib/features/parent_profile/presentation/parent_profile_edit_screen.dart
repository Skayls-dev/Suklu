import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/parent_profile_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider — stream own parent profile from Firestore
// ─────────────────────────────────────────────────────────────────────────────
final _ownParentProfileProvider = StreamProvider.autoDispose<ParentProfileModel?>((ref) {
  final uid = ref.watch(authStateNotifierProvider).value?.uid;
  final fullName = ref.watch(authStateNotifierProvider).value?.displayName ?? '';
  if (uid == null) return const Stream.empty();
  
  return ref
      .watch(firestoreProvider)
      .collection('parent_profiles')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists 
          ? ParentProfileModel.fromFirestore(snap) 
          : ParentProfileModel.empty(uid, fullName));
});

// ─────────────────────────────────────────────────────────────────────────────
// ParentProfileEditScreen
// ─────────────────────────────────────────────────────────────────────────────
class ParentProfileEditScreen extends ConsumerStatefulWidget {
  const ParentProfileEditScreen({super.key});

  @override
  ConsumerState<ParentProfileEditScreen> createState() => _ParentProfileEditScreenState();
}

class _ParentProfileEditScreenState extends ConsumerState<ParentProfileEditScreen> {
  bool _loaded = false;
  bool _saving = false;

  int _numberOfChildren  = 1;
  String _communicationPref = 'Email';
  final _notesCtrl = TextEditingController();

  static const _commPreferences = ['Email', 'SMS', 'WhatsApp', 'Appel téléphonique'];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _loadFromProfile(ParentProfileModel profile) {
    if (_loaded) return;
    _loaded = true;
    _numberOfChildren = profile.numberOfChildren;
    _communicationPref = profile.communicationPreference;
    _notesCtrl.text = profile.notes;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_ownParentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (profile) {
        if (profile != null) _loadFromProfile(profile);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon profil parent'),
            backgroundColor: AppColors.tutorAccent,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                AppSpacing.gapMd,
                
                // Number of children
                DropdownButtonFormField<int>(
                  value: _numberOfChildren,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Nombre d\'enfants',
                    prefixIcon: const Icon(Icons.groups),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: List.generate(10, (i) => i + 1)
                      .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text(n == 1 ? '$n enfant' : '$n enfants'),
                      ))
                      .toList(),
                  onChanged: (v) => setState(() => _numberOfChildren = v ?? 1),
                ),
                AppSpacing.gapLg,

                // Communication preference
                DropdownButtonFormField<String>(
                  value: _communicationPref,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Préférence de communication',
                    prefixIcon: const Icon(Icons.mail_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _commPreferences
                      .map((pref) => DropdownMenuItem(value: pref, child: Text(pref)))
                      .toList(),
                  onChanged: (v) => setState(() => _communicationPref = v ?? 'Email'),
                ),
                AppSpacing.gapLg,

                // Notes
                Text('Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                AppSpacing.gapMd,
                TextField(
                  controller: _notesCtrl,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Ajoutez des notes particulières pour l\'équipe Suklu (ex : allergies, régimes spéciaux, infos importantes)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
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
      await ref.read(firestoreProvider).collection('parent_profiles').doc(uid).set({
        'uid':                      uid,
        'fullName':                 ref.read(authStateNotifierProvider).value?.displayName ?? '',
        'numberOfChildren':         _numberOfChildren,
        'communicationPreference':  _communicationPref,
        'notes':                    _notesCtrl.text.trim(),
        'updatedAt':                FieldValue.serverTimestamp(),
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
