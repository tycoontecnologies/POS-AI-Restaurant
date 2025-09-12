// products_screen.dart (updated)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/onboarding_completion.dart';
import 'package:pos/components/ui/onboarding_tooltip.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/custom_dropdown.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<String> _categories = [];
  final bool _showCompletion = false;
  bool _hasData = false;

  final List<String> _units = ['piece', 'kg', 'litre', 'pack', 'box'];

  @override
  void initState() {
    super.initState();
    _checkIfHasData();
    _searchController.addListener(_onSearchChanged);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final productProvider = context.read<ProductProvider>();
      if (authProvider.currentUser != null) {
        productProvider.loadProducts(authProvider.currentUser!.id);
      }
    });

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
    _loadCategories();
  }

  Future<void> _checkIfHasData() async {
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    if (authProvider.currentUser != null) {
      await productProvider.loadProducts(authProvider.currentUser!.id);
      setState(() {
        _hasData = productProvider.products.isNotEmpty;
      });
    }
  }

  void _loadCategories() {
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    // Load categories if not already loaded
    if (categoryProvider.categories.isEmpty) {
      categoryProvider.loadInitialCategories();
    } else {
      // Update local categories list
      _updateCategoriesList(categoryProvider);
    }
  }

  // Helper method to update categories list
  void _updateCategoriesList(CategoryProvider categoryProvider) {
    setState(() {
      _categories = categoryProvider.categories
          .where((category) => category.active) // Only active categories
          .map((category) => category.name)
          .toList();

      // Ensure we have at least one category
      if (_categories.isEmpty) {
        _categories = ['General']; // Fallback category
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to category provider changes
    final categoryProvider = Provider.of<CategoryProvider>(context);
    _updateCategoriesList(categoryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final productProvider = context.read<ProductProvider>();
    productProvider.setSearchQuery(_searchController.text);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _loadMoreData() async {
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    if (!productProvider.isLoading &&
        productProvider.hasMore &&
        authProvider.currentUser != null &&
        !_isLoadingMore) {
      setState(() => _isLoadingMore = true);
      await productProvider.loadProducts(
        authProvider.currentUser!.id,
        loadMore: true,
      );
      setState(() => _isLoadingMore = false);
    }
  }

  void _createOrEdit({Product? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    if (authProvider.currentUser == null) return;

    final availableCategories = categoryProvider.categories
        .where((category) => category.active)
        .map((category) => category.name)
        .toList();

    // Ensure we have at least one category
    if (availableCategories.isEmpty) {
      availableCategories.add('General');
    }

    final nameCtrl = TextEditingController(text: item?.name ?? '');
    String category = item?.category ?? availableCategories.first;
    String unit = item?.unit ?? 'piece';
    final saleCtrl = TextEditingController(
      text: item?.salePrice.toString() ?? '',
    );
    final purchaseCtrl = TextEditingController(
      text: item?.purchasePrice.toString() ?? '',
    );
    final quantityCtrl = TextEditingController(
      text: item?.quantity.toString() ?? '',
    );
    bool isActive = item?.active ?? true;

    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            title: Text(item == null ? l10n.addProduct : l10n.editProduct),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInput(
                      label: l10n.name,
                      controller: nameCtrl,
                      hint: 'Enter product name',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropdown<String>(
                            label: l10n.category,
                            value: category,
                            items: availableCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => category = v ?? category),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomDropdown<String>(
                            label: l10n.unit,
                            value: unit,
                            items: _units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => unit = v ?? unit),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInput(
                            label: l10n.salePrice,
                            controller: saleCtrl,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomInput(
                            label: l10n.purchasePrice,
                            controller: purchaseCtrl,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: const Icon(Icons.shopping_cart),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInput(
                      label: l10n.quantity,
                      controller: quantityCtrl,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.inventory),
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
                  if (nameCtrl.text.trim().isNotEmpty) {
                    final sale = double.tryParse(saleCtrl.text.trim()) ?? 0;
                    final purchase =
                        double.tryParse(purchaseCtrl.text.trim()) ?? 0;
                    final qty = int.tryParse(quantityCtrl.text.trim()) ?? 0;
                    Navigator.pop(
                      context,
                      _ProductFormResult(
                        name: nameCtrl.text.trim(),
                        category: category,
                        unit: unit,
                        salePrice: sale,
                        purchasePrice: purchase,
                        quantity: qty,
                        active: isActive,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    try {
      final newProduct = Product(
        id:
            item?.id ??
            '', // Will be replaced with auto-generated ID for new items
        name: result.name,
        category: result.category,
        unit: result.unit,
        salePrice: result.salePrice,
        purchasePrice: result.purchasePrice,
        quantity: result.quantity,
        active: result.active,
      );

      if (item == null) {
        await productProvider.addProduct(
          authProvider.currentUser!.id,
          newProduct,
        );
      } else {
        await productProvider.updateProduct(
          authProvider.currentUser!.id,
          newProduct.copyWith(id: item.id),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item == null
                  ? 'Product added successfully'
                  : 'Product updated successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Check if this was the first product added
        if (item == null) {
          final prefs = await SharedPreferences.getInstance();
          final hasSeenStaff = prefs.getBool('onboarding_staff_seen') ?? false;

          if (!hasSeenStaff) {
            // Navigate to staff screen after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                context.go(AppRouter.staff);
              }
            });
          }
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

  void _delete(Product item) async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    if (authProvider.currentUser == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.deleteConfirmTitle('Product')),
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
        await productProvider.deleteProduct(
          authProvider.currentUser!.id,
          item.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
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
    final productProvider = context.watch<ProductProvider>();

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_hasData)
            OnboardingTooltip(
              screenKey: 'products',
              title: 'Add Product',
              description:
                  'From here, you can add your products to build your inventory. Products are the items you sell to your customers.',
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
                      l10n.products,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your product inventory',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: l10n.addProduct,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          SearchBarWidget(
            controller: _searchController,
            hint: 'Search products...',
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
              child: _buildContent(productProvider, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ProductProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // if (provider.error != null) {
    //   return Center(
    //     child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       children: [
    //         Icon(Icons.error, size: 64, color: AppColors.error),
    //         const SizedBox(height: AppSpacing.md),
    //         Text('Error: ${provider.error}'),
    //         const SizedBox(height: AppSpacing.md),
    //         CustomButton(
    //           text: 'Retry',
    //           onPressed: () {
    //             final authProvider = context.read<AuthProvider>();
    //             if (authProvider.currentUser != null) {
    //               provider.loadProducts(authProvider.currentUser!.id);
    //             }
    //           },
    //           variant: ButtonVariant.filled,
    //         ),
    //       ],
    //     ),
    //   );
    // }

    final products = provider.products;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchController.text.isEmpty
                  ? 'No products found'
                  : 'No products found for "${_searchController.text}"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                text: 'Add Sample Data',
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
                  if (authProvider.currentUser != null) {
                    await provider.seedInitialData(
                      authProvider.currentUser!.id,
                    );
                  }
                },
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
          _loadMoreData();
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
                DataColumn(label: Text(l10n.category)),
                DataColumn(label: Text(l10n.unit)),
                DataColumn(label: Text(l10n.salePrice)),
                DataColumn(label: Text(l10n.purchasePrice)),
                DataColumn(label: Text(l10n.quantity)),
                DataColumn(label: Text(l10n.status)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: products
                  .asMap()
                  .entries
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text('${entry.key + 1}')),
                        DataCell(Text(entry.value.name)),
                        DataCell(Text(entry.value.category)),
                        DataCell(Text(entry.value.unit)),
                        DataCell(
                          Text(entry.value.salePrice.toStringAsFixed(2)),
                        ),
                        DataCell(
                          Text(entry.value.purchasePrice.toStringAsFixed(2)),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${entry.value.quantity}'),
                              if (entry.value.quantity < 20) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(
                                  Icons.warning,
                                  color: AppColors.warning,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            text: entry.value.active
                                ? l10n.active
                                : l10n.inactive,
                            variant: entry.value.active
                                ? BadgeVariant.success
                                : BadgeVariant.neutral,
                          ),
                        ),
                        DataCell(_rowActions(entry.value)),
                      ],
                    ),
                  )
                  .toList(),
              mobileItemBuilder: (context, index) {
                final item = products[index];
                return CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${index + 1}. ${item.name}', // Serial number in mobile view
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
                        'ID: ${item.id} • ${item.category} • ${item.unit} • SP: ${item.salePrice.toStringAsFixed(2)} • PP: ${item.purchasePrice.toStringAsFixed(2)} • Qty: ${item.quantity}',
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
            if (!provider.hasMore && products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No more products to load',
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

  Widget _rowActions(Product item) {
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

class _ProductFormResult {
  _ProductFormResult({
    required this.name,
    required this.category,
    required this.unit,
    required this.salePrice,
    required this.purchasePrice,
    required this.quantity,
    required this.active,
  });
  final String name;
  final String category;
  final String unit;
  final double salePrice;
  final double purchasePrice;
  final int quantity;
  final bool active;
}
