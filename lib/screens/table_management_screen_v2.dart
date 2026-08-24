import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
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
  String _filter = 'Available';
  bool _loadedOrders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableProvider>().loadTables();
      if (!_loadedOrders) {
        _loadedOrders = true;
        context.read<TableOrderProvider>().loadAllTableOrders();
      }
    });
  }

  @override
  void dispose() {
    _tableController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  String _orderStatus(RestaurantTable table, TableOrderProvider orders) {
    final status = orders.getOrderStatus(table.id);
    if (status == 'making') return 'Order in Making';
    if (table.status == TableStatus.cleared) return 'Billing';
    if (table.status == TableStatus.served || status == 'served') return 'Served';
    if (table.status == TableStatus.occupied) return 'Occupied';
    return 'Available';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Order in Making':
        return AppColors.warning;
      case 'Occupied':
        return AppColors.info;
      case 'Served':
        return AppColors.success;
      case 'Billing':
        return AppColors.primary;
      default:
        return AppColors.success;
    }
  }

  DateTime? _createdAt(RestaurantTable table, TableOrderProvider orders) {
    final raw = orders.getOrderInfo(table.id)['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _expectedVacant(RestaurantTable table, TableOrderProvider orders) {
    if (table.status == TableStatus.empty) return 'Available now';
    final created = _createdAt(table, orders);
    if (created == null) return 'ETA not set';
    final eta = created.add(const Duration(minutes: 45));
    final h = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final m = eta.minute.toString().padLeft(2, '0');
    final ap = eta.hour >= 12 ? 'PM' : 'AM';
    return 'Expected vacant $h:$m $ap';
  }

  List<RestaurantTable> _visible(List<RestaurantTable> tables, TableOrderProvider orders) {
    switch (_filter) {
      case 'Available':
        return tables.where((t) => t.status == TableStatus.empty).toList();
      case 'Occupied':
        return tables.where((t) => t.status == TableStatus.occupied && orders.getOrderStatus(t.id) != 'making').toList();
      case 'Order in Making':
        return tables.where((t) => orders.getOrderStatus(t.id) == 'making').toList();
      case 'Billing':
        return tables.where((t) => t.status == TableStatus.cleared || t.status == TableStatus.served).toList();
      case 'Expected Vacant':
        return tables.where((t) => t.status != TableStatus.empty).toList();
      default:
        return tables;
    }
  }

  int _count(List<RestaurantTable> tables, TableOrderProvider orders, String filter) {
    final old = _filter;
    _filter = filter;
    final result = _visible(tables, orders).length;
    _filter = old;
    return result;
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _tableController, decoration: const InputDecoration(labelText: 'Table number', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            TextField(controller: _seatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder())),
          ]),
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
          child: TextField(controller: _seatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder())),
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
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) await context.read<TableProvider>().deleteTable(table.id);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().currentUser?.isAdmin ?? false;
    final orders = context.watch<TableOrderProvider>();

    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        final all = provider.tables;
        final tables = _visible(all, orders);
        final filters = ['Available', 'Occupied', 'Order in Making', 'Billing', 'Expected Vacant'];

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAdmin ? 'Table Operations' : 'Tables', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                const SizedBox(height: 3),
                Text(isAdmin ? 'Live restaurant floor. Administrative controls stay separate.' : 'Open a table, add items, send KOT and complete billing.', style: const TextStyle(color: AppColors.grey500, fontSize: 11.5)),
              ])),
              if (isAdmin)
                FilledButton.icon(onPressed: _addTable, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add table')),
            ]),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.map((filter) {
                final selected = _filter == filter;
                final count = _count(all, orders, filter);
                return ChoiceChip(
                  avatar: Icon(
                    filter == 'Available' ? Icons.check_circle_outline_rounded : filter == 'Occupied' ? Icons.people_alt_outlined : filter == 'Order in Making' ? Icons.soup_kitchen_outlined : filter == 'Billing' ? Icons.receipt_long_outlined : Icons.schedule_rounded,
                    size: 16,
                    color: selected ? Colors.white : AppColors.grey600,
                  ),
                  label: Text(filter == 'Expected Vacant' ? 'Expected Vacant  $count' : '$filter  $count'),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : tables.isEmpty
                      ? _EmptyFilterState(filter: _filter)
                      : LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 1200 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 650 ? 3 : 2;
                          return GridView.builder(
                            itemCount: tables.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55),
                            itemBuilder: (_, i) {
                              final table = tables[i];
                              final status = _orderStatus(table, orders);
                              return _OperatorTableCard(
                                table: table,
                                status: status,
                                color: _statusColor(status),
                                expectedVacant: _expectedVacant(table, orders),
                                isAdmin: isAdmin,
                                onOpen: () => _openOrder(table),
                                onEdit: () => _editTable(table),
                                onDelete: () => _deleteTable(table),
                              );
                            },
                          );
                        }),
            ),
          ]),
        );
      },
    );
  }
}

class _OperatorTableCard extends StatelessWidget {
  final RestaurantTable table;
  final String status;
  final Color color;
  final String expectedVacant;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OperatorTableCard({required this.table, required this.status, required this.color, required this.expectedVacant, required this.isAdmin, required this.onOpen, required this.onEdit, required this.onDelete});

  String get action {
    if (status == 'Available') return 'Open table';
    if (status == 'Billing' || status == 'Served') return 'Open bill';
    return 'Open order';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(status.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .35))),
              if (isAdmin)
                PopupMenuButton<String>(
                  tooltip: 'Table settings',
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.grey400),
                  onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit table')), PopupMenuItem(value: 'delete', child: Text('Delete table'))],
                ),
            ]),
            const Spacer(),
            Text('Table ${table.tableNumber}', style: const TextStyle(color: AppColors.grey900, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.chair_alt_outlined, size: 14, color: AppColors.grey400),
              const SizedBox(width: 5),
              Text('${table.numberOfSeats} seats', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
            ]),
            if (status != 'Available') ...[
              const SizedBox(height: 7),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 13, color: AppColors.grey400),
                const SizedBox(width: 5),
                Expanded(child: Text(expectedVacant, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey500, fontSize: 9.5))),
              ]),
            ],
            const Spacer(),
            const Divider(height: 1, color: AppColors.outlineLight),
            const SizedBox(height: 9),
            Row(children: [
              Text(action, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.grey400),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  final String filter;
  const _EmptyFilterState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.table_restaurant_outlined, size: 36, color: AppColors.grey300),
      const SizedBox(height: 9),
      Text('No $filter tables', style: const TextStyle(color: AppColors.grey700, fontWeight: FontWeight.w600)),
    ]));
  }
}
