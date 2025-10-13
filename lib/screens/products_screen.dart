import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
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
import '../components/ui/simple_variant_manager.dart';
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

  final List<String> _units = ['piece', 'kg', 'litre', 'pack', 'box'];
  final _formKey = GlobalKey<FormState>();

  // Tutorial coach mark controller and targets
  TutorialCoachMark? tutorialCoachMark;
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _productsTableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _checkAndShowTutorial();

    // Load products in a single post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialProducts();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('products_tutorial_seen') ?? false;

    if (!hasSeenTutorial) {
      // Wait for the UI to build before showing the tutorial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showTutorial(context);
          prefs.setBool('products_tutorial_seen', true);
        });
      });
    }
  }

  void _showTutorial(BuildContext context) {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black26,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Products tutorial completed");
      },
      onClickTarget: (target) {
        print(target);
      },
      onSkip: () {
        print("Products tutorial skipped");
        return true;
      },
    );

    tutorialCoachMark!.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "add_button",
        keyTarget: _addButtonKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Add Product",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap here to create new products for your inventory.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
      TargetFocus(
        identify: "search_bar",
        keyTarget: _searchBarKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Products",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Use this search bar to quickly find products by name, category, or other attributes.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
      TargetFocus(
        identify: "products_table",
        keyTarget: _productsTableKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Products List",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Here you'll see all your products. You can edit, manage variants, or delete them using the action buttons.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
    ];
  }

  Future<void> _loadInitialProducts() async {
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    // ADD THIS CHECK to prevent multiple loads
    if (productProvider.isLoading) return;

    if (authProvider.currentUser != null && productProvider.products.isEmpty) {
      await productProvider.loadProducts(authProvider.currentUser!.id);
      setState(() {});
    } else {
      setState(() {});
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
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load more when user scrolls near the bottom (within 100 pixels)
    if (maxScroll - currentScroll <= 100.0 &&
        !_isLoadingMore &&
        context.read<ProductProvider>().hasMore) {
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
    bool hasVariants = item?.hasVariants ?? false;
    List<ProductVariant> variants = List.from(item?.variants ?? []);
    // List<ProductAttribute> attributes = List.from(item?.attributes ?? []);

    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            title: Text(item == null ? l10n.addProduct : l10n.editProduct),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomInput(
                        label: l10n.name,
                        controller: nameCtrl,
                        hint: 'Enter product name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
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
                              onChanged: (v) => setDialogState(
                                () => category = v ?? category,
                              ),
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
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: CustomInput(
                              label: l10n.salePrice,
                              controller: saleCtrl,
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: CustomInput(
                              label: l10n.purchasePrice,
                              controller: purchaseCtrl,
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixIcon: const Icon(Icons.shopping_cart),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (!hasVariants)
                        CustomInput(
                          label: l10n.quantity,
                          controller: quantityCtrl,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.inventory),
                        ),
                      if (!hasVariants) const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(
                            l10n.active,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const Spacer(),
                          Switch(
                            value: isActive,
                            onChanged: (v) =>
                                setDialogState(() => isActive = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(
                            'Has Variants',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const Spacer(),
                          Switch(
                            value: hasVariants,
                            onChanged: (v) => setDialogState(() {
                              hasVariants = v;
                              if (!v) {
                                variants.clear();
                              }
                            }),
                          ),
                        ],
                      ),
                      if (hasVariants) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const Divider(),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Variant Prices will be calculated as: Base Price + Modifier',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.grey600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SimpleVariantManager(
                          variants: variants,
                          basePrice:
                              double.tryParse(saleCtrl.text.trim()) ?? 0.0,
                          onVariantsChanged: (newVariants) {
                            setDialogState(() {
                              variants = newVariants;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
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
                  if (_formKey.currentState?.validate() ?? false) {
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
                        hasVariants: hasVariants,
                        variants: variants,
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
        hasVariants: result.hasVariants,
        variants: result.variants,
        attributes: [],
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
            duration: const Duration(seconds: 1),
            content: Text(
              item == null
                  ? 'Product added successfully'
                  : 'Product updated successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Check if this was the first product added
        // if (item == null) {
        //   final prefs = await SharedPreferences.getInstance();
        //   final hasSeenStaff = prefs.getBool('onboarding_staff_seen') ?? false;

        //   if (!hasSeenStaff) {
        //     Future.delayed(const Duration(milliseconds: 500), () {
        //       if (mounted) {
        //         context.go(AppRouter.staff);
        //       }
        //     });
        //   }
        // }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
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
              duration: Duration(seconds: 1),
              content: Text('Product deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
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
                key: _addButtonKey, // Added key for tutorial

                text: l10n.addProduct,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SearchBarWidget(
            key: _searchBarKey,

            controller: _searchController,
            hint: 'Search products...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            key: _productsTableKey,
            child: _buildContent(productProvider, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ProductProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.products.isEmpty) {
      return _buildShimmerTable();
    }

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
                _scrollController.position.maxScrollExtent &&
            !_isLoadingMore &&
            provider.hasMore) {
          _loadMoreData();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: [
            DataColumn(label: Text('#')),
            DataColumn(label: Text(l10n.name)),
            DataColumn(label: Text(l10n.category)),
            DataColumn(label: Text(l10n.unit)),
            DataColumn(label: Text(l10n.salePrice)),
            // DataColumn(label: Text(l10n.purchasePrice)),
            DataColumn(label: Text(l10n.quantity)),
            DataColumn(label: Text('Variants')),
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
                    DataCell(Text(entry.value.salePrice.toStringAsFixed(0))),
                    // DataCell(
                    //   Text(entry.value.purchasePrice.toStringAsFixed(0)),
                    // ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value.hasVariants
                                ? '${entry.value.totalVariantQuantity}'
                                : '${entry.value.quantity}',
                          ),
                          if ((entry.value.hasVariants
                                  ? entry.value.totalVariantQuantity
                                  : entry.value.quantity) <
                              20) ...[
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
                      entry.value.hasVariants
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXs,
                                ),
                              ),
                              child: Text(
                                '${entry.value.variants.length} variants',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : Text('-'),
                    ),
                    DataCell(
                      StatusBadge(
                        text: entry.value.active ? l10n.active : l10n.inactive,
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
                    'ID: ${item.id} • ${item.category} • ${item.unit} • ${item.hasVariants ? 'Price: ${item.minPrice.toStringAsFixed(0)}-${item.maxPrice.toStringAsFixed(0)}' : 'SP: ${item.salePrice.toStringAsFixed(0)}'} • PP: ${item.purchasePrice.toStringAsFixed(0)} • Qty: ${item.hasVariants ? item.totalVariantQuantity : item.quantity}${item.hasVariants ? ' • ${item.variants.length} variants' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
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

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        10,
        (index) => DataColumn(label: ShimmerEffect(width: 60, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            10,
            (index) => DataCell(ShimmerEffect(width: 60, height: 20)),
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
                  Expanded(
                    child: ShimmerEffect(width: double.infinity, height: 20),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 250, height: 14),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                ],
              ),
            ],
          ),
        );
      },
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
    required this.hasVariants,
    required this.variants,
    // required this.attributes,
  });
  final String name;
  final String category;
  final String unit;
  final double salePrice;
  final double purchasePrice;
  final int quantity;
  final bool active;
  final bool hasVariants;
  final List<ProductVariant> variants;
  // final List<ProductAttribute> attributes;
}
