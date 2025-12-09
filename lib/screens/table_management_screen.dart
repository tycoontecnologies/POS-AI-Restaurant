import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_input.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final _tableNumberController = TextEditingController();
  final _seatsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TableProvider>(context, listen: false).loadTables();
    });
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _showAddTableDialog() {
    _tableNumberController.clear();
    _seatsController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Table'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInput(
                controller: _tableNumberController,
                label: 'Table Number',
                keyboardType: TextInputType.text, // Changed from number to text
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInput(
                controller: _seatsController,
                label: 'Number of Seats',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final tableNumber = _tableNumberController.text.trim();
              final seats = int.tryParse(_seatsController.text);

              if (tableNumber.isEmpty || seats == null) {
                // Changed validation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid table number and seats'),
                  ),
                );
                return;
              }

              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.addTable(
                tableNumber,
                seats,
              ); // Changed parameter type

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Table added successfully')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(RestaurantTable table) {
    _seatsController.text = table.numberOfSeats.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Table'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Table ${table.tableNumber}'),
              const SizedBox(height: AppSpacing.md),
              CustomInput(
                controller: _seatsController,
                label: 'Number of Seats',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Status:'),
              const SizedBox(height: AppSpacing.sm),
              ..._buildStatusButtons(table),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final seats = int.tryParse(_seatsController.text);
              if (seats == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid number')),
                );
                return;
              }

              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.updateTable(table.id, numberOfSeats: seats);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Table updated successfully')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusButtons(RestaurantTable table) {
    return [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          FilterChip(
            label: const Text('Empty'),
            selected: table.status == TableStatus.empty,
            onSelected: (_) async {
              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.updateTableStatus(table.id, TableStatus.empty);
              if (mounted) Navigator.pop(context);
            },
            backgroundColor: Colors.grey.shade300,
            selectedColor: Colors.grey.shade400,
          ),
          FilterChip(
            label: const Text('Occupied'),
            selected: table.status == TableStatus.occupied,
            onSelected: (_) async {
              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.updateTableStatus(table.id, TableStatus.occupied);
              if (mounted) Navigator.pop(context);
            },
            backgroundColor: AppColors.success.withOpacity(0.3),
            selectedColor: AppColors.success,
          ),
          FilterChip(
            label: const Text('Served'),
            selected: table.status == TableStatus.served,
            onSelected: (_) async {
              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.updateTableStatus(table.id, TableStatus.served);
              if (mounted) Navigator.pop(context);
            },
            backgroundColor: Colors.orange.withOpacity(0.3),
            selectedColor: Colors.orange.shade300,
          ),
        ],
      ),
    ];
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.grey.shade300;
      case TableStatus.occupied:
        return Colors.green.shade300;
      case TableStatus.served:
        return Colors.orange.shade300;
      case TableStatus.cleared:
        return Colors.blue.shade400;
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
      case TableStatus.cleared:
        return 'Cleared';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CustomButton(
                text: 'Add Table',
                onPressed: _showAddTableDialog,
                icon: Icons.add,
                variant: ButtonVariant.filled,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProvider, child) {
          if (tableProvider.isLoading && tableProvider.tables.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tableProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error: ${tableProvider.error}'),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton(
                    text: 'Retry',
                    onPressed: () => tableProvider.refreshTables(),
                    variant: ButtonVariant.filled,
                  ),
                ],
              ),
            );
          }

          if (tableProvider.tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart, size: 64, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No tables added yet'),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton(
                    text: 'Add First Table',
                    onPressed: _showAddTableDialog,
                    icon: Icons.add,
                    variant: ButtonVariant.filled,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, // 5 cards in a row
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: tableProvider.tables.length,
            itemBuilder: (context, index) {
              final table = tableProvider.tables[index];
              final statusColor = _getStatusColor(table.status);
              final statusLabel = _getStatusLabel(table.status);

              return GestureDetector(
                onTap: () => _showEditTableDialog(table),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        offset: const Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // STATUS BUBBLE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Table number big + nice UI box
                      Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            table.tableNumber, // Already String
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Seats
                      Text(
                        '${table.numberOfSeats} seats',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),

                      const Spacer(),

                      // Edit + Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue.shade700),
                            onPressed: () => _showEditTableDialog(table),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Table'),
                                  content: Text(
                                    'Are you sure you want to delete Table ${table.tableNumber}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        final provider =
                                            Provider.of<TableProvider>(
                                              context,
                                              listen: false,
                                            );
                                        await provider.deleteTable(table.id);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Table deleted successfully',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
