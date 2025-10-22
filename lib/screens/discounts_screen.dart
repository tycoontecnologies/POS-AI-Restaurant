import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/discount.dart';
import '../providers/discount_provider.dart';
import '../providers/auth_provider.dart';
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
      // Load initial data
      discountProvider.loadDiscounts(vendorId);

      // Listen to stream for real-time updates
      _discountsSubscription = discountProvider
          .getDiscountsStream(vendorId)
          .listen((discounts) {
            discountProvider.loadDiscounts(
              vendorId,
            ); // Reload when stream updates
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final discountProvider = Provider.of<DiscountProvider>(context);
    final vendorId = authProvider.currentUser!.id;

    if (vendorId.isEmpty) {
      return const Center(child: Text('No vendor found'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Discounts & Offers'), elevation: 0),
      body: _buildContent(discountProvider, vendorId),
    );
  }

  Widget _buildContent(DiscountProvider provider, String vendorId) {
    if (provider.isLoading && provider.discounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.discounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error: ${provider.error}'),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Retry',
              onPressed: () => provider.loadDiscounts(vendorId),
            ),
          ],
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: CustomInput(
                  hint: 'Search discounts...',
                  prefixIcon: const Icon(Icons.search),
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              CustomButton(
                text: 'Add Discount',
                onPressed: () => _showDiscountDialog(context, vendorId),
                icon: Icons.add,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 64,
                        color: AppColors.grey300,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No discounts found',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No results for "$_searchQuery"',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomButton(
                          text: 'Clear Search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          variant: ButtonVariant.outlined,
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final discount = filtered[index];
                    return _buildDiscountCard(context, vendorId, discount);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDiscountCard(
    BuildContext context,
    String vendorId,
    Discount discount,
  ) {
    final isValid = discount.isValidNow();

    return CustomCard(
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            discount.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isValid
                                ? AppColors.success
                                : AppColors.error,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                          ),
                          child: Text(
                            isValid ? 'Active' : 'Inactive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      discount.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    discount.type == 'percentage'
                        ? '${discount.value.toStringAsFixed(1)}%'
                        : '\$${discount.value.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    discount.type == 'percentage'
                        ? 'Percentage'
                        : 'Fixed Amount',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valid Period',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(discount.startDate)} - ${discount.endDate != null ? DateFormat('MMM dd, yyyy').format(discount.endDate!) : 'No end date'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomButton(
                text: 'Edit',
                onPressed: () =>
                    _showDiscountDialog(context, vendorId, discount),
                variant: ButtonVariant.outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              CustomButton(
                text: 'Delete',
                onPressed: () =>
                    _showDeleteConfirmation(context, vendorId, discount.id),
                color: AppColors.error,
              ),
            ],
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
        content: const Text('Are you sure you want to delete this discount?'),
        actions: [
          CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            variant: ButtonVariant.text,
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
                const SnackBar(content: Text('Discount deleted successfully')),
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
  late TextEditingController _maxUsageController;
  late String _selectedType;
  late DateTime _startDate;
  late DateTime? _endDate;
  late bool _isActive;

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
    _maxUsageController = TextEditingController(
      text: widget.discount?.maxUsageCount == -1
          ? ''
          : widget.discount?.maxUsageCount.toString() ?? '',
    );
    _selectedType = widget.discount?.type ?? 'percentage';
    _startDate = widget.discount?.startDate ?? DateTime.now();
    _endDate = widget.discount?.endDate;
    _isActive = widget.discount?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _maxUsageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.discount == null ? 'Add New Discount' : 'Edit Discount',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomInput(
                label: 'Discount Name',
                hint: 'e.g., Summer Sale, Black Friday',
                controller: _nameController,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInput(
                label: 'Description',
                hint: 'e.g., 20% off on all items',
                controller: _descriptionController,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
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
                      label: 'Value',
                      hint: _selectedType == 'percentage' ? '0-100' : '0.00',
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.grey700,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey300),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(_startDate),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date (Optional)',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.grey700,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey300),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                  : 'No end date',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value ?? true);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Active', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    variant: ButtonVariant.text,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  CustomButton(
                    text: widget.discount == null
                        ? 'Add Discount'
                        : 'Update Discount',
                    onPressed: _saveDiscount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _saveDiscount() {
    if (_nameController.text.isEmpty || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
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
      applicableProductIds: [],
      applicableCategoryIds: [],
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      maxUsageCount: _maxUsageController.text.isEmpty
          ? -1
          : int.parse(_maxUsageController.text),
      currentUsageCount: widget.discount?.currentUsageCount ?? 0,
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
              ? 'Discount added successfully'
              : 'Discount updated successfully',
        ),
      ),
    );
  }
}
