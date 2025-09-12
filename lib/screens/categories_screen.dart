// categories_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/onboarding_completion.dart';
import 'package:pos/components/ui/onboarding_tooltip.dart';
import 'package:pos/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final bool _showCompletion = false;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _checkIfHasData();

    _searchController.addListener(_onSearchChanged);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = context.read<CategoryProvider>();
      categoryProvider.loadInitialCategories();
    });

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  Future<void> _checkIfHasData() async {
    final categoryProvider = context.read<CategoryProvider>();
    await categoryProvider.loadInitialCategories();
    setState(() {
      _hasData = categoryProvider.categories.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final categoryProvider = context.read<CategoryProvider>();
    categoryProvider.searchCategories(_searchController.text);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreCategories();
    }
  }

  void _loadMoreCategories() async {
    final categoryProvider = context.read<CategoryProvider>();
    if (!categoryProvider.isLoading && categoryProvider.hasMore) {
      setState(() => _isLoadingMore = true);
      await categoryProvider.loadMoreCategories();
      setState(() => _isLoadingMore = false);
    }
  }

  void _createOrEdit({Category? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final categoryProvider = context.read<CategoryProvider>();

    final controller = TextEditingController(text: item?.name ?? '');
    bool isActive = item?.active ?? true;

    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDFDFE),
              surfaceTintColor: Colors.transparent,
              title: Text(item == null ? l10n.addCategory : l10n.editCategory),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInput(
                      label: l10n.name,
                      controller: controller,
                      hint: 'Enter category name',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          l10n.active,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                CustomButton(
                  text: l10n.cancel,
                  variant: ButtonVariant.text,
                  onPressed: () => Navigator.pop(context),
                ),
                CustomButton(
                  text: l10n.save,
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(
                        context,
                        _CategoryFormResult(
                          name: controller.text.trim(),
                          active: isActive,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      if (item == null) {
        // Create new category with auto-generated ID (will be set in service)
        final newCategory = Category(
          id: '', // Will be auto-generated
          name: result.name,
          active: result.active,
        );

        final success = await categoryProvider.addCategory(newCategory);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category added successfully'),
              backgroundColor: AppColors.success,
            ),
          );

          // Check if this was the first category added
          if (item == null) {
            final prefs = await SharedPreferences.getInstance();
            final hasSeenProducts =
                prefs.getBool('onboarding_products_seen') ?? false;

            if (!hasSeenProducts) {
              // Navigate to products screen after a short delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  context.go(AppRouter.products);
                }
              });
            }
          }
        }
      } else {
        // Update existing category
        final updatedCategory = item.copyWith(
          name: result.name,
          active: result.active,
        );

        final success = await categoryProvider.updateCategory(updatedCategory);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _delete(Category item) async {
    final l10n = AppLocalizations.of(context)!;
    final categoryProvider = context.read<CategoryProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.deleteConfirmTitle('Category')),
        content: Text(l10n.deleteConfirmMessage(item.name)),
        actions: [
          CustomButton(
            text: l10n.cancel,
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: l10n.delete,
            color: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final success = await categoryProvider.deleteCategory(item.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting category: $e'),
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
    final categoryProvider = context.watch<CategoryProvider>();

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_hasData)
            OnboardingTooltip(
              screenKey: 'categories',
              title: 'Add Category',
              description:
                  'From here, you can add your categories to organize your products. Categories help you manage your inventory efficiently.',
            ),

          // Completion message (if needed)
          if (_showCompletion) const OnboardingCompletion(),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.categories,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your product categories',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: l10n.addCategory,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          SearchBarWidget(
            controller: _searchController,
            hint: 'Search categories...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),

          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: _buildContent(categoryProvider, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CategoryProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
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
              onPressed: () => provider.loadInitialCategories(),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    final categories = provider.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchController.text.isEmpty
                  ? 'No categories found'
                  : 'No categories found for "${_searchController.text}"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                text: 'Create First Category',
                onPressed: () => _createOrEdit(),
                variant: ButtonVariant.filled,
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
          _loadMoreCategories();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            DataTableWidget(
              columns: [
                DataColumn(label: Text('#')),
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.status)),
                DataColumn(label: Text(l10n.createdOn)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: categories
                  .asMap()
                  .entries
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text('${e.key + 1}')),
                        DataCell(Text(e.value.name)),
                        DataCell(
                          StatusBadge(
                            text: e.value.active ? l10n.active : l10n.inactive,
                            variant: e.value.active
                                ? BadgeVariant.success
                                : BadgeVariant.neutral,
                          ),
                        ),
                        DataCell(
                          Text(
                            e.value.createdOn.toIso8601String().substring(
                              0,
                              10,
                            ),
                          ),
                        ),
                        DataCell(_rowActions(e.value)),
                      ],
                    ),
                  )
                  .toList(),
              mobileItemBuilder: (context, index) {
                final item = categories[index];
                return CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          StatusBadge(
                            text: item.active ? l10n.active : l10n.inactive,
                            variant: item.active
                                ? BadgeVariant.success
                                : BadgeVariant.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'ID: ${item.id} • Created: ${item.createdOn.toIso8601String().substring(0, 10)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_rowActions(item)],
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
            if (!provider.hasMore && categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No more categories to load',
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

  Widget _rowActions(Category item) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _CategoryFormResult {
  _CategoryFormResult({required this.name, required this.active});
  final String name;
  final bool active;
}
