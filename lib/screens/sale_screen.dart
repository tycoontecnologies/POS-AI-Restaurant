// lib/screens/sale_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
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
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _error;

  // Pagination variables
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  final List<Sale> _allSales = [];

  // Filtering
  DateTime? _singleDate; // when user picks a single date
  DateTimeRange? _dateRange; // when user picks a range
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _presetFilter = 'All'; // All, Today, This Week, This Month

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Delay the loading to avoid build phase conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales();
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
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
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
    Provider.of<SaleProvider>(context, listen: false);

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
              duration: const Duration(seconds: 1),
              content: Text('Failed to load more sales: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // Combined filtering: search + date/time filters + preset
  List<Sale> _applyAllFilters() {
    final now = DateTime.now();
    List<Sale> list = _allSales;

    // Preset filter logic
    if (_presetFilter == 'Today') {
      final DateTime start = DateTime(now.year, now.month, now.day);
      final DateTime end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      list = list
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                s.createdAt.toLocal().isBefore(
                  end.add(const Duration(milliseconds: 1)),
                ),
          )
          .toList();
    } else if (_presetFilter == 'This Week') {
      // assuming week starts on Monday
      final weekday = now.weekday;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: weekday - 1));
      final end = start
          .add(const Duration(days: 7))
          .subtract(const Duration(milliseconds: 1));
      list = list
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                s.createdAt.toLocal().isBefore(
                  end.add(const Duration(milliseconds: 1)),
                ),
          )
          .toList();
    } else if (_presetFilter == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));
      list = list
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                s.createdAt.toLocal().isBefore(
                  end.add(const Duration(milliseconds: 1)),
                ),
          )
          .toList();
    }

    // Single date filter
    if (_singleDate != null) {
      final start = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      list = list
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                s.createdAt.toLocal().isBefore(
                  end.add(const Duration(milliseconds: 1)),
                ),
          )
          .toList();
    }

    // Date range filter
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
      list = list
          .where(
            (s) =>
                s.createdAt.toLocal().isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                s.createdAt.toLocal().isBefore(
                  end.add(const Duration(milliseconds: 1)),
                ),
          )
          .toList();
    }

    // Time-of-day filter (applied within singleDate or for each day in range)
    if (_startTime != null || _endTime != null) {
      list = list.where((s) {
        final local = s.createdAt.toLocal();
        // Build comparison times on same day of sale
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
        return local.isAfter(
              startTimeOfSale.subtract(const Duration(milliseconds: 1)),
            ) &&
            local.isBefore(endTimeOfSale.add(const Duration(milliseconds: 1)));
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((sale) {
        final matchId = sale.id.toLowerCase().contains(query);
        final matchItems = sale.items.any(
          (item) => item.productName.toLowerCase().contains(query),
        );
        final matchTotal = sale.total.toString().contains(query);
        final matchDate =
            _formatDate(sale.createdAt).contains(query) ||
            DateFormat(
              'd MMM yyyy',
            ).format(sale.createdAt.toLocal()).toLowerCase().contains(query);
        return matchId || matchItems || matchTotal || matchDate;
      }).toList();
    }

    // Sort by date desc (most recent first)
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }

  double _sumSalesForToday() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final todays = _allSales.where((s) {
      final t = s.createdAt.toLocal();
      return t.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          t.isBefore(end.add(const Duration(milliseconds: 1)));
    });

    double sum = 0;
    for (var s in todays) {
      sum += s.total;
    }
    return sum;
  }

  double _sumSalesForList(List<Sale> list) {
    double sum = 0;
    for (var s in list) {
      sum += s.total;
    }
    return sum;
  }

  String _formatProductNames(List<SaleItem> items) {
    if (items.isEmpty) return 'No items';

    // Group by product name and show quantity if multiple
    final grouped = groupBy(items, (item) => item.productName);
    final result = grouped.entries.map((entry) {
      final qty = entry.value.fold<int>(0, (p, e) => p + (e.quantity));
      if (qty > 1) {
        return '${entry.key} (x$qty)';
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
                Text('Receipt ID: ${sale.id}'),
                Text('Date: ${_formatDate(sale.createdAt)}'),
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
                        final price = item.price;
                        final qty = item.quantity;
                        return DataRow(
                          cells: [
                            DataCell(Text(item.productName)),
                            DataCell(Text(price.toStringAsFixed(0))),
                            DataCell(Text('$qty')),
                            DataCell(Text((price * qty).toStringAsFixed(0))),
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

  Widget _rowActions(Sale sale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
              refundAmount: (item.price) * (item.quantity),
            ),
          )
          .toList();

      // Calculate total refund
      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + (item.refundAmount),
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
              refundAmount: (item.price) * (item.quantity),
            ),
          )
          .toList();

      // Calculate total refund
      final totalRefund = returnItems.fold(
        0.0,
        (sum, item) => sum + (item.refundAmount),
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

  // UI helpers for picking dates and times
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
        _dateRange = null; // clear range when single date chosen
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

  void _resetFilters() {
    setState(() {
      _presetFilter = 'All';
      _singleDate = null;
      _dateRange = null;
      _startTime = null;
      _endTime = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<SaleProvider>(context); // keep provider alive
    final l10n = AppLocalizations.of(context)!;
    final filteredSales = _applyAllFilters();

    final todaysTotal = _sumSalesForToday();
    final filteredTotal = _sumSalesForList(filteredSales);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE TITLE
              Expanded(
                flex: 2,
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

              const SizedBox(width: 20),

              // ------------------ RIGHT SIDE CARDS ------------------
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // ---------- Today Total ----------
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Today\'s Sales',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.grey700,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat('#,###').format(todaysTotal),
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

                    // ---------- Filtered Total ----------
                    Expanded(
                      child: CustomCard(
                        color: Colors.grey.shade100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredSales.length} records',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.grey600),
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
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Search and filters row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: SearchBarWidget(
                  controller: _searchController,
                  hint: 'Search sales...',
                  onChanged: (_) => _onSearchChanged(),
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Preset dropdown
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
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
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
                        // clear single/range when selecting preset
                        if (v != 'All') {
                          _singleDate = null;
                          _dateRange = null;
                        }
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Buttons for date pickers
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

              const SizedBox(width: AppSpacing.sm),

              CustomButton(
                text: 'Reset',
                variant: ButtonVariant.outlined,
                onPressed: _resetFilters,
              ),
            ],
          ),

          // Show active filter summary
          if (_presetFilter != 'All' ||
              _singleDate != null ||
              _dateRange != null ||
              _startTime != null ||
              _endTime != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
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
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(child: _buildContent(l10n, filteredSales)),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n, List<Sale> filteredSales) {
    if (_isLoading && _allSales.isEmpty) {
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
                'Try clearing filters or fetch fresh data.',
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
        child: DataTableWidget(
          columns: [
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('Products')),
            const DataColumn(label: Text('Total')),
            const DataColumn(label: Text('Date')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: filteredSales.asMap().entries.map((entry) {
            final index = entry.key;
            final sale = entry.value;
            final serialNumber = index + 1; // Serial number starts from 1

            return DataRow(
              cells: [
                DataCell(Text('$serialNumber')),
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
                DataCell(_rowActions(sale)),
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
                    _formatProductNames(sale.items),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Date: ${DateFormat('d MMM yyyy – hh:mm a').format(sale.createdAt.toLocal())}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
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
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 180, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 150, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 200, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 120, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 100, height: 16),
              const SizedBox(height: AppSpacing.sm),
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
