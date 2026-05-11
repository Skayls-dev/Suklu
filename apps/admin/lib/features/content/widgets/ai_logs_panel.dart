import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../shared/widgets/admin_data_table.dart';

final aiLogsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('ai_logs')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class AiLogsPanel extends ConsumerWidget {
  const AiLogsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiLogsProvider);

    return async.when(
      loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (logs) {
        final totalTokens = logs.fold<int>(0, (sum, l) {
          final usage = (l['usage'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final p = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
          final r = (usage['completion_tokens'] as num?)?.toInt() ?? 0;
          return sum + p + r;
        });

        final totalChunks = logs.fold<int>(0, (sum, l) => sum + ((l['ragChunksCount'] as num?)?.toInt() ?? 0));
        final avgChunks = logs.isEmpty ? 0.0 : totalChunks / logs.length;

        final rows = logs
            .map(
              (l) => DataRow2(
                onTap: () => _showLogDialog(context, l),
                cells: [
                  DataCell(Text((l['userId'] ?? '—').toString())),
                  DataCell(Text((l['endpoint'] ?? '—').toString())),
                  DataCell(Text((l['subject'] ?? '—').toString())),
                  DataCell(Text((l['gradeLevel'] ?? '—').toString())),
                  DataCell(Text('${l['ragChunksCount'] ?? 0}')),
                  DataCell(Text('${((l['usage'] as Map<String, dynamic>?)?['prompt_tokens'] ?? 0)}')),
                  DataCell(Text('${((l['usage'] as Map<String, dynamic>?)?['completion_tokens'] ?? 0)}')),
                  DataCell(Text(_fmt(l['createdAt']))),
                ],
              ),
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tokens totaux (100 derniers logs) : $totalTokens'),
            Text('Moy. chunks RAG : ${avgChunks.toStringAsFixed(1)}'),
            const SizedBox(height: 12),
            Expanded(
              child: AdminDataTable(
                columns: const [
                  DataColumn2(label: Text('Utilisateur'), size: ColumnSize.M),
                  DataColumn2(label: Text('Endpoint'), size: ColumnSize.S),
                  DataColumn2(label: Text('Matière'), size: ColumnSize.S),
                  DataColumn2(label: Text('Niveau'), size: ColumnSize.S),
                  DataColumn2(label: Text('Chunks RAG'), size: ColumnSize.S),
                  DataColumn2(label: Text('Tokens prompt'), size: ColumnSize.S),
                  DataColumn2(label: Text('Tokens réponse'), size: ColumnSize.S),
                  DataColumn2(label: Text('Date'), size: ColumnSize.S),
                ],
                rows: rows,
                isLoading: false,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmt(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM HH:mm', 'fr').format(ts.toDate());
  }

  static void _showLogDialog(BuildContext context, Map<String, dynamic> log) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Détail log IA'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText((log['prompt'] ?? '').toString()),
                const SizedBox(height: 16),
                const Text('Réponse', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText((log['response'] ?? '').toString()),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
