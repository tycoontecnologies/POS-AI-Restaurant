import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/category.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
// Add these imports for printing
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';
import '../providers/sale_provider.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryProductsScreen({super.key, required this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late ProductProvider _productProvider;
  late CategoryProvider _categoryProvider;
  String _searchQuery = '';
  // Add printing related variables
  final SaleService _saleService = SaleService();
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productProvider = Provider.of<ProductProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context);

    // Load products if not already loaded
    final vendorId = _categoryProvider.authProvider?.currentUser?.id;
    if (vendorId != null &&
        _productProvider.products.isEmpty &&
        !_productProvider.isLoading) {
      _productProvider.loadProducts(vendorId);
    }
  }

  List<Product> _getProductsInCategory() {
    return _productProvider.products
        .where((product) => product.category == widget.categoryName)
        .toList();
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;

    return products
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.unit.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  // Function to show product details dialog
  void _showProductDetailsDialog(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.lg),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with product name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Divider
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: AppSpacing.md),

                // Product details
                _buildDetailRow('Category', product.category),
                _buildDetailRow('Unit', product.unit),
                _buildDetailRow(
                  'Sale Price',
                  '${product.salePrice.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  'Purchase Price',
                  '${product.purchasePrice.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  'Quantity',
                  '${product.quantity} ${product.unit}',
                ),

                // Stock status
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: product.quantity > 10
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.quantity > 10 ? 'In Stock' : 'Low Stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: product.quantity > 10
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        // Add item to cart
                        final cartProvider = Provider.of<CartProvider>(
                          context,
                          listen: false,
                        );
                        cartProvider.addToCart(product);
                        Navigator.of(context).pop();

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
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

  // Add print bill function from sales_screen.dart
  Future<void> _printBill(Sale sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Receipt #: ${sale.id}'),
              pw.Text('Date: ${sale.createdAt.toString()}'),
              pw.Divider(),
              pw.Text(
                'ITEMS:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              ...sale.items.map((item) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${item.productName} x${item.quantity}'),
                    pw.Text((item.price * item.quantity).toStringAsFixed(2)),
                  ],
                );
              }).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    sale.total.toStringAsFixed(2),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Updated checkout function with printing
  Future<void> _checkout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final authProvider = _categoryProvider.authProvider;

    if (authProvider?.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to complete sale')),
      );
      return;
    }

    if (cartProvider.isCartEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Generate auto ID
      final saleId = FirebaseFirestore.instance.collection('sales').doc().id;

      final sale = Sale(
        id: saleId,
        vendorId: authProvider!.currentUser!.id,
        items: cartProvider.cartItems
            .map(
              (cartItem) => SaleItem(
                productId: cartItem.product.id,
                productName: cartItem.product.name,
                price: cartItem.product.salePrice,
                quantity: cartItem.quantity,
              ),
            )
            .toList(),
        total: cartProvider.total,
        createdAt: DateTime.now(),
      );

      await _saleService.createSale(authProvider.currentUser!.id, sale);

      // Update product quantities in Firebase
      for (final cartItem in cartProvider.cartItems) {
        final updatedProduct = cartItem.product.copyWith(
          quantity: cartItem.product.quantity - cartItem.quantity,
        );
        await productProvider.updateProduct(
          authProvider.currentUser!.id,
          updatedProduct,
        );
      }

      // Also add to provider for local state management
      await saleProvider.createSale(authProvider.currentUser!.id, sale);

      // Print bill
      await _printBill(sale);

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFDFDFE),
          surfaceTintColor: Colors.transparent,
          title: const Text('Sale Completed'),
          content: Text('Total: ${cartProvider.total.toStringAsFixed(2)}'),
          actions: [
            CustomButton(
              text: 'OK',
              onPressed: () {
                Navigator.pop(context);
                cartProvider.clearCart();
                setState(() {
                  _isProcessing = false;
                });
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete sale: $e')));
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading &&
                    productProvider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (productProvider.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No products available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomButton(
                          text: 'Add Products',
                          onPressed: () => context.go('/products'),
                          variant: ButtonVariant.filled,
                        ),
                      ],
                    ),
                  );
                }

                final productsInCategory = _getProductsInCategory();
                final filteredProducts = _filterProducts(productsInCategory);

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products in this category'
                              : 'No products found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          CustomButton(
                            text: 'Add Products',
                            onPressed: () => context.go('/products'),
                            variant: ButtonVariant.filled,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(Icons.arrow_back),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Consumer<CategoryProvider>(
                            builder: (context, categoryProvider, child) {
                              final category = categoryProvider.allCategories
                                  .firstWhere(
                                    (cat) => cat.name == widget.categoryName,
                                    orElse: () => Category(
                                      id: '',
                                      name: widget.categoryName,
                                      active: true,
                                    ),
                                  );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Browse products in this category',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Cart icon with badge
                        Consumer<CartProvider>(
                          builder: (context, cartProvider, child) {
                            return Badge(
                              label: Text(cartProvider.totalItems.toString()),
                              child: const Icon(Icons.shopping_cart, size: 28),
                            );
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: SearchBarWidget(
                        hint: 'Search products...',
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.6,
                              ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return GestureDetector(
                              onTap: () => _showProductDetailsDialog(product),
                              child: // In the GridView.builder itemBuilder, replace the current CustomCard with this:
                              CustomCard(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.category,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${product.quantity} ${product.unit}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: product.quantity > 10
                                                      ? AppColors.success
                                                            .withOpacity(0.1)
                                                      : AppColors.warning
                                                            .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  product.quantity > 10
                                                      ? 'In Stock'
                                                      : 'Low Stock',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: product.quantity > 10
                                                        ? AppColors.success
                                                        : AppColors.warning,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${product.salePrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Add this "Add Item" button at the bottom of the card
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            final cartProvider =
                                                Provider.of<CartProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            cartProvider.addToCart(product);

                                            // Show success message
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${product.name} added to cart',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Add Item',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Cart section - always visible with fixed width
          Container(
            width: 400,
            margin: const EdgeInsets.all(16),
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return CustomCard(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shopping_cart),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Cart',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),

                        Expanded(
                          child: cartProvider.isCartEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 64,
                                        color: Theme.of(context).disabledColor,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      const Text(
                                        'Cart is empty',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Add products to start selling',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: cartProvider.cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = cartProvider.cartItems[index];
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      padding: const EdgeInsets.all(
                                        AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.product.salePrice.toStringAsFixed(2)} each',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () =>
                                                    cartProvider.updateQuantity(
                                                      item,
                                                      item.quantity - 1,
                                                    ),
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                ),
                                                style: IconButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  minimumSize: const Size(
                                                    32,
                                                    32,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 40,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    cartProvider.updateQuantity(
                                                      item,
                                                      item.quantity + 1,
                                                    ),
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 16,
                                                ),
                                                style: IconButton.styleFrom(
                                                  backgroundColor: AppColors
                                                      .primary
                                                      .withOpacity(0.1),
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  minimumSize: const Size(
                                                    32,
                                                    32,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          IconButton(
                                            onPressed: () => cartProvider
                                                .removeFromCart(item),
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 16,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.red
                                                  .withOpacity(0.1),
                                              foregroundColor: Colors.red,
                                              minimumSize: const Size(32, 32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (!cartProvider.isCartEmpty) ...[
                          const Divider(),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${cartProvider.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomButton(
                            text: _isProcessing ? 'Processing...' : 'Checkout',
                            icon: Icons.payment,
                            onPressed: _isProcessing ? null : _checkout,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
