import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'auth_providers.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _codeSent    = false;
  bool _loading     = false;
  ConfirmationResult? _confirmationResult;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authStateNotifierProvider.notifier)
          .sendPhoneOtp(phone);
      setState(() {
        _confirmationResult = result as ConfirmationResult;
        _codeSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_confirmationResult == null) return;
    final code = _otpCtrl.text.trim();
    if (code.length != 6) return;
    setState(() => _loading = true);
    try {
      await ref.read(authStateNotifierProvider.notifier).verifyPhoneOtp(
        confirmationResult: _confirmationResult,
        smsCode:            code,
      );
      // GoRouter redirect will handle navigation after auth state changes
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code invalide: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion par téléphone')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.gapXl,
              const Icon(Icons.phone_outlined, size: 64, color: AppColors.primary),
              AppSpacing.gapMd,
              Text(
                _codeSent
                    ? 'Entrez le code reçu par SMS'
                    : 'Entrez votre numéro de téléphone',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXl,

              if (!_codeSent) ...[
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro (ex: +221 77 000 00 00)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                AppSpacing.gapLg,
                ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Envoyer le code'),
                ),
              ] else ...[
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Code à 6 chiffres',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                ),
                AppSpacing.gapLg,
                ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Valider'),
                ),
                AppSpacing.gapMd,
                TextButton(
                  onPressed: _loading ? null : () => setState(() { _codeSent = false; _otpCtrl.clear(); }),
                  child: const Text('Changer le numéro'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
