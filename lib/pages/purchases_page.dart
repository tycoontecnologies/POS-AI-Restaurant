import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_Purchase> _items = [];
  List<_Purchase> _filtered = [];

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
        _Purchase(
          id: 'PO-1001',
          supplier: 'ABC Traders',
          items: 12,
          total: 2300.0,
          date: DateTime(2024, 2, 12),
          status: 'Received',
        ),
        _Purchase(
          id: 'PO-1002',
          supplier: 'Global Foods',
          items: 5,
          total: 740.5,
          date: DateTime(2024, 2, 15),
          status: 'Pending',
        ),
        _Purchase(
          id: 'PO-1003',
          supplier: 'Stationery Hub',
          items: 20,
          total: 1210.0,
          date: DateTime(2024, 2, 20),
          status: 'Cancelled',
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
            (p) =>
                p.id.toLowerCase().contains(q) ||
                p.supplier.toLowerCase().contains(q) ||
                p.status.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  // reserved for future use if we theme statuses differently

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
                      l10n.purchases,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track your purchase orders',
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
                text: 'New Purchase',
                icon: Icons.add_shopping_cart,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search purchases...',
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
                  DataColumn(label: Text('Supplier')),
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
                          DataCell(Text(e.supplier)),
                          DataCell(Text('${e.items}')),
                          DataCell(Text('\$${e.total.toStringAsFixed(2)}')),
                          DataCell(
                            Text('${e.date.toLocal()}'.split(' ').first),
                          ),
                          DataCell(StatusBadge(text: e.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_red_eye,
                                    size: 18,
                                  ),
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
                  final p = _filtered[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.id,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusBadge(text: p.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Supplier: ${p.supplier}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Items: ${p.items}  •  Total: \$${p.total.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Date: ${'${p.date.toLocal()}'.split(' ').first}'),
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

class _Purchase {
  final String id;
  final String supplier;
  final int items;
  final double total;
  final DateTime date;
  final String status;
  _Purchase({
    required this.id,
    required this.supplier,
    required this.items,
    required this.total,
    required this.date,
    required this.status,
  });
}
