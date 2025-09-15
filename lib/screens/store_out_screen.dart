import 'package:flutter/material.dart';
import 'package:pos/screens/add_edit_store_out_screen.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/providers/store_out_provider.dart';
import 'package:pos/models/store_out.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/loading_widget.dart';
import '../utils/app_spacing.dart';

class StoreOutScreen extends StatefulWidget {
  const StoreOutScreen({super.key});

  @override
  State<StoreOutScreen> createState() => _StoreOutScreenState();
}

class _StoreOutScreenState extends State<StoreOutScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StoreOutProvider>();
      provider.loadStoreOuts();
    });

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = context.read<StoreOutProvider>();
    provider.setSearchQuery(_searchController.text);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreStoreOuts();
    }
  }

  void _loadMoreStoreOuts() async {
    final provider = context.read<StoreOutProvider>();
    if (!provider.isLoading && provider.hasMore) {
      await provider.loadStoreOuts(loadMore: true);
    }
  }

  Future<void> _navigateToAddStoreOut() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditStoreOutScreen()),
    );

    if (result == true) {
      final provider = context.read<StoreOutProvider>();
      provider.loadStoreOuts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Store-out record created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditStoreOut(StoreOut storeOut) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditStoreOutScreen(storeOut: storeOut),
      ),
    );

    if (result == true) {
      final provider = context.read<StoreOutProvider>();
      provider.loadStoreOuts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Store-out record updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(StoreOut storeOut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete Store-Out'),
        content: Text(
          'Are you sure you want to delete store-out ${storeOut.id}?',
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CustomButton(
            text: 'Delete',
            color: AppColors.error,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<StoreOutProvider>();
      try {
        await provider.deleteStoreOut(storeOut.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Store-out record deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting store-out: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<StoreOutProvider>();

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.storeOut,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.grey800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Track inventory outgoing',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                  text: 'Record Outgoing',
                  icon: Icons.output,
                  onPressed: _navigateToAddStoreOut,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CustomCard(
                  color: AppColors.error,
                  child: Row(
                    children: [
                      Icon(Icons.error, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: provider.clearError,
                      ),
                    ],
                  ),
                ),
              ),

            SearchBarWidget(
              controller: _searchController,
              hint: 'Search store out...',
              onChanged: (_) => _onSearchChanged(),
              onClear: () {
                _searchController.clear();
                _onSearchChanged();
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            Expanded(child: _buildContent(provider, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StoreOutProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.storeOuts.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    if (provider.error != null && provider.storeOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error: ${provider.error}'),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Retry',
              onPressed: () => provider.loadStoreOuts(),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    final storeOuts = provider.storeOuts;

    if (storeOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.grey400,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchController.text.isEmpty
                  ? 'No store out records found'
                  : 'No store outs found for "${_searchController.text}"',
              style: TextStyle(fontSize: 18, color: AppColors.grey600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start by recording your first outgoing inventory',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomButton(
              text: 'Record First Outgoing',
              onPressed: _navigateToAddStoreOut,
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            _scrollController.position.pixels ==
                _scrollController.position.maxScrollExtent) {
          _loadMoreStoreOuts();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Products')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Handled By')),
            DataColumn(label: Text('Actions')),
          ],
          rows: storeOuts.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final e = entry.value;

            return DataRow(
              cells: [
                DataCell(Text('$index')),
                DataCell(Text(e.reason)),
                DataCell(
                  Tooltip(
                    message: e.products
                        .map((p) => '${p.product.name} (${p.quantity})')
                        .join('\n'),
                    child: Text(
                      e.products
                          .map((p) => '${p.product.name} (${p.quantity})')
                          .join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text('${e.date.toLocal()}'.split(' ').first)),
                DataCell(Text(e.handledBy)),
                DataCell(_rowActions(e)),
              ],
            );
          }).toList(),

          mobileItemBuilder: (context, index) {
            final s = storeOuts[index];
            return CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.id,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _rowActions(s),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Reason: ${s.reason}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Items: ${s.items}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Products: ${s.products.map((p) => '${p.product.name} (${p.quantity})').join(', ')}',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Date: ${'${s.date.toLocal()}'.split(' ').first}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Handled By: ${s.handledBy}'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _rowActions(StoreOut storeOut) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _navigateToEditStoreOut(storeOut),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _showDeleteConfirmation(storeOut),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}
