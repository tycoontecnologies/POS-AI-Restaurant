import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class StoreOutPage extends StatefulWidget {
  const StoreOutPage({super.key});

  @override
  State<StoreOutPage> createState() => _StoreOutPageState();
}

class _StoreOutPageState extends State<StoreOutPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_StoreOut> _items = [];
  List<_StoreOut> _filtered = [];

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
        _StoreOut(
          id: 'SO-3001',
          reason: 'Damaged',
          items: 2,
          date: DateTime(2024, 2, 11),
          handledBy: 'Imran',
        ),
        _StoreOut(
          id: 'SO-3002',
          reason: 'Expired',
          items: 4,
          date: DateTime(2024, 2, 14),
          handledBy: 'Salim',
        ),
        _StoreOut(
          id: 'SO-3003',
          reason: 'Free Sample',
          items: 1,
          date: DateTime(2024, 2, 19),
          handledBy: 'Zubair',
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
            (s) =>
                s.id.toLowerCase().contains(q) ||
                s.reason.toLowerCase().contains(q) ||
                s.handledBy.toLowerCase().contains(q),
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
                      l10n.storeOut,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track inventory outgoing',
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
                text: 'Record Outgoing',
                icon: Icons.output,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search store out...',
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
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Items')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Handled By')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filtered
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.id)),
                          DataCell(Text(e.reason)),
                          DataCell(Text('${e.items}')),
                          DataCell(
                            Text('${e.date.toLocal()}'.split(' ').first),
                          ),
                          DataCell(Text(e.handledBy)),
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
                  final s = _filtered[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.id,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Reason: ${s.reason}  •  Items: ${s.items}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Date: ${'${s.date.toLocal()}'.split(' ').first}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Handled By: ${s.handledBy}'),
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

class _StoreOut {
  final String id;
  final String reason;
  final int items;
  final DateTime date;
  final String handledBy;
  _StoreOut({
    required this.id,
    required this.reason,
    required this.items,
    required this.date,
    required this.handledBy,
  });
}
