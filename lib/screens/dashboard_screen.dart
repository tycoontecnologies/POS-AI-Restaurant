import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        final tables = provider.tables;
        final available = tables.where((t) => t.status == TableStatus.empty).length;
        final active = tables.where((t) => t.status != TableStatus.empty).length;

        return Container(
          color: AppColors.backgroundLight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Order', style: TextStyle(color: AppColors.grey900, fontSize: 28, fontWeight: FontWeight.w800)),
                          SizedBox(height: 5),
                          Text('Choose how the guest is ordering.', style: TextStyle(color: AppColors.grey500, fontSize: 13)),
                        ],
                      ),
                    ),
                    _StatusPill(label: '$active active', icon: Icons.local_fire_department_outlined),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 28) / 3
                        : constraints.maxWidth >= 580
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _OrderTypeCard(
                            icon: Icons.restaurant_rounded,
                            title: 'Dine In',
                            subtitle: 'Choose a table and start service',
                            badge: '$available tables available',
                            primary: true,
                            onTap: () => context.go(AppRouter.tables),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _OrderTypeCard(
                            icon: Icons.shopping_bag_outlined,
                            title: 'Take Away',
                            subtitle: 'Fast counter order, no table required',
                            badge: 'Counter order',
                            onTap: () => context.go(AppRouter.sales),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _OrderTypeCard(
                            icon: Icons.delivery_dining_outlined,
                            title: 'Delivery',
                            subtitle: 'Create an order for delivery',
                            badge: 'Customer details',
                            onTap: () => context.go(AppRouter.sales),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Restaurant Floor', style: TextStyle(color: AppColors.grey900, fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 3),
                          Text('Tap a table to open or continue its order.', style: TextStyle(color: AppColors.grey500, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go(AppRouter.orders),
                      icon: const Icon(Icons.receipt_long_outlined, size: 17),
                      label: const Text('Active Orders'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.isLoading && tables.isEmpty)
                  const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
                else if (tables.isEmpty)
                  _EmptyFloor(onTap: () => context.go(AppRouter.tables))
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 1100
                          ? 5
                          : constraints.maxWidth >= 820
                              ? 4
                              : constraints.maxWidth >= 580
                                  ? 3
                                  : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tables.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemBuilder: (_, i) => _TableTile(table: tables[i]),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool primary;
  final VoidCallback onTap;

  const _OrderTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 166,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary ? AppColors.primary : AppColors.outlineLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primary ? Colors.white.withValues(alpha: .14) : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: primary ? Colors.white : AppColors.primary, size: 22),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: primary ? Colors.white70 : AppColors.grey400, size: 20),
                ],
              ),
              const Spacer(),
              Text(title, style: TextStyle(color: primary ? Colors.white : AppColors.grey900, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? Colors.white70 : AppColors.grey500, fontSize: 11.5)),
              const SizedBox(height: 7),
              Text(badge, style: TextStyle(color: primary ? Colors.white : AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  final RestaurantTable table;
  const _TableTile({required this.table});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(table.status);
    final label = _statusLabel(table.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/table-order/${table.id}', extra: table),
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
                  Expanded(child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .45))),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 18),
                ],
              ),
              const Spacer(),
              Text('Table ${table.tableNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${table.numberOfSeats} seats', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(TableStatus s) {
    switch (s) {
      case TableStatus.empty: return AppColors.success;
      case TableStatus.occupied: return AppColors.error;
      case TableStatus.served: return AppColors.warning;
      case TableStatus.cleared: return AppColors.info;
    }
  }

  static String _statusLabel(TableStatus s) {
    switch (s) {
      case TableStatus.empty: return 'Available';
      case TableStatus.occupied: return 'In Service';
      case TableStatus.served: return 'Served';
      case TableStatus.cleared: return 'Billing';
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatusPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineLight)),
      child: Row(children: [Icon(icon, size: 15, color: AppColors.primary), const SizedBox(width: 6), Text(label, style: const TextStyle(color: AppColors.grey700, fontSize: 11, fontWeight: FontWeight.w600))]),
    );
  }
}

class _EmptyFloor extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyFloor({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.table_restaurant_outlined, size: 32, color: AppColors.grey400),
        const SizedBox(height: 10),
        const Text('No tables configured', style: TextStyle(color: AppColors.grey800, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextButton(onPressed: onTap, child: const Text('Manage tables')),
      ]),
    );
  }
}
