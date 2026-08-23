import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pos/components/ui/simple_variant_selector.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/category_provider.dart';
import 'package:pos/providers/product_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/services/pdf_service.dart';
import 'package:pos/services/sale_service.dart';
import 'package:pos/utils/app_colors.dart';

class TableOrderScreen extends StatefulWidget {
  final RestaurantTable table;
  const TableOrderScreen({super.key, required this.table});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  final SaleService _saleService = SaleService();
  String _selectedCategory = 'All';
  String _search = '';
  bool _bootstrapped = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;

    final products = context.read<ProductProvider>();
    final categories = context.read<CategoryProvider>();
    final orders = context.read<TableOrderProvider>();
    final vendorId = categories.authProvider?.currentUser?.id;

    if (vendorId != null && products.products.isEmpty && !products.isLoading) {
      products.loadProducts(vendorId);
    }
    orders.loadTableOrder(widget.table.id);
  }

  List<String> _categories(List<Product> products) {
    final values = products.map((e) => e.category).where((e) => e.isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<Product> _filteredProducts(List<Product> products) {
    return products.where((p) {
      if (!p.hasStock) return false;
      final categoryOk = _selectedCategory == 'All' || p.category == _selectedCategory;
      final q = _search.trim().toLowerCase();
      final searchOk = q.isEmpty || p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
      return categoryOk && searchOk;
    }).toList();
  }

  Future<void> _addProduct(Product product) async {
    final orders = context.read<TableOrderProvider>();
    final tables = context.read<TableProvider>();

    Future<void> add(ProductVariant? variant, int quantity) async {
      final current = orders.getOrderForTable(widget.table.id);
      final index = current.indexWhere((item) => item.product.id == product.id && item.variant?.id == variant?.id);
      if (index >= 0) {
        await orders.updateTableOrderQuantity(
          tableId: widget.table.id,
          itemIndex: index,
          quantity: current[index].quantity + quantity,
        );
      } else {
        await orders.addToTableOrder(
          tableId: widget.table.id,
          product: product,
          variant: variant,
          quantity: quantity,
        );
      }
      await tables.updateTableStatus(widget.table.id, TableStatus.occupied);
    }

    try {
      if (product.hasVariants && product.activeVariants.isNotEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (dialogContext) => SimpleVariantSelector(
            product: product,
            onAddToCart: (variant, quantity) async {
              Navigator.of(dialogContext).pop();
              await add(variant, quantity);
            },
          ),
        );
      } else {
        await add(null, 1);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _sendKot() async {
    final orders = context.read<TableOrderProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty) return;

    setState(() => _busy = true);
    try {
      final pdf = await PdfService.createKOT(
        items: items,
        table: widget.table,
        user: user,
        orderType: 'Dine In',
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order sent to kitchen'), backgroundColor: AppColors.success),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markServed() async {
    await context.read<TableProvider>().updateTableStatus(widget.table.id, TableStatus.served);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Table ${widget.table.tableNumber} marked served'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _checkout() async {
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty) return;

    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    String method = 'Cash';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Checkout'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Table ${widget.table.tableNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Total  Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Cash', 'Card', 'Online'].map((value) {
                    return ChoiceChip(
                      label: Text(value),
                      selected: method == value,
                      onSelected: (_) => setDialogState(() => method = value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Complete $method Payment')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await _completeSale(method);
  }

  Future<void> _completeSale(String paymentMethod) async {
    final orders = context.read<TableOrderProvider>();
    final tables = context.read<TableProvider>();
    final saleProvider = context.read<SaleProvider>();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty) return;

    setState(() => _busy = true);
    try {
      final sale = Sale(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vendorId: user.id,
        items: items.map((item) => SaleItem(
          productId: item.product.id,
          productName: item.displayName,
          price: item.unitPrice,
          quantity: item.quantity,
        )).toList(),
        total: items.fold<double>(0, (sum, item) => sum + item.totalPrice),
        createdAt: DateTime.now(),
        tableNumber: widget.table.tableNumber,
      );

      await _saleService.createSale(user.id, sale);
      await saleProvider.createSale(user.id, sale);

      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

      await orders.clearTableOrder(widget.table.id);
      await tables.updateTableStatus(widget.table.id, TableStatus.empty);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$paymentMethod payment completed • Table closed'), backgroundColor: AppColors.success),
      );
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductProvider>();
    final orders = context.watch<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final categories = _categories(productsProvider.products);
    if (!categories.contains(_selectedCategory)) _selectedCategory = 'All';
    final products = _filteredProducts(productsProvider.products);
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final served = widget.table.status == TableStatus.served;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        children: [
          SizedBox(
            width: 178,
            child: _CategoryRail(
              categories: categories,
              selected: _selectedCategory,
              onSelect: (value) => setState(() => _selectedCategory = value),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _OrderHeader(
                  table: widget.table,
                  search: _search,
                  onSearch: (value) => setState(() => _search = value),
                  onBack: () => context.go('/dashboard'),
                ),
                Expanded(
                  child: productsProvider.isLoading && productsProvider.products.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : products.isEmpty
                          ? const Center(child: Text('No menu items found', style: TextStyle(color: AppColors.grey500)))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 760 ? 3 : 2;
                                return GridView.builder(
                                  padding: const EdgeInsets.all(18),
                                  itemCount: products.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.55,
                                  ),
                                  itemBuilder: (_, index) => _ProductTile(product: products[index], onTap: () => _addProduct(products[index])),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 370,
            child: _BillPanel(
              table: widget.table,
              items: items,
              total: total,
              served: served,
              busy: _busy,
              onMinus: (index) async {
                final item = items[index];
                await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: index, quantity: item.quantity - 1);
              },
              onPlus: (index) async {
                final item = items[index];
                await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: index, quantity: item.quantity + 1);
              },
              onDelete: (index) => orders.removeFromTableOrder(tableId: widget.table.id, itemIndex: index),
              onKot: _sendKot,
              onServed: _markServed,
              onCheckout: _checkout,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final RestaurantTable table;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;
  const _OrderHeader({required this.table, required this.search, required this.onSearch, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Table ${table.tableNumber}', style: const TextStyle(color: AppColors.grey900, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${table.numberOfSeats} seats • Dine In', style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search menu...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppColors.grey50,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.outlineLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.outlineLight)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryRail({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.outlineLight))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text('MENU', style: TextStyle(color: AppColors.grey400, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final category = categories[i];
                final active = category == selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: active ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => onSelect(category),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.grey700, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                      ),
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

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 20),
              ),
              const Spacer(),
              Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(product.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey500, fontSize: 10)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Rs ${product.salePrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.grey900, fontSize: 14, fontWeight: FontWeight.w800))),
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillPanel extends StatelessWidget {
  final RestaurantTable table;
  final List<dynamic> items;
  final double total;
  final bool served;
  final bool busy;
  final Future<void> Function(int) onMinus;
  final Future<void> Function(int) onPlus;
  final Future<void> Function(int) onDelete;
  final VoidCallback onKot;
  final VoidCallback onServed;
  final VoidCallback onCheckout;

  const _BillPanel({
    required this.table,
    required this.items,
    required this.total,
    required this.served,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
    required this.onKot,
    required this.onServed,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = items.fold<int>(0, (sum, item) => sum + (item.quantity as int));
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.outlineLight))),
      child: Column(
        children: [
          Container(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Order', style: TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('Table ${table.tableNumber} • ${served ? 'Served' : items.isEmpty ? 'New order' : 'In service'}', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: served ? AppColors.successSoft : AppColors.warningSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text(served ? 'SERVED' : 'ACTIVE', style: TextStyle(color: served ? AppColors.successDark : AppColors.warningDark, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Add menu items to begin', style: TextStyle(color: AppColors.grey500, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.outlineVariantLight),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                                  const SizedBox(height: 3),
                                  Text('Rs ${item.unitPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.grey500, fontSize: 10.5)),
                                  const SizedBox(height: 7),
                                  Row(children: [
                                    _MiniButton(icon: Icons.remove_rounded, onTap: () => onMinus(index)),
                                    SizedBox(width: 30, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                                    _MiniButton(icon: Icons.add_rounded, onTap: () => onPlus(index)),
                                  ]),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Rs ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                IconButton(onPressed: () => onDelete(index), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.grey400), visualDensity: VisualDensity.compact),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.outlineLight))),
            child: Column(
              children: [
                Row(children: [const Expanded(child: Text('Items', style: TextStyle(color: AppColors.grey500, fontSize: 11))), Text('$itemCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 6),
                Row(children: [const Expanded(child: Text('Subtotal', style: TextStyle(color: AppColors.grey500, fontSize: 11))), Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: AppColors.outlineLight)),
                Row(children: [const Expanded(child: Text('TOTAL', style: TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w700))), Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.grey900, fontSize: 19, fontWeight: FontWeight.w800))]),
                const SizedBox(height: 12),
                if (items.isNotEmpty && !served) ...[
                  SizedBox(width: double.infinity, height: 44, child: FilledButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.soup_kitchen_outlined, size: 18), label: const Text('SEND TO KITCHEN'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary))),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: busy ? null : onServed, icon: const Icon(Icons.room_service_outlined, size: 18), label: const Text('MARK SERVED'))),
                ] else if (items.isNotEmpty && served) ...[
                  SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(onPressed: busy ? null : onCheckout, icon: const Icon(Icons.payments_outlined, size: 18), label: Text('CHECKOUT • Rs ${total.toStringAsFixed(0)}'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary))),
                ] else
                  const SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: null, child: Text('ADD ITEMS TO START'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.outlineLight)),
        child: Icon(icon, size: 15, color: AppColors.grey700),
      ),
    );
  }
}
