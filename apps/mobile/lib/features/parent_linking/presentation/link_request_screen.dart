import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/firebase_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LinkRequestScreen
//
// Parents use this to request account linking with their child.
// Flow:
//   1. Enter child's email address and relationship.
//   2. requestParentLink Cloud Function looks up the student, creates
//      a /link_requests/{id} doc with status pending_admin_verification.
//   3. Admin reviews via admin panel (verifyParentLink function).
//   4. On approval, both user docs are updated bidirectionally.
// ─────────────────────────────────────────────────────────────────────────────

final _linkRequestProvider =
    AsyncNotifierProvider.autoDispose<_LinkRequestNotifier, void>(
  _LinkRequestNotifier.new,
);

class _LinkRequestNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> requestLink({
    required String email,
    required String relationship,
  }) async {
    state = const AsyncLoading();
    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final result    = await functions
          .httpsCallable('requestParentLink')
          .call<Map<String, dynamic>>({
        'studentEmail': email,
        'relationship': relationship,
      });
      state = const AsyncData(null);
      return result.data['requestId'] as String;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

class LinkRequestScreen extends ConsumerStatefulWidget {
  const LinkRequestScreen({super.key});

  @override
  ConsumerState<LinkRequestScreen> createState() => _LinkRequestScreenState();
}

class _LinkRequestScreenState extends ConsumerState<LinkRequestScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  String _relationship = 'parent';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(_linkRequestProvider.notifier).requestLink(
        email:        _emailCtrl.text.trim(),
        relationship: _relationship,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
            title: const Text('Demande envoyée'),
            content: const Text(
              'Notre équipe va vérifier le lien et l\'activer dans les 24h.\n'
              'Vous recevrez une notification lorsque c\'est approuvé.',
            ),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_linkRequestProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Lier un compte enfant')),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.info.withAlpha(60)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Votre enfant doit déjà avoir un compte Suklu. '
                      'La liaison sera vérifiée par notre équipe.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
              ),
              AppSpacing.gapLg,

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email du compte de votre enfant',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Email requis';
                  if (!v!.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              AppSpacing.gapMd,

              DropdownButtonFormField<String>(
                value: _relationship,
                decoration: const InputDecoration(
                  labelText: 'Lien de parenté',
                  prefixIcon: Icon(Icons.family_restroom_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'parent',      child: Text('Parent')),
                  DropdownMenuItem(value: 'guardian',    child: Text('Tuteur légal')),
                  DropdownMenuItem(value: 'grandparent', child: Text('Grand-parent')),
                  DropdownMenuItem(value: 'other',       child: Text('Autre')),
                ],
                onChanged: (v) => setState(() => _relationship = v!),
              ),
              AppSpacing.gapXl,

              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer la demande de liaison'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
