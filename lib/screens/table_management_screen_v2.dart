import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/utils/app_colors.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final _tableController = TextEditingController();
  final _seatsController = TextEditingController();
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableProvider>().loadTables();
    });
  }

  @override
  void dispose() {
    _tableController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  String _label(TableStatus s) {
    switch (s) {
      case TableStatus.empty:
        return 'Available';
      case TableStatus.occupied:
        return 'In Service';
      case TableStatus.served:
        return 'Served';
      case TableStatus.cleared:
        return 'Billing';
    }
  }

  Color _color(TableStatus s) {
    switch (s) {
      case TableStatus.empty:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.warning;
      case TableStatus.served:
        return AppColors.info;
      case TableStatus.cleared:
        return AppColors.primary;
    }
  }

  List<RestaurantTable> _visible(List<RestaurantTable> tables) {
    if (_filter == 'All') return tables;
    return tables.where((t) => _label(t.status) == _filter).toList();
  }

  int _count(List<RestaurantTable> tables, String filter) {
    if (filter == 'All') return tables.length;
    return tables.where((t) => _label(t.status) == filter).length;
  }

  void _openOrder(RestaurantTable table) {
    context.go('/table-order/${table.id}', extra: table);
  }

  Future<void> _addTable() async {
    _tableController.clear();
    _seatsController.clear();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add table'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tableController,
                decoration: const InputDecoration(labelText: 'Table number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final number = _tableController.text.trim();
              final seats = int.tryParse(_seatsController.text.trim());
              if (number.isEmpty || seats == null || seats <= 0) return;
              await context.read<TableProvider>().addTable(number, seats);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Add table'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTable(RestaurantTable table) async {
    _seatsController.text = table.numberOfSeats.toString();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Table ${table.tableNumber}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Administrative status', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TableStatus.values.map((status) {
                  return ActionChip(
                    label: Text(_label(status)),
                    onPressed: () async {
                      await context.read<TableProvider>().updateTableStatus(table.id, status);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final seats = int.tryParse(_seatsController.text.trim());
              if (seats == null || seats <= 0) return;
              await context.read<TableProvider>().updateTable(table.id, numberOfSeats: seats);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete table'),
        content: Text('Delete Table ${table.tableNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<TableProvider>().deleteTable(table.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        final all = provider.tables;
        final tables = _visible(all);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Restaurant Floor', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                        SizedBox(height: 4),
                        Text('Click a table to start or resume its order.', style: TextStyle(color: AppColors.grey500, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addTable,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add table'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: ['All', 'Available', 'In Service', 'Served', 'Billing'].map((filter) {
                  final selected = _filter == filter;
                  return ChoiceChip(
                    label: Text('$filter  ${_count(all, filter)}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = filter),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: provider.isLoading && all.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : tables.isEmpty
                        ? const Center(child: Text('No tables in this status', style: TextStyle(color: AppColors.grey500)))
                        : LayoutBuilder(
                            builder: (context, c) {
                              final cols = c.maxWidth >= 1180 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 650 ? 3 : 2;
                              return GridView.builder(
                                itemCount: tables.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.55,
                                ),
                                itemBuilder: (_, i) {
                                  final table = tables[i];
                                  return _OperationalTableCard(
                                    table: table,
                                    label: _label(table.status),
                                    color: _color(table.status),
                                    onOpen: () => _openOrder(table),
                                    onEdit: () => _editTable(table),
                                    onDelete: () => _deleteTable(table),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OperationalTableCard extends StatelessWidget {
  final RestaurantTable table;
  final String label;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OperationalTableCard({
    required this.table,
    required this.label,
    required this.color,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  String get action {
    switch (table.status) {
      case TableStatus.empty:
        return 'Start order';
      case TableStatus.occupied:
        return 'Open order';
      case TableStatus.served:
        return 'Open / checkout';
      case TableStatus.cleared:
        return 'Open bill';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .5))),
                  PopupMenuButton<String>(
                    tooltip: 'Table settings',
                    icon: const Icon(Icons.more_horiz_rounded, size: 19, color: AppColors.grey400),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit table')),
                      PopupMenuItem(value: 'delete', child: Text('Delete table')),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text('Table ${table.tableNumber}', style: const TextStyle(color: AppColors.grey900, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.chair_alt_outlined, size: 15, color: AppColors.grey400),
                const SizedBox(width: 5),
                Text('${table.numberOfSeats} seats', style: const TextStyle(color: AppColors.grey500, fontSize: 11.5)),
              ]),
              const Spacer(),
              const Divider(height: 1, color: AppColors.outlineLight),
              const SizedBox(height: 10),
              Row(children: [
                Text(action, style: TextStyle(color: table.status == TableStatus.empty ? AppColors.primary : AppColors.grey700, fontSize: 11.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.grey400),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
