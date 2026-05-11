import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/firebase_providers.dart';
import '../shared/widgets/admin_data_table.dart';
import '../shared/widgets/confirm_dialog.dart';
import '../shared/widgets/status_badge.dart';
import 'user_detail_dialog.dart';

final _userRoleFilterProvider = StateProvider<String>((ref) => 'all');
final _userSearchProvider = StateProvider<String>((ref) => '');

final _usersProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, roleFilter) {
    final fs = ref.watch(firestoreProvider);
    Query<Map<String, dynamic>> query =
        fs.collection('users').orderBy('createdAt', descending: true).limit(100);
    if (roleFilter != 'all') {
      query = query.where('role', isEqualTo: roleFilter);
    }
    return query.snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  },
);

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(adminRoleProvider).valueOrNull;
    final roleFilter = ref.watch(_userRoleFilterProvider);
    final search = ref.watch(_userSearchProvider).toLowerCase().trim();
    final usersAsync = ref.watch(_usersProvider(roleFilter));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Tous')),
                    ButtonSegment(value: 'student', label: Text('Étudiant')),
                    ButtonSegment(value: 'parent', label: Text('Parent')),
                    ButtonSegment(value: 'tutor', label: Text('Tuteur')),
                    ButtonSegment(value: 'academic_staff', label: Text('Staff')),
                    ButtonSegment(value: 'super_admin', label: Text('Admin')),
                  ],
                  selected: {roleFilter},
                  onSelectionChanged: (v) => ref.read(_userRoleFilterProvider.notifier).state = v.first,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Nom ou email',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => ref.read(_userSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 12),
              if (role == 'super_admin')
                FilledButton.icon(
                  onPressed: () {
                    final list = usersAsync.valueOrNull ?? const <Map<String, dynamic>>[];
                    _exportCsv(list.where((u) {
                      final name = (u['displayName'] ?? '').toString().toLowerCase();
                      final email = (u['email'] ?? '').toString().toLowerCase();
                      return search.isEmpty || name.contains(search) || email.contains(search);
                    }).toList());
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Exporter CSV'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: usersAsync.when(
              loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (users) {
                final filtered = users.where((u) {
                  if (search.isEmpty) return true;
                  final name = (u['displayName'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  return name.contains(search) || email.contains(search);
                }).toList();

                final rows = filtered
                    .map(
                      (u) => DataRow2(cells: [
                        DataCell(Text((u['displayName'] ?? '—').toString())),
                        DataCell(Text((u['email'] ?? '—').toString())),
                        DataCell(Text((u['role'] ?? '—').toString())),
                        DataCell(Text((u['country'] ?? '—').toString())),
                        DataCell(
                          StatusBadge(
                            text: ((u['isActive'] ?? true) as bool) ? 'Actif' : 'Inactif',
                            backgroundColor: ((u['isActive'] ?? true) as bool)
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            textColor: ((u['isActive'] ?? true) as bool)
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        DataCell(Text(_formatDate(u['createdAt']))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Voir',
                              onPressed: () => showUserDetailDialog(context, user: u, role: role ?? ''),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            if (role == 'super_admin')
                              IconButton(
                                tooltip: 'Changer rôle',
                                onPressed: () => _showRoleDialog(context, ref, u),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            IconButton(
                              tooltip: ((u['isActive'] ?? true) as bool) ? 'Désactiver' : 'Activer',
                              onPressed: () => _toggleActive(context, ref, u),
                              icon: Icon(
                                ((u['isActive'] ?? true) as bool)
                                    ? Icons.block_outlined
                                    : Icons.check_circle_outline,
                                color: ((u['isActive'] ?? true) as bool)
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        )),
                      ]),
                    )
                    .toList();

                return AdminDataTable(
                  isLoading: false,
                  emptyMessage: 'Aucun utilisateur',
                  columns: const [
                    DataColumn2(label: Text('Nom'), size: ColumnSize.L),
                    DataColumn2(label: Text('Email'), size: ColumnSize.L),
                    DataColumn2(label: Text('Rôle'), size: ColumnSize.M),
                    DataColumn2(label: Text('Pays'), size: ColumnSize.S),
                    DataColumn2(label: Text('Statut'), size: ColumnSize.S),
                    DataColumn2(label: Text('Créé le'), size: ColumnSize.M),
                    DataColumn2(label: Text('Actions'), size: ColumnSize.L),
                  ],
                  rows: rows,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy', 'fr').format(ts.toDate());
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Map<String, dynamic> user) async {
    final uid = (user['uid'] ?? user['id']).toString();
    final current = (user['isActive'] ?? true) as bool;
    final ok = await showConfirmDialog(
      context,
      title: current ? 'Désactiver le compte' : 'Activer le compte',
      message: current
          ? 'Confirmer la désactivation de ce compte ?'
          : 'Confirmer la réactivation de ce compte ?',
      confirmColor: current ? Colors.red : Colors.green,
    );
    if (!ok) return;

    await ref.read(firestoreProvider).collection('users').doc(uid).set(
      {'isActive': !current},
      SetOptions(merge: true),
    );
  }

  Future<void> _showRoleDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) async {
    String selected = (user['role'] ?? 'student').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le rôle'),
        content: DropdownButtonFormField<String>(
          value: selected,
          items: const [
            DropdownMenuItem(value: 'student', child: Text('student')),
            DropdownMenuItem(value: 'parent', child: Text('parent')),
            DropdownMenuItem(value: 'tutor', child: Text('tutor')),
            DropdownMenuItem(value: 'academic_staff', child: Text('academic_staff')),
            DropdownMenuItem(value: 'super_admin', child: Text('super_admin')),
          ],
          onChanged: (v) => selected = v ?? selected,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = (user['uid'] ?? user['id']).toString();
      await ref.read(functionsProvider).httpsCallable('setUserRole').call({'uid': uid, 'role': selected});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rôle mis à jour.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de rôle: ${e.message ?? e.code}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> users) async {
    final header = 'uid,email,displayName,role,isActive,country,createdAt';
    final lines = users.map((u) {
      final values = [
        (u['uid'] ?? u['id']).toString(),
        (u['email'] ?? '').toString(),
        (u['displayName'] ?? '').toString(),
        (u['role'] ?? '').toString(),
        ((u['isActive'] ?? true) as bool).toString(),
        (u['country'] ?? '').toString(),
        _formatDate(u['createdAt']),
      ].map((v) => '"${v.replaceAll('"', '""')}"').join(',');
      return values;
    });

    final csv = '$header\n${lines.join('\n')}';
    final dataUri = Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8);
    await launchUrl(dataUri, webOnlyWindowName: '_blank');
  }
}
