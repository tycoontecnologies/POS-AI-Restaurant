import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _error;

  // Pagination variables
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  final List<Order> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Delay the loading to avoid build phase conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
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
      _loadMoreOrders();
    }
  }

  Future<void> _loadOrders() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        await orderProvider.fetchOrders(authProvider.currentUser!.id);
        setState(() {
          _allOrders.clear();
          _allOrders.addAll(orderProvider.orders);
          _hasMore = orderProvider.orders.length >= _itemsPerPage;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text('Failed to load orders: $e'),
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

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      setState(() => _isLoadingMore = true);

      try {
        // Load more orders from provider
        await orderProvider.fetchOrders(authProvider.currentUser!.id);
        setState(() {
          _allOrders.clear();
          _allOrders.addAll(orderProvider.orders);
          _hasMore = orderProvider.orders.length >= _itemsPerPage;
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
              duration: const Duration(seconds: 1),
              content: Text('Failed to load more orders: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  List<Order> _filterOrders(List<Order> orders) {
    if (_searchQuery.isEmpty) return orders;

    final query = _searchQuery.toLowerCase();
    return orders.where((order) {
      return order.id.toLowerCase().contains(query) ||
          order.items.any(
            (item) => item.productName.toLowerCase().contains(query),
          ) ||
          order.totalAmount.toString().contains(query) ||
          order.status.toLowerCase().contains(query) ||
          _formatDate(order.createdAt).contains(query);
    }).toList();
  }

  List<Order> _getPaginatedOrders(List<Order> allOrders) {
    final filteredOrders = _filterOrders(allOrders);
    // For now, return all filtered orders since we're not implementing actual pagination
    return filteredOrders;
  }

  String _formatProductNames(List<OrderItem> items) {
    if (items.isEmpty) return 'No items';

    // Group by product name and show quantity if multiple
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final totalQuantity = entry.value.fold(
        0,
        (sum, item) => sum + item.quantity,
      );
      if (totalQuantity > 1) {
        return '${entry.key} (x$totalQuantity)';
      }
      return entry.key;
    }).toList();

    return result.join(', ');
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMM yyyy h:mm a').format(date.toLocal());
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'confirmed':
        return AppColors.warning;
      case 'completed':
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.grey600;
    }
  }

  void _showOrderDetails(Order order) {
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
                  'Order Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Order ID: ${order.id}'),
                Text('Date: ${_formatDate(order.createdAt)}'),
                Text(
                  'Status: ${order.status}',
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('Payment Method: ${order.paymentMethod}'),
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
                        DataColumn(label: Text('Variant')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Subtotal'), numeric: true),
                      ],
                      rows: order.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(
                              Text(item.selectedVariantName ?? 'Standard'),
                            ),
                            DataCell(Text(item.price.toStringAsFixed(0))),
                            DataCell(Text('${item.quantity}')),
                            DataCell(Text(item.totalPrice.toStringAsFixed(0))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtotal: ${order.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Delivery Fee: ${order.deliveryFee.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      'Total: ${order.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
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

  Widget _rowActions(Order order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 6,
      children: [
        IconButton(
          tooltip: 'View Details',
          icon: const Icon(Icons.visibility, size: 16),
          onPressed: () => _showOrderDetails(order),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        if (order.status.toLowerCase() != 'completed' &&
            order.status.toLowerCase() != 'delivered')
          IconButton(
            tooltip: 'Mark as Completed',
            icon: const Icon(Icons.check_circle, size: 16),
            onPressed: () => _updateOrderStatus(order, 'completed'),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.success.withOpacity(0.1),
              foregroundColor: AppColors.success,
            ),
          ),
        IconButton(
          tooltip: 'Delete Order',
          icon: const Icon(Icons.delete, size: 16),
          onPressed: () => _deleteOrder(order),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }

  Future<void> _updateOrderStatus(Order order, String newStatus) async {
    final authProvider = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();

    try {
      final updatedOrder = order.copyWith(
        status: newStatus,
        deliveredAt: newStatus == 'completed'
            ? DateTime.now()
            : order.deliveredAt,
      );

      await orderProvider.updateOrder(
        authProvider.currentUser!.id,
        updatedOrder,
      );

      // 🔥 UPDATE LOCAL LIST IMMEDIATELY
      final index = _allOrders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        setState(() {
          _allOrders[index] = updatedOrder;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Order status updated to $newStatus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to update order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();

    try {
      await orderProvider.deleteOrder(authProvider.currentUser!.id, order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: const Text('Order deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Failed to delete order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final paginatedOrders = _getPaginatedOrders(_allOrders);
    final filteredOrders = _filterOrders(_allOrders);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      'Orders',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track and manage your orders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              if (orderProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search orders...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(child: _buildContent(l10n, paginatedOrders, filteredOrders)),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    List<Order> paginatedOrders,
    List<Order> filteredOrders,
  ) {
    if (_isLoading && _allOrders.isEmpty) {
      return _buildShimmerTable();
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
              onPressed: _loadOrders,
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isEmpty
                  ? 'No orders found'
                  : 'No orders found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your orders will appear here',
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
          _loadMoreOrders();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Products')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Payment')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: paginatedOrders.asMap().entries.map((entry) {
            final index = entry.key;
            final order = entry.value;
            final serialNumber = index + 1;

            return DataRow(
              cells: [
                DataCell(Text('$serialNumber')),
                DataCell(
                  SizedBox(
                    width: 250,
                    child: Tooltip(
                      message: _formatProductNames(order.items),
                      child: Text(
                        _formatProductNames(order.items),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    order.totalAmount.toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(order.paymentMethod)),
                DataCell(
                  Text(
                    DateFormat('d MMM yyyy').format(order.createdAt.toLocal()),
                  ),
                ),
                DataCell(_rowActions(order)),
              ],
            );
          }).toList(),

          mobileItemBuilder: (context, index) {
            final order = paginatedOrders[index];
            return CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${order.id.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        order.totalAmount.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _formatProductNames(order.items),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(order.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_rowActions(order)],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        7,
        (index) =>
            const DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            7,
            (index) => DataCell(
              index == 6
                  ? const ShimmerEffect(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    )
                  : const ShimmerEffect(width: 80, height: 20),
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
                children: const [
                  Expanded(child: ShimmerEffect(width: 120, height: 20)),
                  ShimmerEffect(width: 60, height: 20),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerEffect(width: 180, height: 16),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerEffect(width: 150, height: 16),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerEffect(width: 200, height: 16),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerEffect(width: 120, height: 16),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
