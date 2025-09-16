import 'package:flutter/material.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/models/draft.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/app_spacing.dart';
import '../providers/draft_provider.dart';
import '../providers/auth_provider.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrafts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatProductNames(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) return 'No items';

    // Extract product names from cart items
    final productNames = cartItems.map((item) {
      final product = item['product'] as Map<String, dynamic>?;
      return product?['name'] as String? ?? 'Unknown Product';
    }).toList();

    // Group by product name and show quantity if multiple
    final grouped = <String, int>{};
    for (final name in productNames) {
      grouped[name] = (grouped[name] ?? 0) + 1;
    }

    final result = grouped.entries.map((entry) {
      if (entry.value > 1) {
        return '${entry.key} (x${entry.value})';
      }
      return entry.key;
    }).toList();

    return result.join(', ');
  }

  Future<void> _loadDrafts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      draftProvider.initialize(authProvider.currentUser!.id);
      await draftProvider.loadDrafts();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final query = _searchController.text.toLowerCase();
    draftProvider.searchDrafts(query);
  }

  Future<void> _deleteDraft(String draftId) async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    try {
      await draftProvider.deleteDraft(draftId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft deleted successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete draft: $e')));
    }
  }

  Future<void> _loadDraftToSales(Draft draft) async {
    // Navigate to sales screen with the draft data
    // You'll need to implement this navigation based on your app structure
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draftProvider = Provider.of<DraftProvider>(context);
    Provider.of<AuthProvider>(context);

    return Padding(
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
                      l10n.drafts,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your draft transactions',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search drafts...',
            onChanged: (_) => _applyFilter(),
            onClear: () {
              _searchController.clear();
              _applyFilter();
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          if (draftProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                draftProvider.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _isLoading
                ? _buildShimmerTable()
                : draftProvider.drafts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No drafts found',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color?.withOpacity(0.8),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Create drafts in the sales screen',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTableWidget(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Products')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: draftProvider.drafts.asMap().entries.map((entry) {
                        final index =
                            entry.key + 1; // Serial number starts at 1
                        final draft = entry.value;

                        return DataRow(
                          cells: [
                            DataCell(Text('$index')),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Tooltip(
                                  message: _formatProductNames(draft.cartItems),
                                  child: Text(
                                    _formatProductNames(draft.cartItems),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                draft.total == 0
                                    ? '-'
                                    : draft.total.toStringAsFixed(0),
                              ),
                            ),
                            DataCell(
                              Text('${draft.date.toLocal()}'.split(' ').first),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _loadDraftToSales(draft),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primary
                                          .withOpacity(0.1),
                                      foregroundColor: AppColors.primary,
                                    ),
                                    tooltip: 'Edit Draft',
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () => _deleteDraft(draft.id),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.error
                                          .withOpacity(0.1),
                                      foregroundColor: AppColors.error,
                                    ),
                                    tooltip: 'Delete Draft',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),

                      mobileItemBuilder: (context, index) {
                        final draft = draftProvider.drafts[index];
                        return CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Draft #${draft.id.substring(0, 6)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  StatusBadge(text: draft.status),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text('Type: ${draft.type}'),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Products: ${_formatProductNames(draft.cartItems)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Total: ${draft.total == 0 ? '-' : draft.total.toStringAsFixed(0)}',
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Date: ${'${draft.date.toLocal()}'.split(' ').first}',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _loadDraftToSales(draft),
                                    tooltip: 'Edit Draft',
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () => _deleteDraft(draft.id),
                                    tooltip: 'Delete Draft',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        6,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            6,
            (index) => DataCell(
              index == 5
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
                        SizedBox(width: AppSpacing.xs),
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
                  SizedBox(width: AppSpacing.xs),
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
}
