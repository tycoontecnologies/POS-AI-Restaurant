// lib/screens/transaction_management_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/components/ui/status_badge.dart';
import 'package:pos/components/ui/search_bar_widget.dart';
import 'package:pos/components/ui/data_table_widget.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/utils/app_colors.dart';

// Models
import 'package:pos/models/purchase.dart';
import 'package:pos/models/purchase_return.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/sale_return.dart';

// Providers
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/supplier_provider.dart';
import 'package:pos/providers/purchase_provider.dart';
import 'package:pos/providers/purchase_return_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/sale_return_provider.dart';
import 'package:pos/providers/auth_provider.dart' as myAuth;

// Screens & Widgets
import 'package:pos/widget/purchase_form_dialogue.dart';
import 'package:pos/screens/select_purchase_return_items_screen.dart';
import 'package:pos/screens/select_return_items_screen.dart';

class OperationScreen extends StatefulWidget {
  const OperationScreen({super.key});

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Tab-specific controllers
  final Map<int, TextEditingController> _tabSearchControllers = {};
  final Map<int, ScrollController> _tabScrollControllers = {};

  // Sale screen specific filters
  DateTime? _singleDate;
  DateTimeRange? _dateRange;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _presetFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize controllers for each tab
    for (int i = 0; i < 4; i++) {
      _tabSearchControllers[i] = TextEditingController();
      _tabScrollControllers[i] = ScrollController();
    }

    _searchController.addListener(_applySearch);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    for (var controller in _tabSearchControllers.values) {
      controller.dispose();
    }
    for (var controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadInitialData() {
    final purchaseProvider = context.read<PurchaseProvider>();
    final supplierProvider = context.read<SupplierProvider>();
    final productProvider = context.read<ProductProvider>();
    final authProvider = context.read<myAuth.AuthProvider>();

    purchaseProvider.loadInitialPurchases();

    // Load suppliers
    supplierProvider.getSuppliersStream().listen((suppliers) {
      supplierProvider.setSuppliers(suppliers);
    });

    // Load products
    final vendorId =
        authProvider.currentUser?.id ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    productProvider.loadProducts(vendorId);

    // Load sale returns
    if (authProvider.currentUser != null) {
      final saleReturnProvider = context.read<SaleReturnProvider>();
      saleReturnProvider.fetchSaleReturns(authProvider.currentUser!.id);

      final purchaseReturnProvider = context.read<PurchaseReturnProvider>();
      purchaseReturnProvider.fetchPurchaseReturns(authProvider.currentUser!.id);

      final saleProvider = context.read<SaleProvider>();
      saleProvider.fetchSales(authProvider.currentUser!.id);
    }
  }

  void _applySearch() {
    final searchText = _searchController.text;
    for (var controller in _tabSearchControllers.values) {
      controller.text = searchText;
    }

    // Apply search based on current tab
    switch (_tabController.index) {
      case 0: // Purchases
        context.read<PurchaseProvider>().searchPurchases(searchText);
        break;
      case 2: // Sales
        setState(() {}); // Sales search is handled by local filtering
        break;
      case 1: // Purchase Returns
      case 3: // Sale Returns
        setState(() {}); // These are handled by local filtering
        break;
    }
  }

  String _getCurrentVendorId() {
    final authProvider = context.read<myAuth.AuthProvider>();
    return authProvider.currentUser?.id ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
  }

  // ========== COMMON METHODS ==========

  Widget _buildShimmerTable({int columns = 6}) {
    return DataTableWidget(
      columns: List.generate(
        columns,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            columns,
            (index) => DataCell(
              index == columns - 1
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShimmerEffect(
                          width: 36,
                          height: 36,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        ShimmerEffect(
                          width: 36,
                          height: 36,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ],
                    )
                  : ShimmerEffect(width: 80, height: 20),
            ),
          ),
        ),
      ),
      mobileItemBuilder: (context, index) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: ShimmerEffect(width: 120, height: 20)),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 150, height: 16),
              SizedBox(height: AppSpacing.xs),
              ShimmerEffect(width: 200, height: 16),
              SizedBox(height: AppSpacing.xs),
              ShimmerEffect(width: 80, height: 16),
              SizedBox(height: AppSpacing.xs),
              ShimmerEffect(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text('Error: $error'),
          const SizedBox(height: AppSpacing.md),
          CustomButton(
            text: 'Retry',
            onPressed: onRetry,
            variant: ButtonVariant.filled,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(
    String message, {
    bool showCreateButton = false,
    VoidCallback? onCreate,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 64, color: Colors.grey),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          if (showCreateButton && onCreate != null) ...[
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Create First Transaction',
              onPressed: onCreate,
              variant: ButtonVariant.filled,
            ),
          ],
        ],
      ),
    );
  }

  // ========== PURCHASE TAB ==========

  Widget _buildPurchaseTab() {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final purchases = purchaseProvider.purchases;
    final searchText = _tabSearchControllers[0]?.text ?? '';

    if (purchaseProvider.isLoading && purchases.isEmpty) {
      return _buildShimmerTable(columns: 6);
    }

    if (purchaseProvider.error != null) {
      return _buildErrorWidget(
        purchaseProvider.error!,
        () => purchaseProvider.loadInitialPurchases(),
      );
    }

    if (purchases.isEmpty) {
      return _buildEmptyWidget(
        searchText.isEmpty
            ? 'No purchases found'
            : 'No purchases found for "$searchText"',
        showCreateButton: searchText.isEmpty,
        onCreate: () {
          showPurchaseDialog(
            context,
            onSave: (newPurchase) async {
              await purchaseProvider.addPurchase(newPurchase);
            },
          );
        },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            _tabScrollControllers[0]!.position.pixels ==
                _tabScrollControllers[0]!.position.maxScrollExtent) {
          _loadMorePurchases();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _tabScrollControllers[0],
        child: DataTableWidget(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: purchases.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final purchase = entry.value;

            return DataRow(
              cells: [
                DataCell(Text('$index')),
                DataCell(Text(purchase.supplierName)),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Tooltip(
                      message: purchase.items
                          .map((item) => item.productName)
                          .join(', '),
                      child: Text(
                        purchase.items
                            .map((item) => item.productName)
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(purchase.total.toStringAsFixed(0))),
                DataCell(
                  Text(
                    DateFormat('d MMM yyyy').format(purchase.date.toLocal()),
                  ),
                ),
                DataCell(_buildPurchaseActions(purchase)),
              ],
            );
          }).toList(),
          mobileItemBuilder: (context, index) {
            final purchase = purchases[index];
            return CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Purchase #${purchase.id.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      StatusBadge(text: purchase.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Supplier: ${purchase.supplierName}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Items: ${purchase.items.map((item) => item.productName).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Total: ${purchase.total.toStringAsFixed(0)}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Date: ${'${purchase.date.toLocal()}'.split(' ').first}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_buildPurchaseActions(purchase)],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPurchaseActions(Purchase purchase) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.visibility, size: 16),
          onPressed: () => _showPurchaseDetails(purchase),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Return All Items',
          icon: const Icon(Icons.all_inbox, size: 16),
          onPressed: () => _returnAllPurchaseItems(purchase),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.success.withOpacity(0.1),
            foregroundColor: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Select Items to Return',
          icon: const Icon(Icons.checklist, size: 16),
          onPressed: () => _returnSelectedPurchaseItems(purchase),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.warning.withOpacity(0.1),
            foregroundColor: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          icon: const Icon(Icons.delete, size: 16),
          onPressed: () => _deletePurchase(purchase.id),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }

  void _loadMorePurchases() async {
    final purchaseProvider = context.read<PurchaseProvider>();
    if (!purchaseProvider.isLoading && purchaseProvider.hasMore) {
      await purchaseProvider.loadMorePurchases();
    }
  }

  Future<void> _deletePurchase(String purchaseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: const Text('Are you sure you want to delete this purchase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<PurchaseProvider>();
      await provider.deletePurchase(purchaseId);
    }
  }

  // ========== SALE TAB ==========

  Widget _buildSaleTab() {
    final saleProvider = context.watch<SaleProvider>();
    final sales = saleProvider.sales;
    final searchText = _tabSearchControllers[2]?.text ?? '';

    // Apply filters
    final filteredSales = _applySaleFilters(sales);

    if (saleProvider.isLoading && sales.isEmpty) {
      return _buildShimmerTable(columns: 5);
    }

    if (saleProvider.error != null) {
      return _buildErrorWidget(
        saleProvider.error!,
        () => saleProvider.fetchSales(_getCurrentVendorId()),
      );
    }

    if (filteredSales.isEmpty) {
      return _buildEmptyWidget(
        searchText.isEmpty
            ? 'No sales records found'
            : 'No sales found for "$searchText"',
        showCreateButton: false,
      );
    }

    // Calculate totals
    final todayTotal = _calculateTodaySales(sales);
    final filteredTotal = _calculateFilteredSalesTotal(filteredSales);

    return Column(
      children: [
        // Stats Cards
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.grey300.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Sales',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.grey700,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        NumberFormat('#,###').format(todayTotal),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 20,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.grey300.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredSales.length} records',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          symbol: '',
                          decimalDigits: 0,
                        ).format(filteredTotal),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                              fontSize: 20,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter Chips
        if (_hasActiveSaleFilters())
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_presetFilter != 'All')
                        Chip(label: Text('Preset: $_presetFilter')),
                      if (_singleDate != null)
                        Chip(
                          label: Text(
                            'Date: ${DateFormat('d MMM yyyy').format(_singleDate!)}',
                          ),
                        ),
                      if (_dateRange != null)
                        Chip(
                          label: Text(
                            'Range: ${DateFormat('d MMM yyyy').format(_dateRange!.start)} - ${DateFormat('d MMM yyyy').format(_dateRange!.end)}',
                          ),
                        ),
                      if (_startTime != null)
                        Chip(
                          label: Text('From: ${_startTime!.format(context)}'),
                        ),
                      if (_endTime != null)
                        Chip(label: Text('To: ${_endTime!.format(context)}')),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear filters',
                  onPressed: _resetSaleFilters,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),

        // Sales Table
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              controller: _tabScrollControllers[2],
              child: DataTableWidget(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Products')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Date')),
                  DataColumn(
                    label: Text('Actions'),
                    headingRowAlignment: MainAxisAlignment.center,
                  ),
                ],
                rows: filteredSales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sale = entry.value;

                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Tooltip(
                            message: _formatSaleProductNames(sale.items),
                            child: Text(
                              _formatSaleProductNames(sale.items),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          sale.total.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          DateFormat(
                            'd MMM yyyy – hh:mm a',
                          ).format(sale.createdAt.toLocal()),
                        ),
                      ),
                      DataCell(_buildSaleActions(sale)),
                    ],
                  );
                }).toList(),
                mobileItemBuilder: (context, index) {
                  final sale = filteredSales[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sale #${sale.id.substring(0, sale.id.length > 8 ? 8 : sale.id.length)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              sale.total.toStringAsFixed(0),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _formatSaleProductNames(sale.items),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Date: ${DateFormat('d MMM yyyy – hh:mm a').format(sale.createdAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey600),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [_buildSaleActions(sale)],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleActions(Sale sale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.visibility, size: 16),
          onPressed: () => _showSaleDetails(sale),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        IconButton(
          tooltip: 'Return All Items',
          icon: const Icon(Icons.all_inbox, size: 16),
          onPressed: () => _returnAllSaleItems(sale),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.success.withOpacity(0.1),
            foregroundColor: AppColors.success,
          ),
        ),
        IconButton(
          tooltip: 'Select Items to Return',
          icon: const Icon(Icons.checklist, size: 16),
          onPressed: () => _returnSelectedSaleItems(sale),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.warning.withOpacity(0.1),
            foregroundColor: AppColors.warning,
          ),
        ),
      ],
    );
  }

  // ========== RETURN TABS (PURCHASE & SALE) ==========

  Widget _buildPurchaseReturnTab() {
    final purchaseReturnProvider = context.watch<PurchaseReturnProvider>();
    final purchaseReturns = purchaseReturnProvider.purchaseReturns;
    final searchText = _tabSearchControllers[1]?.text ?? '';

    final filteredReturns = _filterPurchaseReturns(purchaseReturns, searchText);

    if (purchaseReturnProvider.isLoading && purchaseReturns.isEmpty) {
      return _buildShimmerTable(columns: 8);
    }

    if (purchaseReturnProvider.error != null) {
      return _buildErrorWidget(
        purchaseReturnProvider.error!,
        () =>
            purchaseReturnProvider.fetchPurchaseReturns(_getCurrentVendorId()),
      );
    }

    if (filteredReturns.isEmpty) {
      return _buildEmptyWidget(
        searchText.isEmpty
            ? 'No purchase return records found'
            : 'No purchase returns found for "$searchText"',
        showCreateButton: false,
      );
    }

    return SingleChildScrollView(
      controller: _tabScrollControllers[1],
      child: DataTableWidget(
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Purchase ID')),
          DataColumn(label: Text('Supplier')),
          DataColumn(label: Text('Products')),
          DataColumn(label: Text('Refund Amount')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filteredReturns.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final purchaseReturn = entry.value;

          return DataRow(
            cells: [
              DataCell(Text('$index')),
              DataCell(
                SizedBox(
                  width: 120,
                  child: Tooltip(
                    message: purchaseReturn.originalPurchaseId,
                    child: Text(
                      purchaseReturn.originalPurchaseId.substring(0, 8),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Monospace'),
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Tooltip(
                    message: purchaseReturn.supplierName,
                    child: Text(
                      purchaseReturn.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Tooltip(
                    message: _formatPurchaseReturnProductNames(
                      purchaseReturn.items,
                    ),
                    child: Text(
                      _formatPurchaseReturnProductNames(purchaseReturn.items),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  purchaseReturn.totalRefund.toStringAsFixed(0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Tooltip(
                    message: purchaseReturn.reason,
                    child: Text(
                      purchaseReturn.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  DateFormat(
                    'd MMM yyyy',
                  ).format(purchaseReturn.createdAt.toLocal()),
                ),
              ),
              DataCell(_buildPurchaseReturnActions(purchaseReturn)),
            ],
          );
        }).toList(),
        mobileItemBuilder: (context, index) {
          final purchaseReturn = filteredReturns[index];
          return CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Return #${purchaseReturn.id.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      purchaseReturn.totalRefund.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Purchase ID: ${purchaseReturn.originalPurchaseId.substring(0, 8)}...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Supplier: ${purchaseReturn.supplierName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formatPurchaseReturnProductNames(purchaseReturn.items),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reason: ${purchaseReturn.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Date: ${_formatDateTime(purchaseReturn.createdAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildPurchaseReturnActions(purchaseReturn)],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaleReturnTab() {
    final saleReturnProvider = context.watch<SaleReturnProvider>();
    final saleReturns = saleReturnProvider.saleReturns;
    final searchText = _tabSearchControllers[3]?.text ?? '';

    final filteredReturns = _filterSaleReturns(saleReturns, searchText);

    if (saleReturnProvider.isLoading && saleReturns.isEmpty) {
      return _buildShimmerTable(columns: 7);
    }

    if (saleReturnProvider.error != null) {
      return _buildErrorWidget(
        saleReturnProvider.error!,
        () => saleReturnProvider.fetchSaleReturns(_getCurrentVendorId()),
      );
    }

    if (filteredReturns.isEmpty) {
      return _buildEmptyWidget(
        searchText.isEmpty
            ? 'No sale return records found'
            : 'No sale returns found for "$searchText"',
        showCreateButton: false,
      );
    }

    return SingleChildScrollView(
      controller: _tabScrollControllers[3],
      child: DataTableWidget(
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Receipt ID')),
          DataColumn(label: Text('Products')),
          DataColumn(label: Text('Refund Amount')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filteredReturns.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final saleReturn = entry.value;

          return DataRow(
            cells: [
              DataCell(Text('$index')),
              DataCell(
                SizedBox(
                  width: 120,
                  child: Tooltip(
                    message: saleReturn.originalSaleId,
                    child: Text(
                      saleReturn.originalSaleId.substring(0, 8),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Monospace'),
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Tooltip(
                    message: _formatSaleReturnProductNames(saleReturn.items),
                    child: Text(
                      _formatSaleReturnProductNames(saleReturn.items),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  saleReturn.totalRefund.toStringAsFixed(0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Tooltip(
                    message: saleReturn.reason,
                    child: Text(
                      saleReturn.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  DateFormat(
                    'd MMM yyyy',
                  ).format(saleReturn.createdAt.toLocal()),
                ),
              ),
              DataCell(_buildSaleReturnActions(saleReturn)),
            ],
          );
        }).toList(),
        mobileItemBuilder: (context, index) {
          final saleReturn = filteredReturns[index];
          return CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Return #${saleReturn.id.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      saleReturn.totalRefund.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Receipt ID: ${saleReturn.originalSaleId.substring(0, 8)}...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formatSaleReturnProductNames(saleReturn.items),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reason: ${saleReturn.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Date: ${_formatDateTime(saleReturn.createdAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildSaleReturnActions(saleReturn)],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPurchaseReturnActions(PurchaseReturn purchaseReturn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.visibility, size: 18),
          onPressed: () => _showPurchaseReturnDetails(purchaseReturn),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleReturnActions(SaleReturn saleReturn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.visibility, size: 18),
          onPressed: () => _showSaleReturnDetails(saleReturn),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ========== HELPER METHODS ==========

  String _formatSaleProductNames(List<SaleItem> items) {
    if (items.isEmpty) return 'No items';
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final qty = entry.value.fold<int>(0, (p, e) => p + e.quantity);
      return qty > 1 ? '${entry.key} (x$qty)' : entry.key;
    }).toList();
    return result.join(', ');
  }

  String _formatPurchaseReturnProductNames(List<PurchaseReturnItem> items) {
    if (items.isEmpty) return 'No items';
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final totalQuantity = entry.value.fold<int>(
        0,
        (a, b) => a + b.returnedQuantity,
      );
      return '${entry.key} (x$totalQuantity)';
    }).toList();
    return result.join(', ');
  }

  String _formatSaleReturnProductNames(List<SaleReturnItem> items) {
    if (items.isEmpty) return 'No items';
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final totalQuantity = entry.value.fold<int>(
        0,
        (a, b) => a + b.returnedQuantity,
      );
      return '${entry.key} (x$totalQuantity)';
    }).toList();
    return result.join(', ');
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<PurchaseReturn> _filterPurchaseReturns(
    List<PurchaseReturn> purchaseReturns,
    String query,
  ) {
    if (query.isEmpty) return purchaseReturns;
    final searchQuery = query.toLowerCase();
    return purchaseReturns.where((purchaseReturn) {
      return purchaseReturn.id.toLowerCase().contains(searchQuery) ||
          purchaseReturn.originalPurchaseId.toLowerCase().contains(
            searchQuery,
          ) ||
          purchaseReturn.supplierName.toLowerCase().contains(searchQuery) ||
          purchaseReturn.items.any(
            (item) => item.productName.toLowerCase().contains(searchQuery),
          ) ||
          purchaseReturn.totalRefund.toString().contains(searchQuery) ||
          purchaseReturn.reason.toLowerCase().contains(searchQuery) ||
          _formatDateTime(purchaseReturn.createdAt).contains(searchQuery);
    }).toList();
  }

  List<SaleReturn> _filterSaleReturns(
    List<SaleReturn> saleReturns,
    String query,
  ) {
    if (query.isEmpty) return saleReturns;
    final searchQuery = query.toLowerCase();
    return saleReturns.where((saleReturn) {
      return saleReturn.id.toLowerCase().contains(searchQuery) ||
          saleReturn.originalSaleId.toLowerCase().contains(searchQuery) ||
          saleReturn.items.any(
            (item) => item.productName.toLowerCase().contains(searchQuery),
          ) ||
          saleReturn.totalRefund.toString().contains(searchQuery) ||
          saleReturn.reason.toLowerCase().contains(searchQuery) ||
          _formatDateTime(saleReturn.createdAt).contains(searchQuery);
    }).toList();
  }

  List<Sale> _applySaleFilters(List<Sale> sales) {
    List<Sale> filtered = sales;
    final now = DateTime.now();
    final searchText = _tabSearchControllers[2]?.text ?? '';

    // Preset filters
    if (_presetFilter == 'Today') {
      final start = DateTime(now.year, now.month, now.day);
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      filtered = filtered
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(start) &&
                s.createdAt.toLocal().isBefore(end),
          )
          .toList();
    } else if (_presetFilter == 'This Week') {
      final weekday = now.weekday;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: weekday - 1));
      final end = start
          .add(const Duration(days: 7))
          .subtract(const Duration(milliseconds: 1));
      filtered = filtered
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(start) &&
                s.createdAt.toLocal().isBefore(end),
          )
          .toList();
    } else if (_presetFilter == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));
      filtered = filtered
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(start) &&
                s.createdAt.toLocal().isBefore(end),
          )
          .toList();
    }

    // Date filters
    if (_singleDate != null) {
      final start = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      filtered = filtered
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(start) &&
                s.createdAt.toLocal().isBefore(end),
          )
          .toList();
    }

    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
      ).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      filtered = filtered
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(start) &&
                s.createdAt.toLocal().isBefore(end),
          )
          .toList();
    }

    // Time filters
    if (_startTime != null || _endTime != null) {
      filtered = filtered.where((s) {
        final local = s.createdAt.toLocal();
        final startTimeOfSale = DateTime(
          local.year,
          local.month,
          local.day,
          _startTime?.hour ?? 0,
          _startTime?.minute ?? 0,
        );
        final endTimeOfSale = DateTime(
          local.year,
          local.month,
          local.day,
          _endTime?.hour ?? 23,
          _endTime?.minute ?? 59,
        );
        return local.isAfter(startTimeOfSale) && local.isBefore(endTimeOfSale);
      }).toList();
    }

    // Search filter
    if (searchText.isNotEmpty) {
      final query = searchText.toLowerCase();
      filtered = filtered.where((sale) {
        return sale.id.toLowerCase().contains(query) ||
            sale.items.any(
              (item) => item.productName.toLowerCase().contains(query),
            ) ||
            sale.total.toString().contains(query) ||
            DateFormat(
              'd MMM yyyy',
            ).format(sale.createdAt.toLocal()).toLowerCase().contains(query);
      }).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  double _calculateTodaySales(List<Sale> sales) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return sales
        .where(
          (s) =>
              s.createdAt.toLocal().isAfter(start) &&
              s.createdAt.toLocal().isBefore(end),
        )
        .fold(0.0, (sum, sale) => sum + sale.total);
  }

  double _calculateFilteredSalesTotal(List<Sale> filteredSales) {
    return filteredSales.fold(0.0, (sum, sale) => sum + sale.total);
  }

  bool _hasActiveSaleFilters() {
    return _presetFilter != 'All' ||
        _singleDate != null ||
        _dateRange != null ||
        _startTime != null ||
        _endTime != null;
  }

  void _resetSaleFilters() {
    setState(() {
      _presetFilter = 'All';
      _singleDate = null;
      _dateRange = null;
      _startTime = null;
      _endTime = null;
    });
  }

  // ========== ACTION METHODS (from original screens) ==========

  // Purchase actions
  void _showPurchaseDetails(Purchase purchase) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Purchase Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Purchase ID: ${purchase.id.substring(0, 6)}'),
                Text('Supplier: ${purchase.supplierName}'),
                Text(
                  'Date: ${purchase.date.toLocal().toString().split(' ').first}',
                ),
                Text('Total: ${purchase.total.toStringAsFixed(0)}'),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Subtotal'), numeric: true),
                      ],
                      rows: purchase.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(Text(item.unitPrice.toStringAsFixed(0))),
                            DataCell(Text('${item.quantity}')),
                            DataCell(Text(item.total.toStringAsFixed(0))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: 'Close',
                    variant: ButtonVariant.text,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _returnAllPurchaseItems(Purchase purchase) async {
    final authProvider = context.read<myAuth.AuthProvider>();
    final purchaseReturnProvider = context.read<PurchaseReturnProvider>();
    final reason = await _showReasonDialog('purchase');

    if (reason == null) return;

    try {
      final returnItems = purchase.items
          .map(
            (item) => PurchaseReturnItem(
              productId: item.productId,
              productName: item.productName,
              originalPrice: item.unitPrice,
              returnedQuantity: item.quantity,
              refundAmount: item.total,
            ),
          )
          .toList();

      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      final purchaseReturn = PurchaseReturn(
        id: '',
        vendorId: authProvider.currentUser!.id,
        originalPurchaseId: purchase.id,
        supplierId: purchase.supplierId,
        supplierName: purchase.supplierName,
        items: returnItems,
        totalRefund: totalRefund,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await purchaseReturnProvider.createPurchaseReturn(
        authProvider.currentUser!.id,
        purchaseReturn,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
              'Return processed successfully for ${totalRefund.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _returnSelectedPurchaseItems(Purchase purchase) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectPurchaseReturnItemsScreen(purchase: purchase),
      ),
    );

    if (result == null) return;

    final authProvider = context.read<myAuth.AuthProvider>();
    final purchaseReturnProvider = context.read<PurchaseReturnProvider>();
    final List<String> selectedProductIds = result['selectedProductIds'];
    final String reason = result['reason'];

    try {
      final returnItems = purchase.items
          .where((item) => selectedProductIds.contains(item.productId))
          .map(
            (item) => PurchaseReturnItem(
              productId: item.productId,
              productName: item.productName,
              originalPrice: item.unitPrice,
              returnedQuantity: item.quantity,
              refundAmount: item.total,
            ),
          )
          .toList();

      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      final purchaseReturn = PurchaseReturn(
        id: '',
        vendorId: authProvider.currentUser!.id,
        originalPurchaseId: purchase.id,
        supplierId: purchase.supplierId,
        supplierName: purchase.supplierName,
        items: returnItems,
        totalRefund: totalRefund,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await purchaseReturnProvider.createPurchaseReturn(
        authProvider.currentUser!.id,
        purchaseReturn,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
              'Return processed successfully for ${totalRefund.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Sale actions
  void _showSaleDetails(Sale sale) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sale Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Receipt ID: ${sale.id}'),
                Text('Date: ${_formatDateTime(sale.createdAt)}'),
                Text('Total: ${sale.total.toStringAsFixed(0)}'),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Subtotal'), numeric: true),
                      ],
                      rows: sale.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(Text(item.price.toStringAsFixed(0))),
                            DataCell(Text('${item.quantity}')),
                            DataCell(
                              Text(
                                (item.price * item.quantity).toStringAsFixed(0),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: 'Close',
                    variant: ButtonVariant.text,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _returnAllSaleItems(Sale sale) async {
    final authProvider = context.read<myAuth.AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();
    final reason = await _showReasonDialog('sale');

    if (reason == null) return;

    try {
      final returnItems = sale.items
          .map(
            (item) => SaleReturnItem(
              productId: item.productId,
              productName: item.productName,
              originalPrice: item.price,
              returnedQuantity: item.quantity,
              refundAmount: item.price * item.quantity,
            ),
          )
          .toList();

      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      final saleReturn = SaleReturn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vendorId: authProvider.currentUser!.id,
        originalSaleId: sale.id,
        items: returnItems,
        totalRefund: totalRefund,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await saleReturnProvider.createSaleReturn(
        authProvider.currentUser!.id,
        saleReturn,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
              'Return processed successfully for ${totalRefund.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _returnSelectedSaleItems(Sale sale) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectReturnItemsScreen(sale: sale),
      ),
    );

    if (result == null) return;

    final authProvider = context.read<myAuth.AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();
    final List<String> selectedProductIds = result['selectedProductIds'];
    final String reason = result['reason'];

    try {
      final returnItems = sale.items
          .where((item) => selectedProductIds.contains(item.productId))
          .map(
            (item) => SaleReturnItem(
              productId: item.productId,
              productName: item.productName,
              originalPrice: item.price,
              returnedQuantity: item.quantity,
              refundAmount: item.price * item.quantity,
            ),
          )
          .toList();

      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      final saleReturn = SaleReturn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vendorId: authProvider.currentUser!.id,
        originalSaleId: sale.id,
        items: returnItems,
        totalRefund: totalRefund,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await saleReturnProvider.createSaleReturn(
        authProvider.currentUser!.id,
        saleReturn,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
              'Return processed successfully for ${totalRefund.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Return details
  void _showPurchaseReturnDetails(PurchaseReturn purchaseReturn) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Purchase Return Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Return ID: ${purchaseReturn.id}'),
                Text(
                  'Original Purchase ID: ${purchaseReturn.originalPurchaseId}',
                ),
                Text('Supplier: ${purchaseReturn.supplierName}'),
                Text('Date: ${_formatDateTime(purchaseReturn.createdAt)}'),
                Text(
                  'Total Refund: ${purchaseReturn.totalRefund.toStringAsFixed(0)}',
                ),
                Text('Reason: ${purchaseReturn.reason}'),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Returned Products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(
                          label: Text('Original Price'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Qty Returned'), numeric: true),
                        DataColumn(label: Text('Refund Amount'), numeric: true),
                      ],
                      rows: purchaseReturn.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(
                              Text(item.originalPrice.toStringAsFixed(0)),
                            ),
                            DataCell(Text('${item.returnedQuantity}')),
                            DataCell(
                              Text(item.refundAmount.toStringAsFixed(0)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: 'Close',
                    variant: ButtonVariant.text,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSaleReturnDetails(SaleReturn saleReturn) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sale Return Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Return ID: ${saleReturn.id}'),
                Text('Receipt ID: ${saleReturn.originalSaleId}'),
                Text('Date: ${_formatDateTime(saleReturn.createdAt)}'),
                Text(
                  'Total Refund: ${saleReturn.totalRefund.toStringAsFixed(0)}',
                ),
                Text('Reason: ${saleReturn.reason}'),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Returned Products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(
                          label: Text('Original Price'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Qty Returned'), numeric: true),
                        DataColumn(label: Text('Refund Amount'), numeric: true),
                      ],
                      rows: saleReturn.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(
                              Text(item.originalPrice.toStringAsFixed(0)),
                            ),
                            DataCell(Text('${item.returnedQuantity}')),
                            DataCell(
                              Text(item.refundAmount.toStringAsFixed(0)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: 'Close',
                    variant: ButtonVariant.text,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showReasonDialog(String type) async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reason for ${type == 'purchase' ? 'Purchase' : 'Sale'} Return',
        ),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for returning items...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context, reasonController.text);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Sale filter methods
  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _singleDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _singleDate = picked;
        _dateRange = null;
        _presetFilter = 'All';
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange:
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _singleDate = null;
        _presetFilter = 'All';
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 0, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: AppColors.secondaryDark,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Purchases'),
            Tab(text: 'Purchase Returns'),
            Tab(text: 'Sales'),
            Tab(text: 'Sale Returns'),
          ],
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Global Search
            Row(
              children: [
                Expanded(
                  child: SearchBarWidget(
                    controller: _searchController,
                    hint: 'Search across all transactions...',
                    onChanged: (_) => _applySearch(),
                    onClear: () {
                      _searchController.clear();
                      _applySearch();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Add Purchase Button (only for purchase tab)
                if (_tabController.index == 0)
                  CustomButton(
                    text: 'New Purchase',
                    icon: Icons.add_shopping_cart,
                    onPressed: () {
                      showPurchaseDialog(
                        context,
                        onSave: (newPurchase) async {
                          final provider = context.read<PurchaseProvider>();
                          await provider.addPurchase(newPurchase);
                        },
                      );
                    },
                  ),
                // Sale Filters (only for sale tab)
                if (_tabController.index == 2) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _presetFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                            value: 'Today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: 'This Week',
                            child: Text('This Week'),
                          ),
                          DropdownMenuItem(
                            value: 'This Month',
                            child: Text('This Month'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _presetFilter = v;
                            if (v != 'All') {
                              _singleDate = null;
                              _dateRange = null;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pick single date',
                    onPressed: _pickSingleDate,
                    icon: const Icon(Icons.calendar_today),
                  ),
                  IconButton(
                    tooltip: 'Pick date range',
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                  ),
                  IconButton(
                    tooltip: 'Pick start time',
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.access_time),
                  ),
                  IconButton(
                    tooltip: 'Pick end time',
                    onPressed: _pickEndTime,
                    icon: const Icon(Icons.access_time_filled),
                  ),
                  CustomButton(
                    text: 'Reset',
                    variant: ButtonVariant.outlined,
                    onPressed: _resetSaleFilters,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPurchaseTab(),
                  _buildPurchaseReturnTab(),
                  _buildSaleTab(),
                  _buildSaleReturnTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add to your l10n file (app_localizations.dart):
// String get transactions => 'Transactions';
