import 'package:flutter/material.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class TableOrderDialog extends StatefulWidget {
  final Function(RestaurantTable) onTableSelected;

  const TableOrderDialog({super.key, required this.onTableSelected});

  @override
  State<TableOrderDialog> createState() => _TableOrderDialogState();
}

class _TableOrderDialogState extends State<TableOrderDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      if (tableProvider.tables.isEmpty && !tableProvider.isLoading) {
        tableProvider.loadTables();
      }
    });
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.grey.shade300; // Silver
      case TableStatus.occupied:
        return Colors.green.shade300; // Green
      case TableStatus.served:
        return Colors.orange.shade300; // Orange
    }
  }

  String _getStatusLabel(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Empty';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.served:
        return 'Served';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Consumer<TableProvider>(
        builder: (context, tableProvider, child) {
          if (tableProvider.isLoading && tableProvider.tables.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Loading tables...'),
                ],
              ),
            );
          }

          if (tableProvider.error != null) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error: ${tableProvider.error}'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => tableProvider.loadTables(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tables = tableProvider.tables;

          if (tables.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_chart, size: 48, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No tables available'),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Add tables from the Table Management page',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select a Table',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  shrinkWrap: true,
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    final table = tables[index];
                    final statusColor = _getStatusColor(table.status);
                    final statusLabel = _getStatusLabel(table.status);

                    return GestureDetector(
                      onTap: () {
                        final cartProvider = Provider.of<CartProvider>(
                          context,
                          listen: false,
                        );
                        cartProvider.setSelectedTable(table);

                        widget.onTableSelected(table);
                        Navigator.of(context).pop();
                      },
                      child: Card(
                        color: statusColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.2),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Table ${table.tableNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '${table.numberOfSeats} seats',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
