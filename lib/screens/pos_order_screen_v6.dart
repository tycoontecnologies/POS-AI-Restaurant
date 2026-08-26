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
    final values =
        products
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to add item: $e')));
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

  Sale _buildSale({
    required String id,
    required String paymentMethod,
    String? paymentReference,
  }) {
    final user = context.read<AuthProvider>().currentUser!;
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    final info = orders.getOrderInfo(widget.table.id);
    return Sale(
      id: id,
      vendorId: user.id,
      items: items
          .map(
            (item) => SaleItem(
              productId: item.product.id,
              productName: item.displayName,
              price: item.unitPrice,
              quantity: item.quantity,
            ),
          )
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
    if (user == null ||
        orders.getOrderForTable(widget.table.id).isEmpty ||
        orderStatus != 'served') {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bill printing is enabled after the order is served.',
            ),
          ),
        );
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
    await context.read<TableOrderProvider>().setOrderStatus(
      widget.table.id,
      'served',
    );
    await context.read<TableProvider>().updateTableStatus(
      widget.table.id,
      TableStatus.served,
    );
  }

  Future<void> _checkout() async {
    final orders = context.read<TableOrderProvider>();
    final items = orders.getOrderForTable(widget.table.id);
    if (items.isEmpty || orders.getOrderStatus(widget.table.id) != 'served')
      return;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Complete payment',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Rs ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table ${widget.table.tableNumber} • Choose payment method',
                      style: const TextStyle(color: AppColors.grey500),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: methods
                          .map(
                            (m) => ChoiceChip(
                              avatar: Icon(m.icon, size: 16),
                              label: Text(m.name),
                              selected: method == m.name,
                              onSelected: (_) =>
                                  setDialogState(() => method = m.name),
                            ),
                          )
                          .toList(),
                    ),
                    if (method != 'Cash') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction / reference / cheque number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final ref = referenceController.text.trim();
                  Navigator.pop(
                    dialogContext,
                    _PaymentResult(method, ref.isEmpty ? null : ref),
                  );
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
    if (user == null || orders.getOrderForTable(widget.table.id).isEmpty)
      return;
    setState(() => _busy = true);
    try {
      final receiptId = _timestampId();
      final sale = _buildSale(
        id: receiptId,
        paymentMethod: method,
        paymentReference: reference,
      );
      await context.read<SaleProvider>().createSale(user.id, sale);
      final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => pdf.save());
      await orders.clearTableOrder(widget.table.id);
      await context.read<TableProvider>().updateTableStatus(
        widget.table.id,
        TableStatus.empty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$method payment complete • Table closed'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/tables');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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

  Widget _menuArea(
    ProductProvider provider,
    List<Product> products,
    List<String> categories,
  ) {
    return Column(
      children: [
        _CashierHeader(
          table: widget.table,
          onBack: () => context.go('/tables'),
          onSearch: (v) => setState(() => _search = v),
        ),
        _CategoryStrip(
          categories: categories,
          selected: _category,
          onSelect: (v) => setState(() => _category = v),
        ),
        Expanded(
          child: provider.isLoading && provider.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
              ? const _EmptyMenu()
              : LayoutBuilder(
                  builder: (_, c) {
                    final cols = c.maxWidth >= 1180
                        ? 5
                        : c.maxWidth >= 900
                        ? 4
                        : c.maxWidth >= 620
                        ? 3
                        : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: c.maxWidth < 620 ? 1.18 : 1.35,
                      ),
                      itemBuilder: (_, i) => _MenuTile(
                        product: products[i],
                        onTap: () => _addProduct(products[i]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
    final state = served
        ? 'served'
        : ready
        ? 'ready'
        : making
        ? 'making'
        : 'open';

    final panel = _TicketPanel(
      table: widget.table,
      items: items,
      state: state,
      busy: _busy,
      onMinus: (i) async {
        final item = items[i];
        await orders.updateTableOrderQuantity(
          tableId: widget.table.id,
          itemIndex: i,
          quantity: item.quantity - 1,
        );
        await orders.setOrderStatus(widget.table.id, 'open');
      },
      onPlus: (i) async {
        final item = items[i];
        await orders.updateTableOrderQuantity(
          tableId: widget.table.id,
          itemIndex: i,
          quantity: item.quantity + 1,
        );
        await orders.setOrderStatus(widget.table.id, 'open');
      },
      onDelete: (i) async {
        await orders.removeFromTableOrder(
          tableId: widget.table.id,
          itemIndex: i,
        );
        await orders.setOrderStatus(widget.table.id, 'open');
      },
      onKot: _sendKot,
      onBill: served ? _printBill : null,
      onServed: ready ? _markServed : null,
      onCheckout: served ? _checkout : null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            if (c.maxWidth < 850) {
              return Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: _menuArea(productProvider, products, categories),
                  ),
                  SizedBox(height: c.maxHeight * .42, child: panel),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _menuArea(productProvider, products, categories),
                ),
                SizedBox(width: c.maxWidth >= 1250 ? 410 : 360, child: panel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CashierHeader extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onBack;
  final ValueChanged<String> onSearch;
  const _CashierHeader({
    required this.table,
    required this.onBack,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
    color: Colors.white,
    child: Row(
      children: [
        _SquareAction(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Tables',
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NEW ORDER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.grey500,
                letterSpacing: .8,
              ),
            ),
            Text(
              'Table ${table.tableNumber}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search dishes, drinks or categories',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF7F7F8),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const _HeaderPill(icon: Icons.restaurant_rounded, text: 'Dine in'),
      ],
    ),
  );
}

class _CategoryStrip extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    color: Colors.white,
    child: Row(
      children: [
        const SizedBox(width: 8),
        _CategoryArrow(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous categories',
          onTap: () => _move(-320),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            scrollDirection: Axis.horizontal,
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final item = widget.categories[i];
              final active = item == widget.selected;
              return ChoiceChip(
                label: Text(item),
                selected: active,
                showCheckmark: false,
                onSelected: (_) => widget.onSelect(item),
                selectedColor: AppColors.primary,
                backgroundColor: const Color(0xFFF7F7F8),
                side: BorderSide(
                  color: active ? AppColors.primary : AppColors.outlineLight,
                ),
                labelStyle: TextStyle(
                  color: active ? Colors.white : AppColors.grey700,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 4),
        _CategoryArrow(
          icon: Icons.chevron_right_rounded,
          tooltip: 'More categories',
          onTap: () => _move(320),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );
}

class _CategoryArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CategoryArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: AppColors.grey700),
        ),
      ),
    ),
  );
}

class _MenuTile extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  const _MenuTile({required this.product, required this.onTap});
  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: hover ? 1.015 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hover
                    ? AppColors.primary.withValues(alpha: .35)
                    : AppColors.outlineLight,
              ),
              boxShadow: hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .05),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: hover
                            ? AppColors.primary
                            : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: hover ? Colors.white : AppColors.grey700,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${widget.product.salePrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TicketPanel extends StatelessWidget {
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
  const _TicketPanel({
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
    final making = state == 'making',
        ready = state == 'ready',
        served = state == 'served';
    final label = making
        ? 'IN KITCHEN'
        : ready
        ? 'READY'
        : served
        ? 'SERVED'
        : 'OPEN';
    final color = making
        ? AppColors.warning
        : ready
        ? AppColors.success
        : served
        ? AppColors.info
        : AppColors.primary;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.outlineLight)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current ticket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count item${count == 1 ? '' : 's'} • Table ${table.tableNumber}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const _EmptyTicket()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final locked = making || ready || served;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F6),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${item.quantity}×',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Rs ${item.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.grey500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!locked) ...[
                              _MiniAction(
                                icon: Icons.remove_rounded,
                                onTap: () => onMinus(i),
                              ),
                              const SizedBox(width: 3),
                              _MiniAction(
                                icon: Icons.add_rounded,
                                onTap: () => onPlus(i),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              'Rs ${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (!locked) ...[
                              const SizedBox(width: 4),
                              _MiniAction(
                                icon: Icons.close_rounded,
                                onTap: () => onDelete(i),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFCFCFD),
              border: Border(top: BorderSide(color: AppColors.outlineLight)),
            ),
            child: Column(
              children: [
                _BillLine(label: 'Items', value: '$count'),
                const SizedBox(height: 5),
                _BillLine(
                  label: 'Subtotal',
                  value: 'Rs ${total.toStringAsFixed(0)}',
                ),
                const Divider(height: 18),
                _BillLine(
                  label: 'TOTAL',
                  value: 'Rs ${total.toStringAsFixed(0)}',
                  strong: true,
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (state == 'open')
                    _PrimaryTicketButton(
                      icon: Icons.soup_kitchen_outlined,
                      text: 'Send to kitchen',
                      onTap: busy ? null : onKot,
                    )
                  else if (making)
                    const _StateBox(
                      icon: Icons.local_fire_department_outlined,
                      text: 'Kitchen is preparing this order',
                      color: AppColors.warning,
                    )
                  else if (ready)
                    _PrimaryTicketButton(
                      icon: Icons.room_service_outlined,
                      text: 'Mark served',
                      onTap: busy ? null : onServed,
                    )
                  else
                    _PrimaryTicketButton(
                      icon: Icons.payments_outlined,
                      text: 'Proceed to pay  •  Rs ${total.toStringAsFixed(0)}',
                      onTap: busy ? null : onCheckout,
                    ),
                  const SizedBox(height: 8),
                  if (onBill != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : onKot,
                            icon: const Icon(Icons.print_outlined, size: 15),
                            label: Text(
                              state == 'open' ? 'KOT' : 'Reprint KOT',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : onBill,
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 15,
                            ),
                            label: const Text('Bill'),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryTicketButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _PrimaryTicketButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SquareAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19),
      ),
    ),
  );
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 14, color: AppColors.grey700),
    ),
  );
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderPill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    ),
  );
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 34, color: AppColors.grey400),
        SizedBox(height: 8),
        Text(
          'No menu items found',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.grey600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Try another search or category',
          style: TextStyle(fontSize: 10, color: AppColors.grey500),
        ),
      ],
    ),
  );
}

class _EmptyTicket extends StatelessWidget {
  const _EmptyTicket();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_outlined, size: 34, color: AppColors.grey400),
        SizedBox(height: 8),
        Text(
          'Ticket is empty',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.grey700,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Tap a menu item to start the order',
          style: TextStyle(fontSize: 10, color: AppColors.grey500),
        ),
      ],
    ),
  );
}

class _StateBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StateBox({
    required this.icon,
    required this.text,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _BillLine({
    required this.label,
    required this.value,
    this.strong = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: strong ? 12 : 10.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
            color: strong ? AppColors.grey900 : AppColors.grey500,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: strong ? 21 : 11,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? AppColors.primaryDark : AppColors.grey900,
        ),
      ),
    ],
  );
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
