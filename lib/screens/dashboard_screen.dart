import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pos/components/ui/custom_input.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/category.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/custom_button.dart';
import '../routes/app_router.dart';
import 'package:pos/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late CategoryProvider _categoryProvider;
  late ProductProvider _productProvider;
  late StatisticsProvider _statisticsProvider;
  late TableProvider _tableProvider;

  final List<String> _orderTypes = ['Dine In', 'Take Away', 'Delivery'];
  String _selectedOrderType = 'Dine In';

  final _seatsController = TextEditingController();
  final _tableNumberController = TextEditingController();

  final GlobalKey _categoriesGridKey = GlobalKey();
  final GlobalKey _statisticsBarKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _categoryProvider = context.read<CategoryProvider>();
_productProvider = context.read<ProductProvider>();
_statisticsProvider = context.read<StatisticsProvider>();
_tableProvider = context.read<TableProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_categoryProvider.allCategories.isEmpty &&
          !_categoryProvider.isLoading) {
        _categoryProvider.loadInitialCategories();
      }

      if (_tableProvider.tables.isEmpty && !_tableProvider.isLoading) {
        _tableProvider.loadTables();
      }

      final vendorId = _categoryProvider.authProvider?.currentUser?.id;
      if (vendorId != null &&
          _productProvider.products.isEmpty &&
          !_productProvider.isLoading) {
        _productProvider.loadProducts(vendorId);
      }

      if (_statisticsProvider.isLoading) {
        _statisticsProvider.loadStatistics();
      }
    });
  }

  @override
  void dispose() {
    _seatsController.dispose();
    _tableNumberController.dispose();

    super.dispose();
  }

  void _handleViewItems(RestaurantTable table) {
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );

    final orderItems = tableOrderProvider.getOrderForTable(table.id);

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items found for Table ${table.tableNumber}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340), // ⬅ Reduced width
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Title ----------
                  Text(
                    'Items for Table ${table.tableNumber}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---------- List ----------
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orderItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = orderItems[index];

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon box
                            // Container(
                            //   width: 38,
                            //   height: 38,
                            //   decoration: BoxDecoration(
                            //     color: AppColors.primary.withOpacity(0.08),
                            //     borderRadius: BorderRadius.circular(10),
                            //   ),
                            //   child: Icon(
                            //     Icons.fastfood,
                            //     size: 20,
                            //     color: AppColors.primary,
                            //   ),
                            // ),
                            // const SizedBox(width: 12),

                            // Item info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Qty: ${item.quantity}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Price
                            Text(
                              item.totalPrice.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------- Button ----------
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _printBillForTable(RestaurantTable table) async {
    final authProvider = _categoryProvider.authProvider;
    final user = authProvider?.currentUser;
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );
    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to print bill')),
      );
      return;
    }

    // Check if table is in cleared status
    if (table.status != TableStatus.cleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please set Table ${table.tableNumber} to "Cleared" status first',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get items for this table
    final tableOrderItems = tableOrderProvider.getOrderForTable(table.id);

    if (tableOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items found for Table ${table.tableNumber}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate total
    final total = tableOrderItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    // Create a Sale object for the bill
    final sale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      vendorId: user.id,
      items: tableOrderItems.map((item) {
        return SaleItem(
          productId: item.product.id,
          productName: item.displayName,
          quantity: item.quantity,
          price: item.unitPrice,
        );
      }).toList(),
      total: total,
      tableNumber: table.tableNumber,
      createdAt: DateTime.now(),
    );

    try {
      // Use the PDF service to create and print bill
      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      // Clear table order after successful printing
      await tableOrderProvider.clearTableOrder(table.id);

      // Reset table status to empty
      await tableProvider.updateTableStatus(table.id, TableStatus.empty);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bill printed for Table ${table.tableNumber}. Table cleared.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing bill: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          flex: Responsive.isDesktop(context) ? 3 : 1,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: _orderTypes.map((type) {
                    bool isSelected = _selectedOrderType == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: CustomButton(
                          text: type,
                          onPressed: () {
                            setState(() {
                              _selectedOrderType = type;
                            });
                          },
                          // color: isSelected
                          //     ? AppColors.successDark
                          //     : AppColors.warning,
                          color: type == 'Dine In'
                              ? (isSelected
                                    ? AppColors.successDark
                                    : AppColors.success)
                              : type == 'Take Away'
                              ? (isSelected
                                    ? AppColors.secondaryDark
                                    : AppColors.secondary)
                              : (isSelected
                                    ? AppColors.warningDark
                                    : AppColors.warning),
                          textColor: AppColors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Expanded(key: _categoriesGridKey, child: _buildMainContent()),

              Container(
                key: _statisticsBarKey,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Consumer<StatisticsProvider>(
                  builder: (context, statisticsProvider, child) {
                    if (statisticsProvider.isLoading) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          8,
                          (index) => ShimmerEffect(
                            width: 80,
                            height: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }

                    return Responsive.isDesktop(context)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _buildStatistics(
                              l10n,
                              _statisticsProvider.statistics,
                            ),
                          )
                        : Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.sm,
                            children: _buildStatistics(
                              l10n,
                              _statisticsProvider.statistics,
                            ),
                          );
                  },
                ),
              ),
            ],
          ),
        ),

        if (Responsive.isDesktop(context))
          Container(
            key: _quickActionsKey,
            width: 325,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final user = authProvider.currentUser;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: _buildRestaurantLogo(user),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.restaurantName.isNotEmpty == true
                                      ? user!.restaurantName
                                      : 'My Restaurant',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user?.location.isNotEmpty == true
                                      ? user!.location
                                      : 'My Restaurant Address',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.quickActions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 1.3,
                            children: [
                              _buildQuickActionButton(
                                'Add Table',
                                Icons.table_chart,
                                Colors.teal,
                                _showAddTableDialog,
                              ),
                              _buildQuickActionButton(
                                l10n.sales,
                                Icons.shopping_cart,
                                const Color(0xFF8B5CF6),
                                () => context.go(AppRouter.sales),
                              ),
                              _buildQuickActionButton(
                                l10n.products,
                                Icons.add_box,
                                AppColors.success,
                                () => context.go(AppRouter.products),
                              ),
                              _buildQuickActionButton(
                                l10n.categories,
                                Icons.category,
                                AppColors.info,
                                () => context.go(AppRouter.categories),
                              ),
                              _buildQuickActionButton(
                                l10n.staff,
                                Icons.people,
                                AppColors.primary,
                                () => context.go(AppRouter.staff),
                              ),
                              _buildQuickActionButton(
                                l10n.suppliers,
                                Icons.local_shipping,
                                AppColors.warning,
                                () => context.go(AppRouter.suppliers),
                              ),
                              _buildQuickActionButton(
                                l10n.purchases,
                                Icons.shopping_bag,
                                AppColors.error,
                                () => context.go(AppRouter.purchases),
                              ),
                              _buildQuickActionButton(
                                l10n.attendance,
                                Icons.timeline,
                                const Color(0xFF06B6D4),
                                () => context.go(AppRouter.attendance),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: l10n.settings,
                            onPressed: () => context.go(AppRouter.settings),
                            variant: ButtonVariant.filled,
                            icon: Icons.settings,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_selectedOrderType == 'Dine In') {
      return _buildTablesContent();
    } else {
      return _buildCategoriesContent();
    }
  }

  Widget _buildCategoriesContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading &&
              categoryProvider.allCategories.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ShimmerCategoryGrid(
                crossAxisCount: Responsive.isDesktop(context)
                    ? 4
                    : Responsive.isTablet(context)
                    ? 4
                    : 2,
                itemCount: 8,
              ),
            );
          }

          if (categoryProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error: ${categoryProvider.error}'),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton(
                    text: 'Retry',
                    onPressed: () => categoryProvider.refreshCategories(),
                    variant: ButtonVariant.filled,
                  ),
                ],
              ),
            );
          }

          final categories = categoryProvider.allCategories;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 64, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No categories found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomButton(
                    text: 'Refresh',
                    onPressed: () => categoryProvider.refreshCategories(),
                    variant: ButtonVariant.filled,
                  ),
                ],
              ),
            );
          }

          return _PagedCategoryGrid(
            categories: categories,
            onCategoryTap: (category) {
              context.go('/category-products/${category.name}');
            },
          );
        },
      ),
    );
  }

  Widget _buildTablesContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Expanded(
            child: Consumer2<TableProvider, TableOrderProvider>(
              // Add TableOrderProvider to listen for order changes
              builder: (context, tableProvider, tableOrderProvider, child) {
                if (tableProvider.isLoading && tableProvider.tables.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
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

                final tables = tableProvider.tables;

                if (tables.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No tables available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomButton(
                          text: 'Add Table',
                          onPressed: _showAddTableDialog,
                          variant: ButtonVariant.filled,
                        ),
                      ],
                    ),
                  );
                }

                return _TablesGrid(
                  tables: tables,
                  onTableTap: _handleTableTap,
                  onEditTable: _handleEditTable,
                  onDeleteTable: _handleDeleteTable,
                  onPrintBill: _printBillForTable,
                  onViewItems: _handleViewItems,
                  onUpdateStatus: _handleUpdateTableStatus, // Add this callback
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTableDialog() {
    final tableNumberController = TextEditingController();
    final seatsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Table'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInput(
                controller: tableNumberController,
                label: 'Table Number',
                keyboardType: TextInputType.text,
                hint: 'e.g., T1, Table 1',
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInput(
                controller: seatsController,
                label: 'Number of Seats',
                keyboardType: TextInputType.number,
                hint: 'e.g., 2, 4, 6',
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
              final tableNumber = tableNumberController.text.trim();
              final seats = int.tryParse(seatsController.text);

              if (tableNumber.isEmpty || seats == null) {
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
              await provider.addTable(tableNumber, seats);

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

  void _handleTableTap(RestaurantTable table) {
    context.go('/table-order/${table.id}', extra: table);
  }

  void _handleEditTable(RestaurantTable table) {
    _seatsController.text = table.numberOfSeats.toString();
    _tableNumberController.text = table.tableNumber;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Table'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              final seats = int.tryParse(_seatsController.text);
              final tableNumber = _tableNumberController.text.trim();

              if (seats == null || tableNumber.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid number and table number'),
                  ),
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

  void _handleDeleteTable(RestaurantTable table) {
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
              final provider = Provider.of<TableProvider>(
                context,
                listen: false,
              );
              await provider.deleteTable(table.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Table deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantLogo(UserModel? user) {
    if (user?.restaurantLogoUrl != null &&
        user!.restaurantLogoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user.restaurantLogoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => ShimmerEffect(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.circular(8),
        ),
        errorWidget: (context, url, error) => _buildDefaultLogo(),
      );
    }

    return _buildDefaultLogo();
  }

  Widget _buildDefaultLogo() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.restaurant, size: 24, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return CustomButton(
      text: label,
      onPressed: onPressed,
      variant: ButtonVariant.filled,
      icon: icon,
      color: color,
    );
  }

  List<Widget> _buildStatistics(AppLocalizations l10n, Map<String, int> stats) {
    final statistics = [
      {
        'label': l10n.categories,
        'value': stats['categories'] ?? 0,
        'color': AppColors.info,
      },
      {
        'label': l10n.products,
        'value': stats['products'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': l10n.staff,
        'value': stats['staff'] ?? 0,
        'color': AppColors.primary,
      },
      {
        'label': l10n.suppliers,
        'value': stats['suppliers'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': l10n.purchases,
        'value': stats['purchases'] ?? 0,
        'color': Colors.orange,
      },
      {
        'label': l10n.sales,
        'value': stats['sales'] ?? 0,
        'color': Colors.green,
      },
      {
        'label': "Store Out",
        'value': stats['storeOuts'] ?? 0,
        'color': Colors.red,
      },
    ];

    return statistics
        .map(
          (stat) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${stat['label']}: ',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '${stat['value']}',
                    style: TextStyle(
                      color: stat['color'] as Color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  void _handleUpdateTableStatus(
    RestaurantTable table,
    TableStatus newStatus,
  ) async {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    try {
      await tableProvider.updateTableStatus(table.id, newStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Table ${table.tableNumber} marked as ${newStatus.toString().split('.').last}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _PagedCategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final Function(Category) onCategoryTap;

  const _PagedCategoryGrid({
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 4 : 2);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      padding: const EdgeInsets.all(0),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];

        return HoverableCategoryCard(
          category: category,
          onTap: () => onCategoryTap(category),
        );
      },
    );
  }
}

class _TablesGrid extends StatelessWidget {
  final List<RestaurantTable> tables;
  final Function(RestaurantTable) onTableTap;
  final Function(RestaurantTable) onEditTable;
  final Function(RestaurantTable) onDeleteTable;
  final Function(RestaurantTable) onPrintBill;
  final Function(RestaurantTable) onViewItems;
  final Function(RestaurantTable, TableStatus)? onUpdateStatus; // Add this

  const _TablesGrid({
    required this.tables,
    required this.onTableTap,
    required this.onEditTable,
    required this.onDeleteTable,
    required this.onPrintBill,
    required this.onViewItems,
    this.onUpdateStatus, // Add this
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isDesktop ? 5 : (isTablet ? 4 : 3);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        // childAspectRatio: .9,
      ),
      padding: const EdgeInsets.all(0),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return HoverableTableCard(
          table: table,
          onTap: () => onTableTap(table),
          onEdit: () => onEditTable(table),
          onDelete: () => onDeleteTable(table),
          onPrintBill: () => onPrintBill(table),
          onViewItems: () => onViewItems(table),
          onUpdateStatus: onUpdateStatus, // Pass the callback
        );
      },
    );
  }
}

class HoverableTableCard extends StatefulWidget {
  final RestaurantTable table;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrintBill;
  final VoidCallback onViewItems;
  final Function(RestaurantTable, TableStatus)? onUpdateStatus;

  const HoverableTableCard({
    super.key,
    required this.table,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPrintBill,
    required this.onViewItems,
    this.onUpdateStatus,
  });

  @override
  State<HoverableTableCard> createState() => _HoverableTableCardState();
}

class _HoverableTableCardState extends State<HoverableTableCard> {
  bool _isHovered = false;

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.grey.shade400;
      case TableStatus.occupied:
        return Colors.orange.shade400;
      case TableStatus.served:
        return Colors.green.shade500;
      case TableStatus.cleared:
        return Colors.blue.shade500;
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

  // Get next status in the flow
  TableStatus? _getNextStatus(TableStatus current) {
    switch (current) {
      case TableStatus.empty:
        return TableStatus.occupied;
      case TableStatus.occupied:
        return TableStatus.served;
      case TableStatus.served:
        return TableStatus.cleared;
      case TableStatus.cleared:
        return null;
    }
  }

  // Get status button text and color
  Map<String, dynamic> _getStatusButtonInfo(TableStatus current) {
    final nextStatus = _getNextStatus(current);

    if (nextStatus == null) {
      return {
        'text': 'Print Bill',
        'color': AppColors.success,
        'icon': Icons.print,
      };
    }

    switch (nextStatus) {
      case TableStatus.occupied:
        return {
          'text': 'Occupy',
          'color': Colors.orange.shade400,
          'icon': Icons.person,
        };
      case TableStatus.served:
        return {
          'text': 'Serve',
          'color': Colors.green.shade400,
          'icon': Icons.check_circle,
        };
      case TableStatus.cleared:
        return {
          'text': 'Clear',
          'color': Colors.blue.shade400,
          'icon': Icons.cleaning_services,
        };
      default:
        return {
          'text': 'Update',
          'color': AppColors.primary,
          'icon': Icons.edit,
        };
    }
  }

  // Handle status update
  void _handleStatusUpdate() {
    final currentStatus = widget.table.status;
    final nextStatus = _getNextStatus(currentStatus);

    if (nextStatus != null && widget.onUpdateStatus != null) {
      widget.onUpdateStatus!(widget.table, nextStatus);
    } else if (currentStatus == TableStatus.cleared) {
      widget.onPrintBill();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.table.status);
    final tableOrderProvider = context.read<TableOrderProvider>();

final orderItems = tableOrderProvider.getOrderForTable(widget.table.id);

final orderCount = orderItems.length;

double totalAmount = 0;
for (final item in orderItems) {
  totalAmount += item.totalPrice;
}
    final statusButtonInfo = _getStatusButtonInfo(widget.table.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: statusColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. HEADER: Table number + Edit/Delete buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
                child: Row(
                children: [
                  // Table number with status badge
                  Expanded(
  child: Text(
    widget.table.tableNumber,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  ),
),

const SizedBox(width: 8),

Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 4,
  ),
  decoration: BoxDecoration(
    color: statusColor,
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    _getStatusLabel(widget.table.status),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
),

const SizedBox(width: 8),

Row(
  mainAxisSize: MainAxisSize.min,
  children: [
                      // Add Items button
                      InkWell(
                        onTap: widget.onTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // View Items button
                      InkWell(
                        onTap: widget.onViewItems,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.visibility,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.table.status != TableStatus.empty) ...[
                      // 3. Total Items row
                      _buildInfoRow(
                        label: 'Total Items',
                        value: orderCount.toString(),
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 7. FOOTER: Total Amount + Status button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Total Amount
                  Text(
                    totalAmount.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),

                  // Status Update button
                  ElevatedButton(
                    onPressed: _handleStatusUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusButtonInfo['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                      shadowColor: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusButtonInfo['icon'] as IconData, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          statusButtonInfo['text'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: valueColor.withOpacity(0.3), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class HoverableCategoryCard extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const HoverableCategoryCard({
    required this.category,
    required this.onTap,
    super.key,
  });

  @override
  State<HoverableCategoryCard> createState() => _HoverableCategoryCardState();
}

class _HoverableCategoryCardState extends State<HoverableCategoryCard> {
  bool _isHovered = false;

  IconData getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'dinner':
        return Icons.dinner_dining;
      case 'fast food':
        return Icons.fastfood;
      case 'beverages':
        return Icons.local_drink;
      case 'desserts':
        return Icons.icecream;
      case 'snacks':
        return Icons.lunch_dining;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
            ],
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.category.imageUrl.isNotEmpty)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.category.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ShimmerEffect(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          getCategoryIcon(widget.category.name),
                          size: 30,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getCategoryIcon(widget.category.name),
                    size: 30,
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                widget.category.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerCategoryGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const ShimmerCategoryGrid({
    required this.crossAxisCount,
    required this.itemCount,
    super.key,
  });

@override
Widget build(BuildContext context) {
  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.75,
    ),
    itemCount: itemCount,
    itemBuilder: (context, index) {
      return ShimmerEffect(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(20),
      );
    },
  );
}
}
