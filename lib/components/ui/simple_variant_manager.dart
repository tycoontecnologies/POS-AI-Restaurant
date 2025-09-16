import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import 'custom_button.dart';
import 'custom_card.dart';
import 'custom_input.dart';

class SimpleVariantManager extends StatefulWidget {
  final List<ProductVariant> variants;
  final Function(List<ProductVariant>) onVariantsChanged;
  final double basePrice;

  const SimpleVariantManager({
    super.key,
    required this.variants,
    required this.basePrice,
    required this.onVariantsChanged,
  });

  @override
  State<SimpleVariantManager> createState() => _SimpleVariantManagerState();
}

class _SimpleVariantManagerState extends State<SimpleVariantManager> {
  late List<ProductVariant> _variants;

  @override
  void initState() {
    super.initState();
    _variants = List.from(widget.variants);
  }


  void _showCustomVariantDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomVariantDialog(
        onSave: (variant) {
          setState(() {
            _variants.add(variant);
          });
          widget.onVariantsChanged(_variants);
        },
        basePrice: widget.basePrice,
      ),
    );
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
    widget.onVariantsChanged(_variants);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Product Variants',
              style: AppTypography.h6.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.grey800,
              ),
            ),
            const Spacer(),
            CustomButton(
              text: 'Add Variant',
              size: ButtonSize.small,
              variant: ButtonVariant.outlined,
              onPressed: _showCustomVariantDialog,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        if (_variants.isEmpty)
          CustomCard(
            color: AppColors.backgroundLight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: AppColors.grey400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No variants added yet',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Use quick add or create custom variants',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_variants.length, (index) {
            final variant = _variants[index];
            return CustomCard(
              color: AppColors.backgroundLight,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: variant.active
                          ? AppColors.success
                          : AppColors.grey400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant.name,
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Stock: ${variant.quantity}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: variant.priceModifier >= 0
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusXs,
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (widget.basePrice + variant.priceModifier).toStringAsFixed(0),
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.grey800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${variant.priceModifier >= 0 ? '+' : ''}${variant.priceModifier.toStringAsFixed(0)} modifier',
                                style: AppTypography.labelSmall.copyWith(
                                  color: variant.priceModifier >= 0
                                      ? AppColors.success
                                      : AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => _removeVariant(index),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _CustomVariantDialog extends StatefulWidget {
  final Function(ProductVariant) onSave;
  final double basePrice; // Add this

  const _CustomVariantDialog({required this.onSave, required this.basePrice});

  @override
  State<_CustomVariantDialog> createState() => _CustomVariantDialogState();
}

class _CustomVariantDialogState extends State<_CustomVariantDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '0.0');
  final _stockController = TextEditingController(text: '100');

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFDFDFE),
      surfaceTintColor: Colors.transparent,
      title: const Text('Add Custom Variant'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Base Price: ${widget.basePrice.toStringAsFixed(0)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.grey600),
            ),

            const SizedBox(height: AppSpacing.sm),
            CustomInput(
              label: 'Variant Name',
              controller: _nameController,
              hint: 'e.g., Spicy Large, Mild Medium',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: CustomInput(
                    label: 'Price Modifier',
                    controller: _priceController,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CustomInput(
                    label: 'Stock',
                    controller: _stockController,
                    hint: '100',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.inventory, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        CustomButton(
          text: 'Cancel',
          variant: ButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          text: 'Add Variant',
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              final priceModifier =
                  double.tryParse(_priceController.text) ?? 0.0;
              final finalPrice = widget.basePrice + priceModifier;

              if (finalPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: Duration(seconds: 1),
                    content: Text('Variant price cannot be zero or negative'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final variant = ProductVariant(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text.trim(),
                priceModifier: priceModifier,
                quantity: int.tryParse(_stockController.text) ?? 100,
              );
              widget.onSave(variant);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
