import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_input.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final _tableNumberController = TextEditingController();
  final _seatsController = TextEditingController();
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableProvider>().loadTables();
    });
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _showAddTableDialog() async {
    _tableNumberController.clear();
    _seatsController.clear();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add table'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInput(
                controller: _tableNumberController,
                label: 'Table number',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInput(
                controller: _seatsController,
                label: 'Number of seats',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final tableNumber = _tableNumberController.text.trim();
              final seats = int.tryParse(_seatsController.text.trim());
              if (tableNumber.isEmpty || seats == null || seats <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid table number and seat count')),
                );
                return;
              }

              await context.read<TableProvider>().addTable(tableNumber, seats);
              if (!mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Table added successfully')),
              );
            },
            child: const Text('Add table'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTableDialog(RestaurantTable table) async {
    _seatsController.text = table.numberOfSeats.toString();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Table ${table.tableNumber}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomInput(
                controller: _seatsController,
                label: 'Number of seats',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              const Text('Table status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TableStatus.values.map((status) {
                  final selected = table.status == status;
                  return ChoiceChip(
                    label: Text(_statusLabel(status)),
                    selected: selected,
                    onSelected: (_) async {
                      await context.read<TableProvider>().updateTableStatus(table.id, status);
                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final seats = int.tryParse(_seatsController.text.trim());
              if (seats == null || seats <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid seat count')),
                );
                return;
              }
              await context.read<TableProvider>().updateTable(table.id, numberOfSeats: seats);
              if (!mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Table updated successfully')),
              );
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete table'),
        content: Text('Delete Table ${table.tableNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<TableProvider>().deleteTable(table.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Table deleted successfully')),
    );
  }

  String _statusLabel(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.served:
        return 'Served';
      case TableStatus.cleared:
        return 'Billing';
    }
  }

  Color _statusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.error;
      case TableStatus.served:
        return AppColors.info;
      case TableStatus.cleared:
        return AppColors.warning;
    }
  }

  List<RestaurantTable> _filteredTables(List<RestaurantTable> tables) {
    if (_filter == 'All') return tables;
    return tables.where((table) => _statusLabel(table.status) == _filter).toList();
  }

  int _count(List<RestaurantTable> tables, String status) {
    if (status == 'All') return tables.length;
    return tables.where((table) => _statusLabel(table.status) == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, tableProvider, child) {
        if (tableProvider.isLoading && tableProvider.tables.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (tableProvider.error != null) {
          return _ErrorState(
            message: tableProvider.error.toString(),
            onRetry: tableProvider.refreshTables,
          );
        }

        final allTables = tableProvider.tables;
        final tables = _filteredTables(allTables);

        return Padding(
          padding: const EdgeInsets.all(24),
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
                          'Restaurant Floor',
                          style: TextStyle(
                            color: AppColors.grey900,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'View availability and manage your dining tables.',
                          style: TextStyle(color: AppColors.grey500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddTableDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add table'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['All', 'Available', 'Occupied', 'Served', 'Billing'].map((status) {
                  final selected = _filter == status;
                  return InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _filter = status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primarySoft : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.outlineLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status,
                            style: TextStyle(
                              color: selected ? AppColors.primaryDark : AppColors.grey600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : AppColors.grey100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _count(allTables, status).toString(),
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: tables.isEmpty
                    ? const _EmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final columns = width >= 1250
                              ? 5
                              : width >= 950
                                  ? 4
                                  : width >= 680
                                      ? 3
                                      : 2;
                          return GridView.builder(
                            itemCount: tables.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.35,
                            ),
                            itemBuilder: (context, index) {
                              final table = tables[index];
                              return _TableCard(
                                table: table,
                                label: _statusLabel(table.status),
                                statusColor: _statusColor(table.status),
                                onEdit: () => _showEditTableDialog(table),
                                onDelete: () => _deleteTable(table),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableCard extends StatefulWidget {
  final RestaurantTable table;
  final String label;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableCard({
    required this.table,
    required this.label,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? AppColors.grey300 : AppColors.outlineLight),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.055),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onEdit,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: widget.statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        widget.label.toUpperCase(),
                        style: TextStyle(
                          color: widget.statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Table actions',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded, color: AppColors.grey400, size: 20),
                        onSelected: (value) {
                          if (value == 'edit') widget.onEdit();
                          if (value == 'delete') widget.onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit table')),
                          PopupMenuItem(value: 'delete', child: Text('Delete table')),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Table ${widget.table.tableNumber}',
                    style: const TextStyle(
                      color: AppColors.grey900,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.chair_alt_outlined, size: 16, color: AppColors.grey400),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.table.numberOfSeats} seats',
                        style: const TextStyle(color: AppColors.grey500, fontSize: 12.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Divider(height: 1, color: AppColors.outlineLight),
                  const SizedBox(height: 11),
                  const Row(
                    children: [
                      Text('Manage table', style: TextStyle(color: AppColors.grey500, fontSize: 11.5)),
                      Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.grey400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant_outlined, size: 48, color: AppColors.grey300),
          SizedBox(height: 12),
          Text('No tables found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 5),
          Text('Try another status filter or add a new table.', style: TextStyle(color: AppColors.grey500)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Unable to load tables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
