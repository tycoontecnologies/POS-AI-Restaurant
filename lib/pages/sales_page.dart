import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/product.dart';
import '../services/dummy_data_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final List<CartItem> _cartItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    setState(() {
      _products = DummyDataService.getProducts()
          .where((p) => p.active)
          .toList();
      _filteredProducts = _products;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      _cartItems.remove(item);
    });
  }

  void _updateQuantity(CartItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cartItems.remove(item);
      } else {
        item.quantity = quantity;
      }
    });
  }

  double get _total => _cartItems.fold(
    0,
    (sum, item) => sum + (item.product.salePrice * item.quantity),
  );

  void _checkout() {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
        surfaceTintColor:
            Colors.transparent, // Prevents Material 3 color overlay

        title: const Text('Sale Completed'),
        content: Text('Total: \$${_total.toStringAsFixed(2)}'),
        actions: [
          CustomButton(
            text: 'OK',
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cartItems.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: isMobile
          ? Column(
              children: [
                // Products list section
                Expanded(child: _buildProductsSection(context, colorScheme)),
                const SizedBox(height: AppSpacing.lg),
                // Cart section below on mobile
                _buildCartSection(context, colorScheme, width: double.infinity),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildProductsSection(context, colorScheme),
                ),

                const SizedBox(width: AppSpacing.lg),

                _buildCartSection(
                  context,
                  colorScheme,
                  width: isTablet ? 360 : 400,
                ),
              ],
            ),
    );
  }

  Widget _buildProductsSection(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.sales,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Point of Sale System',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SearchBarWidget(
          controller: _searchController,
          hint: 'Search products to sell...',
          onChanged: (_) => _filterProducts(),
          onClear: () => _filterProducts(),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.2,
            ),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return CustomCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: Theme.of(context).colorScheme.surfaceVariant,
                onTap: () => _addToCart(product),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      product.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.salePrice.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          'Stock: ${product.quantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withOpacity(0.8),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection(
    BuildContext context,
    ColorScheme colorScheme, {
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: CustomCard(
        color: Theme.of(context).colorScheme.onSecondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Cart (${_cartItems.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => _cartItems.clear()),
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear Cart',
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _cartItems.isEmpty
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
                          Text(
                            'Cart is empty',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color
                                      ?.withOpacity(0.8),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add products to start selling',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withOpacity(0.5),
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
                                      item.product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      '\$${item.product.salePrice.toStringAsFixed(2)} each',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withOpacity(0.8),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _updateQuantity(
                                      item,
                                      item.quantity - 1,
                                    ),
                                    icon: const Icon(Icons.remove, size: 16),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                      minimumSize: const Size(32, 32),
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _updateQuantity(
                                      item,
                                      item.quantity + 1,
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      minimumSize: const Size(32, 32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                onPressed: () => _removeFromCart(item),
                                icon: const Icon(Icons.delete, size: 16),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error.withOpacity(0.1),
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  minimumSize: const Size(32, 32),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_cartItems.isNotEmpty) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${_total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                text: 'Checkout',
                icon: Icons.payment,
                fullWidth: true,
                onPressed: _checkout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});
}
