import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/firebase_providers.dart';
import '../shared/widgets/admin_data_table.dart';
import '../shared/widgets/status_badge.dart';

final _paymentStatusFilterProvider = StateProvider<String>((ref) => 'all');
final _paymentProviderFilterProvider = StateProvider<String>((ref) => 'all');

final _paymentsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String status, String provider})>((ref, filters) {
  final fs = ref.watch(firestoreProvider);
  Query<Map<String, dynamic>> q =
      fs.collection('payments').orderBy('createdAt', descending: true).limit(200);

  if (filters.status != 'all') {
    q = q.where('status', isEqualTo: filters.status);
  }
  if (filters.provider != 'all') {
    q = q.where('provider', isEqualTo: filters.provider);
  }

  return q.snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;
    final role = ref.watch(adminRoleProvider).valueOrNull;
    final status = ref.watch(_paymentStatusFilterProvider);
    final provider = ref.watch(_paymentProviderFilterProvider);
    final async = ref.watch(_paymentsProvider((status: status, provider: provider)));

    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Transactions', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Tous')),
                      ButtonSegment(value: 'pending', label: Text('pending')),
                      ButtonSegment(value: 'success', label: Text('success')),
                      ButtonSegment(value: 'failed', label: Text('failed')),
                      ButtonSegment(value: 'refunded', label: Text('refunded')),
                    ],
                    selected: {status},
                    onSelectionChanged: (v) => ref.read(_paymentStatusFilterProvider.notifier).state = v.first,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  value: provider,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous providers')),
                    DropdownMenuItem(value: 'flutterwave', child: Text('flutterwave')),
                    DropdownMenuItem(value: 'wave', child: Text('wave')),
                    DropdownMenuItem(value: 'orange_money', child: Text('orange_money')),
                  ],
                  onChanged: (v) => ref.read(_paymentProviderFilterProvider.notifier).state = v ?? 'all',
                ),
              ],
            )
          else
            Row(
              children: [
                Text('Transactions', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Tous')),
                    ButtonSegment(value: 'pending', label: Text('pending')),
                    ButtonSegment(value: 'success', label: Text('success')),
                    ButtonSegment(value: 'failed', label: Text('failed')),
                    ButtonSegment(value: 'refunded', label: Text('refunded')),
                  ],
                  selected: {status},
                  onSelectionChanged: (v) => ref.read(_paymentStatusFilterProvider.notifier).state = v.first,
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: provider,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous providers')),
                    DropdownMenuItem(value: 'flutterwave', child: Text('flutterwave')),
                    DropdownMenuItem(value: 'wave', child: Text('wave')),
                    DropdownMenuItem(value: 'orange_money', child: Text('orange_money')),
                  ],
                  onChanged: (v) => ref.read(_paymentProviderFilterProvider.notifier).state = v ?? 'all',
                ),
              ],
            ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              final totals = <String, double>{};
              for (final item in items) {
                final currency = (item['currency'] ?? 'XOF').toString().toUpperCase();
                totals[currency] = (totals[currency] ?? 0) + ((item['amount'] as num?)?.toDouble() ?? 0);
              }
              return Wrap(
                spacing: 16,
                children: totals.entries
                    .map((e) => Text('Total ${e.key} : ${e.value.toStringAsFixed(0)}'))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (payments) {
                final rows = payments
                    .map(
                      (p) => DataRow2(
                        onTap: role == 'super_admin'
                            ? () => _showWebhookDialog(context, p)
                            : null,
                        cells: [
                          DataCell(Text((p['id'] ?? '—').toString())),
                          DataCell(Text((p['bookingId'] ?? '—').toString())),
                          DataCell(Text((p['userId'] ?? '—').toString())),
                          DataCell(Text('${(p['amount'] ?? 0)}')),
                          DataCell(Text((p['currency'] ?? '—').toString())),
                          DataCell(Text((p['provider'] ?? '—').toString())),
                          DataCell(Text((p['providerTransactionId'] ?? '—').toString())),
                          DataCell(_status((p['status'] ?? '').toString())),
                          DataCell(Text(_fmt(p['createdAt']))),
                        ],
                      ),
                    )
                    .toList();

                return AdminDataTable(
                  columns: const [
                    DataColumn2(label: Text('ID transaction'), size: ColumnSize.L),
                    DataColumn2(label: Text('Réservation'), size: ColumnSize.M),
                    DataColumn2(label: Text('Utilisateur'), size: ColumnSize.M),
                    DataColumn2(label: Text('Montant'), size: ColumnSize.S),
                    DataColumn2(label: Text('Devise'), size: ColumnSize.S),
                    DataColumn2(label: Text('Fournisseur'), size: ColumnSize.S),
                    DataColumn2(label: Text('ID Fournisseur'), size: ColumnSize.M),
                    DataColumn2(label: Text('Statut'), size: ColumnSize.S),
                    DataColumn2(label: Text('Date'), size: ColumnSize.M),
                  ],
                  rows: rows,
                  isLoading: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _status(String status) {
    final bg = switch (status) {
      'success' => Colors.green.withValues(alpha: 0.15),
      'failed' => Colors.red.withValues(alpha: 0.15),
      'refunded' => Colors.purple.withValues(alpha: 0.15),
      _ => Colors.orange.withValues(alpha: 0.15),
    };
    final fg = switch (status) {
      'success' => Colors.green.shade700,
      'failed' => Colors.red.shade700,
      'refunded' => Colors.purple.shade700,
      _ => Colors.orange.shade700,
    };
    return StatusBadge(text: status, backgroundColor: bg, textColor: fg);
  }

  static String _fmt(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(ts.toDate());
  }

  static void _showWebhookDialog(BuildContext context, Map<String, dynamic> p) {
    final pretty = const JsonEncoder.withIndent('  ').convert(p['webhookPayload'] ?? {'message': 'Aucun payload'});
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('webhookPayload'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(pretty),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
