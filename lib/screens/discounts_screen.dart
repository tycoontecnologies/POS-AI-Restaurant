import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/discount.dart';
import '../providers/discount_provider.dart';
import '../providers/auth_provider.dart';
import '../services/image_upload_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/custom_card.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<Discount>>? _discountsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _discountsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final discountProvider = Provider.of<DiscountProvider>(
      context,
      listen: false,
    );
    final vendorId = authProvider.currentUser!.id;

    if (vendorId.isNotEmpty) {
      discountProvider.loadDiscounts(vendorId);
      _discountsSubscription = discountProvider
          .getDiscountsStream(vendorId)
          .listen((discounts) {
            discountProvider.loadDiscounts(vendorId);
          });
    }
  }

  // Calculate number of columns based on screen width
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 4; // Large desktop
    } else if (screenWidth > 900) {
      return 3; // Small desktop / tablet landscape
    } else if (screenWidth > 600) {
      return 2; // Tablet portrait
    } else {
      return 1; // Mobile
    }
  }

  // Calculate card width based on screen size
  double _getCardAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 0.85; // Wider cards for desktop
    } else if (screenWidth > 900) {
      return 0.9;
    } else if (screenWidth > 600) {
      return 1.0; // Square-ish for tablet
    } else {
      return 1.1; // Taller for mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final discountProvider = Provider.of<DiscountProvider>(context);
    final vendorId = authProvider.currentUser!.id;

    if (vendorId.isEmpty) {
      return const Center(
        child: Text(
          'No vendor account found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discount Management',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Create and manage promotional offers for your products',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  CustomButton(
                    text: 'Add Discount',
                    onPressed: () => _showDiscountDialog(context, vendorId),
                    icon: Icons.add,
                    size: ButtonSize.large,
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: CustomInput(
                    hint: 'Search discounts...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.filter_list, size: 20),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent(discountProvider, vendorId)),
        ],
      ),
    );
  }

  Widget _buildContent(DiscountProvider provider, String vendorId) {
    if (provider.isLoading && provider.discounts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text(
              'Loading your discounts...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (provider.error != null && provider.discounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unable to load discounts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Try Again',
                onPressed: () => provider.loadDiscounts(vendorId),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = provider.discounts
        .where(
          (d) =>
              d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              d.description.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(context);
        final aspectRatio = _getCardAspectRatio(context);

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: aspectRatio,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final discount = filtered[index];
            return _buildDiscountCard(context, vendorId, discount);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_outlined,
                size: 48,
                color: AppColors.grey400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _searchQuery.isEmpty ? 'No discounts yet' : 'No discounts found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _searchQuery.isEmpty
                  ? 'Get started by creating your first promotional offer'
                  : 'No results matching "$_searchQuery"',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Clear Search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                variant: ButtonVariant.outlined,
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Create First Discount',
                onPressed: () =>
                    _showDiscountDialog(context, authProvider.currentUser!.id),
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountCard(
    BuildContext context,
    String vendorId,
    Discount discount,
  ) {
    return CustomCard(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Discount Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.radiusMd),
                  topRight: Radius.circular(AppSpacing.radiusMd),
                ),
                image: discount.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(discount.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: discount.imageUrl.isEmpty ? AppColors.grey100 : null,
              ),
              child: discount.imageUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.local_offer_outlined,
                        size: 40,
                        color: AppColors.grey400,
                      ),
                    )
                  : Stack(
                      children: [
                        // Gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                        // Discount badge
                        Positioned(
                          top: AppSpacing.sm,
                          left: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              discount.type == 'percentage'
                                  ? '${discount.value.toStringAsFixed(0)}% OFF'
                                  : '\$${discount.value.toStringAsFixed(0)} OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Discount Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              discount.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: discount.isActive
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.grey300,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: discount.isActive
                                    ? AppColors.success
                                    : AppColors.grey400,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              discount.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: discount.isActive
                                    ? AppColors.success
                                    : AppColors.grey600,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discount.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _showDiscountDialog(
                              context,
                              vendorId,
                              discount,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              side: BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                            ),
                            child: Text(
                              'Edit',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _showDeleteConfirmation(
                              context,
                              vendorId,
                              discount.id,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              backgroundColor: AppColors.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                            ),
                            child: Text(
                              'Delete',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(
    BuildContext context,
    String vendorId, [
    Discount? discount,
  ]) {
    showDialog(
      context: context,
      builder: (context) =>
          _DiscountDialog(discount: discount, vendorId: vendorId),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String vendorId,
    String discountId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discount'),
        content: const Text(
          'Are you sure you want to delete this discount? This action cannot be undone.',
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            variant: ButtonVariant.outlined,
          ),
          CustomButton(
            text: 'Delete',
            onPressed: () {
              final provider = Provider.of<DiscountProvider>(
                context,
                listen: false,
              );
              provider.deleteDiscount(vendorId, discountId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Discount deleted successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  final Discount? discount;
  final String vendorId;

  const _DiscountDialog({required this.discount, required this.vendorId});

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _valueController;
  late String _selectedType;
  late bool _isActive;
  String? _imageUrl;
  dynamic _pickedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.discount?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.discount?.description ?? '',
    );
    _valueController = TextEditingController(
      text: widget.discount?.value.toString() ?? '',
    );
    _selectedType = widget.discount?.type ?? 'percentage';
    _isActive = widget.discount?.isActive ?? true;
    _imageUrl = widget.discount?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final imageUploadService = ImageUploadService();
      final image = await imageUploadService.pickImage(fromGallery: true);

      if (image != null) {
        setState(() {
          _pickedImage = image;
          _imageUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final imageUploadService = ImageUploadService();
      final discountId =
          widget.discount?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final uploadedUrl = await imageUploadService.uploadDiscountImage(
        imageFile: _pickedImage!,
        vendorId: widget.vendorId,
        discountId: discountId,
      );

      setState(() {
        _imageUrl = uploadedUrl;
        _pickedImage = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _imageUrl = null;
      _pickedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.discount == null
                          ? 'Create New Discount'
                          : 'Edit Discount',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Section
                      _buildImageSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // Form Fields
                      CustomInput(
                        label: 'Discount Name',
                        hint: 'Enter discount name',
                        controller: _nameController,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      CustomInput(
                        label: 'Description',
                        hint: 'Describe this discount offer',
                        controller: _descriptionController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 400) {
                            // Horizontal layout for wider screens
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Discount Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: _selectedType,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'percentage',
                                        child: Text('Percentage (%)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'fixed',
                                        child: Text('Fixed Amount (\$)'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedType = value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: CustomInput(
                                    label: 'Discount Value',
                                    hint: _selectedType == 'percentage'
                                        ? '0-100'
                                        : '0.00',
                                    controller: _valueController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Vertical layout for narrow screens
                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Discount Type',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _selectedType,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'percentage',
                                      child: Text('Percentage (%)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'fixed',
                                      child: Text('Fixed Amount (\$)'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedType = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                CustomInput(
                                  label: 'Discount Value',
                                  hint: _selectedType == 'percentage'
                                      ? '0-100'
                                      : '0.00',
                                  controller: _valueController,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Active Switch
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.grey50,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Row(
                          children: [
                            Switch(
                              value: _isActive,
                              onChanged: (value) {
                                setState(() => _isActive = value);
                              },
                              activeColor: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Discount',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'Discount will be available to customers',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.grey600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 400) {
                    return Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Cancel',
                            onPressed: () => Navigator.pop(context),
                            variant: ButtonVariant.outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomButton(
                            text: widget.discount == null
                                ? 'Create Discount'
                                : 'Save Changes',
                            onPressed: _saveDiscount,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        CustomButton(
                          text: widget.discount == null
                              ? 'Create Discount'
                              : 'Save Changes',
                          onPressed: _saveDiscount,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CustomButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.pop(context),
                          variant: ButtonVariant.outlined,
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discount Image (Optional)',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.sm),

        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey300, width: 1.5),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            color: AppColors.grey50,
          ),
          child: _buildImageContent(),
        ),

        const SizedBox(height: AppSpacing.sm),

        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            CustomButton(
              text: 'Choose Image',
              onPressed: _pickImage,
              variant: ButtonVariant.outlined,
              icon: Icons.image,
              size: ButtonSize.small,
            ),
            if (_pickedImage != null) ...[
              CustomButton(
                text: _isUploading ? 'Uploading...' : 'Upload Image',
                onPressed: _isUploading ? null : _uploadImage,
                icon: _isUploading ? null : Icons.cloud_upload,
                size: ButtonSize.small,
              ),
            ],
            if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: _removeImage,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Image.network(
          _imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } else if (_pickedImage != null) {
      return _buildImagePreview();
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: AppColors.grey400,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add discount image',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: _isWeb()
          ? FutureBuilder<Uint8List?>(
              future: ImageUploadService().getFileBytes(_pickedImage),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                }
                return Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              },
            )
          : Image.file(
              _pickedImage as File,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
    );
  }

  bool _isWeb() {
    return identical(0, 0.0);
  }

  void _saveDiscount() {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final discount = Discount(
      id:
          widget.discount?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      description: _descriptionController.text,
      type: _selectedType,
      value: double.parse(_valueController.text),
      imageUrl: _imageUrl ?? '',
      isActive: _isActive,
      vendorId: widget.vendorId,
      createdAt: widget.discount?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final provider = Provider.of<DiscountProvider>(context, listen: false);

    if (widget.discount == null) {
      provider.addDiscount(discount);
    } else {
      provider.updateDiscount(discount);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.discount == null
              ? 'Discount created successfully'
              : 'Discount updated successfully',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
