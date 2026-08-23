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
import 'package:pos/utils/app_colors.dart';

class TableOrderScreen extends StatefulWidget {
  final RestaurantTable table;
  const TableOrderScreen({super.key, required this.table});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  String _category = 'All';
  String _search = '';
  bool _loaded = false;
  bool _busy = false;
  bool _kotSent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final products = context.read<ProductProvider>();
    final categories = context.read<CategoryProvider>();
    final vendorId = categories.authProvider?.currentUser?.id;
    if (vendorId != null && products.products.isEmpty && !products.isLoading) {
      products.loadProducts(vendorId);
    }
    context.read<TableOrderProvider>().loadTableOrder(widget.table.id);
  }

  List<String> _categories(List<Product> products) {
    final values = products.map((p) => p.category).where((c) => c.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  List<Product> _visibleProducts(List<Product> products) {
    final q = _search.trim().toLowerCase();
    return products.where((p) {
      if (!p.hasStock) return false;
      if (_category != 'All' && p.category != _category) return false;
      return q.isEmpty || p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _add(Product product) async {
    final orders = context.read<TableOrderProvider>();
    final tables = context.read<TableProvider>();

    Future<void> addVariant(ProductVariant? variant, int quantity) async {
      final items = orders.getOrderForTable(widget.table.id);
      final i = items.indexWhere((x) => x.product.id == product.id && x.variant?.id == variant?.id);
      if (i >= 0) {
        await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: items[i].quantity + quantity);
      } else {
        await orders.addToTableOrder(tableId: widget.table.id, product: product, variant: variant, quantity: quantity);
      }
      await tables.updateTableStatus(widget.table.id, TableStatus.occupied);
      if (mounted) setState(() => _kotSent = false);
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
              await addVariant(variant, quantity);
            },
          ),
        );
      } else {
        await addVariant(null, 1);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _sendKot() async {
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final pdf = await PdfService.createKOT(
        items: items,
        table: widget.table,
        user: context.read<AuthProvider>().currentUser,
        orderType: 'Dine In',
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      if (!mounted) return;
      setState(() => _kotSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KOT sent to kitchen'), backgroundColor: AppColors.success));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markServed() async {
    await context.read<TableProvider>().updateTableStatus(widget.table.id, TableStatus.served);
    if (mounted) setState(() {});
  }

  Future<void> _checkout() async {
    final items = context.read<TableOrderProvider>().getOrderForTable(widget.table.id);
    if (items.isEmpty) return;
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    String method = 'Cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Complete payment'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Table ${widget.table.tableNumber}', style: const TextStyle(color: AppColors.grey500)),
              const SizedBox(height: 8),
              Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: ['Cash', 'Card', 'Online'].map((m) => ChoiceChip(label: Text(m), selected: method == m, onSelected: (_) => setDialogState(() => method = m))).toList()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Pay with $method')),
          ],
        ),
      ),
    );
    if (ok == true) await _completeSale(method);
  }

  Future<void> _completeSale(String method) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final sale = Sale(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vendorId: user.id,
        items: items.map((item) => SaleItem(productId: item.product.id, productName: item.displayName, price: item.unitPrice, quantity: item.quantity)).toList(),
        total: items.fold<double>(0, (sum, item) => sum + item.totalPrice),
        createdAt: DateTime.now(),
        tableNumber: widget.table.tableNumber,
      );
      await context.read<SaleProvider>().createSale(user.id, sale);
      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      await orders.clearTableOrder(widget.table.id);
      await context.read<TableProvider>().updateTableStatus(widget.table.id, TableStatus.empty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$method payment complete • Table closed'), backgroundColor: AppColors.success));
      context.go('/dashboard');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final orders = context.watch<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final categories = _categories(productProvider.products);
    if (!categories.contains(_category)) _category = 'All';
    final products = _visibleProducts(productProvider.products);
    final tableStatus = context.watch<TableProvider>().tables.where((t) => t.id == widget.table.id).cast<RestaurantTable?>().firstOrNull?.status ?? widget.table.status;
    final served = tableStatus == TableStatus.served;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Row(children: [
        SizedBox(width: 164, child: _CategoryRail(categories: categories, selected: _category, onSelect: (v) => setState(() => _category = v))),
        Expanded(
          child: Column(children: [
            _TopBar(table: widget.table, onBack: () => context.go('/dashboard'), onSearch: (v) => setState(() => _search = v)),
            Expanded(
              child: productProvider.isLoading && productProvider.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? const _NoProducts()
                      : LayoutBuilder(builder: (_, c) {
                          final cols = c.maxWidth >= 1050 ? 4 : c.maxWidth >= 720 ? 3 : 2;
                          return GridView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: products.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.30),
                            itemBuilder: (_, i) => _ProductCard(product: products[i], onTap: () => _add(products[i])),
                          );
                        }),
            ),
          ]),
        ),
        SizedBox(
          width: 390,
          child: _OrderPanel(
            table: widget.table,
            items: items,
            served: served,
            kotSent: _kotSent,
            busy: _busy,
            onMinus: (i) async {
              final item = items[i];
              await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity - 1);
              if (mounted) setState(() => _kotSent = false);
            },
            onPlus: (i) async {
              final item = items[i];
              await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity + 1);
              if (mounted) setState(() => _kotSent = false);
            },
            onDelete: (i) => orders.removeFromTableOrder(tableId: widget.table.id, itemIndex: i),
            onKot: _sendKot,
            onServed: _markServed,
            onCheckout: _checkout,
          ),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onBack;
  final ValueChanged<String> onSearch;
  const _TopBar({required this.table, required this.onBack, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 8),
        SizedBox(
          width: 190,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            Text('${table.numberOfSeats} seats  •  Dine In', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search food, drinks or category...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
            ),
          ),
        ),
      ]),
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
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.outlineLight))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: Text('CATEGORIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.grey400, letterSpacing: 1.1)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final c = categories[i];
              final active = c == selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Material(
                  color: active ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onSelect(c),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primaryDark : AppColors.grey700)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineLight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 20)),
              const Spacer(),
              Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 19)),
            ]),
            const Spacer(),
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey900)),
            const SizedBox(height: 4),
            Text(product.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
            const SizedBox(height: 10),
            Text('Rs ${product.salePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.grey900)),
          ]),
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  final RestaurantTable table;
  final List<dynamic> items;
  final bool served;
  final bool kotSent;
  final bool busy;
  final Future<void> Function(int) onMinus;
  final Future<void> Function(int) onPlus;
  final Future<void> Function(int) onDelete;
  final VoidCallback onKot;
  final VoidCallback onServed;
  final VoidCallback onCheckout;

  const _OrderPanel({required this.table, required this.items, required this.served, required this.kotSent, required this.busy, required this.onMinus, required this.onPlus, required this.onDelete, required this.onKot, required this.onServed, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + (item.totalPrice as double));
    final count = items.fold<int>(0, (sum, item) => sum + (item.quantity as int));
    final stage = items.isEmpty ? 1 : served ? 4 : kotSent ? 3 : 2;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: AppColors.outlineLight))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.grey900))),
              Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ]),
            const SizedBox(height: 13),
            _StageBar(stage: stage),
          ]),
        ),
        const Divider(height: 1, color: AppColors.outlineLight),
        Expanded(
          child: items.isEmpty
              ? const _EmptyOrder()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.outlineVariantLight),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Rs ${item.unitPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                          const SizedBox(height: 9),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            _Qty(icon: Icons.remove_rounded, onTap: () => onMinus(i)),
                            SizedBox(width: 32, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
                            _Qty(icon: Icons.add_rounded, onTap: () => onPlus(i)),
                          ]),
                        ])),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rs ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          IconButton(onPressed: () => onDelete(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.grey400)),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.outlineLight))),
          child: Column(children: [
            _BillLine(label: 'Items', value: '$count'),
            const SizedBox(height: 7),
            _BillLine(label: 'Subtotal', value: 'Rs ${total.toStringAsFixed(0)}'),
            const Padding(padding: EdgeInsets.symmetric(vertical: 11), child: Divider(height: 1, color: AppColors.outlineLight)),
            _BillLine(label: 'Total', value: 'Rs ${total.toStringAsFixed(0)}', strong: true),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: null, child: Text('ADD ITEMS TO START')))
            else if (!kotSent && !served)
              SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.soup_kitchen_outlined), label: const Text('SEND TO KITCHEN'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary)))
            else if (!served)
              SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(onPressed: busy ? null : onServed, icon: const Icon(Icons.room_service_outlined), label: const Text('MARK AS SERVED'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary)))
            else
              SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: busy ? null : onCheckout, icon: const Icon(Icons.payments_outlined), label: Text('CHECKOUT  •  Rs ${total.toStringAsFixed(0)}'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary))),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 40, child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 17), label: Text(kotSent ? 'REPRINT KOT' : 'PRINT KOT'))),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StageBar extends StatelessWidget {
  final int stage;
  const _StageBar({required this.stage});
  @override
  Widget build(BuildContext context) {
    const labels = ['Order', 'Kitchen', 'Serve', 'Pay'];
    return Row(children: List.generate(4, (i) {
      final active = i + 1 <= stage;
      return Expanded(child: Row(children: [
        Container(width: 20, height: 20, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.primary : AppColors.grey200), child: Text('${i + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.grey500))),
        const SizedBox(width: 4),
        Flexible(child: Text(labels[i], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.grey800 : AppColors.grey400))),
      ]));
    }));
  }
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _BillLine({required this.label, required this.value, this.strong = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 14 : 11, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: strong ? AppColors.grey900 : AppColors.grey500))),
    Text(value, style: TextStyle(fontSize: strong ? 20 : 11.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: AppColors.grey900)),
  ]);
}

class _Qty extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Qty({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.grey50, border: Border.all(color: AppColors.outlineLight), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: AppColors.grey700)),
  );
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 34, color: AppColors.grey300),
        SizedBox(height: 12),
        Text('Start building the order', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.grey800)),
        SizedBox(height: 5),
        Text('Tap any menu item to add it here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.grey500)),
      ]),
    ),
  );
}

class _NoProducts extends StatelessWidget {
  const _NoProducts();
  @override
  Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search_off_rounded, size: 34, color: AppColors.grey300),
    SizedBox(height: 10),
    Text('No menu items found', style: TextStyle(color: AppColors.grey500)),
  ]));
}
