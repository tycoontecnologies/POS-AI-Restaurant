import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pos/components/premium/premium_restaurant_ui.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_order_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/pdf_service.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class PremiumBillingScreen extends StatefulWidget {
  final RestaurantTable table;

  const PremiumBillingScreen({super.key, required this.table});

  @override
  State<PremiumBillingScreen> createState() => _PremiumBillingScreenState();
}

class _PremiumBillingScreenState extends State<PremiumBillingScreen> {
  String _paymentMethod = 'Cash';
  double _discount = 0;
  double _tip = 0;
  bool _partialPayment = false;
  bool _splitPayment = false;
  bool _processing = false;
  bool _didLoad = false;

  static const List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Online',
    'Room Charge',
    'Credit Customer',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableOrderProvider>().loadTableOrder(widget.table.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumRestaurantScaffold(
      eyebrow: 'Luxury checkout',
      title: 'Bill Table ${widget.table.tableNumber}',
      subtitle:
          'Settle fast with cash, card, online, split, partial, room charge, or credit customer workflows.',
      actions: [
        PremiumActionButton(
          label: 'Back to order',
          icon: Icons.arrow_back_rounded,
          filled: false,
          onPressed: () => context.go(
            '${AppRouter.ordering}/${widget.table.id}',
            extra: widget.table,
          ),
        ),
      ],
      child: Consumer<TableOrderProvider>(
        builder: (context, orderProvider, _) {
          final items = orderProvider.getOrderForTable(widget.table.id);
          final subtotal = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
          final tax = subtotal * 0.08;
          final service = subtotal * 0.05;
          final total = subtotal + tax + service + _tip - _discount;

          final guestCheck = PremiumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PremiumSectionTitle(
                      title: 'Guest check',
                      subtitle: 'Review items before settlement.',
                    ),
                    const Spacer(),
                    PremiumStatusPill(
                      label: '${items.length} lines',
                      color: AppColors.restaurantIndigo,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: items.isEmpty
                      ? const PremiumEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No active check',
                          message:
                              'Add items from the ordering workspace before billing this table.',
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _BillLine(item: item);
                          },
                        ),
                ),
              ],
            ),
          );

          final settlement = PremiumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSectionTitle(
                  title: 'Settlement',
                  subtitle: 'Premium billing without spreadsheet friction.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _paymentMethods.map((method) {
                    final selected = method == _paymentMethod;
                    return ChoiceChip(
                      label: Text(method),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _paymentMethod = method);
                      },
                      selectedColor:
                          AppColors.restaurantGold.withOpacity(0.24),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      side: BorderSide(
                        color: selected
                            ? AppColors.restaurantGold.withOpacity(0.5)
                            : Colors.white.withOpacity(0.08),
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.restaurantGold
                            : AppColors.restaurantInk,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final discount = _MoneyAdjuster(
                      label: 'Discount',
                      value: _discount,
                      icon: Icons.percent,
                      onChanged: (value) => setState(() => _discount = value),
                    );
                    final tip = _MoneyAdjuster(
                      label: 'Tips',
                      value: _tip,
                      icon: Icons.volunteer_activism_outlined,
                      onChanged: (value) => setState(() => _tip = value),
                    );
                    if (compact) {
                      return Column(
                        children: [
                          discount,
                          const SizedBox(height: AppSpacing.sm),
                          tip,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: discount),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: tip),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile.adaptive(
                  value: _splitPayment,
                  onChanged: (value) => setState(() => _splitPayment = value),
                  activeColor: AppColors.restaurantGold,
                  title: const Text(
                    'Split payment',
                    style: TextStyle(color: AppColors.restaurantInk),
                  ),
                  subtitle: const Text(
                    'Divide by guest, amount, or selected items.',
                    style: TextStyle(color: AppColors.restaurantMuted),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _partialPayment,
                  onChanged: (value) => setState(() => _partialPayment = value),
                  activeColor: AppColors.restaurantGold,
                  title: const Text(
                    'Partial payment',
                    style: TextStyle(color: AppColors.restaurantInk),
                  ),
                  subtitle: const Text(
                    'Keep remainder open for the table.',
                    style: TextStyle(color: AppColors.restaurantMuted),
                  ),
                ),
                const Spacer(),
                _TotalsBox(
                  subtotal: subtotal,
                  tax: tax,
                  discount: _discount,
                  service: service,
                  tip: _tip,
                  total: total,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: PremiumActionButton(
                        label: 'Print',
                        icon: Icons.print_outlined,
                        filled: false,
                        onPressed: items.isEmpty
                            ? null
                            : () => _printBill(context, items, subtotal),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PremiumActionButton(
                        label: _processing ? 'Settling' : 'Settle',
                        icon: Icons.check_rounded,
                        onPressed: items.isEmpty || _processing
                            ? null
                            : () => _settle(context, items, subtotal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1050) {
                return Column(
                  children: [
                    Expanded(child: guestCheck),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(child: settlement),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: guestCheck),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 4, child: settlement),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<Sale?> _createSale(BuildContext context, List<CartItem> items) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;
    return Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      vendorId: user.id,
      items: items.map((item) {
        return SaleItem(
          productId: item.product.id,
          productName: item.displayName,
          price: item.unitPrice,
          quantity: item.quantity,
        );
      }).toList(),
      total: items.fold<double>(0, (sum, item) => sum + item.totalPrice),
      createdAt: DateTime.now(),
      tableNumber: widget.table.tableNumber,
    );
  }

  Future<void> _printBill(
    BuildContext context,
    List<CartItem> items,
    double subtotal,
  ) async {
    final sale = await _createSale(context, items);
    final user = context.read<AuthProvider>().currentUser;
    if (sale == null) return;
    final pdf = await PdfService.createBillReceipt(sale: sale, user: user);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _settle(
    BuildContext context,
    List<CartItem> items,
    double subtotal,
  ) async {
    setState(() => _processing = true);
    try {
      final auth = context.read<AuthProvider>();
      final sale = await _createSale(context, items);
      if (sale == null || auth.currentUser == null) return;

      await context.read<SaleProvider>().createSale(auth.currentUser!.id, sale);
      if (!_partialPayment) {
        await context.read<TableOrderProvider>().clearTableOrder(widget.table.id);
        await context.read<TableProvider>().updateTableStatus(
              widget.table.id,
              TableStatus.empty,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _partialPayment
                  ? 'Partial ${_paymentMethod.toLowerCase()} payment recorded'
                  : 'Table ${widget.table.tableNumber} settled by $_paymentMethod',
            ),
            backgroundColor: AppColors.restaurantPanelStrong,
          ),
        );
        context.go(AppRouter.floorPlan);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $error'),
            backgroundColor: AppColors.restaurantCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _BillLine extends StatelessWidget {
  final CartItem item;

  const _BillLine({required this.item});

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
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.restaurantGold.withOpacity(0.13),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: AppColors.restaurantGold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    color: AppColors.restaurantInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Rs ${item.unitPrice.toStringAsFixed(0)} each',
                  style: const TextStyle(color: AppColors.restaurantMuted),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.restaurantInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyAdjuster extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final ValueChanged<double> onChanged;

  const _MoneyAdjuster({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.restaurantGold, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.restaurantMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (raw) => onChanged(double.tryParse(raw) ?? 0),
            style: const TextStyle(color: AppColors.restaurantInk),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rs ',
              prefixStyle: const TextStyle(color: AppColors.restaurantMuted),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBox extends StatelessWidget {
  final double subtotal;
  final double tax;
  final double discount;
  final double service;
  final double tip;
  final double total;

  const _TotalsBox({
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.service,
    required this.tip,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.restaurantGold.withOpacity(0.16),
            Colors.white.withOpacity(0.055),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.restaurantGold.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          _TotalLine('Subtotal', subtotal),
          _TotalLine('Tax', tax),
          _TotalLine('Discount', -discount),
          _TotalLine('Service charges', service),
          _TotalLine('Tips', tip),
          const Divider(color: Colors.white24, height: AppSpacing.lg),
          _TotalLine('Total', total < 0 ? 0 : total, total: true),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double value;
  final bool total;

  const _TotalLine(this.label, this.value, {this.total = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: total ? AppColors.restaurantInk : AppColors.restaurantMuted,
              fontWeight: total ? FontWeight.w900 : FontWeight.w600,
              fontSize: total ? 20 : 14,
            ),
          ),
          const Spacer(),
          Text(
            '${value < 0 ? '-' : ''}Rs ${value.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: total ? AppColors.restaurantGold : AppColors.restaurantInk,
              fontWeight: FontWeight.w900,
              fontSize: total ? 22 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
