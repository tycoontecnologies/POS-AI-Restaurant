import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/purchase.dart';
import 'package:pos/models/supplier.dart';
import 'package:pos/models/product.dart';
import 'package:pos/providers/supplier_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/utils/app_spacing.dart';

class PurchaseFormDialog extends StatefulWidget {
  final Purchase? existingPurchase;
  final Function(Purchase) onSave;

  const PurchaseFormDialog({
    super.key,
    this.existingPurchase,
    required this.onSave,
  });

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierSearchController = TextEditingController();
  final _productSearchController = TextEditingController();

  Supplier? _selectedSupplier;
  List<PurchaseItem> _selectedItems = [];
  DateTime _selectedDate = DateTime.now();
  String _status = 'Pending';

  @override
  void initState() {
    super.initState();
    if (widget.existingPurchase != null) {
      _selectedSupplier = Supplier(
        id: widget.existingPurchase!.supplierId,
        name: widget.existingPurchase!.supplierName,
        phone: '',
        address: '',
        active: true,
        createdOn: DateTime.now(),
      );
      _selectedItems = List.from(widget.existingPurchase!.items);
      _selectedDate = widget.existingPurchase!.date;
      _status = widget.existingPurchase!.status;
    }
  }

  @override
  void dispose() {
    _supplierSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _addProductItem(Product product, int quantity) {
    final existingIndex = _selectedItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      setState(() {
        _selectedItems[existingIndex] = PurchaseItem(
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unitPrice: product.purchasePrice,
          total: product.purchasePrice * quantity,
        );
      });
    } else {
      setState(() {
        _selectedItems.add(
          PurchaseItem(
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            unitPrice: product.purchasePrice,
            total: product.purchasePrice * quantity,
          ),
        );
      });
    }
  }

  void _removeProductItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  double get _totalAmount {
    return _selectedItems.fold(0, (sum, item) => sum + item.total);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedSupplier != null) {
      final purchase = Purchase(
        id: widget.existingPurchase?.id ?? '',
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        items: _selectedItems,
        total: _totalAmount,
        date: _selectedDate,
        status: _status,
        createdOn: widget.existingPurchase?.createdOn ?? DateTime.now(),
      );

      widget.onSave(purchase);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.existingPurchase == null
                              ? 'New Purchase'
                              : 'Edit Purchase',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),

                  // Supplier Input
                  TextFormField(
                    controller: _supplierSearchController,
                    decoration: InputDecoration(
                      labelText: 'Supplier',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () =>
                            _showSupplierSearchDialog(supplierProvider),
                      ),
                    ),
                    readOnly: true,
                    onTap: () => _showSupplierSearchDialog(supplierProvider),
                    validator: (_) => _selectedSupplier == null
                        ? 'Please select a supplier'
                        : null,
                  ),

                  if (_selectedSupplier != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Selected: ${_selectedSupplier!.name}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Add Products Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Products'),
                    onPressed: () =>
                        _showProductSelectionDialog(productProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Product List
                  if (_selectedItems.isNotEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Products',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Divider(),
                            ..._selectedItems.asMap().entries.map(
                              (entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.value.productName),
                                subtitle: Text(
                                  'Qty: ${entry.value.quantity} × ${entry.value.unitPrice.toStringAsFixed(2)}',
                                ),
                                trailing: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpacing.sm,
                                  children: [
                                    Text(
                                      '${entry.value.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _removeProductItem(entry.key),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Total: ${_totalAmount.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Date Picker
                  Row(
                    children: [
                      const Text(
                        'Date:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              _selectedDate = selectedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${_selectedDate.toLocal()}'.split(' ').first,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: ['Pending', 'Completed', 'Cancelled']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value!;
                      });
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.check),
                        label: Text(
                          widget.existingPurchase == null ? 'Create' : 'Update',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSupplierSearchDialog(SupplierProvider supplierProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _supplierSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search suppliers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    supplierProvider.filterSuppliers(value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: supplierProvider.filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier =
                          supplierProvider.filteredSuppliers[index];
                      return ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(supplier.phone),
                        onTap: () {
                          setState(() {
                            _selectedSupplier = supplier;
                            _supplierSearchController.text = supplier.name;
                          });
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductSelectionDialog(ProductProvider productProvider) {
    final quantityControllers = <String, TextEditingController>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _productSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Search products',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        productProvider.setSearchQuery(value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: productProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = productProvider.products[index];
                          final controller = quantityControllers.putIfAbsent(
                            product.id,
                            () => TextEditingController(
                              text:
                                  _selectedItems
                                      .firstWhere(
                                        (item) => item.productId == product.id,
                                        orElse: () => PurchaseItem(
                                          productId: '',
                                          productName: '',
                                          quantity: 0,
                                          unitPrice: 0,
                                          total: 0,
                                        ),
                                      )
                                      .quantity
                                      .toString() ??
                                  '0',
                            ),
                          );

                          return ListTile(
                            title: Text(product.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Price: ${product.purchasePrice}'),
                                Text('Stock: ${product.quantity}'),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  final quantity = int.tryParse(value) ?? 0;
                                  if (quantity > 0) {
                                    _addProductItem(product, quantity);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Clean up controllers
      quantityControllers.forEach((_, controller) => controller.dispose());
    });
  }
}

void showPurchaseDialog(
  BuildContext context, {
  Purchase? purchase,
  required Function(Purchase) onSave,
}) {
  showDialog(
    context: context,
    builder: (context) =>
        PurchaseFormDialog(existingPurchase: purchase, onSave: onSave),
  );
}
