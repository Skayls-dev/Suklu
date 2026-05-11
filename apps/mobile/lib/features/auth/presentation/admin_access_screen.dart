import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import 'auth_providers.dart';

class AdminAccessScreen extends ConsumerWidget {
  const AdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compte administration')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 72),
                AppSpacing.gapLg,
                Text(
                  'Ce compte appartient à l\'espace administration.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapMd,
                Text(
                  'L\'application mobile ne propose pas de dashboard super admin. Utilisez l\'application admin dédiée pour gérer les tuteurs, utilisateurs, paiements et logs.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXl,
                FilledButton(
                  onPressed: () => ref.read(authStateNotifierProvider.notifier).signOut(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}