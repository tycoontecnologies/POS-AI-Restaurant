import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/custom_input.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/components/ui/table_order_dialog.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/category.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/statistics_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
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

    _categoryProvider = Provider.of<CategoryProvider>(context);
    _productProvider = Provider.of<ProductProvider>(context);
    _statisticsProvider = Provider.of<StatisticsProvider>(context);
    _tableProvider = Provider.of<TableProvider>(context);

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
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                          variant: isSelected
                              ? ButtonVariant.filled
                              : ButtonVariant.outlined,
                          color: isSelected
                              ? AppColors.successDark
                              : Colors.grey.shade700,
                          textColor: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
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
                                'Dine In',
                                Icons.table_chart,
                                Colors.teal,
                                _showTableOrderDialog,
                              ),
                              _buildQuickActionButton(
                                l10n.sales,
                                Icons.shopping_cart,
                                const Color(0xFF8B5CF6),
                                () => context.go(AppRouter.salesRecord),
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomButton(
                text: 'Add Table',
                onPressed: _showAddTableDialog,
                icon: Icons.add,
                variant: ButtonVariant.filled,
                color: AppColors.primary,
              ),
            ],
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

  void _showTableOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => TableOrderDialog(
        onTableSelected: (table) {
          setState(() {
            _selectedOrderType = 'Dine In';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Table ${table.tableNumber} selected'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
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

  const _TablesGrid({
    required this.tables,
    required this.onTableTap,
    required this.onEditTable,
    required this.onDeleteTable,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isDesktop ? 6 : (isTablet ? 4 : 3);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: .8,
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

  const HoverableTableCard({
    required this.table,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  @override
  State<HoverableTableCard> createState() => _HoverableTableCardState();
}

class _HoverableTableCardState extends State<HoverableTableCard> {
  bool _isHovered = false;

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.grey.shade400; // Silver for empty
      case TableStatus.occupied:
        return Colors.orange.shade400;
      case TableStatus.served:
        return Colors.green.shade500; // Green for served
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

  LinearGradient _getCardGradient(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TableStatus.occupied:
        return LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TableStatus.served:
        return LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.table.status);
    final statusLabel = _getStatusLabel(widget.table.status);
    final cardGradient = _getCardGradient(widget.table.status);
    final tableOrderProvider = Provider.of<TableOrderProvider>(context);
    final hasActiveOrder = tableOrderProvider.hasActiveOrder(widget.table.id);
    final orderCount = hasActiveOrder
        ? tableOrderProvider.getOrderForTable(widget.table.id).length
        : 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: cardGradient,
                border: Border.all(
                  color: _isHovered ? statusColor : Colors.grey.shade300,
                  width: _isHovered ? 3 : 2,
                ),
                boxShadow: [
                  if (_isHovered)
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                      offset: const Offset(0, 5),
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      // color: statusColor.withOpacity(0.2),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        // color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Table Number Circle
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white, // White circle background
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: statusColor,
                        width: _isHovered ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: _isHovered ? 12 : 6,
                          spreadRadius: _isHovered ? 2 : 1,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.table.tableNumber,
                        style: TextStyle(
                          fontSize: _isHovered ? 26 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          shadows: _isHovered
                              ? [
                                  Shadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Number of seats
                  Text(
                    '${widget.table.numberOfSeats} Seats',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Edit Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: _isHovered
                            ? Matrix4.translationValues(0, -2, 0)
                            : Matrix4.identity(),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onEdit,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade100,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.blue.shade600,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Delete Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: _isHovered
                            ? Matrix4.translationValues(0, -2, 0)
                            : Matrix4.identity(),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onDelete,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.shade100,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.delete,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Order Count Badge
            if (hasActiveOrder && orderCount > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$orderCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
        childAspectRatio: 1.5,
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
