import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/firebase_providers.dart';
import '../shared/widgets/confirm_dialog.dart';

Future<void> showUserDetailDialog(
  BuildContext context, {
  required Map<String, dynamic> user,
  required String role,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UserDetailDialog(user: user, role: role),
  );
}

final _recentBookingsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, uid) {
  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('bookings')
      .where('studentId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class _UserDetailDialog extends ConsumerWidget {
  const _UserDetailDialog({required this.user, required this.role});

  final Map<String, dynamic> user;
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = (user['uid'] ?? '').toString();
    final bookingsAsync = ref.watch(_recentBookingsProvider(uid));

    return AlertDialog(
      title: const Text('Détails utilisateur'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('UID', uid),
              _kv('Email', (user['email'] ?? '—').toString()),
              _kv('Nom', (user['displayName'] ?? '—').toString()),
              _kv('Rôle', (user['role'] ?? '—').toString()),
              _kv('Pays', (user['country'] ?? '—').toString()),
              _kv('Actif', ((user['isActive'] ?? true) as bool) ? 'Oui' : 'Non'),
              _kv('Créé le', _formatDate(user['createdAt'])),
              const SizedBox(height: 16),
              Text('Réservations récentes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur: $e'),
                data: (rows) {
                  if (rows.isEmpty) return const Text('Aucune réservation récente.');
                  return Column(
                    children: rows
                        .map(
                          (r) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text((r['subjectId'] ?? '—').toString()),
                            subtitle: Text('Statut: ${(r['status'] ?? '—')}'),
                            trailing: Text(_formatDate(r['createdAt'])),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if ((user['role'] ?? '') == 'tutor') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await launchUrl(
                      Uri.parse('https://suklu.app/tutors/$uid'),
                      webOnlyWindowName: '_blank',
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impossible d\'ouvrir le profil tuteur')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir profil tuteur'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (role == 'super_admin')
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Désactiver le compte',
                message: 'Voulez-vous désactiver ce compte ?'
              );
              if (!confirmed || !context.mounted) return;
              await ref.read(firestoreProvider).collection('users').doc(uid).set(
                {'isActive': false},
                SetOptions(merge: true),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Désactiver le compte'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(ts.toDate());
  }
}
