import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_Draft> _items = [];
  List<_Draft> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _items = [
        _Draft(
          id: 'DR-2001',
          type: 'Sale',
          items: 3,
          total: 120.0,
          date: DateTime(2024, 2, 10),
          status: 'Open',
        ),
        _Draft(
          id: 'DR-2002',
          type: 'Purchase',
          items: 5,
          total: 540.5,
          date: DateTime(2024, 2, 12),
          status: 'Open',
        ),
        _Draft(
          id: 'DR-2003',
          type: 'Store Out',
          items: 2,
          total: 0.0,
          date: DateTime(2024, 2, 18),
          status: 'Closed',
        ),
      ];
      _filtered = _items;
    });
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _items
          .where(
            (d) =>
                d.id.toLowerCase().contains(q) ||
                d.type.toLowerCase().contains(q) ||
                d.status.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.drafts,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your draft transactions',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'New Draft',
                icon: Icons.note_add,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search drafts...',
            onChanged: (_) => _applyFilter(),
            onClear: () => _applyFilter(),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Items')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filtered
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.id)),
                          DataCell(Text(e.type)),
                          DataCell(Text('${e.items}')),
                          DataCell(
                            Text(
                              e.total == 0
                                  ? '-'
                                  : '\$${e.total.toStringAsFixed(2)}',
                            ),
                          ),
                          DataCell(
                            Text('${e.date.toLocal()}'.split(' ').first),
                          ),
                          DataCell(StatusBadge(text: e.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () {},
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
                mobileItemBuilder: (context, index) {
                  final d = _filtered[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.id,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusBadge(text: d.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Type: ${d.type}  •  Items: ${d.items}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Total: ${d.total == 0 ? '-' : '\$${d.total.toStringAsFixed(2)}'}',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Date: ${'${d.date.toLocal()}'.split(' ').first}'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Draft {
  final String id;
  final String type;
  final int items;
  final double total;
  final DateTime date;
  final String status;
  _Draft({
    required this.id,
    required this.type,
    required this.items,
    required this.total,
    required this.date,
    required this.status,
  });
}
