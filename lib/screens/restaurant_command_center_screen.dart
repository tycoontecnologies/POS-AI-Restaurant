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

class RestaurantCommandCenterScreen extends StatefulWidget {
  const RestaurantCommandCenterScreen({super.key});

  @override
  State<RestaurantCommandCenterScreen> createState() => _RestaurantCommandCenterScreenState();
}

class _RestaurantCommandCenterScreenState extends State<RestaurantCommandCenterScreen> {
  bool _loaded = false;
  final Set<String> _hidden = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final tableProvider = context.read<TableProvider>();
    final saleProvider = context.read<SaleProvider>();
    if (tableProvider.tables.isEmpty && !tableProvider.isLoading) {
      tableProvider.loadTables();
    }
    if (saleProvider.sales.isEmpty && !saleProvider.isLoading) {
      saleProvider.fetchSales(user.id);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
    final occupied = tables.where((t) => t.status != TableStatus.empty).length;

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.restaurantName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
                const SizedBox(height: 4),
                Text('${user.branchName} • Today at a glance', style: const TextStyle(fontSize: 11.5, color: _muted)),
              ]),
            ),
            if (_hidden.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => setState(_hidden.clear),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
                label: const Text('Restore widgets'),
              ),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            final count = c.maxWidth >= 1050 ? 4 : c.maxWidth >= 650 ? 2 : 1;
            final width = (c.maxWidth - (count - 1) * 12) / count;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              if (!_hidden.contains('revenue')) _Kpi(width: width, label: "Today's Sales", value: 'Rs ${revenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, accent: _purple, onTap: () => context.go(AppRouter.sales), onHide: () => setState(() => _hidden.add('revenue'))),
              if (!_hidden.contains('orders')) _Kpi(width: width, label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, accent: const Color(0xFF3B82F6), onTap: () => context.go(AppRouter.orders), onHide: () => setState(() => _hidden.add('orders'))),
              if (!_hidden.contains('service')) _Kpi(width: width, label: 'Tables In Service', value: '$occupied', icon: Icons.table_restaurant_outlined, accent: const Color(0xFFF59E0B), onTap: () => context.go(AppRouter.tables), onHide: () => setState(() => _hidden.add('service'))),
              if (!_hidden.contains('available')) _Kpi(width: width, label: 'Tables Available', value: '$available', icon: Icons.event_available_outlined, accent: const Color(0xFF10B981), onTap: () => context.go(AppRouter.tables), onHide: () => setState(() => _hidden.add('available'))),
            ]);
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final two = c.maxWidth >= 850;
            final width = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              if (!_hidden.contains('tables')) SizedBox(width: width, child: _Panel(title: 'Tables in Service', subtitle: 'Live floor status', onHide: () => setState(() => _hidden.add('tables')), child: _TablesPanel(tables: tables))),
              if (!_hidden.contains('transactions')) SizedBox(width: width, child: _Panel(title: 'Recent Transactions', subtitle: 'Latest completed sales', onHide: () => setState(() => _hidden.add('transactions')), child: _TransactionsPanel(sales: sales.take(8).toList()))),
            ]);
          }),
        ]),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onHide;

  const _Kpi({required this.width, required this.label, required this.value, required this.icon, required this.accent, required this.onTap, required this.onHide});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 104,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _ink)),
                const SizedBox(height: 3),
                Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
              ]),
            ),
          ),
          Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Hide widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)))),
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
        height: 345,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 9.5, color: _muted)),
            ])),
            IconButton(tooltip: 'Hide widget', visualDensity: VisualDensity.compact, onPressed: onHide, icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 8),
          Expanded(child: child),
        ]),
      );
}

class _TablesPanel extends StatelessWidget {
  final List<RestaurantTable> tables;
  const _TablesPanel({required this.tables});

  String _status(TableStatus status) {
    switch (status) {
      case TableStatus.occupied: return 'OCCUPIED';
      case TableStatus.served: return 'SERVED';
      case TableStatus.cleared: return 'BILLING';
      default: return 'AVAILABLE';
    }
  }

  Color _statusColor(TableStatus status) {
    switch (status) {
      case TableStatus.occupied: return const Color(0xFFF59E0B);
      case TableStatus.served: return const Color(0xFF3B82F6);
      case TableStatus.cleared: return _purple;
      default: return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = tables.where((t) => t.status != TableStatus.empty).take(9).toList();
    if (active.isEmpty) return const Center(child: Text('No tables in service.', style: TextStyle(color: _muted)));
    return ListView.separated(
      itemCount: active.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = active[i];
        final color = _statusColor(t.status);
        return InkWell(
          onTap: () => context.go(AppRouter.tables),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Table ${t.tableNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
                Text('${t.numberOfSeats} seats', style: const TextStyle(fontSize: 9.5, color: _muted)),
              ])),
              Text(_status(t.status), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3.6),
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
