import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Modal pour sélectionner une matière avec recherche et scroll performant
class SubjectSelectorModal extends StatefulWidget {
  const SubjectSelectorModal({
    required this.subjects,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final List<Map<String, String>> subjects;
  final String? selectedId;
  final Function(String? id) onSelect;

  @override
  State<SubjectSelectorModal> createState() => _SubjectSelectorModalState();
}

class _SubjectSelectorModalState extends State<SubjectSelectorModal> {
  late TextEditingController _searchController;
  late List<Map<String, String>> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = widget.subjects;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.subjects;
      } else {
        _filtered = widget.subjects
            .where((s) => (s['name'] ?? '').toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sélectionner une matière',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          AppSpacing.gapMd,
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher une matière...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
          AppSpacing.gapMd,
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Aucune matière trouvée',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtered.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          title: const Text('Toutes les matières'),
                          selected: widget.selectedId == null,
                          onTap: () {
                            widget.onSelect(null);
                            Navigator.of(context).pop();
                          },
                        );
                      }
                      final subject = _filtered[index - 1];
                      final id = subject['id'] ?? '';
                      final name = subject['name'] ?? id;
                      return ListTile(
                        title: Text(name),
                        selected: widget.selectedId == id,
                        onTap: () {
                          widget.onSelect(id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
