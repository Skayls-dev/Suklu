import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    required this.columns,
    required this.rows,
    required this.isLoading,
    this.emptyMessage,
    super.key,
  });

  final List<DataColumn2> columns;
  final List<DataRow2> rows;
  final bool isLoading;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;
    final hasColumns = columns.isNotEmpty;
    final safeRows = hasColumns
        ? rows.where((row) => row.cells.length == columns.length).toList()
        : const <DataRow2>[];

    if (rows.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey.shade500, size: 48),
            const SizedBox(height: 8),
            Text(emptyMessage ?? 'Aucune donnée'),
          ],
        ),
      );
    }

    if (!hasColumns) {
      return Column(
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_rows_outlined, color: Colors.grey.shade500, size: 48),
                        const SizedBox(height: 8),
                        const Text('Table indisponible (colonnes manquantes)'),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    if (safeRows.isEmpty && rows.isNotEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 48),
            const SizedBox(height: 8),
            const Text('Donnees de tableau invalides'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return DataTable2(
                fixedLeftColumns: isCompact ? 0 : (hasColumns ? 1 : 0),
                minWidth: constraints.maxWidth < 980 ? 980 : constraints.maxWidth,
                columns: columns,
                rows: safeRows,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columnSpacing: isCompact ? 10 : 12,
                horizontalMargin: isCompact ? 8 : 12,
              );
            },
          ),
        ),
      ],
    );
  }
}
