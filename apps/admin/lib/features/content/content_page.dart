import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/firebase_providers.dart';
import '../shared/widgets/admin_data_table.dart';
import '../shared/widgets/confirm_dialog.dart';
import 'widgets/ai_logs_panel.dart';
import 'widgets/flagged_content_panel.dart';
import 'widgets/image_preview_dialog.dart';
import 'widgets/upload_rag_dialog.dart';

const _aiGatewayUrl = String.fromEnvironment(
  'AI_GATEWAY_URL',
  defaultValue: 'http://localhost:8000',
);

final ragDocumentsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('rag_documents')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(adminRoleProvider).valueOrNull;

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 24),
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Curriculum RAG'),
                Tab(text: 'Contenus signalés'),
                Tab(text: 'Logs IA'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _RagDocumentsPanel(role: role),
                  const FlaggedContentPanel(),
                  const AiLogsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RagDocumentsPanel extends ConsumerWidget {
  const _RagDocumentsPanel({required this.role});

  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ragDocumentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => showUploadRagDialog(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Ingérer un nouveau document'),
            ),
            const SizedBox(width: 12),
            const Text('Gestion RAG multimodale activée.'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (docs) {
              final rows = docs
                  .map(
                    (d) => DataRow2(cells: [
                      DataCell(Text((d['filename'] ?? '—').toString())),
                      DataCell(Text((d['subject'] ?? '—').toString())),
                      DataCell(Text((d['grade_level'] ?? d['gradeLevel'] ?? '—').toString())),
                      DataCell(Text((d['country'] ?? '—').toString())),
                      DataCell(Text('${d['chunkCount'] ?? 0}')),
                      DataCell(
                        Text(
                          '${d['imageChunkCount'] ?? 0}',
                          style: TextStyle(
                            color: (d['imageChunkCount'] ?? 0) > 0 ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text((d['status'] ?? '—').toString())),
                      DataCell(Text((d['createdAt'] ?? '—').toString())),
                      DataCell(
                        Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Voir les images',
                              icon: const Icon(Icons.image_outlined),
                              onPressed: () => _showImages(context, ref, d['id'].toString()),
                            ),
                            if (role == 'super_admin')
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteDoc(context, ref, d['id'].toString()),
                              ),
                          ],
                        ),
                      ),
                    ]),
                  )
                  .toList();

              return AdminDataTable(
                columns: const [
                  DataColumn2(label: Text('Fichier'), size: ColumnSize.L),
                  DataColumn2(label: Text('Matière'), size: ColumnSize.S),
                  DataColumn2(label: Text('Niveau'), size: ColumnSize.S),
                  DataColumn2(label: Text('Pays'), size: ColumnSize.S),
                  DataColumn2(label: Text('Chunks'), size: ColumnSize.S),
                  DataColumn2(label: Text('Images'), size: ColumnSize.S),
                  DataColumn2(label: Text('Statut'), size: ColumnSize.S),
                  DataColumn2(label: Text('Uploadé le'), size: ColumnSize.M),
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

  Future<void> _deleteDoc(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce document',
      message: 'Confirmer la suppression du document RAG ?',
    );
    if (!ok) return;
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http.delete(
      Uri.parse('$_aiGatewayUrl/ingest/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!context.mounted) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression: ${response.statusCode} ${response.body}')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document supprimé.')),
    );
  }

  Future<void> _showImages(BuildContext context, WidgetRef ref, String id) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ImagePreviewDialog(docId: id),
    );
  }
}
