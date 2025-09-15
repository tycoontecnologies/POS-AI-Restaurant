// import 'package:flutter/material.dart';
// import 'package:pos/providers/cart_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:printing/printing.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';
// import 'package:pos/l10n/app_localizations.dart';
// import '../models/product.dart';
// import '../models/sale.dart';
// import '../models/draft.dart';
// import '../services/sale_service.dart';
// import '../providers/sale_provider.dart';
// import '../providers/product_provider.dart';
// import '../providers/draft_provider.dart';
// import '../providers/auth_provider.dart';
// import '../components/ui/custom_button.dart';
// import '../components/ui/custom_card.dart';
// import '../components/ui/search_bar_widget.dart';
// import '../utils/responsive.dart';
// import '../utils/app_spacing.dart';

// class SalesScreen extends StatefulWidget {
//   const SalesScreen({super.key});

//   @override
//   State<SalesScreen> createState() => _SalesScreenState();
// }

// class _SalesScreenState extends State<SalesScreen> {
//   final List<CartItem> _cartItems = [];
//   final TextEditingController _searchController = TextEditingController();
//   final SaleService _saleService = SaleService();
//   bool _isProcessing = false;
//   bool _isSavingDraft = false;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(_filterProducts);
//     _loadProducts();
//     _initializeDraftProvider(); // Add this line
//   }

//   // Add this method
//   void _initializeDraftProvider() {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final draftProvider = Provider.of<DraftProvider>(context, listen: false);

//     if (authProvider.currentUser != null) {
//       draftProvider.initialize(authProvider.currentUser!.id);
//       draftProvider.loadDrafts();
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _loadProducts() {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     if (authProvider.currentUser != null) {
//       final productProvider = Provider.of<ProductProvider>(
//         context,
//         listen: false,
//       );
//       productProvider.loadProducts(authProvider.currentUser!.id);
//     }
//   }

//   void _filterProducts() {
//     final query = _searchController.text.toLowerCase();
//     final productProvider = Provider.of<ProductProvider>(
//       context,
//       listen: false,
//     );
//     productProvider.setSearchQuery(query);
//   }

//   void _addToCart(Product product) {
//     setState(() {
//       final existingIndex = _cartItems.indexWhere(
//         (item) => item.product.id == product.id,
//       );
//       if (existingIndex >= 0) {
//         _cartItems[existingIndex].quantity++;
//       } else {
//         _cartItems.add(CartItem(product: product, quantity: 1));
//       }
//     });
//   }

//   void _addToCartWithCheck(Product product) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     if (cartProvider.canAddToCart(product)) {
//       cartProvider.addToCart(product);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Added to cart successfully')));
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Insufficient stock')));
//     }
//   }

//   void _removeFromCart(CartItem item) {
//     setState(() {
//       _cartItems.remove(item);
//     });
//   }

//   void _updateQuantity(CartItem item, int quantity) {
//     setState(() {
//       if (quantity <= 0) {
//         _cartItems.remove(item);
//       } else {
//         item.quantity = quantity;
//       }
//     });
//   }

//   double get _total => _cartItems.fold(
//     0,
//     (sum, item) => sum + (item.product.salePrice * item.quantity),
//   );

//   int get _totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

//   Future<void> _saveAsDraft() async {
//     if (_cartItems.isEmpty) return;

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final draftProvider = Provider.of<DraftProvider>(context, listen: false);

//     if (authProvider.currentUser == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please login to save draft')),
//       );
//       return;
//     }

//     setState(() {
//       _isSavingDraft = true;
//     });

//     try {
//       final draft = Draft(
//         id: '',
//         vendorId: authProvider.currentUser!.id,
//         type: 'Sale',
//         items: _totalItems,
//         total: _total,
//         date: DateTime.now(),
//         status: 'Open',
//         cartItems: _cartItems.map((item) => item.toMap()).toList(),
//       );

//       await draftProvider.createDraft(draft);

//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Draft saved successfully')));

//       setState(() {
//         _cartItems.clear();
//         _isSavingDraft = false;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to save draft: $e')));
//         setState(() {
//           _isSavingDraft = false;
//         });
//       }
//     }
//   }

//   Future<void> _checkout() async {
//     if (_cartItems.isEmpty) return;

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final saleProvider = Provider.of<SaleProvider>(context, listen: false);
//     final productProvider = Provider.of<ProductProvider>(
//       context,
//       listen: false,
//     );
//     Provider.of<DraftProvider>(context, listen: false);

//     if (authProvider.currentUser == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please login to complete sale')),
//       );
//       return;
//     }

//     setState(() {
//       _isProcessing = true;
//     });

//     try {
//       // Generate auto ID
//       final saleId = FirebaseFirestore.instance.collection('sales').doc().id;

//       final sale = Sale(
//         id: saleId,
//         vendorId: authProvider.currentUser!.id,
//         items: _cartItems
//             .map(
//               (cartItem) => SaleItem(
//                 productId: cartItem.product.id,
//                 productName: cartItem.product.name,
//                 price: cartItem.product.salePrice,
//                 quantity: cartItem.quantity,
//               ),
//             )
//             .toList(),
//         total: _total,
//         createdAt: DateTime.now(),
//       );

//       await _saleService.createSale(authProvider.currentUser!.id, sale);

//       // Update product quantities in Firebase
//       for (final cartItem in _cartItems) {
//         final updatedProduct = cartItem.product.copyWith(
//           quantity: cartItem.product.quantity - cartItem.quantity,
//         );
//         await productProvider.updateProduct(
//           authProvider.currentUser!.id,
//           updatedProduct,
//         );
//       }

//       // Also add to provider for local state management
//       await saleProvider.createSale(authProvider.currentUser!.id, sale);

//       // Print bill
//       await _printBill(sale);

//       // Show success dialog
//       if (mounted) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: const Color(0xFFFDFDFE),
//             surfaceTintColor: Colors.transparent,
//             title: const Text('Sale Completed'),
//             content: Text('Total: ${_total.toStringAsFixed(0)}'),
//             actions: [
//               CustomButton(
//                 text: 'OK',
//                 onPressed: () {
//                   Navigator.pop(context);
//                   setState(() {
//                     _cartItems.clear();
//                     _isProcessing = false;
//                   });
//                 },
//               ),
//             ],
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to complete sale: $e')));
//         setState(() {
//           _isProcessing = false;
//         });
//       }
//     }
//   }

//   Future<void> _printBill(Sale sale) async {
//     final pdf = pw.Document();

//     pdf.addPage(
//       pw.Page(
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Center(
//                 child: pw.Text(
//                   'SALES RECEIPT',
//                   style: pw.TextStyle(
//                     fontSize: 20,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//               ),
//               pw.SizedBox(height: 10),
//               pw.Text('Receipt #: ${sale.id}'),
//               pw.Text('Date: ${sale.createdAt.toString()}'),
//               pw.Divider(),
//               pw.Text(
//                 'ITEMS:',
//                 style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               ),
//               pw.SizedBox(height: 5),
//               ...sale.items.map((item) {
//                 return pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Text('${item.productName} x${item.quantity}'),
//                     pw.Text((item.price * item.quantity).toStringAsFixed(0)),
//                   ],
//                 );
//               }),
//               pw.Divider(),
//               pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Text(
//                     'TOTAL:',
//                     style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//                   ),
//                   pw.Text(
//                     sale.total.toStringAsFixed(0),
//                     style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//                   ),
//                 ],
//               ),
//               pw.SizedBox(height: 20),
//               pw.Center(
//                 child: pw.Text(
//                   'Thank you for your business!',
//                   style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );

//     await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//     final isMobile = Responsive.isMobile(context);
//     final isTablet = Responsive.isTablet(context);
//     final productProvider = Provider.of<ProductProvider>(context);
//     final draftProvider = Provider.of<DraftProvider>(context);
//     final filteredProducts = productProvider.products
//         .where((p) => p.active)
//         .toList();

//     Provider.of<CartProvider>(context);

//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: isMobile
//           ? Column(
//               children: [
//                 // Products list section
//                 Expanded(
//                   child: _buildProductsSection(
//                     context,
//                     colorScheme,
//                     filteredProducts,
//                   ),
//                 ),
//                 const SizedBox(height: AppSpacing.lg),
//                 // Cart section below on mobile
//                 _buildCartSection(
//                   context,
//                   colorScheme,
//                   draftProvider,
//                   width: double.infinity,
//                 ),
//               ],
//             )
//           : Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: _buildProductsSection(
//                     context,
//                     colorScheme,
//                     filteredProducts,
//                   ),
//                 ),

//                 const SizedBox(width: AppSpacing.lg),

//                 _buildCartSection(
//                   context,
//                   colorScheme,
//                   draftProvider,
//                   width: isTablet ? 360 : 400,
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _buildProductsSection(
//     BuildContext context,
//     ColorScheme colorScheme,
//     List<Product> filteredProducts,
//   ) {
//     final l10n = AppLocalizations.of(context)!;
//     final isMobile = Responsive.isMobile(context);
//     final isTablet = Responsive.isTablet(context);
//     final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
//     final productProvider = Provider.of<ProductProvider>(context);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Text(
//           l10n.sales,
//           style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//             fontWeight: FontWeight.w700,
//             color: colorScheme.onSurface,
//           ),
//         ),
//         const SizedBox(height: AppSpacing.xs),
//         Text(
//           'Point of Sale System',
//           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//             color: Theme.of(
//               context,
//             ).textTheme.bodyMedium?.color?.withOpacity(0.8),
//           ),
//         ),
//         const SizedBox(height: AppSpacing.lg),
//         SearchBarWidget(
//           controller: _searchController,
//           hint: 'Search products to sell...',
//           onChanged: (_) => _filterProducts(),
//           onClear: () {
//             _searchController.clear();
//             _filterProducts();
//           },
//         ),
//         const SizedBox(height: AppSpacing.md),
//         if (productProvider.isLoading)
//           const Center(child: CircularProgressIndicator())
//         else
//           Expanded(
//             child: GridView.builder(
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: crossAxisCount,
//                 crossAxisSpacing: AppSpacing.md,
//                 mainAxisSpacing: AppSpacing.md,
//                 childAspectRatio: 1.8,
//               ),
//               itemCount: filteredProducts.length,
//               itemBuilder: (context, index) {
//                 final product = filteredProducts[index];
//                 return CustomCard(
//                   padding: const EdgeInsets.all(AppSpacing.md),
//                   color: Theme.of(context).colorScheme.surfaceContainerHighest,
//                   onTap: () => _addToCartWithCheck(product),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         product.name,
//                         style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: AppSpacing.xs),
//                       Text(
//                         product.category,
//                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Theme.of(
//                             context,
//                           ).textTheme.bodySmall?.color?.withOpacity(0.8),
//                         ),
//                       ),
//                       const Spacer(),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             product.salePrice.toStringAsFixed(0),
//                             style: Theme.of(context).textTheme.titleMedium
//                                 ?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   color: Theme.of(context).colorScheme.primary,
//                                 ),
//                           ),
//                           Text(
//                             'Stock: ${product.quantity}',
//                             style: Theme.of(context).textTheme.bodySmall
//                                 ?.copyWith(
//                                   color: Theme.of(context)
//                                       .textTheme
//                                       .bodySmall
//                                       ?.color
//                                       ?.withOpacity(0.8),
//                                 ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildCartSection(
//     BuildContext context,
//     ColorScheme colorScheme,
//     DraftProvider draftProvider, {
//     double? width,
//   }) {
//     return SizedBox(
//       width: width,
//       child: CustomCard(
//         color: Theme.of(context).colorScheme.onSecondary,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.shopping_cart, color: colorScheme.primary),
//                 const SizedBox(width: AppSpacing.sm),
//                 Text(
//                   'Cart (${_cartItems.length})',
//                   style: Theme.of(
//                     context,
//                   ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
//                 ),
//                 const Spacer(),
//                 if (_cartItems.isNotEmpty)
//                   IconButton(
//                     onPressed: () => setState(() => _cartItems.clear()),
//                     icon: const Icon(Icons.clear_all),
//                     tooltip: 'Clear Cart',
//                   ),
//               ],
//             ),
//             const Divider(),

//             Expanded(
//               child: _cartItems.isEmpty
//                   ? Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.shopping_cart_outlined,
//                             size: 64,
//                             color: Theme.of(context).disabledColor,
//                           ),
//                           const SizedBox(height: AppSpacing.md),
//                           Text(
//                             'Cart is empty',
//                             style: Theme.of(context).textTheme.bodyLarge
//                                 ?.copyWith(
//                                   color: Theme.of(context)
//                                       .textTheme
//                                       .bodyLarge
//                                       ?.color
//                                       ?.withOpacity(0.8),
//                                 ),
//                           ),
//                           const SizedBox(height: AppSpacing.sm),
//                           Text(
//                             'Add products to start selling',
//                             style: Theme.of(context).textTheme.bodyMedium
//                                 ?.copyWith(
//                                   color: Theme.of(context)
//                                       .textTheme
//                                       .bodyMedium
//                                       ?.color
//                                       ?.withOpacity(0.7),
//                                 ),
//                           ),
//                         ],
//                       ),
//                     )
//                   : ListView.builder(
//                       itemCount: _cartItems.length,
//                       itemBuilder: (context, index) {
//                         final item = _cartItems[index];
//                         return Container(
//                           margin: const EdgeInsets.only(bottom: AppSpacing.sm),
//                           padding: const EdgeInsets.all(AppSpacing.sm),
//                           decoration: BoxDecoration(
//                             color: Theme.of(context)
//                                 .colorScheme
//                                 .surfaceContainerHighest
//                                 .withOpacity(0.5),
//                             borderRadius: BorderRadius.circular(
//                               AppSpacing.radiusSm,
//                             ),
//                           ),
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       item.product.name,
//                                       style: Theme.of(context)
//                                           .textTheme
//                                           .titleSmall
//                                           ?.copyWith(
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                     ),
//                                     Text(
//                                       '${item.product.salePrice.toStringAsFixed(0)} each',
//                                       style: Theme.of(context)
//                                           .textTheme
//                                           .bodySmall
//                                           ?.copyWith(
//                                             color: Theme.of(context)
//                                                 .textTheme
//                                                 .bodySmall
//                                                 ?.color
//                                                 ?.withOpacity(0.8),
//                                           ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   IconButton(
//                                     onPressed: () => _updateQuantity(
//                                       item,
//                                       item.quantity - 1,
//                                     ),
//                                     icon: const Icon(Icons.remove, size: 16),
//                                     style: IconButton.styleFrom(
//                                       backgroundColor: Theme.of(
//                                         context,
//                                       ).colorScheme.surfaceContainerHighest,
//                                       minimumSize: const Size(32, 32),
//                                     ),
//                                   ),
//                                   Container(
//                                     width: 40,
//                                     alignment: Alignment.center,
//                                     child: Text(
//                                       '${item.quantity}',
//                                       style: Theme.of(context)
//                                           .textTheme
//                                           .titleSmall
//                                           ?.copyWith(
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                     ),
//                                   ),
//                                   IconButton(
//                                     onPressed: () => _updateQuantity(
//                                       item,
//                                       item.quantity + 1,
//                                     ),
//                                     icon: const Icon(Icons.add, size: 16),
//                                     style: IconButton.styleFrom(
//                                       backgroundColor: Theme.of(
//                                         context,
//                                       ).colorScheme.primary.withOpacity(0.1),
//                                       foregroundColor: Theme.of(
//                                         context,
//                                       ).colorScheme.primary,
//                                       minimumSize: const Size(32, 32),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(width: AppSpacing.sm),
//                               IconButton(
//                                 onPressed: () => _removeFromCart(item),
//                                 icon: const Icon(Icons.delete, size: 16),
//                                 style: IconButton.styleFrom(
//                                   backgroundColor: Theme.of(
//                                     context,
//                                   ).colorScheme.error.withOpacity(0.1),
//                                   foregroundColor: Theme.of(
//                                     context,
//                                   ).colorScheme.error,
//                                   minimumSize: const Size(32, 32),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//             ),
//             if (_cartItems.isNotEmpty) ...[
//               const Divider(),
//               Container(
//                 padding: const EdgeInsets.all(AppSpacing.md),
//                 decoration: BoxDecoration(
//                   color: Theme.of(
//                     context,
//                   ).colorScheme.primary.withOpacity(0.08),
//                   borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Total:',
//                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       _total.toStringAsFixed(0),
//                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                         fontWeight: FontWeight.w700,
//                         color: Theme.of(context).colorScheme.primary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: AppSpacing.md),
//               Row(
//                 children: [
//                   Expanded(
//                     child: CustomButton(
//                       text: _isSavingDraft ? 'Saving...' : 'Save Draft',
//                       icon: Icons.save,
//                       variant: ButtonVariant.outlined,
//                       onPressed: _isSavingDraft ? null : _saveAsDraft,
//                     ),
//                   ),
//                   const SizedBox(width: AppSpacing.sm),
//                   Expanded(
//                     child: CustomButton(
//                       text: _isProcessing ? 'Processing...' : 'Checkout',
//                       icon: Icons.payment,
//                       onPressed: _isProcessing ? null : _checkout,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

// class CartItem {
//   final Product product;
//   int quantity;

//   CartItem({required this.product, required this.quantity});

//   Map<String, dynamic> toMap() {
//     return {'product': product.toJson(), 'quantity': quantity};
//   }
// }
