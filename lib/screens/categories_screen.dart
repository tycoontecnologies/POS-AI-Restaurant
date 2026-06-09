// categories_screen.dart
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../services/image_upload_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
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
  final ImageUploadService _imageUploadService = ImageUploadService();

  // Tutorial coach mark controller and targets
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _categoriesTableKey = GlobalKey();

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
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);
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
      await categoryProvider.loadMoreCategories();
    }
  }

  void _createOrEdit({Category? item}) async {
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
                      _buildImageUploadSection(
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
        // Create new category
        final newCategory = Category(
          id: '', // Will be auto-generated
          name: result.name,
          active: result.active,
          imageUrl: '', // Will be set after upload
        );

        // Upload image if selected
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

  Widget _buildImageUploadSection(
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

        // Image Preview
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

        // Error message
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

        // Upload buttons - show only when no image is selected
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
    // Show selected image preview
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () {
                  // Clear the selected image
                  onImageSelected(null, null, null);
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),
        ],
      );
    }
    // Show existing image from URL with CachedNetworkImage
    else if (existingImageUrl?.isNotEmpty == true) {
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () {
                  // Clear the existing image URL
                  onImageSelected(null, null, null);
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),
        ],
      );
    }
    // Show placeholder when no image is selected
    else {
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

        // Get image bytes for preview (for web)
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

  // Check if running on web
  bool _isWeb() {
    return identical(0, 0.0);
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
        // Delete image from storage if exists
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoryProvider = context.watch<CategoryProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                key: _addButtonKey,
                text: l10n.addCategory,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          SearchBarWidget(
            key: _searchBarKey,
            controller: _searchController,
            hint: 'Search categories...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            key: _categoriesTableKey,
            child: _buildContent(categoryProvider, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CategoryProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.categories.isEmpty) {
      return _buildShimmerTable();
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
                  // Image for mobile
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
                    'ID: ${item.id} • Created: ${item.createdOn.toIso8601String().substring(0, 10)}',
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

  Widget _buildShimmerTable() {
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
