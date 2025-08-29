import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../models/product.dart';
import '../services/dummy_data_service.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/custom_input.dart';
import '../components/ui/custom_dropdown.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'Beverages',
    'Snacks',
    'Stationery',
    'Electronics',
    'Clothing',
  ];
  final List<String> _units = DummyDataService.getUnits();

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
      _products = DummyDataService.getProducts();
      _filteredProducts = _products;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products
          .where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                product.category.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  void _createOrEdit({Product? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    String category = item?.category ?? _categories.first;
    String unit = item?.unit ?? _units.first;
    final saleCtrl = TextEditingController(
      text: item?.salePrice.toString() ?? '',
    );
    final purchaseCtrl = TextEditingController(
      text: item?.purchasePrice.toString() ?? '',
    );
    final quantityCtrl = TextEditingController(
      text: item?.quantity.toString() ?? '',
    );
    bool isActive = item?.active ?? true;

    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
            surfaceTintColor:
                Colors.transparent, // Prevents Material 3 color overlay

            title: Text(item == null ? l10n.addProduct : l10n.editProduct),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInput(
                      label: l10n.name,
                      controller: nameCtrl,
                      hint: 'Enter product name',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropdown<String>(
                            label: l10n.category,
                            value: category,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => category = v ?? category),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomDropdown<String>(
                            label: l10n.unit,
                            value: unit,
                            items: _units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => unit = v ?? unit),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInput(
                            label: l10n.salePrice,
                            controller: saleCtrl,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CustomInput(
                            label: l10n.purchasePrice,
                            controller: purchaseCtrl,
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: const Icon(Icons.shopping_cart),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInput(
                      label: l10n.quantity,
                      controller: quantityCtrl,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.inventory),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          l10n.active,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CustomButton(
                text: l10n.cancel,
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: l10n.save,
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    final sale = double.tryParse(saleCtrl.text.trim()) ?? 0;
                    final purchase =
                        double.tryParse(purchaseCtrl.text.trim()) ?? 0;
                    final qty = int.tryParse(quantityCtrl.text.trim()) ?? 0;
                    Navigator.pop(
                      context,
                      _ProductFormResult(
                        name: nameCtrl.text.trim(),
                        category: category,
                        unit: unit,
                        salePrice: sale,
                        purchasePrice: purchase,
                        quantity: qty,
                        active: isActive,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    setState(() {
      if (item == null) {
        _products.add(
          Product(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            category: result.category,
            unit: result.unit,
            salePrice: result.salePrice,
            purchasePrice: result.purchasePrice,
            quantity: result.quantity,
            active: result.active,
          ),
        );
      } else {
        item.name = result.name;
        item.category = result.category;
        item.unit = result.unit;
        item.salePrice = result.salePrice;
        item.purchasePrice = result.purchasePrice;
        item.quantity = result.quantity;
        item.active = result.active;
      }
      _filterProducts();
    });
  }

  void _delete(Product item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
        surfaceTintColor:
            Colors.transparent, // Prevents Material 3 color overlay

        title: Text(l10n.deleteConfirmTitle('Product')),
        content: Text(l10n.deleteConfirmMessage(item.name)),
        actions: [
          CustomButton(
            text: l10n.cancel,
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: l10n.delete,
            color: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _products.removeWhere((p) => p.id == item.id);
        _filterProducts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: Responsive.getPagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.products,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your product inventory',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: l10n.addProduct,
                icon: Icons.add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          SearchBarWidget(
            controller: _searchController,
            hint: 'Search products...',
            onChanged: (_) => _filterProducts(),
            onClear: () => _filterProducts(),
          ),

          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget(
                columns: [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text(l10n.name)),
                  DataColumn(label: Text(l10n.category)),
                  DataColumn(label: Text(l10n.unit)),
                  DataColumn(label: Text(l10n.salePrice)),
                  DataColumn(label: Text(l10n.purchasePrice)),
                  DataColumn(label: Text(l10n.quantity)),
                  DataColumn(label: Text(l10n.status)),
                  DataColumn(label: Text(l10n.actions)),
                ],
                rows: _filteredProducts
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.id)),
                          DataCell(Text(e.name)),
                          DataCell(Text(e.category)),
                          DataCell(Text(e.unit)),
                          DataCell(Text('\$${e.salePrice.toStringAsFixed(2)}')),
                          DataCell(
                            Text('\$${e.purchasePrice.toStringAsFixed(2)}'),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${e.quantity}'),
                                if (e.quantity < 20) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    Icons.warning,
                                    color: AppColors.warning,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(
                            StatusBadge(
                              text: e.active ? l10n.active : l10n.inactive,
                              variant: e.active
                                  ? BadgeVariant.success
                                  : BadgeVariant.neutral,
                            ),
                          ),
                          DataCell(_rowActions(e)),
                        ],
                      ),
                    )
                    .toList(),
                mobileItemBuilder: (context, index) {
                  final item = _filteredProducts[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusBadge(
                              text: item.active ? l10n.active : l10n.inactive,
                              variant: item.active
                                  ? BadgeVariant.success
                                  : BadgeVariant.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${item.category} • ${item.unit} • SP: \$${item.salePrice.toStringAsFixed(2)} • PP: \$${item.purchasePrice.toStringAsFixed(2)} • Qty: ${item.quantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey600),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [_rowActions(item)],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.grey600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.grey800,
          ),
        ),
      ],
    );
  }

  Widget _rowActions(Product item) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(item),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _ProductFormResult {
  _ProductFormResult({
    required this.name,
    required this.category,
    required this.unit,
    required this.salePrice,
    required this.purchasePrice,
    required this.quantity,
    required this.active,
  });
  final String name;
  final String category;
  final String unit;
  final double salePrice;
  final double purchasePrice;
  final int quantity;
  final bool active;
}
