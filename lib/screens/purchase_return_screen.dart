// purchase_return_screen.dart
import 'package:flutter/material.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/purchase_return.dart';
import '../providers/purchase_return_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key});

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Load data after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPurchaseReturns();
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
      _loadMorePurchaseReturns();
    }
  }

  Future<void> _loadPurchaseReturns() async {
    final authProvider = context.read<AuthProvider>();
    final purchaseReturnProvider = context.read<PurchaseReturnProvider>();

    if (authProvider.currentUser != null) {
      try {
        // Show shimmer immediately
        setState(() {
          _error = null;
        });

        await purchaseReturnProvider.fetchPurchaseReturns(
          authProvider.currentUser!.id,
        );
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Failed to load purchase returns: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadMorePurchaseReturns() async {
    final authProvider = context.read<AuthProvider>();
    final purchaseReturnProvider = context.read<PurchaseReturnProvider>();

    if (_isLoadingMore || !purchaseReturnProvider.hasMore) return;

    if (authProvider.currentUser != null) {
      setState(() => _isLoadingMore = true);

      try {
        await purchaseReturnProvider.fetchPurchaseReturns(
          authProvider.currentUser!.id,
          loadMore: true,
        );
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Failed to load more purchase returns: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      setState(() => _isLoadingMore = false);
    }
  }

  List<PurchaseReturn> _filterPurchaseReturns(
    List<PurchaseReturn> purchaseReturns,
  ) {
    if (_searchQuery.isEmpty) return purchaseReturns;

    final query = _searchQuery.toLowerCase();
    return purchaseReturns.where((purchaseReturn) {
      return purchaseReturn.id.toLowerCase().contains(query) ||
          purchaseReturn.originalPurchaseId.toLowerCase().contains(query) ||
          purchaseReturn.supplierName.toLowerCase().contains(query) ||
          purchaseReturn.items.any(
            (item) => item.productName.toLowerCase().contains(query),
          ) ||
          purchaseReturn.totalRefund.toString().contains(query) ||
          purchaseReturn.reason.toLowerCase().contains(query) ||
          _formatDate(purchaseReturn.createdAt).contains(query);
    }).toList();
  }

  String _formatProductNames(List<PurchaseReturnItem> items) {
    if (items.isEmpty) return 'No items';

    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final totalQuantity = entry.value
          .map((item) => item.returnedQuantity)
          .reduce((a, b) => a + b);
      return '${entry.key} (x$totalQuantity)';
    }).toList();

    return result.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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
                Text('Date: ${_formatDate(purchaseReturn.createdAt)}'),
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

  Widget _rowActions(PurchaseReturn purchaseReturn) {
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

  @override
  Widget build(BuildContext context) {
    final purchaseReturnProvider = context.watch<PurchaseReturnProvider>();
    context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    final filteredPurchaseReturns = _filterPurchaseReturns(
      purchaseReturnProvider.purchaseReturns,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      'Purchase Returns',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track your purchase return records',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search purchase returns...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: _buildContent(
              l10n,
              filteredPurchaseReturns,
              purchaseReturnProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    List<PurchaseReturn> filteredPurchaseReturns,
    PurchaseReturnProvider purchaseReturnProvider,
  ) {
    if (purchaseReturnProvider.isLoading &&
        purchaseReturnProvider.purchaseReturns.isEmpty) {
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
              onPressed: _loadPurchaseReturns,
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (filteredPurchaseReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isEmpty
                  ? 'No purchase return records found'
                  : 'No purchase returns found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your purchase returns will appear here',
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
          _loadMorePurchaseReturns();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Purchase ID')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Products')),
            DataColumn(label: Text('Refund Amount')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: filteredPurchaseReturns.asMap().entries.map((entry) {
            final index = entry.key + 1; // Serial numbers starting from 1
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
                      message: _formatProductNames(purchaseReturn.items),
                      child: Text(
                        _formatProductNames(purchaseReturn.items),
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
                DataCell(Text(_formatDate(purchaseReturn.createdAt))),
                DataCell(_rowActions(purchaseReturn)),
              ],
            );
          }).toList(),
          mobileItemBuilder: (context, index) {
            final purchaseReturn = filteredPurchaseReturns[index];
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
                    _formatProductNames(purchaseReturn.items),
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
                    'Date: ${_formatDate(purchaseReturn.createdAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_rowActions(purchaseReturn)],
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
        8,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            8,
            (index) => DataCell(
              index == 7
                  ? ShimmerEffect(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(20),
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
                  ShimmerEffect(width: 60, height: 20),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 180, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 150, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 200, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 120, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
}
