import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import 'custom_button.dart';

class SimpleVariantSelector extends StatefulWidget {
  final Product product;
  final Function(ProductVariant variant, int quantity) onAddToCart;

  const SimpleVariantSelector({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<SimpleVariantSelector> createState() => _SimpleVariantSelectorState();
}

class _SimpleVariantSelectorState extends State<SimpleVariantSelector> {
  ProductVariant? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    final activeVariants = widget.product.activeVariants;
    if (activeVariants.isNotEmpty) {
      _selectedVariant = activeVariants.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeVariants = widget.product.activeVariants;

    if (activeVariants.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: const Text('No Variants Available'),
        content: const Text('This product has no available variants.'),
        actions: [
          CustomButton(
            text: 'Close',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFFFDFDFE),
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.product.name,
        style: AppTypography.h6.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.grey800,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Size',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              ...List.generate(activeVariants.length, (index) {
                final variant = activeVariants[index];
                final isSelected = _selectedVariant?.id == variant.id;
                final price = variant.getPrice(widget.product.salePrice);

                return GestureDetector(
                  onTap: () => setState(() => _selectedVariant = variant),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.grey300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.grey400,
                              width: 2,
                            ),
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    variant.name,
                                    style: AppTypography.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.grey800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    price.toStringAsFixed(0),
                                    style: AppTypography.h6.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.grey800,
                                    ),
                                  ),
                                ],
                              ),
                              if (variant.priceModifier != 0) ...[
                                const SizedBox(height: AppSpacing.xs),
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
                                  child: Text(
                                    '${variant.priceModifier >= 0 ? '+' : ''}${variant.priceModifier.toStringAsFixed(0)} vs base',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: variant.priceModifier >= 0
                                          ? AppColors.success
                                          : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              if (_selectedVariant != null) ...[
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Text(
                      'Quantity',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey800,
                      ),
                    ),
                    const Spacer(),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.grey300),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                            ),
                          ),
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Text(
                              _quantity.toString(),
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _quantity < _selectedVariant!.quantity
                                ? () => setState(() => _quantity++)
                                : null,
                            icon: const Icon(Icons.add, size: 18),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedVariant!.name} × $_quantity',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.grey700,
                            ),
                          ),
                          Text(
                            '${_selectedVariant!.getPrice(widget.product.salePrice).toStringAsFixed(0)} each',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            (_selectedVariant!.getPrice(widget.product.salePrice) * _quantity).toStringAsFixed(0),
                            style: AppTypography.h6.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CustomButton(
          text: 'Cancel',
          variant: ButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          text: 'Add to Cart',
          onPressed: _selectedVariant != null && _quantity > 0
              ? () {
                  widget.onAddToCart(_selectedVariant!, _quantity);
                  Navigator.pop(context);
                }
              : null,
        ),
      ],
    );
  }
}
