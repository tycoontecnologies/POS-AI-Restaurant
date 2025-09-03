import 'package:flutter/material.dart';
import 'package:pos/models/sale_return.dart';
import 'package:pos/providers/sale_return_provider.dart';
import 'package:pos/screens/select_return_items_screen.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/sale.dart';
import '../providers/sale_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class SalesTableScreen extends StatefulWidget {
  const SalesTableScreen({super.key});

  @override
  State<SalesTableScreen> createState() => _SalesTableScreenState();
}

class _SalesTableScreenState extends State<SalesTableScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _error;

  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  final List<Sale> _allSales = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSales();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreSales();
    }
  }

  Future<void> _loadSales() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        await saleProvider.fetchSales(authProvider.currentUser!.id);
        setState(() {
          _allSales.clear();
          _allSales.addAll(saleProvider.sales);
          _hasMore = saleProvider.sales.length >= _itemsPerPage;
          _currentPage = 1;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load sales: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSales() async {
    if (_isLoadingMore || !_hasMore) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      setState(() => _isLoadingMore = true);

      try {
        // Simulate loading more data (you'll need to implement proper pagination in your API)
        await Future.delayed(const Duration(milliseconds: 500));

        // For now, we'll just use the existing data but simulate pagination
        // In a real app, you'd call something like saleProvider.fetchMoreSales()
        setState(() {
          _hasMore = false; // Set to false since we don't have real pagination
          _isLoadingMore = false;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _isLoadingMore = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load more sales: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  List<Sale> _filterSales(List<Sale> sales) {
    if (_searchQuery.isEmpty) return sales;

    final query = _searchQuery.toLowerCase();
    return sales.where((sale) {
      return sale.id.toLowerCase().contains(query) ||
          sale.items.any(
            (item) => item.productName.toLowerCase().contains(query),
          ) ||
          sale.total.toString().contains(query) ||
          _formatDate(sale.createdAt).contains(query);
    }).toList();
  }

  List<Sale> _getPaginatedSales(List<Sale> allSales) {
    final filteredSales = _filterSales(allSales);

    // For infinite scroll, we show all filtered results
    // If you want traditional pagination, uncomment below:
    /*
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return filteredSales.sublist(
      startIndex.clamp(0, filteredSales.length),
      endIndex.clamp(0, filteredSales.length),
    );
    */

    return filteredSales;
  }

  String _formatProductNames(List<SaleItem> items) {
    if (items.isEmpty) return 'No items';

    final productNames = items.map((item) => item.productName).toList();

    // Group by product name and show quantity if multiple
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      if (entry.value.length > 1) {
        return '${entry.key} (x${entry.value.length})';
      }
      return entry.key;
    }).toList();

    return result.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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
                Text('Sale ID: ${sale.id}'),
                Text('Date: ${_formatDate(sale.createdAt)}'),
                Text('Total: \$${sale.total.toStringAsFixed(2)}'),
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
                Expanded(
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
                            DataCell(
                              Text('\$${item.price.toStringAsFixed(2)}'),
                            ),
                            DataCell(Text('${item.quantity}')),
                            DataCell(
                              Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
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

  void _printReceipt(Sale sale) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printing receipt for sale ${sale.id}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _rowActions(Sale sale) {
    return // In the mobileItemBuilder section of sale_record.dart, update the actions row:
    Row(
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
          onPressed: () => _returnAllItems(sale),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.success.withOpacity(0.1),
            foregroundColor: AppColors.success,
          ),
        ),
        IconButton(
          tooltip: 'Select Items to Return',
          icon: const Icon(Icons.checklist, size: 16),
          onPressed: () => _returnSelectedItems(sale),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.warning.withOpacity(0.1),
            foregroundColor: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Future<void> _returnAllItems(Sale sale) async {
    final authProvider = context.read<AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();
    final reason = await _showReasonDialog();

    if (reason == null) return; // User cancelled

    try {
      // Create sale return items for all products
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

      // Calculate total refund
      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      // Create sale return
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
            content: Text(
              'Return processed successfully for \$${totalRefund.toStringAsFixed(2)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _returnSelectedItems(Sale sale) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectReturnItemsScreen(sale: sale),
      ),
    );

    if (result == null) return; // User cancelled

    final authProvider = context.read<AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();
    final List<String> selectedProductIds = result['selectedProductIds'];
    final String reason = result['reason'];

    try {
      // Create sale return items only for selected products
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

      // Calculate total refund
      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + item.refundAmount,
      );

      // Create sale return
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
            content: Text(
              'Return processed successfully for \$${totalRefund.toStringAsFixed(2)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _showReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Return'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for returning all items...',
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

  @override
  Widget build(BuildContext context) {
    final saleProvider = Provider.of<SaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final paginatedSales = _getPaginatedSales(_allSales);
    final filteredSales = _filterSales(_allSales);

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sales,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track your sales records',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search sales...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // Results count
          Text(
            '${filteredSales.length} sales found',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
          ),

          const SizedBox(height: AppSpacing.md),

          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: _buildContent(l10n, paginatedSales, filteredSales),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    List<Sale> paginatedSales,
    List<Sale> filteredSales,
  ) {
    if (_isLoading && _allSales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error: $_error'),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Retry',
              onPressed: _loadSales,
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isEmpty
                  ? 'No sales records found'
                  : 'No sales found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your sales will appear here',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            _scrollController.position.pixels ==
                _scrollController.position.maxScrollExtent) {
          _loadMoreSales();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            DataTableWidget(
              columns: [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Products')),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Actions')),
              ],
              rows: paginatedSales
                  .map(
                    (sale) => DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Tooltip(
                              message: sale.id,
                              child: Text(
                                sale.id,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Monospace'),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 300,
                            child: Tooltip(
                              message: _formatProductNames(sale.items),
                              child: Text(
                                _formatProductNames(sale.items),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '\$${sale.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        DataCell(Text(_formatDate(sale.createdAt))),
                        DataCell(_rowActions(sale)),
                      ],
                    ),
                  )
                  .toList(),
              mobileItemBuilder: (context, index) {
                final sale = paginatedSales[index];
                return CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sale #${sale.id.substring(0, 8)}...',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '\$${sale.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _formatProductNames(sale.items),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Date: ${_formatDate(sale.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_rowActions(sale)],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Loading more indicator
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),

            // No more items indicator
            if (!_hasMore && paginatedSales.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No more sales to load',
                  style: TextStyle(
                    color: AppColors.grey600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
