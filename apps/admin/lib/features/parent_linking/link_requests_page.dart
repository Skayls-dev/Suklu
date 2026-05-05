import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/firebase_providers.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class _LinkRequestRow {
  const _LinkRequestRow({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.parentEmail,
    required this.studentEmail,
    required this.relationship,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String   id;
  final String   parentId;
  final String   studentId;
  final String   parentEmail;
  final String   studentEmail;
  final String   relationship;
  final String   status;
  final DateTime createdAt;
  final String?  rejectionReason;

  factory _LinkRequestRow.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _LinkRequestRow(
      id:              doc.id,
      parentId:        d['parentId']     as String? ?? '',
      studentId:       d['studentId']    as String? ?? '',
      parentEmail:     d['parentEmail']  as String? ?? '—',
      studentEmail:    d['studentEmail'] as String? ?? '—',
      relationship:    d['relationship'] as String? ?? '—',
      status:          d['status']       as String? ?? 'pending_admin_verification',
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      rejectionReason: d['rejectionReason'] as String?,
    );
  }

  String get relationshipLabel => switch (relationship) {
    'guardian'    => 'Tuteur légal',
    'grandparent' => 'Grand-parent',
    'other'       => 'Autre',
    _             => 'Parent',
  };

  String get statusLabel => switch (status) {
    'approved' => 'Approuvé',
    'rejected' => 'Refusé',
    _          => 'En attente',
  };

  Color get statusColor => switch (status) {
    'approved' => Colors.green,
    'rejected' => Colors.red,
    _          => Colors.orange,
  };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _linkFilterProvider = StateProvider<String>((ref) => 'pending_admin_verification');

final _linkRequestsProvider = StreamProvider.autoDispose
    .family<List<_LinkRequestRow>, String>((ref, filter) {
  final fs = ref.watch(firestoreProvider);
  Query q  = fs.collection('link_requests').orderBy('createdAt', descending: true);

  if (filter != 'all') {
    q = q.where('status', isEqualTo: filter);
  }

  return q.snapshots().map(
    (snap) => snap.docs.map(_LinkRequestRow.fromDoc).toList(),
  );
});

// ── Page ──────────────────────────────────────────────────────────────────────
class LinkRequestsPage extends ConsumerWidget {
  const LinkRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_linkFilterProvider);
    final async  = ref.watch(_linkRequestsProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Text('Liaisons parent-enfant', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending_admin_verification', label: Text('En attente')),
                  ButtonSegment(value: 'all',      label: Text('Toutes')),
                  ButtonSegment(value: 'approved', label: Text('Approuvées')),
                  ButtonSegment(value: 'rejected', label: Text('Refusées')),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(_linkFilterProvider.notifier).state = s.first,
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
                : _LinkRequestsTable(rows: rows),
          ),
        ),
      ],
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────
class _LinkRequestsTable extends StatelessWidget {
  const _LinkRequestsTable({required this.rows});
  final List<_LinkRequestRow> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn2(label: Text('Email parent'),  size: ColumnSize.L),
          DataColumn2(label: Text('Email enfant'),  size: ColumnSize.L),
          DataColumn2(label: Text('Lien'),          size: ColumnSize.M),
          DataColumn2(label: Text('Statut'),        size: ColumnSize.M),
          DataColumn2(label: Text('Date'),          size: ColumnSize.M),
          DataColumn2(label: Text('Actions'),       size: ColumnSize.M, numeric: true),
        ],
        rows: rows.map((row) => DataRow2(
          cells: [
            DataCell(Text(row.parentEmail,  overflow: TextOverflow.ellipsis)),
            DataCell(Text(row.studentEmail, overflow: TextOverflow.ellipsis)),
            DataCell(Text(row.relationshipLabel)),
            DataCell(_StatusChip(label: row.statusLabel, color: row.statusColor)),
            DataCell(Text(DateFormat('dd/MM/yy').format(row.createdAt))),
            DataCell(
              row.status == 'pending_admin_verification'
                  ? _LinkActionButtons(row: row)
                  : const SizedBox.shrink(),
            ),
          ],
        )).toList(),
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────
class _LinkActionButtons extends ConsumerStatefulWidget {
  const _LinkActionButtons({required this.row});
  final _LinkRequestRow row;

  @override
  ConsumerState<_LinkActionButtons> createState() => _LinkActionButtonsState();
}

class _LinkActionButtonsState extends ConsumerState<_LinkActionButtons> {
  bool _loading = false;

  Future<void> _decide(String decision, {String? reason}) async {
    setState(() => _loading = true);
    try {
      final fn = ref.read(functionsProvider);
      await fn.httpsCallable('verifyParentLink').call({
        'requestId': widget.row.id,
        'decision':  decision,
        if (reason != null) 'rejectionReason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'approve' ? 'Lien approuvé.' : 'Lien refusé.'),
            backgroundColor: decision == 'approve' ? Colors.green : Colors.red,
          ),
        );
      }
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Approuver',
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          onPressed: () => _decide('approve'),
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
    if (reason != null) await _decide('reject', reason: reason.isEmpty ? null : reason);
  }
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
