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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
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
    final values = products
        .map((p) => p.category)
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<Product> _visibleProducts(List<Product> products) {
    final q = _search.trim().toLowerCase();
    return products.where((p) {
      if (!p.hasStock) return false;
      if (_category != 'All' && p.category != _category) return false;
      return q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addProduct(Product product) async {
    final orders = context.read<TableOrderProvider>();
    final tables = context.read<TableProvider>();

    Future<void> add(ProductVariant? variant, int quantity) async {
      final items = orders.getOrderForTable(widget.table.id);
      final index = items.indexWhere(
        (x) => x.product.id == product.id && x.variant?.id == variant?.id,
      );
      if (index >= 0) {
        await orders.updateTableOrderQuantity(
          tableId: widget.table.id,
          itemIndex: index,
          quantity: items[index].quantity + quantity,
        );
      } else {
        await orders.addToTableOrder(
          tableId: widget.table.id,
          product: product,
          variant: variant,
          quantity: quantity,
        );
      }
      await orders.setOrderStatus(widget.table.id, 'open');
      await tables.updateTableStatus(widget.table.id, TableStatus.occupied);
    }

    try {
      if (product.hasVariants && product.activeVariants.isNotEmpty) {
        if (!mounted) return;
        await showDialog<void>(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add item: $e')),
        );
      }
    }
  }

  String _timestampId() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}${two(d.month)}${two(d.year % 100)}${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  Future<void> _sendKot() async {
    final orders = context.read<TableOrderProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final items = orders.getOrderForTable(widget.table.id);
    if (user == null || items.isEmpty) return;

    setState(() => _busy = true);
    try {
      final info = orders.getOrderInfo(widget.table.id);
      final kotNumber = (info['kotNumber'] ?? '').toString().trim().isEmpty
          ? _timestampId()
          : info['kotNumber'].toString();
      await orders.setOrderStatus(widget.table.id, 'making');
      await orders.setOrderMeta(widget.table.id, {
        'kotNumber': kotNumber,
        'kotSentAt': DateTime.now(),
      });

      final pdf = await PdfService.createKOT(
        items: items,
        table: widget.table,
        user: user,
        orderType: 'Dine In',
        kotNumber: kotNumber,
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KOT Sent to Kitchen'),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Sale _buildSale({required String id, required String paymentMethod, String? paymentReference}) {
    final user = context.read<AuthProvider>().currentUser!;
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final info = orders.getOrderInfo(widget.table.id);
    return Sale(
      id: id,
      vendorId: user.id,
      items: items
          .map((item) => SaleItem(
                productId: item.product.id,
                productName: item.displayName,
                price: item.unitPrice,
                quantity: item.quantity,
              ))
          .toList(),
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
    final orders = context.read<TableOrderProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final orderStatus = orders.getOrderStatus(widget.table.id);
    if (user == null || orders.getOrderForTable(widget.table.id).isEmpty || orderStatus != 'served') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill printing is enabled after the order is served.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final info = orders.getOrderInfo(widget.table.id);
      final billId = (info['billNumber'] ?? '').toString().trim().isEmpty
          ? _timestampId()
          : info['billNumber'].toString();
      await orders.setOrderMeta(widget.table.id, {'billNumber': billId});
      final sale = _buildSale(id: billId, paymentMethod: 'Pending');
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
  }

  Future<void> _checkout() async {
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty || orders.getOrderStatus(widget.table.id) != 'served') return;

    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    String method = 'Cash';
    final referenceController = TextEditingController();

    final result = await showDialog<_PaymentResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          const methods = [
            _PayMethod('Cash', Icons.payments_outlined),
            _PayMethod('Card', Icons.credit_card_outlined),
            _PayMethod('Bank', Icons.account_balance_outlined),
            _PayMethod('Cheque', Icons.receipt_long_outlined),
            _PayMethod('JazzCash', Icons.phone_android_rounded),
            _PayMethod('Easypaisa', Icons.phone_iphone_rounded),
            _PayMethod('Raast', Icons.qr_code_2_rounded),
            _PayMethod('QR', Icons.qr_code_scanner_rounded),
            _PayMethod('Online', Icons.language_rounded),
          ];
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Checkout'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Table ${widget.table.tableNumber}', style: const TextStyle(color: AppColors.grey500)),
                    const SizedBox(height: 4),
                    Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    const Text('Paid via', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: methods
                          .map((m) => ChoiceChip(
                                avatar: Icon(m.icon, size: 16),
                                label: Text(m.name),
                                selected: method == m.name,
                                onSelected: (_) => setDialogState(() => method = m.name),
                              ))
                          .toList(),
                    ),
                    if (method != 'Cash') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction / reference / cheque number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Receipt will show: Paid via $method', style: const TextStyle(fontSize: 11, color: AppColors.grey600)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final ref = referenceController.text.trim();
                  Navigator.pop(dialogContext, _PaymentResult(method, ref.isEmpty ? null : ref));
                },
                child: Text('Complete • $method'),
              ),
            ],
          );
        },
      ),
    );
    referenceController.dispose();
    if (result != null) await _completeSale(result.method, result.reference);
  }

  Future<void> _completeSale(String method, String? reference) async {
    final user = context.read<AuthProvider>().currentUser;
    final orders = context.read<TableOrderProvider>();
    if (user == null || orders.getOrderForTable(widget.table.id).isEmpty) return;

    setState(() => _busy = true);
    try {
      final receiptId = _timestampId();
      final sale = _buildSale(id: receiptId, paymentMethod: method, paymentReference: reference);
      await context.read<SaleProvider>().createSale(user.id, sale);
      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
      await orders.clearTableOrder(widget.table.id);
      await context.read<TableProvider>().updateTableStatus(widget.table.id, TableStatus.empty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$method payment complete • Table closed'), backgroundColor: AppColors.success),
      );
      context.go('/tables');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  RestaurantTable? _currentTable(List<RestaurantTable> tables) {
    for (final table in tables) {
      if (table.id == widget.table.id) return table;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final orders = context.watch<TableOrderProvider>();
    final tableProvider = context.watch<TableProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final categories = _categories(productProvider.products);
    if (!categories.contains(_category)) _category = 'All';
    final products = _visibleProducts(productProvider.products);
    final currentTable = _currentTable(tableProvider.tables);
    final orderStatus = orders.getOrderStatus(widget.table.id);
    final tableStatus = currentTable?.status ?? widget.table.status;
    final served = orderStatus == 'served' || tableStatus == TableStatus.served;
    final ready = orderStatus == 'ready';
    final making = orderStatus == 'making';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          SizedBox(
            width: 150,
            child: _CategoryRail(categories: categories, selected: _category, onSelect: (v) => setState(() => _category = v)),
          ),
          Expanded(
            child: Column(
              children: [
                _OrderTopBar(
                  table: widget.table,
                  onBack: () => context.go('/tables'),
                  onSearch: (v) => setState(() => _search = v),
                ),
                Expanded(
                  child: productProvider.isLoading && productProvider.products.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : products.isEmpty
                          ? const Center(child: Text('No menu items found', style: TextStyle(color: AppColors.grey500)))
                          : LayoutBuilder(
                              builder: (_, c) {
                                final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 700 ? 3 : 2;
                                return GridView.builder(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: products.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.45,
                                  ),
                                  itemBuilder: (_, i) => _ProductCard(product: products[i], onTap: () => _addProduct(products[i])),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 390,
            child: _OrderPanel(
              table: widget.table,
              items: items,
              state: served ? 'served' : ready ? 'ready' : making ? 'making' : 'open',
              busy: _busy,
              onMinus: (i) async {
                final item = items[i];
                await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity - 1);
                await orders.setOrderStatus(widget.table.id, 'open');
              },
              onPlus: (i) async {
                final item = items[i];
                await orders.updateTableOrderQuantity(tableId: widget.table.id, itemIndex: i, quantity: item.quantity + 1);
                await orders.setOrderStatus(widget.table.id, 'open');
              },
              onDelete: (i) async {
                await orders.removeFromTableOrder(tableId: widget.table.id, itemIndex: i);
                await orders.setOrderStatus(widget.table.id, 'open');
              },
              onKot: _sendKot,
              onBill: served ? _printBill : null,
              onServed: ready ? _markServed : null,
              onCheckout: served ? _checkout : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTopBar extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onBack;
  final ValueChanged<String> onSearch;
  const _OrderTopBar({required this.table, required this.onBack, required this.onSearch});

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.outlineLight))),
        child: Row(children: [
          IconButton(tooltip: 'Back to Tables', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 6),
          SizedBox(
            width: 190,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tables / POS', style: TextStyle(fontSize: 10, color: AppColors.grey500)),
              const SizedBox(height: 2),
              Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.outlineLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.outlineLight)),
              ),
            ),
          ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 17, 14, 8),
            child: Text('CATEGORIES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.grey400, letterSpacing: 1)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final category = categories[i];
                final active = category == selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: active ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onSelect(category),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primaryDark : AppColors.grey700),
                        ),
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outlineLight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 16)),
                const Spacer(),
                Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
              ]),
              const Spacer(),
              Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(product.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
              const SizedBox(height: 7),
              Text('Rs ${product.salePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class _OrderPanel extends StatelessWidget {
  final RestaurantTable table;
  final List<dynamic> items;
  final String state;
  final bool busy;
  final Future<void> Function(int) onMinus;
  final Future<void> Function(int) onPlus;
  final Future<void> Function(int) onDelete;
  final VoidCallback onKot;
  final VoidCallback? onBill;
  final VoidCallback? onServed;
  final VoidCallback? onCheckout;

  const _OrderPanel({
    required this.table,
    required this.items,
    required this.state,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
    required this.onKot,
    required this.onBill,
    required this.onServed,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final count = items.fold<int>(0, (sum, item) => sum + item.quantity as int);
    final making = state == 'making';
    final ready = state == 'ready';
    final served = state == 'served';
    final statusLabel = making
        ? 'ORDER IN MAKING'
        : ready
            ? 'READY TO SERVE'
            : served
                ? 'SERVED • CHECKOUT READY'
                : 'ORDER OPEN';
    final statusColor = making
        ? AppColors.warning
        : ready
            ? AppColors.success
            : served
                ? AppColors.info
                : AppColors.primary;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: AppColors.outlineLight))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Current Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              Text('Table ${table.tableNumber}', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
              child: Text(statusLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: statusColor)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Add items to this table', style: TextStyle(color: AppColors.grey500)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Rs ${item.unitPrice.toStringAsFixed(0)} each', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
                            const SizedBox(height: 4),
                            Row(children: [
                              IconButton(onPressed: making || ready || served ? null : () => onMinus(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_rounded, size: 15)),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              IconButton(onPressed: making || ready || served ? null : () => onPlus(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_rounded, size: 15)),
                            ]),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rs ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(onPressed: making || ready || served ? null : () => onDelete(i), visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.grey400)),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 11, 15, 13),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.outlineLight))),
          child: Column(children: [
            _BillLine(label: 'Items', value: '$count'),
            const SizedBox(height: 5),
            _BillLine(label: 'Subtotal', value: 'Rs ${total.toStringAsFixed(0)}'),
            const Divider(height: 20),
            _BillLine(label: 'Total', value: 'Rs ${total.toStringAsFixed(0)}', strong: true),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (state == 'open')
                SizedBox(width: double.infinity, height: 43, child: FilledButton.icon(onPressed: busy ? null : onKot, icon: const Icon(Icons.soup_kitchen_outlined), label: const Text('SEND KOT')))
              else if (making)
                _StateBox(icon: Icons.soup_kitchen_outlined, text: 'Kitchen is preparing this order', color: AppColors.warning)
              else if (ready)
                SizedBox(width: double.infinity, height: 43, child: FilledButton.icon(onPressed: busy ? null : onServed, icon: const Icon(Icons.room_service_outlined), label: const Text('MARK SERVED')))
              else if (served)
                SizedBox(width: double.infinity, height: 45, child: FilledButton.icon(onPressed: busy ? null : onCheckout, icon: const Icon(Icons.payments_outlined), label: Text('CHECKOUT • Rs ${total.toStringAsFixed(0)}'))),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onKot,
                      icon: const Icon(Icons.print_outlined, size: 15),
                      label: Text(state == 'open' ? 'PRINT KOT' : 'REPRINT KOT'),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onBill,
                      icon: const Icon(Icons.receipt_long_outlined, size: 15),
                      label: const Text('PRINT BILL'),
                    ),
                  ),
                ),
              ]),
              if (!served)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Print Bill unlocks after the order is served.', style: TextStyle(fontSize: 9, color: AppColors.grey500)),
                ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StateBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StateBox({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _BillLine({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 13 : 10.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? AppColors.grey900 : AppColors.grey500))),
        Text(value, style: TextStyle(fontSize: strong ? 19 : 11, fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      ]);
}

class _PaymentResult {
  final String method;
  final String? reference;
  const _PaymentResult(this.method, this.reference);
}

class _PayMethod {
  final String name;
  final IconData icon;
  const _PayMethod(this.name, this.icon);
}
