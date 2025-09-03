import 'package:flutter/material.dart';
import 'package:pos/screens/add_edit_store_out_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/providers/store_out_provider.dart';
import 'package:pos/models/store_out.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/loading_widget.dart';
import '../utils/responsive.dart';
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
    _loadStoreOuts();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadStoreOuts() {
    final provider = context.read<StoreOutProvider>();
    provider.loadStoreOuts();
  }

  void _onSearchChanged() {
    final provider = context.read<StoreOutProvider>();
    provider.setSearchQuery(_searchController.text);
  }

  void _onScroll() {
    final provider = context.read<StoreOutProvider>();
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        provider.hasMore &&
        !provider.isLoading) {
      provider.loadStoreOuts(loadMore: true);
    }
  }

  Future<void> _navigateToAddStoreOut() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditStoreOutScreen()),
    );

    if (result == true) {
      _loadStoreOuts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store-out record created successfully')),
      );
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
      _loadStoreOuts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store-out record updated successfully')),
      );
    }
  }

  Future<void> _showDeleteConfirmation(StoreOut storeOut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Store-Out'),
        content: Text(
          'Are you sure you want to delete store-out ${storeOut.id}?',
        ),
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
      final provider = context.read<StoreOutProvider>();
      try {
        await provider.deleteStoreOut(storeOut.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store-out record deleted successfully'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting store-out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<StoreOutProvider>();

    return Scaffold(
      body: Padding(
        padding: Responsive.getPagePadding(context),
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
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Track inventory outgoing',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
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
            const SizedBox(height: AppSpacing.lg),

            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CustomCard(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
            const SizedBox(height: AppSpacing.md),

            Expanded(child: _buildContent(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StoreOutProvider provider) {
    if (provider.isLoading && provider.storeOuts.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    if (provider.error != null && provider.storeOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading store outs',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomButton(text: 'Retry', onPressed: _loadStoreOuts),
          ],
        ),
      );
    }

    if (provider.storeOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No store out records found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start by recording your first outgoing inventory',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomButton(
              text: 'Record First Outgoing',
              onPressed: _navigateToAddStoreOut,
            ),
          ],
        ),
      );
    }

    return CustomCard(
      padding: EdgeInsets.zero,
      child: DataTableWidget(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Items'), numeric: true),
          DataColumn(label: Text('Products')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Handled By')),
          DataColumn(label: Text('Actions')),
        ],
        rows: provider.storeOuts
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(Text(e.id)),
                  DataCell(Text(e.reason)),
                  DataCell(Text('${e.items}')),
                  DataCell(
                    Tooltip(
                      message: e.products
                          .map((p) => '${p.product.name} (${p.quantity})')
                          .join('\n'),
                      child: Text('${e.products.length} products'),
                    ),
                  ),
                  DataCell(Text('${e.date.toLocal()}'.split(' ').first)),
                  DataCell(Text(e.handledBy)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _navigateToEditStoreOut(e),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => _showDeleteConfirmation(e),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
        mobileItemBuilder: (context, index) {
          final s = provider.storeOuts[index];
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _navigateToEditStoreOut(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          onPressed: () => _showDeleteConfirmation(s),
                        ),
                      ],
                    ),
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
    );
  }
}
