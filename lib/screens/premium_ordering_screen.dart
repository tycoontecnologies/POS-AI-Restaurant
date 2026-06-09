import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pos/components/premium/premium_restaurant_ui.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/pdf_service.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class PremiumOrderingScreen extends StatefulWidget {
  final RestaurantTable table;

  const PremiumOrderingScreen({super.key, required this.table});

  @override
  State<PremiumOrderingScreen> createState() => _PremiumOrderingScreenState();
}

class _PremiumOrderingScreenState extends State<PremiumOrderingScreen> {
  String _selectedCategory = 'All';
  String _search = '';
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final productProvider = context.read<ProductProvider>();
      final orderProvider = context.read<TableOrderProvider>();

      if (categoryProvider.allCategories.isEmpty &&
          !categoryProvider.isLoading) {
        await categoryProvider.loadInitialCategories();
      }
      final vendorId = auth.currentUser?.id;
      if (vendorId != null &&
          productProvider.products.isEmpty &&
          !productProvider.isLoading) {
        await productProvider.loadProducts(vendorId);
      }
      await orderProvider.loadTableOrder(widget.table.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumRestaurantScaffold(
      eyebrow: 'Two-click ordering',
      title: 'Table ${widget.table.tableNumber} Order',
      subtitle:
          'Categories, menu products, modifiers, notes, split bills, transfers, and checkout in one premium workspace.',
      actions: [
        PremiumActionButton(
          label: 'Floor',
          icon: Icons.grid_view_rounded,
          filled: false,
          onPressed: () => context.go(AppRouter.floorPlan),
        ),
        PremiumActionButton(
          label: 'Billing',
          icon: Icons.payments_outlined,
          onPressed: () => context.go(
            '${AppRouter.billing}/${widget.table.id}',
            extra: widget.table,
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1050;
          final workspace = compact
              ? Column(
                  children: [
                    SizedBox(height: 120, child: _CategoryRail(horizontal: true)),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(child: _MenuBoard(search: _search, table: widget.table)),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(height: 360, child: _OrderSummary(table: widget.table)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 220, child: _CategoryRail()),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: _MenuBoard(search: _search, table: widget.table)),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(width: 380, child: _OrderSummary(table: widget.table)),
                  ],
                );

          return Column(
            children: [
              _OrderingCommandBar(
                search: _search,
                onSearchChanged: (value) => setState(() => _search = value),
                table: widget.table,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: workspace),
            ],
          );
        },
      ),
    );
  }
}

class _OrderingCommandBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final RestaurantTable table;

  const _OrderingCommandBar({
    required this.search,
    required this.onSearchChanged,
    required this.table,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: AppColors.restaurantInk),
              decoration: InputDecoration(
                hintText: 'Search menu or SKU',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                hintStyle: const TextStyle(color: AppColors.restaurantMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _FeatureChip(label: 'Notes', icon: Icons.edit_note),
          _FeatureChip(label: 'Discounts', icon: Icons.percent),
          _FeatureChip(label: 'Coupons', icon: Icons.confirmation_number_outlined),
          _FeatureChip(label: 'Split', icon: Icons.call_split_outlined),
          _FeatureChip(label: 'Merge', icon: Icons.merge_type_outlined),
          _FeatureChip(label: 'Transfer', icon: Icons.swap_horiz_rounded),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FeatureChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppColors.restaurantGold),
        label: Text(label),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label workspace is ready for backend rules.'),
              backgroundColor: AppColors.restaurantPanelStrong,
            ),
          );
        },
        labelStyle: const TextStyle(
          color: AppColors.restaurantInk,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: Colors.white.withOpacity(0.08),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final bool horizontal;

  const _CategoryRail({this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PremiumOrderingScreenState>()!;
    return Consumer2<CategoryProvider, ProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        final productCategories =
            productProvider.products.map((product) => product.category).toSet();
        final categories = [
          'All',
          ...categoryProvider.allCategories.map((category) => category.name),
          ...productCategories,
        ].where((category) => category.trim().isNotEmpty).toSet().toList();

        final list = ListView.separated(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(
            width: horizontal ? AppSpacing.sm : 0,
            height: horizontal ? 0 : AppSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = state._selectedCategory == category;
            return _CategoryButton(
              label: category,
              selected: selected,
              onTap: () => state.setState(() => state._selectedCategory = category),
            );
          },
        );

        return PremiumGlassPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!horizontal) ...[
                const PremiumSectionTitle(
                  title: 'Menu',
                  subtitle: 'Maximum two clicks to add.',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Expanded(child: list),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.restaurantGold.withOpacity(0.16)
              : Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected
                ? AppColors.restaurantGold.withOpacity(0.52)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              color: selected
                  ? AppColors.restaurantGold
                  : AppColors.restaurantMuted,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.restaurantInk
                    : AppColors.restaurantMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuBoard extends StatelessWidget {
  final String search;
  final RestaurantTable table;

  const _MenuBoard({required this.search, required this.table});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PremiumOrderingScreenState>()!;
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final products = productProvider.products.where((product) {
          final categoryMatches = state._selectedCategory == 'All' ||
              product.category == state._selectedCategory;
          final searchMatches = search.trim().isEmpty ||
              product.name.toLowerCase().contains(search.toLowerCase()) ||
              product.category.toLowerCase().contains(search.toLowerCase());
          return product.active && categoryMatches && searchMatches;
        }).toList();

        return PremiumGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PremiumSectionTitle(
                    title: 'Menu products',
                    subtitle: 'Tap once for standard items, select variant for configured items.',
                  ),
                  const Spacer(),
                  PremiumStatusPill(
                    label: '${products.length} available',
                    color: AppColors.restaurantEmerald,
                    icon: Icons.bolt_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: productProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.restaurantGold,
                        ),
                      )
                    : products.isEmpty
                        ? const PremiumEmptyState(
                            icon: Icons.no_meals_outlined,
                            title: 'No products in this category',
                            message:
                                'Add products or choose a different category to continue ordering.',
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 250,
                              mainAxisExtent: 250,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              return _ProductTile(
                                product: products[index],
                                table: table,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final RestaurantTable table;

  const _ProductTile({required this.product, required this.table});

  @override
  Widget build(BuildContext context) {
    final available = product.hasStock;
    return InkWell(
      onTap: available ? () => _addProduct(context) : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: product.imageUrl.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.restaurantGold.withOpacity(0.24),
                              AppColors.restaurantIndigo.withOpacity(0.18),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.dinner_dining_rounded,
                            color: AppColors.restaurantGold,
                            size: 34,
                          ),
                        ),
                      )
                    : Image.network(
                        product.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.06),
                          child: const Icon(
                            Icons.restaurant_outlined,
                            color: AppColors.restaurantGold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.restaurantInk,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.restaurantMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  product.hasVariants
                      ? 'Rs ${product.minPrice.toStringAsFixed(0)}-${product.maxPrice.toStringAsFixed(0)}'
                      : 'Rs ${product.salePrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.restaurantGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(
                  product.hasVariants
                      ? Icons.tune_rounded
                      : Icons.add_circle_rounded,
                  color: available
                      ? AppColors.restaurantEmerald
                      : AppColors.restaurantMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct(BuildContext context) async {
    if (product.hasVariants && product.activeVariants.isNotEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.restaurantCharcoal,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        builder: (context) => _VariantSheet(product: product, table: table),
      );
      return;
    }
    await _persistItem(context, product, null, table);
  }

  static Future<void> _persistItem(
    BuildContext context,
    Product product,
    ProductVariant? variant,
    RestaurantTable table,
  ) async {
    final orderProvider = context.read<TableOrderProvider>();
    final tableProvider = context.read<TableProvider>();
    await orderProvider.addToTableOrder(
      tableId: table.id,
      product: product,
      variant: variant,
    );
    await tableProvider.updateTableStatus(table.id, TableStatus.occupied);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${variant?.name ?? product.name} added to table ${table.tableNumber}'),
          backgroundColor: AppColors.restaurantPanelStrong,
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }
}

class _VariantSheet extends StatelessWidget {
  final Product product;
  final RestaurantTable table;

  const _VariantSheet({required this.product, required this.table});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose ${product.name}',
              style: const TextStyle(
                color: AppColors.restaurantInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Second click completes the add.',
              style: TextStyle(color: AppColors.restaurantMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: product.activeVariants.map((variant) {
                return InkWell(
                  onTap: () async {
                    await context.read<TableOrderProvider>().addToTableOrder(
                          tableId: table.id,
                          product: product,
                          variant: variant,
                        );
                    await context.read<TableProvider>().updateTableStatus(
                          table.id,
                          TableStatus.occupied,
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: AppColors.restaurantGold.withOpacity(0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.name,
                          style: const TextStyle(
                            color: AppColors.restaurantInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Rs ${variant.getPrice(product.salePrice).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.restaurantGold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final RestaurantTable table;

  const _OrderSummary({required this.table});

  @override
  Widget build(BuildContext context) {
    return Consumer<TableOrderProvider>(
      builder: (context, orderProvider, _) {
        final items = orderProvider.getOrderForTable(table.id);
        final subtotal = items.fold<double>(0, (sum, item) => sum + item.totalPrice);

        return PremiumGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PremiumSectionTitle(
                    title: 'Current order',
                    subtitle: 'Kitchen-ready ticket.',
                  ),
                  const Spacer(),
                  PremiumStatusPill(
                    label: 'Table ${table.tableNumber}',
                    color: AppColors.restaurantIndigo,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: items.isEmpty
                    ? const PremiumEmptyState(
                        icon: Icons.room_service_outlined,
                        title: 'No items yet',
                        message:
                            'Tap any product to start the order. Variants complete in the second click.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _OrderLineItem(
                            item: item,
                            onIncrease: () => orderProvider
                                .updateTableOrderQuantity(
                                  tableId: table.id,
                                  itemIndex: index,
                                  quantity: item.quantity + 1,
                                ),
                            onDecrease: () => orderProvider
                                .updateTableOrderQuantity(
                                  tableId: table.id,
                                  itemIndex: index,
                                  quantity: item.quantity - 1,
                                ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryRow(label: 'Subtotal', value: subtotal),
              _SummaryRow(label: 'Est. tax', value: subtotal * 0.08),
              _SummaryRow(label: 'Service', value: subtotal * 0.05),
              const Divider(color: Colors.white12, height: AppSpacing.lg),
              _SummaryRow(
                label: 'Due now',
                value: subtotal * 1.13,
                total: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: PremiumActionButton(
                      label: 'Print KOT',
                      icon: Icons.print_outlined,
                      filled: false,
                      color: AppColors.restaurantEmerald,
                      onPressed: items.isEmpty ? null : () => _printKOT(context, items),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PremiumActionButton(
                      label: 'Checkout',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: items.isEmpty
                          ? null
                          : () => context.go(
                                '${AppRouter.billing}/${table.id}',
                                extra: table,
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _printKOT(BuildContext context, List<CartItem> items) async {
    final user = context.read<AuthProvider>().currentUser;
    final pdf = await PdfService.createKOT(
      items: items,
      table: table,
      user: user,
      orderType: 'Dine In',
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

class _OrderLineItem extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _OrderLineItem({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.restaurantInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Rs ${item.unitPrice.toStringAsFixed(0)} each',
                  style: const TextStyle(
                    color: AppColors.restaurantMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
            color: AppColors.restaurantInk,
          ),
          Text(
            '${item.quantity}',
            style: const TextStyle(
              color: AppColors.restaurantInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
            color: AppColors.restaurantGold,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool total;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.total = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color:
                  total ? AppColors.restaurantInk : AppColors.restaurantMuted,
              fontWeight: total ? FontWeight.w900 : FontWeight.w600,
              fontSize: total ? 18 : 14,
            ),
          ),
          const Spacer(),
          Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color:
                  total ? AppColors.restaurantGold : AppColors.restaurantInk,
              fontWeight: FontWeight.w900,
              fontSize: total ? 20 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
