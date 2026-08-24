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
      case 'Occupied': return AppColors.error;
      case 'Order in Making': return AppColors.warning;
      case 'Served': return AppColors.info;
      case 'Billing': return AppColors.primary;
      default: return AppColors.success;
    }
  }

  DateTime? _createdAt(RestaurantTable table, TableOrderProvider orders) {
    final raw = orders.getOrderInfo(table.id)['openedAt'] ?? orders.getOrderInfo(table.id)['createdAt'];
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
    return 'Expected vacant $h:$m ${eta.hour >= 12 ? 'PM' : 'AM'}';
  }

  List<RestaurantTable> _visible(List<RestaurantTable> tables, TableOrderProvider orders) {
    switch (_filter) {
      case 'Available': return tables.where((t) => t.status == TableStatus.empty).toList();
      case 'Occupied': return tables.where((t) => t.status == TableStatus.occupied && orders.getOrderStatus(t.id) != 'making').toList();
      case 'Order in Making': return tables.where((t) => orders.getOrderStatus(t.id) == 'making').toList();
      case 'Billing': return tables.where((t) => t.status == TableStatus.cleared || t.status == TableStatus.served).toList();
      case 'Expected Vacant': return tables.where((t) => t.status != TableStatus.empty).toList();
      default: return tables;
    }
  }

  int _count(List<RestaurantTable> tables, TableOrderProvider orders, String filter) {
    final old = _filter; _filter = filter; final result = _visible(tables, orders).length; _filter = old; return result;
  }

  Future<void> _openOrder(RestaurantTable table) async {
    if (table.status == TableStatus.empty) {
      final ok = await _openTableDialog(table);
      if (!ok || !mounted) return;
      await context.read<TableProvider>().updateTableStatus(table.id, TableStatus.occupied);
      await context.read<TableOrderProvider>().loadTableOrder(table.id);
    }
    if (mounted) context.go('/table-order/${table.id}', extra: table);
  }

  Future<bool> _openTableDialog(RestaurantTable table) async {
    final auth = context.read<AuthProvider>().currentUser;
    if (auth == null) return false;
    final guests = TextEditingController(text: '1');
    String? waiterId;
    String waiterName = 'Unassigned';

    final staffSnap = await FirebaseFirestore.instance.collection('vendors').doc(auth.id).collection('staff').get();
    final waiters = staffSnap.docs.where((d) {
      final role = (d.data()['role'] ?? '').toString().toLowerCase();
      return role.contains('waiter') || role.contains('server') || role.contains('service');
    }).toList();

    final opened = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (_, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Open Table ${table.tableNumber}'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${table.numberOfSeats} seats available', style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 16),
          TextField(controller: guests, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of customers', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups_2_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: waiterId,
            decoration: const InputDecoration(labelText: 'Assign waiter', border: OutlineInputBorder(), prefixIcon: Icon(Icons.room_service_outlined)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
              ...waiters.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text((d.data()['name'] ?? 'Waiter').toString()))),
            ],
            onChanged: (v) {
              setDialogState(() {
                waiterId = v;
                waiterName = v == null ? 'Unassigned' : (waiters.firstWhere((x) => x.id == v).data()['name'] ?? 'Waiter').toString();
              });
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final count = int.tryParse(guests.text.trim()) ?? 0;
            if (count < 1 || count > table.numberOfSeats) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter 1 to ${table.numberOfSeats} customers.')));
              return;
            }
            Navigator.pop(dialogContext, true);
          }, child: const Text('Open Table')),
        ],
      )),
    ) ?? false;

    if (opened) {
      final count = int.tryParse(guests.text.trim()) ?? 1;
      await FirebaseFirestore.instance.collection('vendors').doc(auth.id).collection('tableOrders').doc(table.id).set({
        'tableId': table.id,
        'tableNumber': table.tableNumber,
        'customerCount': count,
        'waiterId': waiterId,
        'waiterName': waiterName,
        'status': 'open',
        'openedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'items': <Map<String, dynamic>>[],
        'itemsCount': 0,
        'total': 0.0,
      }, SetOptions(merge: true));
    }
    guests.dispose();
    return opened;
  }

  Future<void> _addTable() async {
    _tableController.clear(); _seatsController.clear();
    await showDialog(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add table'),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _tableController, decoration: const InputDecoration(labelText: 'Table number', border: OutlineInputBorder())), const SizedBox(height: 12),
        TextField(controller: _seatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async {
        final n = _tableController.text.trim(); final s = int.tryParse(_seatsController.text.trim()); if (n.isEmpty || s == null || s <= 0) return;
        await context.read<TableProvider>().addTable(n, s); if (dialogContext.mounted) Navigator.pop(dialogContext);
      }, child: const Text('Add table'))],
    ));
  }

  Future<void> _editTable(RestaurantTable table) async {
    _seatsController.text = table.numberOfSeats.toString();
    await showDialog(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Edit Table ${table.tableNumber}'),
      content: SizedBox(width: 380, child: TextField(controller: _seatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats', border: OutlineInputBorder()))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async {
        final seats = int.tryParse(_seatsController.text.trim()); if (seats == null || seats <= 0) return; await context.read<TableProvider>().updateTable(table.id, numberOfSeats: seats); if (dialogContext.mounted) Navigator.pop(dialogContext);
      }, child: const Text('Save'))],
    ));
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete table'), content: Text('Delete Table ${table.tableNumber}?'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))]));
    if (ok == true && mounted) await context.read<TableProvider>().deleteTable(table.id);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().currentUser?.isAdmin ?? false;
    final orders = context.watch<TableOrderProvider>();
    return Consumer<TableProvider>(builder: (context, provider, _) {
      final all = provider.tables; final tables = _visible(all, orders);
      final filters = ['Available', 'Occupied', 'Order in Making', 'Billing', 'Expected Vacant'];
      return Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Table Operations', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.grey900)), const SizedBox(height: 3), Text(isAdmin ? 'Live restaurant floor. Open tables carry guest and waiter details.' : 'Open a table, add items, send KOT and complete billing.', style: const TextStyle(color: AppColors.grey500, fontSize: 11.5))])),
          if (isAdmin) FilledButton.icon(onPressed: _addTable, icon: const Icon(Icons.add_rounded), label: const Text('Add table')),
        ]),
        const SizedBox(height: 15),
        Wrap(spacing: 8, runSpacing: 8, children: filters.map((f) {
          final selected = _filter == f; final color = f == 'Available' ? AppColors.success : f == 'Occupied' ? AppColors.error : f == 'Order in Making' ? AppColors.warning : f == 'Billing' ? AppColors.primary : AppColors.info;
          return ChoiceChip(label: Text('$f  ${_count(all, orders, f)}'), selected: selected, onSelected: (_) => setState(() => _filter = f), avatar: Icon(f == 'Expected Vacant' ? Icons.schedule_rounded : Icons.circle, size: f == 'Expected Vacant' ? 15 : 9, color: selected ? Colors.white : color));
        }).toList()),
        const SizedBox(height: 15),
        Expanded(child: provider.isLoading && all.isEmpty ? const Center(child: CircularProgressIndicator()) : tables.isEmpty ? Center(child: Text('No $_filter tables', style: const TextStyle(color: AppColors.grey500))) : LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 1200 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 650 ? 3 : 2;
          return GridView.builder(itemCount: tables.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.48), itemBuilder: (_, i) {
            final t = tables[i]; final status = _orderStatus(t, orders); final info = orders.getOrderInfo(t.id);
            return _TableCard(table: t, status: status, color: _statusColor(status), expectedVacant: _expectedVacant(t, orders), waiterName: (info['waiterName'] ?? '').toString(), customerCount: (info['customerCount'] as num?)?.toInt(), isAdmin: isAdmin, onOpen: () => _openOrder(t), onEdit: () => _editTable(t), onDelete: () => _deleteTable(t));
          });
        })),
      ]));
    });
  }
}

class _TableCard extends StatelessWidget {
  final RestaurantTable table; final String status; final Color color; final String expectedVacant; final String waiterName; final int? customerCount; final bool isAdmin; final VoidCallback onOpen; final VoidCallback onEdit; final VoidCallback onDelete;
  const _TableCard({required this.table, required this.status, required this.color, required this.expectedVacant, required this.waiterName, required this.customerCount, required this.isAdmin, required this.onOpen, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onOpen, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))])), const Spacer(), if (isAdmin) PopupMenuButton<String>(icon: const Icon(Icons.more_horiz_rounded, size: 18), onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit table')), PopupMenuItem(value: 'delete', child: Text('Delete table'))])]),
    const Spacer(), Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.grey900)), const SizedBox(height: 5),
    Row(children: [const Icon(Icons.chair_alt_outlined, size: 14, color: AppColors.grey400), const SizedBox(width: 5), Text('${table.numberOfSeats} seats', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)), if (status != 'Available' && customerCount != null) ...[const SizedBox(width: 12), const Icon(Icons.groups_2_outlined, size: 14, color: AppColors.grey400), const SizedBox(width: 4), Text('$customerCount guests', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500))]]),
    if (status != 'Available') ...[const SizedBox(height: 5), Text('Waiter: ${waiterName.isEmpty ? 'Unassigned' : waiterName}', style: const TextStyle(fontSize: 10, color: AppColors.grey600)), const SizedBox(height: 3), Text(expectedVacant, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500))],
    const Spacer(), const Divider(height: 1), const SizedBox(height: 8), Row(children: [Text(status == 'Available' ? 'Open table' : status == 'Billing' ? 'Open bill' : 'Open order', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.grey400)]),
  ]))));
}
