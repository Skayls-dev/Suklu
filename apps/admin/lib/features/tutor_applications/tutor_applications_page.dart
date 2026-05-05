import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/firebase_providers.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class _ApplicationRow {
  const _ApplicationRow({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.subjects,
    required this.gradeLevels,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.country,
  });

  final String       id;
  final String       userId;
  final String       fullName;
  final List<String> subjects;
  final List<String> gradeLevels;
  final String       status;
  final DateTime     createdAt;
  final String?      rejectionReason;
  final String?      country;

  factory _ApplicationRow.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ApplicationRow(
      id:              doc.id,
      userId:          d['userId']   as String? ?? '',
      fullName:        d['fullName'] as String? ?? '—',
      subjects:        List<String>.from(d['subjects']    ?? []),
      gradeLevels:     List<String>.from(d['gradeLevels'] ?? []),
      status:          d['status']   as String? ?? 'pending_document_review',
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      rejectionReason: d['rejectionReason'] as String?,
      country:         d['country']  as String?,
    );
  }

  String get statusLabel => switch (status) {
    'background_check_pending' => 'Vérif. fond',
    'approved'                 => 'Approuvé',
    'rejected'                 => 'Refusé',
    _                          => 'En attente docs',
  };

  Color get statusColor => switch (status) {
    'approved' => Colors.green,
    'rejected' => Colors.red,
    'background_check_pending' => Colors.orange,
    _ => Colors.blue,
  };
}

// ── Provider ──────────────────────────────────────────────────────────────────
final _filterProvider = StateProvider<String>((ref) => 'pending');

final _applicationsProvider = StreamProvider.autoDispose
    .family<List<_ApplicationRow>, String>((ref, filter) {
  final fs = ref.watch(firestoreProvider);
  Query q  = fs.collection('tutor_applications').orderBy('createdAt', descending: true);

  if (filter == 'pending') {
    q = q.where('status', whereIn: ['pending_document_review', 'background_check_pending']);
  } else if (filter != 'all') {
    q = q.where('status', isEqualTo: filter);
  }

  return q.snapshots().map(
    (snap) => snap.docs.map(_ApplicationRow.fromDoc).toList(),
  );
});

// ── Page ──────────────────────────────────────────────────────────────────────
class TutorApplicationsPage extends ConsumerWidget {
  const TutorApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final async  = ref.watch(_applicationsProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Text('Demandes tuteurs', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('En attente')),
                  ButtonSegment(value: 'all',     label: Text('Toutes')),
                  ButtonSegment(value: 'approved', label: Text('Approuvées')),
                  ButtonSegment(value: 'rejected', label: Text('Refusées')),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(_filterProvider.notifier).state = s.first,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => Center(child: Text('Erreur: $e')),
            data:    (rows) => rows.isEmpty
                ? const Center(child: Text('Aucune demande dans cette catégorie.'))
                : _ApplicationsTable(rows: rows),
          ),
        ),
      ],
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────
class _ApplicationsTable extends ConsumerWidget {
  const _ApplicationsTable({required this.rows});
  final List<_ApplicationRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn2(label: Text('Nom'),         size: ColumnSize.L),
          DataColumn2(label: Text('Matières'),    size: ColumnSize.L),
          DataColumn2(label: Text('Pays'),        size: ColumnSize.S),
          DataColumn2(label: Text('Statut'),      size: ColumnSize.M),
          DataColumn2(label: Text('Soumis le'),   size: ColumnSize.M),
          DataColumn2(label: Text('Actions'),     size: ColumnSize.M, numeric: true),
        ],
        rows: rows.map((row) => DataRow2(
          onTap: () => _showDetail(context, ref, row),
          cells: [
            DataCell(Text(row.fullName)),
            DataCell(Text(row.subjects.take(3).join(', ') +
                (row.subjects.length > 3 ? '…' : ''))),
            DataCell(Text(row.country ?? '—')),
            DataCell(_StatusChip(label: row.statusLabel, color: row.statusColor)),
            DataCell(Text(DateFormat('dd/MM/yy').format(row.createdAt))),
            DataCell(
              (row.status == 'pending_document_review' ||
               row.status == 'background_check_pending')
                  ? _ActionButtons(row: row)
                  : const SizedBox.shrink(),
            ),
          ],
        )).toList(),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, _ApplicationRow row) {
    showDialog(
      context: context,
      builder: (_) => _DetailDialog(row: row),
    );
  }
}

// ── Quick action buttons in table row ────────────────────────────────────────
class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({required this.row});
  final _ApplicationRow row;

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _loading = false;

  Future<void> _call(String decision, {String? reason}) async {
    setState(() => _loading = true);
    try {
      final fn = ref.read(functionsProvider);
      await fn.httpsCallable('reviewApplication').call({
        'applicationId':  widget.row.id,
        'decision':       decision,
        if (reason != null) 'rejectionReason': reason,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));

    final isPendingDocs = widget.row.status == 'pending_document_review';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isPendingDocs ? 'Valider les documents' : 'Approuver (fond OK)',
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          onPressed: () => _call(isPendingDocs ? 'approve_documents' : 'approve_background'),
        ),
        IconButton(
          tooltip: 'Refuser',
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          onPressed: () => _promptReject(context),
        ),
      ],
    );
  }

  void _promptReject(BuildContext context) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motif de refus'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Motif (facultatif)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (reason != null) await _call('reject', reason: reason.isEmpty ? null : reason);
  }
}

// ── Detail dialog ─────────────────────────────────────────────────────────────
class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.row});
  final _ApplicationRow row;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(row.fullName),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Statut', row.statusLabel),
            _DetailRow('Pays', row.country ?? '—'),
            _DetailRow('Matières', row.subjects.join(', ')),
            _DetailRow('Niveaux', row.gradeLevels.join(', ')),
            _DetailRow('ID utilisateur', row.userId),
            _DetailRow('Soumis le', DateFormat('dd/MM/yyyy à HH:mm').format(row.createdAt)),
            if (row.rejectionReason != null)
              _DetailRow('Motif de refus', row.rejectionReason!),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
