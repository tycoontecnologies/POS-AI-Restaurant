import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _requestedTables = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedTables) {
      _requestedTables = true;
      final provider = context.read<TableProvider>();
      if (provider.tables.isEmpty && !provider.isLoading) {
        provider.loadTables();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Consumer<TableProvider>(
            builder: (context, tables, _) => _DashboardWorkspace(
              provider: tables,
            ),
          ),
        ),
        if (MediaQuery.of(context).size.width >= 1180)
          const SizedBox(width: 340, child: _CurrentOrderPanel()),
      ],
    );
  }
}

class _DashboardWorkspace extends StatelessWidget {
  final TableProvider provider;
  const _DashboardWorkspace({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tables = provider.tables;
    final available = tables.where((t) => t.status == TableStatus.empty).length;
    final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
    final served = tables.where((t) => t.status == TableStatus.served).length;
    final visibleTables = tables.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today at a glance',
                      style: TextStyle(
                        color: AppColors.grey900,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fast access to your restaurant floor and active orders.',
                      style: TextStyle(
                        color: AppColors.grey500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRouter.tables),
                icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                label: const Text('All tables'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.grey800,
                  side: const BorderSide(color: AppColors.outlineLight),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final cards = [
                _MetricCard(
                  label: 'Total Tables',
                  value: '${tables.length}',
                  icon: Icons.table_restaurant_rounded,
                  accent: AppColors.info,
                ),
                _MetricCard(
                  label: 'Available',
                  value: '$available',
                  icon: Icons.check_circle_outline_rounded,
                  accent: AppColors.success,
                ),
                _MetricCard(
                  label: 'Occupied',
                  value: '$occupied',
                  icon: Icons.people_alt_outlined,
                  accent: AppColors.error,
                ),
                _MetricCard(
                  label: 'Served',
                  value: '$served',
                  icon: Icons.room_service_outlined,
                  accent: AppColors.warning,
                ),
              ];

              if (compact) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: card,
                          ))
                      .toList(),
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Restaurant Floor',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRouter.tables),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (provider.isLoading && tables.isEmpty)
            const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tables.isEmpty)
            _EmptyTables(onPressed: () => context.go(AppRouter.tables))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 5
                    : constraints.maxWidth >= 760
                        ? 4
                        : constraints.maxWidth >= 520
                            ? 3
                            : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleTables.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (context, index) =>
                      _TableCard(table: visibleTables[index]),
                );
              },
            ),
          const SizedBox(height: 24),
          const _FastActions(),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.grey900,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.grey500,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  const _TableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(table.status);
    final label = _statusLabel(table.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/table-order/${table.id}', extra: table),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.grey400,
                    size: 18,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Table ${table.tableNumber}',
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${table.numberOfSeats} seats',
                style: const TextStyle(
                  color: AppColors.grey500,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.error;
      case TableStatus.served:
        return AppColors.warning;
      case TableStatus.cleared:
        return AppColors.info;
    }
  }

  static String _statusLabel(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.served:
        return 'Served';
      case TableStatus.cleared:
        return 'Cleared';
    }
  }
}

class _CurrentOrderPanel extends StatelessWidget {
  const _CurrentOrderPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final table = cart.selectedTable;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: AppColors.outlineLight)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Order',
                            style: TextStyle(
                              color: AppColors.grey900,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Live bill summary',
                            style: TextStyle(
                              color: AppColors.grey500,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!cart.isCartEmpty)
                      TextButton(
                        onPressed: () => _confirmClear(context, cart),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.outlineLight),
              if (table != null)
                Container(
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.table_restaurant_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Table ${table.tableNumber}',
                          style: const TextStyle(
                            color: AppColors.grey800,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Text(
                        'Dine In',
                        style: TextStyle(
                          color: AppColors.grey500,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: cart.isCartEmpty
                    ? const _EmptyOrder()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: cart.cartItems.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.outlineVariantLight,
                        ),
                        itemBuilder: (context, index) {
                          final item = cart.cartItems[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.grey900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rs ${item.unitPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppColors.grey500,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _QtyButton(
                                            icon: Icons.remove_rounded,
                                            onTap: () => cart.updateQuantity(
                                              item,
                                              item.quantity - 1,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 30,
                                            child: Text(
                                              '${item.quantity}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: AppColors.grey900,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          _QtyButton(
                                            icon: Icons.add_rounded,
                                            onTap: () {
                                              try {
                                                cart.updateQuantity(
                                                  item,
                                                  item.quantity + 1,
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text('$e'),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs ${item.totalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.grey900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    IconButton(
                                      tooltip: 'Remove item',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.grey400,
                                        size: 18,
                                      ),
                                      onPressed: () => cart.removeFromCart(item),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.outlineLight)),
                ),
                child: Column(
                  children: [
                    _BillRow(
                      label: 'Items',
                      value: '${cart.totalItems}',
                    ),
                    const SizedBox(height: 7),
                    _BillRow(
                      label: 'Subtotal',
                      value: 'Rs ${cart.total.toStringAsFixed(0)}',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.outlineLight),
                    ),
                    _BillRow(
                      label: 'Total',
                      value: 'Rs ${cart.total.toStringAsFixed(0)}',
                      strong: true,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (table != null) {
                            context.go('/table-order/${table.id}', extra: table);
                          } else {
                            context.go(AppRouter.tables);
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add More Items'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grey800,
                          side: const BorderSide(color: AppColors.outlineLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () => context.go(AppRouter.salesReturn),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.grey700,
                                side: const BorderSide(
                                  color: AppColors.outlineLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text(
                                'Return / Refund',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: table == null
                                  ? null
                                  : () => context.go(
                                        '/table-order/${table.id}',
                                        extra: table,
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.grey700,
                                side: const BorderSide(
                                  color: AppColors.outlineLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text(
                                'KOT / Bill',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: cart.isCartEmpty || table == null
                            ? null
                            : () => context.go(
                                  '/table-order/${table.id}',
                                  extra: table,
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          cart.isCartEmpty
                              ? 'Start an Order'
                              : 'Continue • Rs ${cart.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear current order?'),
        content: const Text('All items currently in the cart will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(dialogContext);
            },
            child: const Text('Clear Order'),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Icon(icon, size: 15, color: AppColors.grey700),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _BillRow({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? AppColors.grey900 : AppColors.grey500,
              fontSize: strong ? 13 : 11,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.grey900,
            fontSize: strong ? 17 : 11.5,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.grey400,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No items yet',
              style: TextStyle(
                color: AppColors.grey800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Open a table and add menu items.\nThey will appear here instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey500,
                height: 1.45,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTables extends StatelessWidget {
  final VoidCallback onPressed;
  const _EmptyTables({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.table_restaurant_outlined,
            color: AppColors.grey400,
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'No tables available',
            style: TextStyle(
              color: AppColors.grey800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onPressed, child: const Text('Manage tables')),
        ],
      ),
    );
  }
}

class _FastActions extends StatelessWidget {
  const _FastActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operations',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Open a management area without crowding the dashboard.',
                  style: TextStyle(
                    color: AppColors.grey500,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          _SmallAction(
            label: 'Orders',
            icon: Icons.receipt_long_outlined,
            onTap: () => context.go(AppRouter.orders),
          ),
          const SizedBox(width: 7),
          _SmallAction(
            label: 'Inventory',
            icon: Icons.inventory_2_outlined,
            onTap: () => context.go(AppRouter.products),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SmallAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.grey700,
        side: const BorderSide(color: AppColors.outlineLight),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}
