import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/screens/pos_order_screen_v6.dart' as v6;

class TableOrderScreen extends StatelessWidget {
  final RestaurantTable table;
  const TableOrderScreen({super.key, required this.table});

  Future<void> _markServed(BuildContext context) async {
    await context.read<TableOrderProvider>().setOrderStatus(table.id, 'served');
    await context.read<TableProvider>().updateTableStatus(table.id, TableStatus.served);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order marked served. Checkout and bill actions are now available.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<TableOrderProvider>();
    final status = orders.getOrderStatus(table.id).toLowerCase();
    final hasItems = orders.getOrderForTable(table.id).isNotEmpty;
    final served = status == 'served';
    final showServed = hasItems && (status == 'making' || status == 'ready');

    return Stack(
      children: [
        v6.TableOrderScreen(table: table),
        // Do not show a disabled PRINT BILL action before the order reaches
        // the served/checkout stage. The underlying V6 screen remains intact.
        if (hasItems && !served)
          Positioned(
            right: 14,
            bottom: 8,
            width: 187,
            height: 58,
            child: IgnorePointer(
              child: ColoredBox(color: Colors.white),
            ),
          ),
        if (showServed)
          Positioned(
            right: 15,
            bottom: 108,
            width: 360,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: () => _markServed(context),
                  icon: const Icon(Icons.room_service_outlined, size: 18),
                  label: Text(status == 'ready' ? 'MARK SERVED' : 'MARK SERVED WHEN DELIVERED'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
