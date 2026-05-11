import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/firebase_providers.dart';
import '../shared/widgets/admin_data_table.dart';
import '../shared/widgets/status_badge.dart';

final _sessionStatusFilterProvider = StateProvider<String>((ref) => 'all');
final _sessionDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final _sessionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) {
  final fs = ref.watch(firestoreProvider);
  Query<Map<String, dynamic>> q =
      fs.collection('sessions').orderBy('scheduledAt', descending: true).limit(200);
  if (status != 'all') {
    q = q.where('status', isEqualTo: status);
  }
  return q.snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_sessionStatusFilterProvider);
    final range = ref.watch(_sessionDateRangeProvider);
    final async = ref.watch(_sessionsProvider(status));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sessions', style: Theme.of(context).textTheme.headlineSmall),
              Row(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Toutes')),
                      ButtonSegment(value: 'scheduled', label: Text('Planifiées')),
                      ButtonSegment(value: 'in_progress', label: Text('En cours')),
                      ButtonSegment(value: 'completed', label: Text('Terminées')),
                    ],
                    selected: {status},
                    onSelectionChanged: (v) => ref.read(_sessionStatusFilterProvider.notifier).state = v.first,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final selected = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 2),
                        lastDate: DateTime(now.year + 2),
                      );
                      ref.read(_sessionDateRangeProvider.notifier).state = selected;
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(range == null ? 'Période' : 'Période active'),
                  ),
                  if (range != null)
                    IconButton(
                      tooltip: 'Réinitialiser',
                      onPressed: () => ref.read(_sessionDateRangeProvider.notifier).state = null,
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const AdminDataTable(columns: [], rows: [], isLoading: true),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (all) {
                final rowsData = all.where((s) {
                  if (range == null) return true;
                  final ts = s['scheduledAt'] as Timestamp?;
                  if (ts == null) return false;
                  final d = ts.toDate();
                  return !d.isBefore(range.start) && !d.isAfter(range.end.add(const Duration(days: 1)));
                }).toList();

                final rows = rowsData
                    .map(
                      (s) => DataRow2(cells: [
                        DataCell(Text((s['id'] ?? '—').toString())),
                        DataCell(Text((s['studentId'] ?? '—').toString())),
                        DataCell(Text((s['tutorId'] ?? '—').toString())),
                        DataCell(Text((s['subjectId'] ?? '—').toString())),
                        DataCell(Text(_fmt(s['scheduledAt']))),
                        DataCell(Text('${(s['durationMinutes'] ?? 0)} min')),
                        DataCell(_status((s['status'] ?? 'scheduled').toString())),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () async {
                              final roomUrl = (s['roomUrl'] ?? '').toString();
                              if (roomUrl.isEmpty) return;
                              await launchUrl(Uri.parse(roomUrl), webOnlyWindowName: '_blank');
                            },
                          ),
                        ),
                      ]),
                    )
                    .toList();

                return AdminDataTable(
                  columns: const [
                    DataColumn2(label: Text('ID session'), size: ColumnSize.L),
                    DataColumn2(label: Text('Étudiant'), size: ColumnSize.M),
                    DataColumn2(label: Text('Tuteur'), size: ColumnSize.M),
                    DataColumn2(label: Text('Matière'), size: ColumnSize.S),
                    DataColumn2(label: Text('Date'), size: ColumnSize.M),
                    DataColumn2(label: Text('Durée'), size: ColumnSize.S),
                    DataColumn2(label: Text('Statut'), size: ColumnSize.S),
                    DataColumn2(label: Text('Salle'), size: ColumnSize.S),
                  ],
                  rows: rows,
                  isLoading: false,
                  emptyMessage: 'Aucune session',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(dynamic raw) {
    final ts = raw as Timestamp?;
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(ts.toDate());
  }

  static Widget _status(String status) {
    final bg = switch (status) {
      'completed' => Colors.green.withValues(alpha: 0.15),
      'in_progress' => Colors.blue.withValues(alpha: 0.15),
      _ => Colors.orange.withValues(alpha: 0.15),
    };
    final fg = switch (status) {
      'completed' => Colors.green.shade700,
      'in_progress' => Colors.blue.shade700,
      _ => Colors.orange.shade700,
    };
    return StatusBadge(
      text: status,
      backgroundColor: bg,
      textColor: fg,
    );
  }
}
