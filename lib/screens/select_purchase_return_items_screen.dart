import 'package:flutter/material.dart';
import 'package:pos/models/purchase.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class SelectPurchaseReturnItemsScreen extends StatefulWidget {
  final Purchase purchase;

  const SelectPurchaseReturnItemsScreen({
    super.key,
    required this.purchase,
  });

  @override
  State<SelectPurchaseReturnItemsScreen> createState() =>
      _SelectPurchaseReturnItemsScreenState();
}

class _SelectPurchaseReturnItemsScreenState
    extends State<SelectPurchaseReturnItemsScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final Map<String, bool> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    // Initialize all items as selected by default
    for (var item in widget.purchase.items) {
      _selectedItems[item.productId] = true;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _toggleItemSelection(String productId) {
    setState(() {
      _selectedItems[productId] = !(_selectedItems[productId] ?? false);
    });
  }

  void _submitReturn() {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for the return'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedProductIds = _selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'selectedProductIds': selectedProductIds,
      'reason': _reasonController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Items to Return'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitReturn,
            tooltip: 'Confirm Return',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Purchase Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase #${widget.purchase.id}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Supplier: ${widget.purchase.supplierName}'),
                    Text('Date: ${widget.purchase.date.toLocal().toString().split(' ').first}'),
                    Text('Total: \$${widget.purchase.total.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Items List
            Expanded(
              child: ListView.builder(
                itemCount: widget.purchase.items.length,
                itemBuilder: (context, index) {
                  final item = widget.purchase.items[index];
                  final isSelected = _selectedItems[item.productId] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleItemSelection(item.productId),
                      ),
                      title: Text(item.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Qty: ${item.quantity}'),
                          Text('Price: \$${item.unitPrice.toStringAsFixed(2)}'),
                          Text('Total: \$${item.total.toStringAsFixed(2)}'),
                        ],
                      ),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppColors.success : AppColors.grey400,
                      ),
                      onTap: () => _toggleItemSelection(item.productId),
                    ),
                  );
                },
              ),
            ),

            // Reason Input
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Return',
                border: OutlineInputBorder(),
                hintText: 'Enter the reason for returning these items...',
              ),
              maxLines: 3,
            ),

            // Submit Button
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _submitReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: const Text('Process Return'),
            ),
          ],
        ),
      ),
    );
  }
}