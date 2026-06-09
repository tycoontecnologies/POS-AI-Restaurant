import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/product_card.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/components/ui/simple_variant_selector.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/services/pdf_service.dart';
import 'package:pos/services/sale_service.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/search_bar_widget.dart';

class TableOrderScreen extends StatefulWidget {
  final RestaurantTable table;

  const TableOrderScreen({super.key, required this.table});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  late ProductProvider _productProvider;
  late CategoryProvider _categoryProvider;
  late TableOrderProvider _tableOrderProvider;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  Map<String, List<Product>> _categorizedProducts = {};
  final SaleService _saleService = SaleService();
  bool _isProcessing = false;

  int? _hoveredCardIndex;
  bool _isHoveredIndex(int index) => _hoveredCardIndex == index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _productProvider = Provider.of<ProductProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context);
    _tableOrderProvider = Provider.of<TableOrderProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vendorId = _categoryProvider.authProvider?.currentUser?.id;

      if (vendorId != null &&
          _productProvider.products.isEmpty &&
          !_productProvider.isLoading) {
        _productProvider.loadProducts(vendorId);
      }

      _tableOrderProvider.loadTableOrder(widget.table.id);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateTableStatusBasedOnCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );
    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    final tableOrderItems = tableOrderProvider.getOrderForTable(
      widget.table.id,
    );

    final cartItems = cartProvider.cartItems
        .where((item) => cartProvider.selectedTable?.id == widget.table.id)
        .toList();

    final allItems = [...tableOrderItems, ...cartItems];
    final hasItems = allItems.isNotEmpty;

    final currentStatus = widget.table.status;

    // Only update to occupied if not already served or cleared
    if (hasItems &&
        currentStatus != TableStatus.occupied &&
        currentStatus != TableStatus.served &&
        currentStatus != TableStatus.cleared) {
      tableProvider.updateTableStatus(widget.table.id, TableStatus.occupied);
    }
    // Only update to empty if no items and not served/cleared
    else if (!hasItems &&
        currentStatus != TableStatus.served &&
        currentStatus != TableStatus.cleared) {
      tableProvider.updateTableStatus(widget.table.id, TableStatus.empty);
    }
  }

  Future<void> _printBill(Sale sale) async {
    final authProvider = _categoryProvider.authProvider;
    final user = authProvider?.currentUser;

    // Use the reusable PDF service
    final pdf = await PdfService.createBillReceipt(sale: sale, user: user);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Add KOT printing method for TableOrderScreen
  Future<void> _printKOT() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );
    final authProvider = _categoryProvider.authProvider;
    final user = authProvider?.currentUser;

    // Get all items for this table
    final tableOrderItems = tableOrderProvider.getOrderForTable(
      widget.table.id,
    );
    final cartItems = cartProvider.cartItems
        .where((item) => cartProvider.selectedTable?.id == widget.table.id)
        .toList();

    final allItems = [...tableOrderItems, ...cartItems];

    if (allItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items to print KOT')));
      return;
    }

    final pdf = await PdfService.createKOT(
      items: allItems,
      table: widget.table,
      user: user,
      orderType: 'Table Order',
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _checkout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );
    Provider.of<ProductProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final authProvider = _categoryProvider.authProvider;

    if (authProvider?.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to complete sale')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final tableOrderItems = tableOrderProvider.getOrderForTable(
        widget.table.id,
      );

      final cartItems = cartProvider.cartItems
          .where((item) => cartProvider.selectedTable?.id == widget.table.id)
          .toList();

      final allItems = [...tableOrderItems, ...cartItems];

      if (allItems.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No items to checkout')));
        return;
      }

      final vendorId = authProvider!.currentUser!.id;
      final tableNumber = widget.table.tableNumber;

      final sale = Sale(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vendorId: vendorId,
        items: allItems.map((item) {
          return SaleItem(
            productId: item.product.id,
            productName: item.displayName,
            quantity: item.quantity,
            price: item.unitPrice,
          );
        }).toList(),
        total: allItems.fold(
          0.0,
          (sum, item) => sum + item.unitPrice * item.quantity,
        ),
        tableNumber: tableNumber,
        createdAt: DateTime.now(),
      );

      await _saleService.createSale(vendorId, sale);
      await saleProvider.createSale(vendorId, sale);

      await tableOrderProvider.clearTableOrder(widget.table.id);

      for (final cartItem in cartItems) {
        cartProvider.removeFromCart(cartItem);
      }

      await tableProvider.updateTableStatus(
        widget.table.id,
        TableStatus.served,
      );

      await _printBill(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout completed for Table $tableNumber'),
            backgroundColor: Colors.green,
          ),
        );

        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during checkout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _handleItemRemoval() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTableStatusBasedOnCart();
    });
  }

  void _setupCategories() {
    if (_productProvider.products.isEmpty) return;

    final uniqueCategories = _productProvider.products
        .map((product) => product.category)
        .toSet()
        .toList();

    _categories = ['All', ...uniqueCategories];

    _categorizedProducts.clear();
    for (final category in _categories) {
      if (category == 'All') {
        _categorizedProducts['All'] = _productProvider.products
            .where((product) => product.hasStock)
            .toList();
      } else {
        _categorizedProducts[category] = _productProvider.products
            .where(
              (product) => product.category == category && product.hasStock,
            )
            .toList();
      }
    }

    if (mounted) setState(() {});
  }

  List<Product> _getFilteredProducts() {
    if (_categories.length == 1) {
      _setupCategories();
    }

    List<Product> products = _categorizedProducts[_selectedCategory] ?? [];

    if (_searchQuery.isEmpty) return products;

    return products
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.category.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              product.unit.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _addToCart(Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableOrderProvider = Provider.of<TableOrderProvider>(
      context,
      listen: false,
    );

    if (product.hasVariants && product.activeVariants.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => SimpleVariantSelector(
          product: product,
          onAddToCart: (variant, quantity) {
            try {
              if (cartProvider.selectedTable?.id == widget.table.id) {
                final existingItem = cartProvider.cartItems.firstWhere(
                  (item) =>
                      item.product.id == product.id &&
                      item.variant?.name == variant.name,
                  orElse: () =>
                      CartItem(product: product, variant: null, quantity: 0),
                );

                if (existingItem.quantity > 0) {
                  cartProvider.updateQuantity(
                    existingItem,
                    existingItem.quantity + quantity,
                  );
                } else {
                  cartProvider.addToCart(
                    product,
                    variant: variant,
                    quantity: quantity,
                  );
                }
              } else {
                final tableOrderItems = tableOrderProvider.getOrderForTable(
                  widget.table.id,
                );
                final existingItemIndex = tableOrderItems.indexWhere(
                  (item) =>
                      item.product.id == product.id &&
                      item.variant?.name == variant.name,
                );

                if (existingItemIndex >= 0) {
                  final currentQuantity =
                      tableOrderItems[existingItemIndex].quantity;
                  tableOrderProvider.updateTableOrderQuantity(
                    tableId: widget.table.id,
                    itemIndex: existingItemIndex,
                    quantity: currentQuantity + quantity,
                  );
                } else {
                  tableOrderProvider.addToTableOrder(
                    tableId: widget.table.id,
                    product: product,
                    variant: variant,
                    quantity: quantity,
                  );
                }
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateTableStatusBasedOnCart();
              });
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        ),
      );
    } else {
      try {
        if (cartProvider.selectedTable?.id == widget.table.id) {
          final existingItem = cartProvider.cartItems.firstWhere(
            (item) => item.product.id == product.id && item.variant == null,
            orElse: () =>
                CartItem(product: product, variant: null, quantity: 0),
          );

          if (existingItem.quantity > 0) {
            cartProvider.updateQuantity(
              existingItem,
              existingItem.quantity + 1,
            );
          } else {
            cartProvider.addToCart(product);
          }
        } else {
          final tableOrderItems = tableOrderProvider.getOrderForTable(
            widget.table.id,
          );
          final existingItemIndex = tableOrderItems.indexWhere(
            (item) => item.product.id == product.id && item.variant == null,
          );

          if (existingItemIndex >= 0) {
            final currentQuantity = tableOrderItems[existingItemIndex].quantity;
            tableOrderProvider.updateTableOrderQuantity(
              tableId: widget.table.id,
              itemIndex: existingItemIndex,
              quantity: currentQuantity + 1,
            );
          } else {
            tableOrderProvider.addToTableOrder(
              tableId: widget.table.id,
              product: product,
              variant: null,
              quantity: 1,
            );
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateTableStatusBasedOnCart();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _getStatusLabel(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return 'Empty';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.served:
        return 'Served';
      case TableStatus.cleared:
        return 'Cleared';
    }
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.empty:
        return Colors.green.shade400;
      case TableStatus.occupied:
        return Colors.orange.shade400;
      case TableStatus.served:
        return Colors.red.shade400;
      case TableStatus.cleared:
        return Colors.blue.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTableStatusBasedOnCart();
    });

    return Scaffold(
      appBar: AppBar(
        title: _buildTableHeader(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildProductsPanel()),

          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
              color: Colors.white,
            ),
            child: _buildOrderPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final statusColor = _getStatusColor(widget.table.status);
    final statusLabel = _getStatusLabel(widget.table.status);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor, width: 2),
          ),
          child: Center(
            child: Text(
              widget.table.tableNumber,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Table ${widget.table.tableNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.table.numberOfSeats} seats • $statusLabel',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductsPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: SearchBarWidget(
                  hint: 'Search products or categories',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Container(
                width: 200,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;

                        _setupCategories();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              if (productProvider.isLoading &&
                  productProvider.products.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShimmerGrid(crossAxisCount: 4, itemCount: 12),
                );
              }

              if (_categories.length == 1 &&
                  productProvider.products.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _setupCategories();
                });
              }

              final filteredProducts = _getFilteredProducts();

              if (filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No products available'
                            : 'No products found for "$_searchQuery"',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductCard(
                      product: product,
                      index: index,
                      isHovered: _isHoveredIndex(index),
                      onAddToCart: (product) => _addToCart(product),
                      onTap: (product) => _showProductDetailsDialog(product),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showProductDetailsDialog(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.lg),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.imageUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => ShimmerEffect(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.grey100,
                            child: const Icon(
                              Icons.broken_image,
                              size: 64,
                              color: AppColors.grey400,
                            ),
                          ),
                        ),
                      ),
                    ),

                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: AppSpacing.xs),

                  _buildDetailRow("Category:", product.category),
                  _buildDetailRow("Unit:", product.unit),
                  if (product.hasVariants) ...[
                    _buildDetailRow(
                      "Total Stock:",
                      '${product.totalVariantQuantity} ${product.unit}',
                    ),
                    _buildDetailRow(
                      "Variants:",
                      '${product.variants.length} available',
                    ),
                  ] else ...[
                    _buildDetailRow(
                      "Sale Price:",
                      product.salePrice.toStringAsFixed(0),
                    ),
                    _buildDetailRow(
                      "Quantity:",
                      '${product.quantity} ${product.unit}',
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: product.hasStock
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.hasStock ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: product.hasStock
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),

                  if (product.hasVariants && product.variants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Available Variants:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...product.activeVariants.take(3).map((variant) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.grey50,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variant.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Price: ${variant.getPrice(product.salePrice).toStringAsFixed(0)} • Stock: ${variant.quantity}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (product.variants.length > 3)
                      Text(
                        '... and ${product.variants.length - 3} more variants',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: product.hasStock
                            ? () {
                                Navigator.of(context).pop();
                                _addToCart(product);
                              }
                            : null,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(
                          product.hasVariants ? 'Select Variant' : 'Add Item',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPanel() {
    return Consumer2<CartProvider, TableOrderProvider>(
      builder: (context, cartProvider, tableOrderProvider, child) {
        final tableOrderItems = tableOrderProvider.getOrderForTable(
          widget.table.id,
        );

        final cartItems = cartProvider.cartItems
            .where((item) => cartProvider.selectedTable?.id == widget.table.id)
            .toList();

        final allItems = [...tableOrderItems, ...cartItems];

        final total = allItems.fold(0.0, (sum, item) => sum + item.totalPrice);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order for Table ${widget.table.tableNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.now()),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            Expanded(
              child: allItems.isEmpty
                  ? _buildEmptyOrder()
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: allItems.length,
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        final isFromTableOrder = index < tableOrderItems.length;

                        return _buildOrderItemCard(
                          item: item,
                          isFromTableOrder: isFromTableOrder,
                          index: index,
                        );
                      },
                    ),
            ),

            if (allItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Total:', total, isTotal: true),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(child: _buildCheckoutButton()),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomButton(
                            text: 'Print KOT',
                            variant: ButtonVariant.filled,
                            color: AppColors.success,
                            onPressed: _printKOT, // Use the new KOT method
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOrderItemCard({
    required CartItem item,
    required bool isFromTableOrder,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${item.unitPrice.toStringAsFixed(0)} each',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (item.variant != null && item.variant!.attributes.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      ...item.variant!.attributes.entries.map((entry) {
                        return Text(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          ),
          _buildQuantityControls(
            item: item,
            isFromTableOrder: isFromTableOrder,
            index: index,
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControls({
    required CartItem item,
    required bool isFromTableOrder,
    required int index,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            if (isFromTableOrder) {
              _tableOrderProvider.updateTableOrderQuantity(
                tableId: widget.table.id,
                itemIndex: index,
                quantity: item.quantity - 1,
              );
            } else {
              final cartProvider = Provider.of<CartProvider>(
                context,
                listen: false,
              );
              cartProvider.updateQuantity(item, item.quantity - 1);
            }
            _handleItemRemoval();
          },
          icon: const Icon(Icons.remove, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            minimumSize: const Size(32, 32),
          ),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: () {
            if (isFromTableOrder) {
              _tableOrderProvider.updateTableOrderQuantity(
                tableId: widget.table.id,
                itemIndex: index,
                quantity: item.quantity + 1,
              );
            } else {
              final cartProvider = Provider.of<CartProvider>(
                context,
                listen: false,
              );
              cartProvider.updateQuantity(item, item.quantity + 1);
            }
          },
          icon: const Icon(Icons.add, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
            minimumSize: const Size(32, 32),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          onPressed: () {
            if (isFromTableOrder) {
              _tableOrderProvider.removeFromTableOrder(
                tableId: widget.table.id,
                itemIndex: index,
              );
            } else {
              final cartProvider = Provider.of<CartProvider>(
                context,
                listen: false,
              );
              cartProvider.removeFromCart(item);
            }
            _handleItemRemoval();
          },
          icon: const Icon(Icons.delete, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            foregroundColor: Colors.red,
            minimumSize: const Size(32, 32),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyOrder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
          SizedBox(height: AppSpacing.md),
          Text('Cart is empty', style: TextStyle(fontSize: 16)),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Add products to start selling',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          'Rs ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppColors.primary : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton() {
    return CustomButton(
      text: _isProcessing ? 'Processing...' : 'Print Bill',
      onPressed: _isProcessing ? null : _checkout,
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const ShimmerGrid({
    required this.crossAxisCount,
    required this.itemCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ShimmerEffect(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.circular(8),
        );
      },
    );
  }
}
