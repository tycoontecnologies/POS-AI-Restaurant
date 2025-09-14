import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/sale_return.dart';
import '../providers/sale_return_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class SaleReturnScreen extends StatefulWidget {
  const SaleReturnScreen({super.key});

  @override
  State<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends State<SaleReturnScreen> {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSaleReturns();
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
      _loadMoreSaleReturns();
    }
  }

  Future<void> _loadSaleReturns() async {
    final authProvider = context.read<AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();

    if (authProvider.currentUser != null) {
      try {
        await saleReturnProvider.fetchSaleReturns(authProvider.currentUser!.id);
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load sale returns: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadMoreSaleReturns() async {
    final authProvider = context.read<AuthProvider>();
    final saleReturnProvider = context.read<SaleReturnProvider>();

    if (_isLoadingMore || !saleReturnProvider.hasMore) return;

    if (authProvider.currentUser != null) {
      setState(() => _isLoadingMore = true);

      try {
        await saleReturnProvider.fetchSaleReturns(
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
              content: Text('Failed to load more sale returns: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      setState(() => _isLoadingMore = false);
    }
  }

  List<SaleReturn> _filterSaleReturns(List<SaleReturn> saleReturns) {
    if (_searchQuery.isEmpty) return saleReturns;

    final query = _searchQuery.toLowerCase();
    return saleReturns.where((saleReturn) {
      return saleReturn.id.toLowerCase().contains(query) ||
          saleReturn.originalSaleId.toLowerCase().contains(query) ||
          saleReturn.items.any(
            (item) => item.productName.toLowerCase().contains(query),
          ) ||
          saleReturn.totalRefund.toString().contains(query) ||
          saleReturn.reason.toLowerCase().contains(query) ||
          _formatDate(saleReturn.createdAt).contains(query);
    }).toList();
  }

  String _formatProductNames(List<SaleReturnItem> items) {
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
                Text('Original Sale ID: ${saleReturn.originalSaleId}'),
                Text('Date: ${_formatDate(saleReturn.createdAt)}'),
                Text(
                  'Total Refund: ${saleReturn.totalRefund.toStringAsFixed(2)}',
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
                              Text(item.originalPrice.toStringAsFixed(2)),
                            ),
                            DataCell(Text('${item.returnedQuantity}')),
                            DataCell(
                              Text(item.refundAmount.toStringAsFixed(2)),
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

  Widget _rowActions(SaleReturn saleReturn) {
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

  @override
  Widget build(BuildContext context) {
    final saleReturnProvider = context.watch<SaleReturnProvider>();
    context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    final filteredSaleReturns = _filterSaleReturns(
      saleReturnProvider.saleReturns,
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
                      'Sale Returns',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track your sale return records',
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
            hint: 'Search sale returns...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: _buildContent(l10n, filteredSaleReturns, saleReturnProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    List<SaleReturn> filteredSaleReturns,
    SaleReturnProvider saleReturnProvider,
  ) {
    if (saleReturnProvider.isLoading &&
        saleReturnProvider.saleReturns.isEmpty) {
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
              onPressed: _loadSaleReturns,
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (filteredSaleReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isEmpty
                  ? 'No sale return records found'
                  : 'No sale returns found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your sale returns will appear here',
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
          _loadMoreSaleReturns();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Sale ID')),
            DataColumn(label: Text('Products')),
            DataColumn(label: Text('Refund Amount')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: filteredSaleReturns.asMap().entries.map((entry) {
            final index = entry.key + 1; // Serial number starts at 1
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
                      message: _formatProductNames(saleReturn.items),
                      child: Text(
                        _formatProductNames(saleReturn.items),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    saleReturn.totalRefund.toStringAsFixed(2),
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
                DataCell(Text(_formatDate(saleReturn.createdAt))),
                DataCell(_rowActions(saleReturn)),
              ],
            );
          }).toList(),

          mobileItemBuilder: (context, index) {
            final saleReturn = filteredSaleReturns[index];
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
                        saleReturn.totalRefund.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sale ID: ${saleReturn.originalSaleId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _formatProductNames(saleReturn.items),
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
                    'Date: ${_formatDate(saleReturn.createdAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_rowActions(saleReturn)],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
