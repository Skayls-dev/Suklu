import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../shared/widgets/admin_data_table.dart';

final flaggedStatusFilterProvider = StateProvider<String>((ref) => 'pending_review');

final flaggedContentProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) {
  final fs = ref.watch(firestoreProvider);
  Query<Map<String, dynamic>> q = fs.collection('flagged_content').orderBy('createdAt', descending: true).limit(50);
  if (status != 'all') q = q.where('status', isEqualTo: status);
  return q.snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class FlaggedContentPanel extends ConsumerWidget {
  const FlaggedContentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(flaggedStatusFilterProvider);
    final async = ref.watch(flaggedContentProvider(status));

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending_review', label: Text('En attente')),
              ButtonSegment(value: 'reviewed_safe', label: Text('Sûr')),
              ButtonSegment(value: 'reviewed_harmful', label: Text('Nuisible')),
              ButtonSegment(value: 'all', label: Text('Tous')),
            ],
            selected: {status},
            onSelectionChanged: (v) => ref.read(flaggedStatusFilterProvider.notifier).state = v.first,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (rowsData) {
              final rows = rowsData
                  .map((r) => DataRow2(cells: [
                        DataCell(Text((r['userId'] ?? '—').toString())),
                        DataCell(Text((r['endpoint'] ?? '—').toString())),
                        DataCell(Text(((r['contentSnippet'] ?? '—').toString()).substring(0, ((r['contentSnippet'] ?? '—').toString().length > 300) ? 300 : (r['contentSnippet'] ?? '—').toString().length))),
                        DataCell(Text((r['matchedPattern'] ?? '—').toString())),
                        DataCell(Text(_fmt(r['createdAt']))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _review(ref, r['id'].toString(), 'reviewed_safe'),
                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              ),
                              IconButton(
                                onPressed: () => _review(ref, r['id'].toString(), 'reviewed_harmful'),
                                icon: const Icon(Icons.block_outlined, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ]))
                  .toList();

              return AdminDataTable(
                columns: const [
                  DataColumn2(label: Text('Utilisateur'), size: ColumnSize.M),
                  DataColumn2(label: Text('Endpoint'), size: ColumnSize.S),
                  DataColumn2(label: Text('Snippet'), size: ColumnSize.L),
                  DataColumn2(label: Text('Pattern'), size: ColumnSize.S),
                  DataColumn2(label: Text('Date'), size: ColumnSize.S),
                  DataColumn2(label: Text('Actions'), size: ColumnSize.S),
                ],
                rows: rows,
                isLoading: false,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _review(WidgetRef ref, String id, String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await ref.read(firestoreProvider).collection('flagged_content').doc(id).set({
      'status': status,
      'reviewedBy': uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _fmt(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM HH:mm', 'fr').format(ts.toDate());
  }
}
