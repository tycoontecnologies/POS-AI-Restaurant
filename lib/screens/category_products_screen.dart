import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for FirebaseFirestore
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/category.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/search_bar_widget.dart';
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
                  // Product Image
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

  Future<void> _printKitchenTicket(Sale sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'KITCHEN ORDER TICKET',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              if (sale.tableNumber != null && sale.tableNumber!.isNotEmpty) ...[
                pw.Text(
                  'TABLE: ${sale.tableNumber}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Text('Order: ${sale.id.substring(0, 6)}'),
              pw.Text('Time: ${sale.createdAt}'),
              pw.SizedBox(height: 6),
              pw.Text(
                'ITEMS:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              ...sale.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.productName,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                      pw.Text(
                        'x${item.quantity}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Send to kitchen',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printBill(Sale sale) async {
    final pdf = pw.Document();
    final authProvider = _categoryProvider.authProvider;
    final user = authProvider?.currentUser;

    // ✅ Fetch logo before building PDF
    Uint8List? logoBytes;
    if (user?.restaurantLogoUrl != null &&
        user!.restaurantLogoUrl!.isNotEmpty) {
      logoBytes = await _getImageData(user.restaurantLogoUrl!);
    }

    // ✅ Format receipt ID as ddMMyyHHmm (e.g. 0311251847)
    final now = DateTime.now();
    final formattedReceiptId = DateFormat('ddMMyyHHmm').format(now);
    final formattedDateTime = DateFormat(
      'dd MMM yyyy hh:mm a',
    ).format(sale.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ===== HEADER =====
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoBytes != null && logoBytes.isNotEmpty)
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(
                          pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      user?.restaurantName.isNotEmpty == true
                          ? user!.restaurantName
                          : 'My Restaurant',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (user?.location.isNotEmpty == true) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        user!.location,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (user?.phoneNo.isNotEmpty == true) ...[
                      pw.Text(
                        'Phone: ${user!.phoneNo}',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'CUSTOMER RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // ===== RECEIPT INFO =====
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                      color: PdfColors.grey600,
                      width: 0.3,
                    ),
                    verticalInside: pw.BorderSide(
                      color: PdfColors.grey600,
                      width: 0.5,
                    ),
                  ),
                  children: [
                    pw.TableRow(
                      children: [
                        _infoCell('Receipt:', isLabel: true),
                        _infoCell(formattedReceiptId),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _infoCell('Date:', isLabel: true),
                        _infoCell(formattedDateTime),
                      ],
                    ),
                    if (sale.tableNumber != null &&
                        sale.tableNumber!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          _infoCell('Table:', isLabel: true),
                          _infoCell(sale.tableNumber!),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // ===== ITEMS TABLE =====
              pw.Text(
                'ITEMS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey600,
                  width: 0.5,
                ),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Product',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...sale.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '${item.productName} x${item.quantity}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              (item.price * item.quantity).toStringAsFixed(0),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 6),

              // ===== TOTAL =====
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.8),
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      sale.total.toStringAsFixed(0),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ===== FOOTER =====
              pw.Divider(thickness: 1),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your purchase!',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Please visit again.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Developed by Tycoon Technologies Pvt. Ltd',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '03060626699',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
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

  // ===== Helper for Info Table Cells =====
  pw.Widget _infoCell(String text, {bool isLabel = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ===== Helper: Load Image Data =====
  Future<Uint8List> _getImageData(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error loading image: $e');
    }
    return Uint8List(0);
  }

  Future<void> _addToTable() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final authProvider = _categoryProvider.authProvider;

    if (authProvider?.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add order to table')),
      );
      return;
    }

    if (cartProvider.isCartEmpty) return;
    if (cartProvider.selectedTable == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final selectedTable = cartProvider.selectedTable!;
      final vendorId = authProvider!.currentUser!.id;

      // Create order data structure
      final orderData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'tableNumber': selectedTable.tableNumber.toString(),
        'items': cartProvider.cartItems.map((item) {
          return {
            'productId': item.product.id,
            'productName': item.displayName,
            'selectedVariantId': item.variant?.id,
            'selectedVariantName': item.variant?.name,
            'quantity': item.quantity,
            'price': item.unitPrice,
            'totalPrice': item.totalPrice,
          };
        }).toList(),
        'subtotal': cartProvider.total,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Save order to table's orders subcollection
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .collection('tables')
          .doc(selectedTable.id)
          .collection('orders')
          .add(orderData);

      // Update table status to occupied if not already
      if (selectedTable.status != TableStatus.occupied) {
        await tableProvider.updateTableStatus(
          selectedTable.id,
          TableStatus.occupied,
        );
      }

      // Clear cart
      cartProvider.clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order added to Table ${selectedTable.tableNumber}'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to dashboard or stay on screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _checkout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
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
      String? tableNumber;

      if (cartProvider.selectedTable != null) {
        tableNumber = cartProvider.selectedTable!.tableNumber.toString();

        // ✅ Update table status to OCCUPIED
        await tableProvider.updateTableStatus(
          cartProvider.selectedTable!.id,
          TableStatus.occupied,
        );

        print(
          'Table ${cartProvider.selectedTable!.tableNumber} status updated to occupied',
        );
      } else {
        tableNumber = '0';
      }

      final now = DateTime.now();
      final saleId = DateFormat('ddMMyyHHmm').format(now);

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
        tableNumber: tableNumber,
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

      await _printKitchenTicket(sale);
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet = constraints.maxWidth < 1024;

            if (isMobile) {
              return _buildMobileLayout();
            } else if (isTablet) {
              return _buildTabletLayout();
            } else {
              return _buildDesktopLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SearchBarWidget(
            hint: 'Search products...',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _buildProductsGrid(crossAxisCount: 2),
        ), // 2 columns for mobile
        _buildMobileCartSection(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SearchBarWidget(
                  hint: 'Search products...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _buildProductsGrid(crossAxisCount: 3),
              ), // 3 columns for tablet
            ],
          ),
        ),
        Container(
          width: 350,
          margin: const EdgeInsets.all(16),
          child: _buildCartSection(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SearchBarWidget(
                  hint: 'Search products...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _buildProductsGrid(crossAxisCount: 4),
              ), // 4 columns for desktop
            ],
          ),
        ),
        Container(
          width: 400,
          margin: const EdgeInsets.all(16),
          child: _buildCartSection(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
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
                final category = categoryProvider.allCategories.firstWhere(
                  (cat) => cat.name == widget.categoryName,
                  orElse: () =>
                      Category(id: '', name: widget.categoryName, active: true),
                );

                return Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid({required int crossAxisCount}) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerGrid(crossAxisCount: crossAxisCount, itemCount: 6),
          );
        }

        if (productProvider.products.isEmpty) {
          return _buildEmptyState();
        }

        final productsInCategory = _getProductsInCategory();
        final filteredProducts = _filterProducts(productsInCategory);

        if (filteredProducts.isEmpty) {
          return _buildNoResultsState();
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
              // mainAxisExtent: 320,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _buildProductCard(product, index);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, int index) {
    final isHovered = _isHoveredIndex(index);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCardIndex = index),
      onExit: (_) => setState(() => _hoveredCardIndex = null),
      child: GestureDetector(
        onTap: () => _showProductDetailsDialog(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? AppColors.primary : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (isHovered)
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
            ],
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with proper aspect ratio
              Container(
                width: double.infinity,
                height: 150,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.grey100, // Fallback background color
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit
                              .contain, // This ensures full image coverage
                          height: 150,
                          placeholder: (context, url) => ShimmerEffect(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.grey100,
                            child: const Icon(
                              Icons.inventory_2,
                              size: 40,
                              color: AppColors.grey400,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.grey100,
                          child: const Icon(
                            Icons.inventory_2,
                            size: 40,
                            color: AppColors.grey400,
                          ),
                        ),
                ),
              ),

              // Product Name and Variant Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.hasVariants)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
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

              // Category
              Text(
                product.category,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Stock and Price Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.hasVariants
                            ? '${product.totalVariantQuantity} ${product.unit}'
                            : '${product.quantity} ${product.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.hasStock
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.hasStock ? 'In Stock' : 'Out of Stock',
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
                  // Show price for products without variants
                  if (!product.hasVariants)
                    Text(
                      'Rs ${product.salePrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Add to Cart Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: product.hasStock
                      ? () => _addToCart(product)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        product.hasVariants ? 'Select Variant' : 'Add to Cart',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCartSection() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (cartProvider.isCartEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cart Total:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Rs ${cartProvider.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(width: double.infinity, child: _buildCheckoutButton()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartSection() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return CustomCard(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),

                Expanded(
                  child: cartProvider.isCartEmpty
                      ? _buildEmptyCart()
                      : _buildCartItems(cartProvider),
                ),

                if (!cartProvider.isCartEmpty) ...[
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  _buildCartTotal(cartProvider),
                  const SizedBox(height: AppSpacing.md),
                  _buildCheckoutButton(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartItems(CartProvider cartProvider) {
    return ListView.builder(
      itemCount: cartProvider.cartItems.length,
      itemBuilder: (context, index) {
        final item = cartProvider.cartItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
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
                    Text(
                      '${item.unitPrice.toStringAsFixed(0)} each',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (item.variant != null &&
                        item.variant!.attributes.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
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
              _buildQuantityControls(item, cartProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantityControls(CartItem item, CartProvider cartProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => cartProvider.updateQuantity(item, item.quantity - 1),
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
          onPressed: () => cartProvider.updateQuantity(item, item.quantity + 1),
          icon: const Icon(Icons.add, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
            minimumSize: const Size(32, 32),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          onPressed: () => cartProvider.removeFromCart(item),
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

  Widget _buildCartTotal(CartProvider cartProvider) {
    return Container(
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            'Rs ${cartProvider.total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton() {
    final cartProvider = Provider.of<CartProvider>(context);
    final isTableSelected = cartProvider.selectedTable != null;

    return CustomButton(
      text: _isProcessing
          ? 'Processing...'
          : isTableSelected
          ? 'Add to Table'
          : 'Checkout',
      icon: isTableSelected ? Icons.table_restaurant : Icons.payment,
      onPressed: _isProcessing
          ? null
          : isTableSelected
          ? _addToTable
          : _checkout,
    );
  }

  Widget _buildEmptyCart() {
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          SizedBox(height: AppSpacing.md),
          Text(
            'No products available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: AppSpacing.md),
          Text(
            _searchQuery.isEmpty
                ? 'No products in this category'
                : 'No products found for "$_searchQuery"',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
