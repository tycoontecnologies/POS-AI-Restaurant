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
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final tables = context.read<TableProvider>();
    if (tables.tables.isEmpty && !tables.isLoading) {
      tables.loadTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showOrderPanel = width >= 1120;

    return Row(
      children: [
        Expanded(
          child: Consumer<TableProvider>(
            builder: (context, provider, _) => _DashboardBody(provider: provider),
          ),
        ),
        if (showOrderPanel)
          const SizedBox(
            width: 360,
            child: _CurrentOrderPanel(),
          ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final TableProvider provider;
  const _DashboardBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tables = provider.tables;
    final available = tables.where((t) => t.status == TableStatus.empty).length;
    final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
    final served = tables.where((t) => t.status == TableStatus.served).length;
    final visibleTables = tables.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Restaurant floor and active service overview.',
                      style: TextStyle(color: AppColors.grey500, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRouter.tables),
                icon: const Icon(Icons.table_restaurant_outlined, size: 18),
                label: const Text('All tables'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.grey800,
                  side: const BorderSide(color: AppColors.outlineLight),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 850 ? 4 : 2;
              final width = (constraints.maxWidth - ((count - 1) * 12)) / count;
              final cards = [
                _MetricCard('Total Tables', '${tables.length}', Icons.table_restaurant_outlined, AppColors.info),
                _MetricCard('Available', '$available', Icons.check_circle_outline, AppColors.success),
                _MetricCard('Occupied', '$occupied', Icons.people_alt_outlined, AppColors.error),
                _MetricCard('Served', '$served', Icons.room_service_outlined, AppColors.warning),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((e) => SizedBox(width: width, child: e)).toList(),
              );
            },
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Restaurant Floor',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontSize: 17,
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
            const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
          else if (tables.isEmpty)
            const _EmptyFloor()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 700
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
                    childAspectRatio: 1.9,
                  ),
                  itemBuilder: (_, index) => _TableCard(table: visibleTables[index]),
                );
              },
            ),
          const SizedBox(height: 22),
          _OperationsBar(onTables: () => context.go(AppRouter.tables)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.grey900,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 11.5)),
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
            border: Border.all(color: AppColors.outlineLight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Table ${table.tableNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey900, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text('${table.numberOfSeats} seats', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 20),
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
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Order', style: TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Live bill summary', style: TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    if (!cart.isCartEmpty)
                      TextButton(onPressed: () => _confirmClear(context, cart), child: const Text('Clear')),
                  ],
                ),
              ),
              if (table != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_restaurant_outlined, size: 17, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Table ${table.tableNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.grey800, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      const Text('Dine In', style: TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                    ],
                  ),
                ),
              Expanded(
                child: cart.isCartEmpty
                    ? const _EmptyOrder()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        itemCount: cart.cartItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.outlineVariantLight),
                        itemBuilder: (context, index) {
                          final item = cart.cartItems[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
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
                                        style: const TextStyle(color: AppColors.grey900, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 3),
                                      Text('Rs ${item.unitPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                                      const SizedBox(height: 7),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _QtyButton(Icons.remove_rounded, () => cart.updateQuantity(item, item.quantity - 1)),
                                          SizedBox(
                                            width: 30,
                                            child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                          ),
                                          _QtyButton(Icons.add_rounded, () {
                                            try {
                                              cart.updateQuantity(item, item.quantity + 1);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                            }
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Rs ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Remove item',
                                      onPressed: () => cart.removeFromCart(item),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.grey400),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              _OrderFooter(cart: cart, table: table),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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

class _OrderFooter extends StatelessWidget {
  final CartProvider cart;
  final RestaurantTable? table;
  const _OrderFooter({required this.cart, required this.table});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.outlineLight))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BillRow('Items', '${cart.totalItems}'),
          const SizedBox(height: 6),
          _BillRow('Subtotal', 'Rs ${cart.total.toStringAsFixed(0)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.outlineLight),
          ),
          _BillRow('Total', 'Rs ${cart.total.toStringAsFixed(0)}', strong: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                if (table != null) {
                  context.go('/table-order/${table!.id}', extra: table);
                } else {
                  context.go(AppRouter.tables);
                }
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add More Items'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRouter.salesReturn),
                    child: const FittedBox(child: Text('Return / Refund', style: TextStyle(fontSize: 10.5))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: table == null ? null : () => context.go('/table-order/${table!.id}', extra: table),
                    child: const FittedBox(child: Text('KOT / Bill', style: TextStyle(fontSize: 10.5))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: cart.isCartEmpty || table == null ? null : () => context.go('/table-order/${table!.id}', extra: table),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: FittedBox(
                child: Text(
                  cart.isCartEmpty ? 'Start an Order' : 'Continue • Rs ${cart.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.receipt_long_outlined, color: AppColors.grey400, size: 25),
                    ),
                    const SizedBox(height: 12),
                    const Text('No items yet', style: TextStyle(color: AppColors.grey800, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                      'Open a table and add menu items. They will appear here instantly.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grey500, height: 1.35, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Icon(icon, size: 14, color: AppColors.grey700),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _BillRow(this.label, this.value, {this.strong = false});

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

class _OperationsBar extends StatelessWidget {
  final VoidCallback onTables;
  const _OperationsBar({required this.onTables});

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
                Text('Operations', style: TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Open the table floor to start or continue service.', style: TextStyle(color: AppColors.grey500, fontSize: 10.5)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onTables,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.table_restaurant_outlined, size: 17),
            label: const Text('Open Tables'),
          ),
        ],
      ),
    );
  }
}

class _EmptyFloor extends StatelessWidget {
  const _EmptyFloor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: const Center(
        child: Text('No tables available', style: TextStyle(color: AppColors.grey500)),
      ),
    );
  }
}
