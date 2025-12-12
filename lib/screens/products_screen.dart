// inventory_screen.dart - COMBINED PRODUCTS AND CATEGORIES
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/category.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/ingredient.dart';
import 'package:pos/models/recipe.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/ingredient_provider.dart';
import 'package:pos/providers/recipe_provider.dart';
import 'package:pos/services/image_upload_service.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/utils/app_typography.dart';
import 'package:provider/provider.dart';
// import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/custom_dropdown.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/simple_variant_manager.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _productsSearchController =
      TextEditingController();
  final TextEditingController _categoriesSearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<String> _categories = [];
  final List<String> _units = ['piece', 'kg', 'litre', 'pack', 'box'];
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  final ImageUploadService _imageUploadService = ImageUploadService();

  // Tutorial keys
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _contentTableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _productsSearchController.addListener(_onProductsSearchChanged);
    _categoriesSearchController.addListener(_onCategoriesSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadCategories();

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialProducts();
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<IngredientProvider>().bindStream(auth.currentUser!.id);
      }

      // Load categories
      final categoryProvider = context.read<CategoryProvider>();
      categoryProvider.loadInitialCategories();
    });
  }

  Future<void> _loadInitialProducts() async {
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

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

    if (categoryProvider.categories.isEmpty) {
      categoryProvider.loadInitialCategories();
    } else {
      _updateCategoriesList(categoryProvider);
    }
  }

  void _updateCategoriesList(CategoryProvider categoryProvider) {
    setState(() {
      _categories = categoryProvider.categories
          .where((category) => category.active)
          .map((category) => category.name)
          .toList();

      if (_categories.isEmpty) {
        _categories = ['General'];
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final categoryProvider = Provider.of<CategoryProvider>(context);
    _updateCategoriesList(categoryProvider);
  }

  @override
  void dispose() {
    _productsSearchController.dispose();
    _categoriesSearchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onProductsSearchChanged() {
    final productProvider = context.read<ProductProvider>();
    productProvider.setSearchQuery(_productsSearchController.text);
  }

  void _onCategoriesSearchChanged() {
    final categoryProvider = context.read<CategoryProvider>();
    categoryProvider.searchCategories(_categoriesSearchController.text);
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= 100.0 &&
        !_isLoadingMore &&
        _tabController.index == 0 && // Only for products tab
        context.read<ProductProvider>().hasMore) {
      _loadMoreData();
    } else if (_tabController.index == 1) {
      // For categories tab
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreCategories();
      }
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

  void _loadMoreCategories() async {
    final categoryProvider = context.read<CategoryProvider>();
    if (!categoryProvider.isLoading && categoryProvider.hasMore) {
      await categoryProvider.loadMoreCategories();
    }
  }

  // PRODUCTS METHODS
  void _createOrEditProduct({Product? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final ImageUploadService _imageUploadService = ImageUploadService();

    if (authProvider.currentUser == null) return;

    final availableCategories = categoryProvider.categories
        .where((category) => category.active)
        .map((category) => category.name)
        .toList();

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

    dynamic selectedImage;
    String? imageError;
    Uint8List? imageBytes;
    String? existingImageUrl = item?.imageUrl;

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
                      // Image Upload Section
                      _buildProductImageUploadSection(
                        context,
                        existingImageUrl,
                        selectedImage,
                        imageBytes,
                        imageError,
                        (file, bytes, error) {
                          setDialogState(() {
                            selectedImage = file;
                            imageBytes = bytes;
                            imageError = error;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

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
                      if (!hasVariants)
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
                      if (!hasVariants) const SizedBox(height: AppSpacing.xs),
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
                        imageFile: selectedImage,
                        existingImageUrl: existingImageUrl,
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
      String? imageUrl = result.existingImageUrl;
      if (result.imageFile != null) {
        if (result.existingImageUrl?.isNotEmpty == true) {
          await _imageUploadService.deleteImage(result.existingImageUrl!);
        }

        imageUrl = await _imageUploadService.uploadProductImage(
          imageFile: result.imageFile!,
          vendorId: authProvider.currentUser!.id,
          productId: item?.id ?? '',
        );
      }

      final newProduct = Product(
        id: item?.id ?? '',
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
        imageUrl: imageUrl ?? '',
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

  void _deleteProduct(Product item) async {
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

  // CATEGORIES METHODS
  void _createOrEditCategory({Category? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final categoryProvider = context.read<CategoryProvider>();

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?.name ?? '');
    bool isActive = item?.active ?? true;
    dynamic selectedImage;
    String? imageError;
    Uint8List? imageBytes;

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
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Upload Section
                      _buildCategoryImageUploadSection(
                        context,
                        item?.imageUrl,
                        selectedImage,
                        imageBytes,
                        imageError,
                        (file, bytes, error) {
                          setDialogState(() {
                            selectedImage = file;
                            imageBytes = bytes;
                            imageError = error;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Name Input
                      CustomInput(
                        label: l10n.name,
                        controller: nameController,
                        hint: 'Enter category name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Category name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Active Switch
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
                    if (formKey.currentState?.validate() ?? false) {
                      if (imageError != null) return;

                      Navigator.pop(
                        context,
                        _CategoryFormResult(
                          name: nameController.text.trim(),
                          active: isActive,
                          imageFile: selectedImage,
                          existingImageUrl:
                              selectedImage == null && imageBytes == null
                              ? null
                              : item?.imageUrl,
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
        final newCategory = Category(
          id: '',
          name: result.name,
          active: result.active,
          imageUrl: '',
        );

        String? imageUrl;
        if (result.imageFile != null) {
          imageUrl = await _uploadCategoryImage(
            result.imageFile!,
            categoryProvider,
            newCategory.id,
          );
        }

        final categoryWithImage = newCategory.copyWith(
          imageUrl: imageUrl ?? '',
        );
        final success = await categoryProvider.addCategory(categoryWithImage);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: const Text('Category added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        String? imageUrl = result.existingImageUrl;

        if (result.imageFile == null &&
            result.existingImageUrl?.isNotEmpty == true) {
          await _imageUploadService.deleteImage(result.existingImageUrl!);
          imageUrl = '';
        } else if (result.imageFile != null) {
          if (result.existingImageUrl?.isNotEmpty == true) {
            await _imageUploadService.deleteImage(result.existingImageUrl!);
          }

          imageUrl = await _uploadCategoryImage(
            result.imageFile!,
            categoryProvider,
            item.id,
          );
        }

        final updatedCategory = item.copyWith(
          name: result.name,
          active: result.active,
          imageUrl: imageUrl ?? item.imageUrl,
        );

        final success = await categoryProvider.updateCategory(updatedCategory);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: const Text('Category updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _deleteCategory(Category item) async {
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
        if (item.imageUrl.isNotEmpty) {
          await _imageUploadService.deleteImage(item.imageUrl);
        }

        final success = await categoryProvider.deleteCategory(item.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Category deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text('Error deleting category: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // HELPER METHODS
  double _getMinVariantPrice(Product product) {
    if (product.hasVariants && product.variants.isNotEmpty) {
      return product.minPrice;
    }
    return product.salePrice;
  }

  Future<String> _uploadCategoryImage(
    dynamic imageFile,
    CategoryProvider categoryProvider,
    String categoryId,
  ) async {
    final vendorId = categoryProvider.authProvider?.currentUser?.id;
    if (vendorId == null) {
      throw Exception('Vendor ID not found');
    }

    return await _imageUploadService.uploadCategoryImage(
      imageFile: imageFile,
      vendorId: vendorId,
      categoryId: categoryId,
    );
  }

  Future<void> _openRecipeDialog(Product product) async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;

    final recipeProvider = context.read<RecipeProvider>();
    final ingredientProvider = context.read<IngredientProvider>();
    final existing = await recipeProvider.loadRecipe(
      auth.currentUser!.id,
      product.id,
    );

    final List<_RecipeRowItem> rows = (existing?.items ?? [])
        .map(
          (it) => _RecipeRowItem(
            ingredientId: it.ingredientId,
            quantity: it.quantityPerUnit,
          ),
        )
        .toList();

    final formKey = GlobalKey<FormState>();
    int? producible() {
      final r = recipeProvider.getRecipeCached(product.id);
      if (r == null) return null;
      return recipeProvider.computeUnitsProducible(
        ingredientProvider.ingredients,
        r,
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addRow() => setDialogState(() => rows.add(_RecipeRowItem()));
            void removeRow(int i) => setDialogState(() => rows.removeAt(i));

            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final items = <RecipeItem>[];
              for (final r in rows) {
                final ing = ingredientProvider.ingredients.firstWhere(
                  (i) => i.id == r.ingredientId,
                  orElse: () => Ingredient(
                    id: '',
                    name: '',
                    unit: 'g',
                    quantityInStock: 0,
                  ),
                );
                if (ing.id.isEmpty) continue;
                items.add(
                  RecipeItem(
                    ingredientId: ing.id,
                    ingredientName: ing.name,
                    unit: ing.unit,
                    quantityPerUnit: r.quantity ?? 0,
                  ),
                );
              }
              final recipe = ProductRecipe(
                productId: product.id,
                productName: product.name,
                items: items,
              );
              await recipeProvider.saveRecipe(auth.currentUser!.id, recipe);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    duration: Duration(seconds: 1),
                    content: Text('Recipe saved'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.pop(context);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFFDFDFE),
              surfaceTintColor: Colors.transparent,
              title: Text('Manage Recipe • ${product.name}'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'No ingredients yet. Click "Add Ingredient" to start.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        for (int i = 0; i < rows.length; i++)
                          _RecipeInlineRow(
                            key: ValueKey('recipe_row_$i'),
                            row: rows[i],
                            ingredients: ingredientProvider.ingredients,
                            onRemove: () => removeRow(i),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (producible() != null)
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.factory,
                                      color: AppColors.secondary,
                                    ),
                                  ],
                                ),
                              ),
                            CustomButton(
                              text: 'Add Ingredient',
                              icon: Icons.add,
                              onPressed: addRow,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                CustomButton(
                  text: 'Close',
                  variant: ButtonVariant.text,
                  onPressed: () => Navigator.pop(context),
                ),
                CustomButton(text: 'Save Recipe', onPressed: save),
              ],
            );
          },
        );
      },
    );
  }

  // IMAGE HANDLING METHODS
  Widget _buildProductImageUploadSection(
    BuildContext context,
    String? existingImageUrl,
    dynamic selectedImage,
    Uint8List? imageBytes,
    String? error,
    Function(dynamic, Uint8List?, String?) onImageSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Image', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),

        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildImagePreview(
            existingImageUrl,
            selectedImage,
            imageBytes,
            onImageSelected,
          ),
        ),

        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),

        if (selectedImage == null && (existingImageUrl?.isEmpty ?? true))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: CustomButton(
              text: 'Choose Image',
              icon: Icons.photo_library,
              onPressed: () => _pickImage(onImageSelected: onImageSelected),
              variant: ButtonVariant.outlined,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryImageUploadSection(
    BuildContext context,
    String? existingImageUrl,
    dynamic selectedImage,
    Uint8List? imageBytes,
    String? error,
    Function(dynamic, Uint8List?, String?) onImageSelected,
  ) {
    final hasImage =
        selectedImage != null || (existingImageUrl?.isNotEmpty == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category Image', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),

        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildImagePreview(
            existingImageUrl,
            selectedImage,
            imageBytes,
            onImageSelected,
          ),
        ),

        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),

        if (!hasImage)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: CustomButton(
              text: 'Choose Image',
              icon: Icons.photo_library,
              onPressed: () => _pickImage(onImageSelected: onImageSelected),
              variant: ButtonVariant.outlined,
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview(
    String? existingImageUrl,
    dynamic selectedImage,
    Uint8List? imageBytes,
    Function(dynamic, Uint8List?, String?) onImageSelected,
  ) {
    if (selectedImage != null && imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => onImageSelected(null, null, null),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ],
      );
    } else if (existingImageUrl?.isNotEmpty == true) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: existingImageUrl!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              placeholder: (context, url) => ShimmerEffect(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.circular(8),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => onImageSelected(null, null, null),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ],
      );
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 48, color: Colors.grey),
          SizedBox(height: AppSpacing.xs),
          Text('No image selected', style: TextStyle(color: Colors.grey)),
        ],
      );
    }
  }

  Future<void> _pickImage({
    required Function(dynamic, Uint8List?, String?) onImageSelected,
  }) async {
    try {
      final imageFile = await _imageUploadService.pickImage();
      if (imageFile != null) {
        final validationError = _imageUploadService.validateImage(imageFile);

        Uint8List? imageBytes;
        if (_isWeb()) {
          imageBytes = await _imageUploadService.getFileBytes(imageFile);
        }

        onImageSelected(imageFile, imageBytes, validationError);
      }
    } catch (e) {
      onImageSelected(null, null, 'Failed to pick image: $e');
    }
  }

  Widget _buildProductImage(String imageUrl, {double size = 40}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2, color: AppColors.grey400),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => ShimmerEffect(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(8),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.grey100,
            child: const Icon(Icons.broken_image, color: AppColors.grey400),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(String imageUrl, {double height = 40}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: height,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.category, color: AppColors.grey400),
      );
    }

    return Container(
      width: height,
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => ShimmerEffect(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(8),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.grey100,
            child: const Icon(Icons.broken_image, color: AppColors.grey400),
          ),
        ),
      ),
    );
  }

  bool _isWeb() {
    return identical(0, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondaryDark,
        toolbarHeight: 0,
        elevation: 0,
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          controller: _tabController,
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Categories'),
          ],
          onTap: (index) {
            setState(() {
              _productsSearchController.clear();
              _categoriesSearchController.clear();
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar and add button in a single row
            Row(
              children: [
                // Search bar takes most of the space
                Expanded(
                  child: _tabController.index == 0
                      ? SearchBarWidget(
                          key: _searchBarKey,
                          controller: _productsSearchController,
                          hint: 'Search products...',
                          onChanged: (_) => _onProductsSearchChanged(),
                          onClear: () {
                            _productsSearchController.clear();
                            _onProductsSearchChanged();
                          },
                        )
                      : SearchBarWidget(
                          key: _searchBarKey,
                          controller: _categoriesSearchController,
                          hint: 'Search categories...',
                          onChanged: (_) => _onCategoriesSearchChanged(),
                          onClear: () {
                            _categoriesSearchController.clear();
                            _onCategoriesSearchChanged();
                          },
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Add button on the right side
                _tabController.index == 0
                    ? CustomButton(
                        color: AppColors.successDark,
                        key: _addButtonKey,
                        text: l10n.addProduct,
                        icon: Icons.add,
                        onPressed: () => _createOrEditProduct(),
                      )
                    : CustomButton(
                        color: AppColors.successDark,
                        key: _addButtonKey,
                        text: l10n.addCategory,
                        icon: Icons.add,
                        onPressed: () => _createOrEditCategory(),
                      ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Tab Content
            Expanded(
              key: _contentTableKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Products Tab
                  _buildProductsContent(),

                  // Categories Tab
                  _buildCategoriesContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsContent() {
    final l10n = AppLocalizations.of(context)!;
    final productProvider = context.watch<ProductProvider>();

    if (productProvider.isLoading && productProvider.products.isEmpty) {
      return _buildProductsShimmerTable();
    }

    final products = productProvider.products;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _productsSearchController.text.isEmpty
                  ? 'No products found'
                  : 'No products found for "${_productsSearchController.text}"',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_productsSearchController.text.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                text: 'Add Sample Data',
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
                  if (authProvider.currentUser != null) {
                    await productProvider.seedInitialData(
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
            productProvider.hasMore) {
          _loadMoreData();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Image')),
            DataColumn(label: Text(l10n.name)),
            DataColumn(label: Text(l10n.category)),
            DataColumn(label: Text(l10n.unit)),
            DataColumn(label: Text(l10n.salePrice)),
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
                    DataCell(_buildProductImage(entry.value.imageUrl)),
                    DataCell(Text(entry.value.name)),
                    DataCell(Text(entry.value.category)),
                    DataCell(Text(entry.value.unit)),
                    DataCell(
                      Text(
                        entry.value.hasVariants &&
                                entry.value.variants.isNotEmpty
                            ? _getMinVariantPrice(
                                entry.value,
                              ).toStringAsFixed(0)
                            : entry.value.salePrice.toStringAsFixed(0),
                      ),
                    ),
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
                    DataCell(_productRowActions(entry.value)),
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
                  if (item.imageUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 120,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => ShimmerEffect(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.grey100,
                            child: const Icon(
                              Icons.broken_image,
                              size: 48,
                              color: AppColors.grey400,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                  Text('Category: ${item.category}'),
                  Text('Unit: ${item.unit}'),
                  Text(
                    'Price: ${_getMinVariantPrice(item).toStringAsFixed(0)}',
                  ),
                  Text('Quantity: ${item.quantity}'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_productRowActions(item)],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _productRowActions(Product item) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Manage Recipe',
          icon: const Icon(Icons.restaurant_menu, size: 18),
          onPressed: () => _openRecipeDialog(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.secondary.withOpacity(0.1),
            foregroundColor: AppColors.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEditProduct(item: item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _deleteProduct(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsShimmerTable() {
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

  Widget _buildCategoriesContent() {
    final l10n = AppLocalizations.of(context)!;
    final categoryProvider = context.watch<CategoryProvider>();

    if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
      return _buildCategoriesShimmerTable();
    }

    if (categoryProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error: ${categoryProvider.error}'),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Retry',
              onPressed: () => categoryProvider.loadInitialCategories(),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    final categories = categoryProvider.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              _categoriesSearchController.text.isEmpty
                  ? 'No categories found'
                  : 'No categories found for "${_categoriesSearchController.text}"',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
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
          _loadMoreCategories();
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTableWidget(
          columns: const [
            DataColumn(
              label: Text('#', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            DataColumn(
              label: Text(
                'Image',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Created On',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          rows: categories
              .asMap()
              .entries
              .map(
                (e) => DataRow(
                  cells: [
                    DataCell(Text('${e.key + 1}')),
                    DataCell(_buildCategoryImage(e.value.imageUrl)),
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
                      Text(DateFormat('d MMM yyyy').format(e.value.createdOn)),
                    ),
                    DataCell(_categoryRowActions(e.value)),
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
                  _buildCategoryImage(item.imageUrl, height: 120),
                  const SizedBox(height: AppSpacing.sm),
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
                    'Created: ${item.createdOn.toIso8601String().substring(0, 10)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_categoryRowActions(item)],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _categoryRowActions(Category item) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEditCategory(item: item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _deleteCategory(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesShimmerTable() {
    return DataTableWidget(
      columns: const [
        DataColumn(label: ShimmerEffect(width: 20, height: 20)),
        DataColumn(label: ShimmerEffect(width: 40, height: 40)),
        DataColumn(label: ShimmerEffect(width: 80, height: 20)),
        DataColumn(label: ShimmerEffect(width: 60, height: 20)),
        DataColumn(label: ShimmerEffect(width: 80, height: 20)),
        DataColumn(label: ShimmerEffect(width: 60, height: 20)),
      ],
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: [
            DataCell(ShimmerEffect(width: 20, height: 20)),
            DataCell(
              ShimmerEffect(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            DataCell(ShimmerEffect(width: 120, height: 20)),
            DataCell(ShimmerEffect(width: 60, height: 20)),
            DataCell(ShimmerEffect(width: 80, height: 20)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      mobileItemBuilder: (context, index) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerEffect(
                width: double.infinity,
                height: 120,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ShimmerEffect(width: double.infinity, height: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 200, height: 14),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: AppSpacing.xs),
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

// Helper Classes
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
    this.imageFile,
    this.existingImageUrl,
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
  final dynamic imageFile;
  final String? existingImageUrl;
}

class _CategoryFormResult {
  _CategoryFormResult({
    required this.name,
    required this.active,
    this.imageFile,
    this.existingImageUrl,
  });

  final String name;
  final bool active;
  final dynamic imageFile;
  final String? existingImageUrl;
}

class _RecipeRowItem {
  String? ingredientId;
  double? quantity;
  _RecipeRowItem({this.ingredientId, this.quantity});
}

class _RecipeInlineRow extends StatelessWidget {
  const _RecipeInlineRow({
    super.key,
    required this.row,
    required this.ingredients,
    required this.onRemove,
  });

  final _RecipeRowItem row;
  final List<Ingredient> ingredients;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    ingredients.where((i) => i.id == row.ingredientId).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              value: row.ingredientId,
              decoration: InputDecoration(
                labelText: 'Ingredient',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              items: ingredients
                  .map(
                    (i) => DropdownMenuItem(
                      value: i.id,
                      child: Row(
                        children: [
                          if (i.isLowStock) ...[
                            const Icon(
                              Icons.warning,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Text(i.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => row.ingredientId = v,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Select ingredient' : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: row.quantity != null ? '${row.quantity}' : '',
              decoration: InputDecoration(
                labelText: 'Qty per Product',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => row.quantity = double.tryParse(v),
              validator: (v) {
                final x = double.tryParse(v ?? '');
                if (x == null || x <= 0) return 'Enter valid qty';
                return null;
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
