import 'package:flutter/material.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/utils/app_colors.dart';
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

//
class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierSearchController = TextEditingController();
  final _productSearchController = TextEditingController();

  Supplier? _selectedSupplier;
  List<PurchaseItem> _selectedItems = [];
  DateTime _selectedDate = DateTime.now();
  String _status = 'Pending';
  String? _productSelectionError;

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
    final isValid = _formKey.currentState?.validate() ?? false;

    setState(() {
      _productSelectionError = _selectedItems.isEmpty
          ? 'Please add at least one product'
          : null;
    });

    if (!isValid || _selectedItems.isEmpty) return;

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

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      elevation: 12,
      backgroundColor: colorScheme.background,
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Bar
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingPurchase == null
                          ? '🧾 New Purchase Order'
                          : '✏️ Edit Purchase Order',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 0.3,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    splashRadius: 20,
                    icon: Icon(Icons.close_rounded, color: colorScheme.outline),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(),

              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Supplier Selection Card
                        CustomCard(
                          color: colorScheme.surface,
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Supplier Information',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _supplierSearchController,
                                  decoration: InputDecoration(
                                    labelText: 'Select Supplier',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto,
                                    hintText: 'Search supplier...',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceVariant
                                        .withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.outline.withOpacity(
                                          0.2,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  readOnly: true,
                                  onTap: () => _showSupplierSearchDialog(
                                    supplierProvider,
                                  ),
                                  validator: (_) => _selectedSupplier == null
                                      ? 'Please select a supplier'
                                      : null,
                                ),
                                if (_selectedSupplier != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedSupplier!.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                                if (_selectedSupplier!
                                                    .phone
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4.0,
                                                        ),
                                                    child: Text(
                                                      _selectedSupplier!.phone,
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Products Section
                        CustomCard(
                          color: colorScheme.surface,
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Products',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    FilledButton.icon(
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                      ),
                                      label: const Text('Add Products'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        foregroundColor:
                                            colorScheme.onPrimaryContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showProductSelectionDialog(
                                            productProvider,
                                          ),
                                    ),
                                  ],
                                ),
                                if (_productSelectionError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      _productSelectionError!,
                                      style: TextStyle(
                                        color: colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.md),

                                // Selected Product List
                                if (_selectedItems.isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.outline.withOpacity(
                                          0.1,
                                        ),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          color: colorScheme.surfaceVariant
                                              .withOpacity(0.5),
                                          child: Row(
                                            children: const [
                                              Expanded(
                                                flex: 3,
                                                child: Text('Product'),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Qty',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Price',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Total',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                              ), // delete button
                                            ],
                                          ),
                                        ),
                                        // Product Items
                                        ..._selectedItems.asMap().entries.map(
                                          (entry) => Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: colorScheme.outline
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.md,
                                                    vertical: AppSpacing.sm,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      entry.value.productName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value.quantity
                                                          .toString(),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurface
                                                            .withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value.unitPrice
                                                          .toStringAsFixed(2),
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurface
                                                            .withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value.total
                                                          .toStringAsFixed(2),
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 40,
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                        color:
                                                            colorScheme.error,
                                                      ),
                                                      onPressed: () =>
                                                          _removeProductItem(
                                                            entry.key,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.md),

                                // Total Amount
                                if (_selectedItems.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withOpacity(
                                        0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Amount:',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          '\$${_totalAmount.toStringAsFixed(2)}',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Submit Buttons
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        widget.existingPurchase == null
                            ? 'Create Purchase'
                            : 'Update Purchase',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<SupplierProvider>(
                // <-- This is key
                builder: (context, supplierProvider, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        'Select Supplier',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),

                      // Search Field
                      TextField(
                        controller: _supplierSearchController,
                        onChanged: supplierProvider.filterSuppliers,
                        decoration: InputDecoration(
                          hintText: 'Search suppliers...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Supplier List
                      Flexible(
                        child: supplierProvider.filteredSuppliers.isEmpty
                            ? const Center(
                                child: Text(
                                  'No suppliers found.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount:
                                    supplierProvider.filteredSuppliers.length,
                                itemBuilder: (context, index) {
                                  final supplier =
                                      supplierProvider.filteredSuppliers[index];
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          _selectedSupplier = supplier;
                                          _supplierSearchController.text =
                                              supplier.name;
                                        });
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.business_rounded,
                                              size: 24,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  supplier.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  supplier.phone,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProductSelectionDialog(ProductProvider productProvider) {
    showDialog(
      context: context,
      builder: (context) => ProductSelectionDialog(
        selectedItems: _selectedItems,
        onProductAdded: _addProductItem,
        productProvider: productProvider,
      ),
    );
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

class ProductSelectionDialog extends StatefulWidget {
  final List<PurchaseItem> selectedItems;
  final Function(Product, int) onProductAdded;
  final ProductProvider productProvider;

  const ProductSelectionDialog({
    super.key,
    required this.selectedItems,
    required this.onProductAdded,
    required this.productProvider,
  });

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final Map<String, TextEditingController> _quantityControllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize controllers for already selected items
    for (final item in widget.selectedItems) {
      _quantityControllers[item.productId] = TextEditingController(
        text: item.quantity.toString(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter products based on search query AND exclude products with 0 stock
    final filteredProducts = widget.productProvider.products.where((product) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final hasStock = product.quantity > 0; // Exclude products with 0 stock
      return matchesSearch && hasStock;
    }).toList();

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Products',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Info message about stock validation
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You cannot order more than available stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Product List Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Product',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Price',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Stock',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Quantity',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Product List
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No products available with stock'
                                  : 'No products found for "$_searchQuery"',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final existingItem = widget.selectedItems.firstWhere(
                            (item) => item.productId == product.id,
                            orElse: () => PurchaseItem(
                              productId: '',
                              productName: '',
                              quantity: 0,
                              unitPrice: 0,
                              total: 0,
                            ),
                          );

                          final controller = _quantityControllers.putIfAbsent(
                            product.id,
                            () => TextEditingController(
                              text: existingItem.quantity.toString(),
                            ),
                          );

                          // Validate if quantity exceeds stock
                          final currentQuantity =
                              int.tryParse(controller.text) ?? 0;
                          final exceedsStock =
                              currentQuantity > product.quantity;

                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: exceedsStock
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '\$${product.purchasePrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      product.quantity.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: product.quantity > 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: controller,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            constraints: const BoxConstraints(
                                              maxWidth: 80,
                                            ),
                                            errorText: exceedsStock
                                                ? 'Exceeds stock'
                                                : null,
                                            errorStyle: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            final quantity =
                                                int.tryParse(value) ?? 0;
                                            setState(
                                              () {},
                                            ); // Rebuild to show validation

                                            if (quantity > 0 &&
                                                quantity <= product.quantity) {
                                              widget.onProductAdded(
                                                product,
                                                quantity,
                                              );
                                            }
                                          },
                                        ),
                                        if (exceedsStock)
                                          Text(
                                            'Max: ${product.quantity}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: () {
                      // Check if any quantity exceeds stock before closing
                      bool hasInvalidQuantities = false;

                      for (final product in filteredProducts) {
                        final controller = _quantityControllers[product.id];
                        if (controller != null) {
                          final quantity = int.tryParse(controller.text) ?? 0;
                          if (quantity > product.quantity) {
                            hasInvalidQuantities = true;
                            break;
                          }
                        }
                      }

                      if (hasInvalidQuantities) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Some quantities exceed available stock',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    child: const Text('Add Selected'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
