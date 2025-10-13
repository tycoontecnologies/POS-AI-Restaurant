import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';
import '../providers/sale_provider.dart';
import '../components/ui/simple_variant_selector.dart';

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
  final SaleService _saleService = SaleService();
  bool _isProcessing = false;

  int? _hoveredCardIndex;
  bool _isHoveredIndex(int index) => _hoveredCardIndex == index;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _productProvider.loadProducts(vendorId);
      });
    }
  }

  List<Product> _getProductsInCategory() {
    return _productProvider.products
        .where(
          (product) =>
              product.category == widget.categoryName && product.hasStock,
        )
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

  void _addToCart(Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (product.hasVariants && product.activeVariants.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => SimpleVariantSelector(
          product: product,
          onAddToCart: (variant, quantity) {
            try {
              cartProvider.addToCart(
                product,
                variant: variant,
                quantity: quantity,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${variant.name} added to cart'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 1),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: Duration(seconds: 1),
                  content: Text(e.toString()),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      );
    } else {
      // Add product without variants directly
      try {
        cartProvider.addToCart(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

                  // Detail rows
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

                  // Stock indicator
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

                  // Show variants if available
                  if (product.hasVariants && product.variants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Available Variants:',
                      style: const TextStyle(
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
                    }),
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

                  // Actions
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Receipt: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(sale.id.substring(0, 6)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(sale.createdAt.toString()),
                ],
              ),
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
                    pw.Text((item.price * item.quantity).toStringAsFixed(0)),
                  ],
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    sale.total.toStringAsFixed(0),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Thank you Sir!',
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
      final saleId = FirebaseFirestore.instance.collection('sales').doc().id;

      final sale = Sale(
        id: saleId,
        vendorId: authProvider!.currentUser!.id,
        items: cartProvider.cartItems
            .map(
              (cartItem) => SaleItem(
                productId: cartItem.product.id,
                productName: cartItem.displayName,
                price: cartItem.unitPrice,
                quantity: cartItem.quantity,
              ),
            )
            .toList(),
        total: cartProvider.total,
        createdAt: DateTime.now(),
      );

      await _saleService.createSale(authProvider.currentUser!.id, sale);

      // Update product/variant quantities in Firebase
      for (final cartItem in cartProvider.cartItems) {
        if (cartItem.variant != null) {
          // Update variant quantity
          final updatedVariants = cartItem.product.variants.map((v) {
            if (v.id == cartItem.variant!.id) {
              return v.copyWith(quantity: v.quantity - cartItem.quantity);
            }
            return v;
          }).toList();

          final updatedProduct = cartItem.product.copyWith(
            variants: updatedVariants,
          );
          await productProvider.updateProduct(
            authProvider.currentUser!.id,
            updatedProduct,
          );
        } else {
          // Update product quantity
          final updatedProduct = cartItem.product.copyWith(
            quantity: cartItem.product.quantity - cartItem.quantity,
          );
          await productProvider.updateProduct(
            authProvider.currentUser!.id,
            updatedProduct,
          );
        }
      }

      await saleProvider.createSale(authProvider.currentUser!.id, sale);
      await _printBill(sale);

      cartProvider.clearCart();
      setState(() {
        _isProcessing = false;
      });
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
    return SizedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading &&
                    productProvider.products.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ShimmerGrid(crossAxisCount: 3, itemCount: 6),
                  );
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

                              return Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
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
                            final isHovered = _isHoveredIndex(index);

                            return MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredCardIndex = index),
                              onExit: (_) =>
                                  setState(() => _hoveredCardIndex = null),
                              child: GestureDetector(
                                onTap: () => _showProductDetailsDialog(product),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isHovered
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      if (isHovered)
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(
                                            0.2,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                    ],
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.grey.shade100,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (product.hasVariants)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${product.variants.length}V',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                        ],
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
                                                product.hasVariants
                                                    ? '${product.totalVariantQuantity} ${product.unit}'
                                                    : '${product.quantity} ${product.unit}',
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
                                                  color: product.hasStock
                                                      ? AppColors.success
                                                            .withOpacity(0.1)
                                                      : AppColors.error
                                                            .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  product.hasStock
                                                      ? 'In Stock'
                                                      : 'Out of Stock',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: product.hasStock
                                                        ? AppColors.success
                                                        : AppColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (product.variants.isEmpty)
                                            Text(
                                              'Rs ${product.salePrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: product.hasStock
                                              ? () => _addToCart(product)
                                              : null,
                                          icon: const Icon(
                                            Icons.add_shopping_cart,
                                            size: 16,
                                          ),
                                          label: Text(
                                            product.hasVariants
                                                ? 'Select'
                                                : 'Add Item',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            textStyle: const TextStyle(
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
                        const SizedBox(height: AppSpacing.xs),
                        const Divider(),
                        const SizedBox(height: AppSpacing.xs),

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
                                        color: AppColors.backgroundLight,
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
                                                  item.displayName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.unitPrice.toStringAsFixed(0)} each',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                if (item.variant != null &&
                                                    item
                                                        .variant!
                                                        .attributes
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Wrap(
                                                    spacing: 4,
                                                    children: item
                                                        .variant!
                                                        .attributes
                                                        .entries
                                                        .map((entry) {
                                                          return Text(
                                                            '${entry.key}: ${entry.value}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: AppColors
                                                                  .secondary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          );
                                                        })
                                                        .toList(),
                                                  ),
                                                ],
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
                                  cartProvider.total.toStringAsFixed(0),
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
