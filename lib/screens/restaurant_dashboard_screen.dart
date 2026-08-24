import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _soft = Color(0xFFF8FAFC);

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() => _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  bool _loaded = false;
  bool _prefsLoaded = false;
  List<String> _order = List<String>.from(_defaults);
  Set<String> _visible = Set<String>.from(_defaults);
  String? _dragging;

  static const _defaults = <String>[
    'sales',
    'orders',
    'service',
    'available',
    'tables',
    'transactions',
    'expenses',
    'store',
    'branches',
  ];

  static const Map<String, String> _labels = {
    'sales': "Today's Sales",
    'orders': "Today's Orders",
    'service': 'Tables In Service',
    'available': 'Tables Available',
    'tables': 'Tables in Service',
    'transactions': 'Recent Transactions',
    'expenses': 'Expenses',
    'store': 'Store Movements',
    'branches': 'Branches',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        final tableProvider = context.read<TableProvider>();
        final saleProvider = context.read<SaleProvider>();
        if (tableProvider.tables.isEmpty && !tableProvider.isLoading) tableProvider.loadTables();
        if (saleProvider.sales.isEmpty && !saleProvider.isLoading) saleProvider.fetchSales(user.id);
      }
    }
    if (!_prefsLoaded) {
      _prefsLoaded = true;
      _loadPrefs();
    }
  }

  DocumentReference<Map<String, dynamic>>? _prefsRef() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;
    final key = (user.authUid ?? user.id).replaceAll('/', '_');
    return FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('dashboardPreferences').doc(key);
  }

  Future<void> _loadPrefs() async {
    try {
      final ref = _prefsRef();
      if (ref == null) return;
      final doc = await ref.get();
      final data = doc.data();
      if (data == null || !mounted) return;
      final savedOrder = (data['order'] as List?)?.map((e) => e.toString()).where(_labels.containsKey).toList() ?? <String>[];
      final savedVisible = (data['visible'] as List?)?.map((e) => e.toString()).where(_labels.containsKey).toSet() ?? <String>{};
      setState(() {
        _order = [...savedOrder, ..._defaults.where((e) => !savedOrder.contains(e))];
        _visible = savedVisible.isEmpty ? Set<String>.from(_defaults) : savedVisible;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final ref = _prefsRef();
      if (ref == null) return;
      await ref.set({'order': _order, 'visible': _visible.toList(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _customize() async {
    final temp = Set<String>.from(_visible);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Customize dashboard'),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Choose what you want to see. Drag cards on the dashboard to change their order.', style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 12),
                ..._defaults.map((id) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: temp.contains(id),
                      title: Text(_labels[id]!),
                      onChanged: (v) => setDialogState(() => v == true ? temp.add(id) : temp.remove(id)),
                    )),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  temp
                    ..clear()
                    ..addAll(_defaults);
                });
              },
              child: const Text('Restore all'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, temp), child: const Text('Save dashboard')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _visible = result);
    await _savePrefs();
  }

  void _hide(String id) {
    setState(() => _visible.remove(id));
    _savePrefs();
  }

  void _swap(String dragged, String target) {
    if (dragged == target) return;
    final from = _order.indexOf(dragged);
    final to = _order.indexOf(target);
    if (from < 0 || to < 0) return;
    setState(() {
      final item = _order.removeAt(from);
      _order.insert(to, item);
    });
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final tables = context.watch<TableProvider>().tables;
    final sales = context.watch<SaleProvider>().sales;
    final todaySales = sales.where((s) => _isToday(s.createdAt)).toList();
    final revenue = todaySales.fold<double>(0, (sum, sale) => sum + sale.total);
    final available = tables.where((t) => t.status == TableStatus.empty).length;
    final service = tables.where((t) => t.status != TableStatus.empty).length;
    final visibleOrder = _order.where(_visible.contains).toList();

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.restaurantName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
              const SizedBox(height: 4),
              Text('${user.branchName} • Today at a glance', style: const TextStyle(fontSize: 11.5, color: _muted)),
            ])),
            OutlinedButton.icon(
              onPressed: _customize,
              style: OutlinedButton.styleFrom(foregroundColor: _purple, side: const BorderSide(color: _line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
              label: const Text('Customize'),
            ),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 1180 ? 3 : c.maxWidth >= 760 ? 2 : 1;
            final width = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: visibleOrder.map((id) {
                return DragTarget<String>(
                  onWillAcceptWithDetails: (d) => d.data != id,
                  onAcceptWithDetails: (d) => _swap(d.data, id),
                  builder: (_, candidate, __) => LongPressDraggable<String>(
                    data: id,
                    onDragStarted: () => setState(() => _dragging = id),
                    onDragEnd: (_) => setState(() => _dragging = null),
                    feedback: Material(color: Colors.transparent, child: Opacity(opacity: .85, child: SizedBox(width: width, child: _buildWidget(id, revenue, todaySales, tables, service, available, sales, dragging: true)))),
                    childWhenDragging: Opacity(opacity: .35, child: SizedBox(width: width, child: _buildWidget(id, revenue, todaySales, tables, service, available, sales))),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: width,
                      decoration: candidate.isNotEmpty ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple, width: 2)) : null,
                      child: _buildWidget(id, revenue, todaySales, tables, service, available, sales),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
          if (visibleOrder.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Column(children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 44, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 10),
                  const Text('Your dashboard is empty.', style: TextStyle(fontWeight: FontWeight.w800, color: _muted)),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: _customize, icon: const Icon(Icons.add_rounded), label: const Text('Add widgets')),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildWidget(String id, double revenue, List<Sale> todaySales, List<RestaurantTable> tables, int service, int available, List<Sale> sales, {bool dragging = false}) {
    switch (id) {
      case 'sales':
        return _MetricCard(label: "Today's Sales", value: 'Rs ${revenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, accent: _purple, onTap: () => context.go(AppRouter.sales), onHide: () => _hide(id));
      case 'orders':
        return _MetricCard(label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, accent: const Color(0xFF3B82F6), onTap: () => context.go(AppRouter.sales), onHide: () => _hide(id));
      case 'service':
        return _MetricCard(label: 'Tables In Service', value: '$service', icon: Icons.table_restaurant_outlined, accent: const Color(0xFFF59E0B), onTap: () => context.go(AppRouter.tables), onHide: () => _hide(id));
      case 'available':
        return _MetricCard(label: 'Tables Available', value: '$available', icon: Icons.event_available_outlined, accent: const Color(0xFF10B981), onTap: () => context.go(AppRouter.tables), onHide: () => _hide(id));
      case 'tables':
        return _Panel(title: 'Tables in Service', subtitle: 'Live floor status', onHide: () => _hide(id), child: _TablesPanel(tables: tables));
      case 'transactions':
        return _Panel(title: 'Recent Transactions', subtitle: 'Compact latest completed sales', onHide: () => _hide(id), child: _TransactionsPanel(sales: sales.take(6).toList()));
      case 'expenses':
        return _ActionCard(title: 'Expenses', subtitle: 'Record rent, utilities, salaries and other costs.', icon: Icons.payments_outlined, onTap: () => context.go(AppRouter.expenses), onHide: () => _hide(id));
      case 'store':
        return _ActionCard(title: 'Store', subtitle: 'Issue stock from the store to kitchen or departments.', icon: Icons.storefront_outlined, onTap: () => context.go(AppRouter.storeOut), onHide: () => _hide(id));
      case 'branches':
        return _ActionCard(title: 'Branches', subtitle: 'Open multi-branch controls and branch setup.', icon: Icons.account_tree_outlined, onTap: () => context.go(AppRouter.branches), onHide: () => _hide(id));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onHide;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.accent, required this.onTap, required this.onHide});

  @override
  Widget build(BuildContext context) => Container(
        height: 112,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Row(children: [
          InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 21))),
          const SizedBox(width: 12),
          Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
          ]))),
          Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Remove widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)))),
        ]),
      );
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onHide;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.onHide, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 9.5, color: _muted)),
            ])),
            IconButton(tooltip: 'Remove widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 8),
          Expanded(child: child),
        ]),
      );
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onHide;
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.onTap, required this.onHide});

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF3EFFF), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _purple)),
          const SizedBox(width: 12),
          Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _muted)),
          ]))),
          Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Remove widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)))),
        ]),
      );
}

class _TablesPanel extends StatelessWidget {
  final List<RestaurantTable> tables;
  const _TablesPanel({required this.tables});
  @override
  Widget build(BuildContext context) {
    final active = tables.where((t) => t.status != TableStatus.empty).take(8).toList();
    if (active.isEmpty) return const Center(child: Text('No tables in service.', style: TextStyle(color: _muted)));
    return ListView.separated(
      itemCount: active.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = active[i];
        return InkWell(
          onTap: () => context.go(AppRouter.tables),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Icons.table_restaurant_outlined, size: 15, color: _purple),
              const SizedBox(width: 8),
              Expanded(child: Text('Table ${t.tableNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))),
              Text('${t.numberOfSeats} seats', style: const TextStyle(fontSize: 9.5, color: _muted)),
            ]),
          ),
        );
      },
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  final List<Sale> sales;
  const _TransactionsPanel({required this.sales});
  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const Center(child: Text('No transactions yet.', style: TextStyle(color: _muted)));
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3.3),
      itemCount: sales.length,
      itemBuilder: (_, i) {
        final sale = sales[i];
        final table = sale.tableNumber == null || sale.tableNumber!.isEmpty ? 'Order' : 'Table ${sale.tableNumber}';
        return InkWell(
          onTap: () => context.go(AppRouter.sales),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, size: 15, color: _purple),
              const SizedBox(width: 7),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(table, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _ink)),
                Text('${sale.items.length} items • ${sale.paymentMethod}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: _muted)),
              ])),
              Text('Rs ${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _ink)),
            ]),
          ),
        );
      },
    );
  }
}
