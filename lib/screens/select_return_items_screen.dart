// select_return_items_screen.dart
import 'package:flutter/material.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class SelectReturnItemsScreen extends StatefulWidget {
  final Sale sale;

  const SelectReturnItemsScreen({super.key, required this.sale});

  @override
  State<SelectReturnItemsScreen> createState() =>
      _SelectReturnItemsScreenState();
}

class _SelectReturnItemsScreenState extends State<SelectReturnItemsScreen> {
  final Map<String, bool> _selectedItems = {};
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize all items as not selected
    for (var item in widget.sale.items) {
      _selectedItems[item.productId] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Items to Return')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sale Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${widget.sale.id.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Total: ${widget.sale.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Date: ${_formatDate(widget.sale.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Items List
            Expanded(
              child: ListView.builder(
                itemCount: widget.sale.items.length,
                itemBuilder: (context, index) {
                  final item = widget.sale.items[index];
                  return CheckboxListTile(
                    title: Text(item.productName),
                    subtitle: Text(
                      'Price: ${item.price.toStringAsFixed(2)} • Qty: ${item.quantity} • Subtotal: ${(item.price * item.quantity).toStringAsFixed(2)}',
                    ),
                    value: _selectedItems[item.productId] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedItems[item.productId] = value ?? false;
                      });
                    },
                  );
                },
              ),
            ),

            // Reason Field
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for return',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.grey300,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Process Return',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _submitReturn() {
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

    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for the return'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Return selected items to the previous screen
    Navigator.pop(context, {
      'selectedProductIds': selectedProductIds,
      'reason': _reasonController.text,
    });
  }
}
