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
    final orders = context.read<TableOrderProvider>();
    final vendorId = categories.authProvider?.currentUser?.id;
    if (vendorId != null && products.products.isEmpty && !products.isLoading) products.loadProducts(vendorId);
    orders.loadTableOrder(widget.table.id).then((_) {
      if (mounted) setState(() => _kotSent = orders.getOrderStatus(widget.table.id) == 'making');
    });
  }

  List<String> _categories(List<Product> products) {
    final values = products.map((p) => p.category).where((x) => x.trim().isNotEmpty).toSet().toList()..sort();
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
      final index = items.indexWhere((x) => x.product.id == product.id && x.variant?.id == variant?.id);
      if (index >= 0) {
        await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: index, quantity: items[index].quantity + quantity);
      } else {
        await orders.addToTableOrder(tableId: widget.table.id, product: product, variant: variant, quantity: quantity);
      }
      await orders.setOrderStatus(widget.table.id, 'open');
      await tables.updateTableStatus(widget.table.id, TableStatus.occupied);
      if (mounted) setState(() => _kotSent = false);
    }

    try {
      if (product.hasVariants && product.activeVariants.isNotEmpty) {
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
    final user = context.read<AuthProvider>().currentUser;
    if (items.isEmpty || user == null) return;
    setState(() => _busy = true);
    try {
      final pdf = await PdfService.createKOT(items: items, table: widget.table, user: user, orderType: 'Dine In');
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
      await orders.setOrderStatus(widget.table.id, 'making');
      if (!mounted) return;
      setState(() => _kotSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KOT printed • Order in Making'), backgroundColor: AppColors.success));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _billDocumentId(TableOrderProvider orders) {
    final created = orders.getOrderInfo(widget.table.id)['createdAt'];
    if (created == null) return 'bill_${widget.table.id}';
    return 'bill_${widget.table.id}_${created.hashCode}';
  }

  Sale _draftSale({required String id, required String paymentMethod, String? paymentReference}) {
    final user = context.read<AuthProvider>().currentUser!;
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final info = orders.getOrderInfo(widget.table.id);
    return Sale(
      id: id,
      vendorId: user.id,
      items: items.map((item) => SaleItem(productId: item.product.id, productName: item.displayName, price: item.unitPrice, quantity: item.quantity)).toList(),
      total: items.fold<double>(0, (sum, item) => sum + item.totalPrice),
      createdAt: DateTime.now(),
      tableNumber: widget.table.tableNumber,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      waiterId: info['waiterId']?.toString(),
      waiterName: info['waiterName']?.toString(),
    );
  }

  Future<void> _printBill() async {
    final user = context.read<AuthProvider>().currentUser;
    final orders = context.read<TableOrderProvider>();
    if (user == null || orders.getOrderForTable(widget.table.id).isEmpty) return;
    setState(() => _busy = true);
    try {
      final sale = _draftSale(id: _billDocumentId(orders), paymentMethod: 'Pending');
      final pdf = await PdfService.createBillReceipt(
        sale: sale,
        user: user,
        documentTitle: 'CUSTOMER BILL',
        documentType: 'BILL',
        showPayment: false,
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markServed() async {
    await context.read<TableOrderProvider>().setOrderStatus(widget.table.id, 'served');
    await context.read<TableProvider>().updateTableStatus(widget.table.id, TableStatus.served);
    if (mounted) setState(() {});
  }

  Future<void> _checkout() async {
    final items = context.read<TableOrderProvider>().getOrderForTable(widget.table.id);
    if (items.isEmpty) return;
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    String method = 'Cash';
    final reference = TextEditingController();
    final result = await showDialog<_PaymentResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (_, setDialogState) {
        final methods = <_PayMethod>[
          const _PayMethod('Cash', Icons.payments_outlined),
          const _PayMethod('Card', Icons.credit_card_outlined),
          const _PayMethod('Bank', Icons.account_balance_outlined),
          const _PayMethod('Cheque', Icons.receipt_long_outlined),
          const _PayMethod('JazzCash', Icons.phone_android_rounded),
          const _PayMethod('Easypaisa', Icons.phone_iphone_rounded),
          const _PayMethod('Raast', Icons.qr_code_2_rounded),
          const _PayMethod('QR', Icons.qr_code_scanner_rounded),
          const _PayMethod('Online', Icons.language_rounded),
        ];
        final needsReference = method != 'Cash';
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Complete payment'),
          content: SizedBox(
            width: 570,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Table ${widget.table.tableNumber}', style: const TextStyle(color: AppColors.grey500)),
                const SizedBox(height: 4),
                Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: methods.map((m) => ChoiceChip(
                    avatar: Icon(m.icon, size: 16),
                    label: Text(m.name),
                    selected: method == m.name,
                    onSelected: (_) => setDialogState(() => method = m.name),
                  )).toList(),
                ),
                if (needsReference) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(labelText: 'Transaction / reference / cheque number', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                  child: Text('Receipt will print “Paid via: $method”.', style: const TextStyle(fontSize: 11, color: AppColors.grey700)),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, _PaymentResult(method, reference.text.trim().isEmpty ? null : reference.text.trim())),
              child: Text('Complete • $method'),
            ),
          ],
        );
      }),
    );
    reference.dispose();
    if (result != null) await _completeSale(result.method, result.reference);
  }

  Future<void> _completeSale(String method, String? reference) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final orders = context.read<TableOrderProvider>();
    if (orders.getOrderForTable(widget.table.id).isEmpty) return;
    setState(() => _busy = true);
    try {
      final sale = _draftSale(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        paymentMethod: method,
        paymentReference: reference,
      );
      await context.read<SaleProvider>().createSale(user.id, sale);
      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
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
    final currentTable = context.watch<TableProvider>().tables.where((t) => t.id == widget.table.id).cast<RestaurantTable?>().firstOrNull;
    final served = (currentTable?.status ?? widget.table.status) == TableStatus.served || orders.getOrderStatus(widget.table.id) == 'served';
    final making = orders.getOrderStatus(widget.table.id) == 'making';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(children: [
        SizedBox(width: 154, child: _CategoryRail(categories: categories, selected: _category, onSelect: (v) => setState(() => _category = v))),
        Expanded(child: Column(children: [
          _TopBar(table: widget.table, onBack: () => context.go('/tables'), onSearch: (v) => setState(() => _search = v)),
          Expanded(
            child: productProvider.isLoading && productProvider.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? const Center(child: Text('No menu items found', style: TextStyle(color: AppColors.grey500)))
                    : LayoutBuilder(builder: (_, c) {
                        final cols = c.maxWidth >= 1050 ? 4 : c.maxWidth >= 720 ? 3 : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.38),
                          itemBuilder: (_, i) => _ProductCard(product: products[i], onTap: () => _add(products[i])),
                        );
                      }),
          ),
        ])),
        SizedBox(
          width: 390,
          child: _OrderPanel(
            table: widget.table,
            items: items,
            served: served,
            kotSent: making || _kotSent,
            busy: _busy,
            onMinus: (i) async {
              final item = items[i];
              await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity - 1);
              await orders.setOrderStatus(widget.table.id, 'open');
              if (mounted) setState(() => _kotSent = false);
            },
            onPlus: (i) async {
              final item = items[i];
              await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity + 1);
              await orders.setOrderStatus(widget.table.id, 'open');
              if (mounted) setState(() => _kotSent = false);
            },
            onDelete: (i) async {
              await orders.removeFromTableOrder(tableId: widget.table.id, itemIndex: i);
              await orders.setOrderStatus(widget.table.id, 'open');
            },
            onKot: _sendKot,
            onBill: _printBill,
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
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
    child: Row(children: [
      Tooltip(message: 'Back to Tables', child: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))),
      const SizedBox(width: 5),
      SizedBox(width: 195, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tables  /  Table ${table.tableNumber}', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        const SizedBox(height: 2),
        Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.grey900)),
      ])),
      const SizedBox(width: 12),
      Expanded(child: TextField(onChanged: onSearch, decoration: InputDecoration(hintText: 'Search items...', prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.outlineLight)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.outlineLight))))),
    ]),
  );
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryRail({required this.categories, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(14, 17, 14, 8), child: Text('CATEGORIES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.grey400, letterSpacing: 1))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: categories.length, itemBuilder: (_, i) {
        final c = categories[i]; final active = c == selected;
        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Material(color: active ? AppColors.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(8), child: InkWell(onTap: () => onSelect(c), borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primaryDark : AppColors.grey700))))));
      })),
    ]),
  );
}

class _ProductCard extends StatelessWidget {
  final Product product; final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(11), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.outlineLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 17)), const Spacer(), Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 18))]),
    const Spacer(), Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(product.category, style: const TextStyle(fontSize: 10, color: AppColors.grey500)), const SizedBox(height: 7), Text('Rs ${product.salePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
  ]))));
}

class _OrderPanel extends StatelessWidget {
  final RestaurantTable table; final List<dynamic> items; final bool served; final bool kotSent; final bool busy;
  final Future<void> Function(int) onMinus; final Future<void> Function(int) onPlus; final Future<void> Function(int) onDelete;
  final VoidCallback onKot; final VoidCallback onBill; final VoidCallback onServed; final VoidCallback onCheckout;
  const _OrderPanel({required this.table, required this.items, required this.served, required this.kotSent, required this.busy, required this.onMinus, required this.onPlus, required this.onDelete, required this.onKot, required this.onBill, required this.onServed, required this.onCheckout});
  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, x) => s + (x.totalPrice as double));
    final count = items.fold<int>(0, (s, x) => s + (x.quantity as int));
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: AppColors.outlineLight))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('Current Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 10, color: AppColors.grey500))]),
          const SizedBox(height: 8),
          if (kotSent && !served) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.soup_kitchen_outlined, size: 15, color: AppColors.warningDark), SizedBox(width: 6), Text('ORDER IN MAKING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.warningDark))])),
        ])),
        const Divider(height: 1),
        Expanded(child: items.isEmpty ? const Center(child: Text('Add items to this table', style: TextStyle(color: AppColors.grey500))) : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
          final item = items[i];
          return Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Row(children: [IconButton(onPressed: () => onMinus(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_rounded, size: 15)), Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)), IconButton(onPressed: () => onPlus(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_rounded, size: 15))])])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Rs ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)), IconButton(onPressed: () => onDelete(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.grey400))])])));
        })),
        Container(padding: const EdgeInsets.fromLTRB(15, 11, 15, 13), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.outlineLight))), child: Column(children: [
          _Line('Items', '$count'), const SizedBox(height: 5), _Line('Subtotal', 'Rs ${total.toStringAsFixed(0)}'), const Divider(height: 20), _Line('Total', 'Rs ${total.toStringAsFixed(0)}', strong: true), const SizedBox(height: 10),
          if (items.isNotEmpty) ...[
            if (!kotSent && !served) SizedBox(width: double.infinity, height: 43, child: FilledButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.soup_kitchen_outlined), label: const Text('SEND KOT')))
            else if (!served) SizedBox(width: double.infinity, height: 43, child: FilledButton.icon(onPressed: busy ? null : onServed, icon: const Icon(Icons.room_service_outlined), label: const Text('MARK SERVED')))
            else SizedBox(width: double.infinity, height: 45, child: FilledButton.icon(onPressed: busy ? null : onCheckout, icon: const Icon(Icons.payments_outlined), label: Text('CHECKOUT • Rs ${total.toStringAsFixed(0)}'))),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: SizedBox(height: 38, child: OutlinedButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.print_outlined, size: 15), label: Text(kotSent ? 'REPRINT KOT' : 'PRINT KOT')))),
              const SizedBox(width: 7),
              Expanded(child: SizedBox(height: 38, child: OutlinedButton.icon(onPressed: busy ? null : onBill, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: const Text('PRINT BILL')))),
            ]),
          ],
        ])),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label; final String value; final bool strong;
  const _Line(this.label, this.value, {this.strong = false});
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 13 : 10.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? AppColors.grey900 : AppColors.grey500))), Text(value, style: TextStyle(fontSize: strong ? 19 : 11, fontWeight: strong ? FontWeight.w900 : FontWeight.w700))]);
}

class _PaymentResult {
  final String method; final String? reference;
  const _PaymentResult(this.method, this.reference);
}

class _PayMethod {
  final String name; final IconData icon;
  const _PayMethod(this.name, this.icon);
}
