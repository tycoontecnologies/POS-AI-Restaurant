import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/screens/table_management_screen.dart';
import 'package:pos/utils/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final tables = context.read<TableProvider>();
    if (tables.tables.isEmpty && !tables.isLoading) tables.loadTables();

    final user = context.read<AuthProvider>().currentUser;
    final sales = context.read<SaleProvider>();
    if (user != null && sales.sales.isEmpty && !sales.isLoading) {
      sales.fetchSales(user.id);
    }
  }

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month && value.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user != null && !user.isAdmin) {
      return const TableManagementScreen();
    }

    final tables = context.watch<TableProvider>();
    final sales = context.watch<SaleProvider>();

    final activeTables = tables.tables.where((t) => t.status != TableStatus.empty).toList();
    final available = tables.tables.where((t) => t.status == TableStatus.empty).length;
    final occupied = tables.tables.where((t) => t.status == TableStatus.occupied).length;
    final served = tables.tables.where((t) => t.status == TableStatus.served).length;
    final todaySales = sales.sales.where((s) => _isToday(s.createdAt)).toList();
    final todayRevenue = todaySales.fold<double>(0, (sum, sale) => sum + sale.total);
    final recent = sales.sales.take(5).toList();

    return Container(
      color: AppColors.backgroundLight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 34),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Restaurant Command Center', style: TextStyle(color: AppColors.grey900, fontSize: 27, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Admin overview for sales, service and restaurant activity.', style: TextStyle(color: AppColors.grey500, fontSize: 12.5)),
              ]),
            ),
            FilledButton.icon(
              onPressed: () => context.go(AppRouter.tables),
              icon: const Icon(Icons.table_restaurant_rounded),
              label: const Text('Open Table Operations'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            ),
          ]),
          const SizedBox(height: 22),

          LayoutBuilder(builder: (_, c) {
            final width = c.maxWidth >= 920 ? (c.maxWidth - 36) / 4 : (c.maxWidth - 12) / 2;
            final cards = [
              _Metric(label: "Today's Sales", value: 'Rs ${todayRevenue.toStringAsFixed(0)}', icon: Icons.payments_outlined, color: AppColors.primary),
              _Metric(label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, color: AppColors.info),
              _Metric(label: 'In Service', value: '$occupied', icon: Icons.restaurant_outlined, color: AppColors.warning),
              _Metric(label: 'Ready / Served', value: '$served', icon: Icons.room_service_outlined, color: AppColors.success),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: cards.map((x) => SizedBox(width: width, child: x)).toList());
          }),

          const SizedBox(height: 26),
          const Text('Quick Operations', style: TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$available tables currently available', style: const TextStyle(color: AppColors.grey500, fontSize: 11.5)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (_, c) {
            final w = c.maxWidth >= 820 ? (c.maxWidth - 24) / 3 : c.maxWidth;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: w, child: _OrderType(icon: Icons.table_restaurant_rounded, title: 'Table Operations', subtitle: 'Open operator floor view', accent: true, onTap: () => context.go(AppRouter.tables))),
              SizedBox(width: w, child: _OrderType(icon: Icons.shopping_bag_outlined, title: 'Take Away', subtitle: 'Fast counter order', onTap: () => context.go(AppRouter.sales))),
              SizedBox(width: w, child: _OrderType(icon: Icons.delivery_dining_outlined, title: 'Delivery', subtitle: 'Customer and delivery order', onTap: () => context.go(AppRouter.sales))),
            ]);
          }),

          const SizedBox(height: 28),
          LayoutBuilder(builder: (_, c) {
            final stacked = c.maxWidth < 940;
            final active = _ActiveService(tables: activeTables, loading: tables.isLoading);
            final recentOrders = _RecentOrders(sales: recent, loading: sales.isLoading);
            if (stacked) {
              return Column(children: [active, const SizedBox(height: 16), recentOrders]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: active),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: recentOrders),
            ]);
          }),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 13),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _OrderType extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;
  const _OrderType({required this.icon, required this.title, required this.subtitle, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 116,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: accent ? AppColors.primary : AppColors.outlineLight)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: accent ? Colors.white.withValues(alpha: .15) : AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent ? Colors.white : AppColors.primary, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent ? Colors.white : AppColors.grey900)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: accent ? Colors.white70 : AppColors.grey500)),
            ])),
            Icon(Icons.arrow_forward_rounded, size: 19, color: accent ? Colors.white70 : AppColors.grey400),
          ]),
        ),
      ),
    );
  }
}

class _ActiveService extends StatelessWidget {
  final List<RestaurantTable> tables;
  final bool loading;
  const _ActiveService({required this.tables, required this.loading});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Active Service',
      subtitle: 'Only tables currently in use are shown here.',
      trailing: TextButton(onPressed: () => context.go(AppRouter.tables), child: const Text('View table operations')),
      child: loading && tables.isEmpty
          ? const SizedBox(height: 210, child: Center(child: CircularProgressIndicator()))
          : tables.isEmpty
              ? const SizedBox(height: 210, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.table_restaurant_outlined, size: 34, color: AppColors.grey300),
                  SizedBox(height: 10),
                  Text('No active tables', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey700)),
                  SizedBox(height: 4),
                  Text('Active service will appear here.', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                ])))
              : LayoutBuilder(builder: (_, c) {
                  final cols = c.maxWidth >= 760 ? 3 : c.maxWidth >= 500 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tables.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.75),
                    itemBuilder: (_, i) => _ActiveTable(table: tables[i]),
                  );
                }),
    );
  }
}

class _ActiveTable extends StatelessWidget {
  final RestaurantTable table;
  const _ActiveTable({required this.table});
  @override
  Widget build(BuildContext context) {
    final served = table.status == TableStatus.served;
    final billing = table.status == TableStatus.cleared;
    final color = served ? AppColors.success : billing ? AppColors.info : AppColors.warning;
    final label = served ? 'Served' : billing ? 'Billing' : 'In Service';
    return Material(
      color: AppColors.grey50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('/table-order/${table.id}', extra: table),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.grey400)]),
            const Spacer(),
            Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900)),
            const SizedBox(height: 3),
            Text('${table.numberOfSeats} seats', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
          ]),
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final List<Sale> sales;
  final bool loading;
  const _RecentOrders({required this.sales, required this.loading});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent Orders',
      subtitle: 'Latest completed sales.',
      trailing: TextButton(onPressed: () => context.go(AppRouter.orders), child: const Text('View orders')),
      child: loading && sales.isEmpty
          ? const SizedBox(height: 210, child: Center(child: CircularProgressIndicator()))
          : sales.isEmpty
              ? const SizedBox(height: 210, child: Center(child: Text('No completed orders yet', style: TextStyle(color: AppColors.grey500))))
              : Column(children: sales.map((sale) => _SaleRow(sale: sale)).toList()),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final Sale sale;
  const _SaleRow({required this.sale});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 17)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sale.tableNumber == null ? 'Order' : 'Table ${sale.tableNumber}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.grey800)),
          const SizedBox(height: 2),
          Text('${sale.items.length} items', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
        ])),
        Text('Rs ${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        ])), trailing]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
