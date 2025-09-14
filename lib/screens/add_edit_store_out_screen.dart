import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/store_out.dart';
import 'package:pos/models/product.dart';
import 'package:pos/providers/store_out_provider.dart';
import 'package:pos/services/store_out_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../utils/app_spacing.dart';

class AddEditStoreOutScreen extends StatefulWidget {
  final StoreOut? storeOut;

  const AddEditStoreOutScreen({super.key, this.storeOut});

  @override
  State<AddEditStoreOutScreen> createState() => _AddEditStoreOutScreenState();
}

class _AddEditStoreOutScreenState extends State<AddEditStoreOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _handledByController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<ProductQuantity> _selectedProducts = [];
  List<Product> _availableProducts = [];
  final StoreOutService _storeOutService = StoreOutService();

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadProducts();
  }

  void _initializeForm() {
    if (widget.storeOut != null) {
      _reasonController.text = widget.storeOut!.reason;
      _handledByController.text = widget.storeOut!.handledBy;
      _selectedDate = widget.storeOut!.date;
      _selectedProducts = widget.storeOut!.products;
    } else {
      // Set current user as default handler
      final currentUser = AuthProvider().currentUser;
      if (currentUser != null) {
        _handledByController.text = currentUser.email;
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      final vendorId = currentUser?.id;

      if (vendorId != null) {
        _availableProducts = await _storeOutService.getVendorProducts(vendorId);
        setState(() {});
      }
    } catch (e) {
      log('Error loading products: $e'); // Debug log
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        products: _availableProducts,
        onAdd: (product, quantity) {
          setState(() {
            // Check if product already exists in selection
            final index = _selectedProducts.indexWhere(
              (p) => p.product.id == product.id,
            );
            if (index >= 0) {
              // Update quantity if product already selected
              _selectedProducts[index] = ProductQuantity(
                product: product,
                quantity: _selectedProducts[index].quantity + quantity,
              );
            } else {
              // Add new product
              _selectedProducts.add(
                ProductQuantity(product: product, quantity: quantity),
              );
            }
          });
        },
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  void _updateProductQuantity(int index, int quantity) {
    setState(() {
      _selectedProducts[index] = ProductQuantity(
        product: _selectedProducts[index].product,
        quantity: quantity,
      );
    });
  }

  Future<void> _saveStoreOut() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    setState(() {
    });

    try {
      final provider = context.read<StoreOutProvider>();
      final storeOut = StoreOut(
        id: widget.storeOut?.id ?? '',
        vendorId: '', // Will be set by the service
        reason: _reasonController.text,
        products: _selectedProducts,
        date: _selectedDate,
        handledBy: _handledByController.text,
      );

      if (widget.storeOut != null) {
        await provider.updateStoreOut(storeOut);
      } else {
        await provider.createStoreOut(storeOut);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving store-out: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.storeOut != null ? 'Edit Store Out' : 'Record Store Out',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CustomCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _reasonController,
                              decoration: InputDecoration(
                                labelText: 'Reason',
                                hintText: 'Enter reason for outgoing items',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a reason';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _handledByController,
                              decoration: InputDecoration(
                                labelText: 'Handled By',
                                hintText: 'Enter handler name',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter handler name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Date',
                                    hintText: 'Select date',
                                    suffixIcon: const Icon(
                                      Icons.calendar_today,
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: '${_selectedDate.toLocal()}'
                                        .split(' ')
                                        .first,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a date';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Products',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                CustomButton(
                                  text: 'Add Product',
                                  icon: Icons.add,
                                  onPressed: _addProduct,
                                  size: ButtonSize.small,
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.md),

                            if (_selectedProducts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                                child: Text(
                                  'No products added',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5),
                                      ),
                                ),
                              ),

                            ..._selectedProducts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return ProductItemRow(
                                product: item.product,
                                quantity: item.quantity,
                                onQuantityChanged: (quantity) =>
                                    _updateProductQuantity(index, quantity),
                                onRemove: () => _removeProduct(index),
                              );
                            }),

                            if (_selectedProducts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Items:',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    Text(
                                      '${_selectedProducts.fold(0, (sum, item) => sum + item.quantity)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
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
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      variant: ButtonVariant.outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: CustomButton(
                      text: widget.storeOut != null ? 'Update' : 'Save',
                      onPressed: _saveStoreOut,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _handledByController.dispose();
    super.dispose();
  }
}

class AddProductDialog extends StatefulWidget {
  final List<Product> products;
  final Function(Product, int) onAdd;

  const AddProductDialog({
    super.key,
    required this.products,
    required this.onAdd,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  Product? _selectedProduct;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      _selectedProduct = widget.products.first;
      // Optional: cap the quantity to available stock
      if (_quantity > _selectedProduct!.quantity) {
        _quantity = _selectedProduct!.quantity;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Product>(
            value: _selectedProduct,
            decoration: InputDecoration(
              labelText: 'Product',
              border: OutlineInputBorder(),
            ),
            items: widget.products.map((product) {
              return DropdownMenuItem<Product>(
                value: product,
                child: Text('${product.name} (${product.quantity} available)'),
              );
            }).toList(),
            onChanged: (product) {
              setState(() {
                _selectedProduct = product;
                if (_selectedProduct != null &&
                    _quantity > _selectedProduct!.quantity) {
                  _quantity = _selectedProduct!.quantity;
                }
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a product';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.md),

          if (_selectedProduct != null)
            Row(
              children: [
                Expanded(
                  child: Text('Quantity (Max: ${_selectedProduct!.quantity})'),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: _quantity.toString(),
                    ), // Add controller
                    onChanged: (value) {
                      final qty = int.tryParse(value) ?? 1;
                      if (qty > 0 && qty <= (_selectedProduct?.quantity ?? 1)) {
                        setState(() => _quantity = qty);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_quantity < (_selectedProduct?.quantity ?? 1)) {
                      setState(() => _quantity++);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedProduct == null
              ? null
              : () {
                  widget.onAdd(_selectedProduct!, _quantity);
                  Navigator.pop(context);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class ProductItemRow extends StatefulWidget {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;
  final Function onRemove;

  const ProductItemRow({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<ProductItemRow> createState() => _ProductItemRowState();
}

class _ProductItemRowState extends State<ProductItemRow> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.product.salePrice} × $_quantity = ${widget.product.salePrice * _quantity}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () {
                  if (_quantity > 1) {
                    setState(() => _quantity--);
                    widget.onQuantityChanged(_quantity);
                  }
                },
              ),
              SizedBox(
                width: 40,
                child: TextFormField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _quantity.toString()),
                  onChanged: (value) {
                    final qty = int.tryParse(value) ?? 1;
                    if (qty > 0 && qty <= widget.product.quantity) {
                      setState(() => _quantity = qty);
                      widget.onQuantityChanged(_quantity);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () {
                  if (_quantity < widget.product.quantity) {
                    setState(() => _quantity++);
                    widget.onQuantityChanged(_quantity);
                  }
                },
              ),

              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: () => widget.onRemove(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
