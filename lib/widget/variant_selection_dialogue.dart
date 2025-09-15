import 'package:flutter/material.dart';
import 'package:pos/models/product.dart';
import 'package:pos/utils/app_spacing.dart';

class VariantSelectionDialog extends StatelessWidget {
  final Product product;
  final Function(ProductVariant, int) onVariantSelected;

  const VariantSelectionDialog({
    super.key,
    required this.product,
    required this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variants = product.activeVariants;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Variant for ${product.name}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              Expanded(
                child: variants.isEmpty
                    ? Center(
                        child: Text(
                          'No variants available',
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: variants.length,
                        itemBuilder: (context, index) {
                          final variant = variants[index];
                          return _buildVariantItem(context, variant);
                        },
                      ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantItem(BuildContext context, ProductVariant variant) {
    final theme = Theme.of(context);
    final quantityController = TextEditingController(text: '1');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Price: \$${variant.getPrice(product.purchasePrice).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    'Stock: ${variant.quantity}',
                    style: TextStyle(
                      color: variant.quantity > 0
                          ? theme.colorScheme.onSurface.withOpacity(0.7)
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxWidth: 80),
                ),
                onChanged: (value) {
                },
              ),
            ),
            
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
              onPressed: variant.quantity > 0
                  ? () {
                      final quantity = int.tryParse(quantityController.text) ?? 1;
                      if (quantity > 0 && quantity <= variant.quantity) {
                        onVariantSelected(variant, quantity);
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              quantity > variant.quantity
                                  ? 'Quantity exceeds available stock'
                                  : 'Please enter a valid quantity',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}