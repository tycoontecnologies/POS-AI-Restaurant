import 'package:flutter/material.dart';

class ProductItem {
  ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.salePrice,
    required this.purchasePrice,
    required this.quantity,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();
  final String id;
  String name;
  String category;
  String unit;
  double salePrice;
  double purchasePrice;
  int quantity;
  bool active;
  DateTime createdOn;
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final List<ProductItem> _products = [
    ProductItem(
      id: '1',
      name: 'Cola 330ml',
      category: 'Beverages',
      unit: 'bottle',
      salePrice: 1.20,
      purchasePrice: 0.90,
      quantity: 120,
    ),
    ProductItem(
      id: '2',
      name: 'Chips',
      category: 'Snacks',
      unit: 'pack',
      salePrice: 1.49,
      purchasePrice: 1.00,
      quantity: 50,
    ),
    ProductItem(
      id: '3',
      name: 'Notebook',
      category: 'Stationery',
      unit: 'piece',
      salePrice: 2.99,
      purchasePrice: 2.20,
      quantity: 35,
      active: false,
    ),
  ];

  final List<String> _categories = const ['Beverages', 'Snacks', 'Stationery'];
  final List<String> _units = const ['piece', 'pack', 'bottle', 'kg', 'ltr'];

  void _createOrEdit({ProductItem? item}) async {
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
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField<String>(
                value: category,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => category = v ?? category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              DropdownButtonFormField<String>(
                value: unit,
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => unit = v ?? unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              TextField(
                controller: saleCtrl,
                decoration: const InputDecoration(labelText: 'Sale Price'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: purchaseCtrl,
                decoration: const InputDecoration(labelText: 'Purchase Price'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: quantityCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Active'),
                  const SizedBox(width: 8),
                  Switch(value: isActive, onChanged: (v) => isActive = v),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final sale = double.tryParse(saleCtrl.text.trim()) ?? 0;
              final purchase = double.tryParse(purchaseCtrl.text.trim()) ?? 0;
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
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      if (item == null) {
        _products.add(
          ProductItem(
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
    });
  }

  void _delete(ProductItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true)
      setState(() => _products.removeWhere((p) => p.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                final dateStr = (DateTime d) =>
                    d.toIso8601String().substring(0, 10);
                if (isMobile) {
                  return ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final item = _products[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.category} • ${item.unit} • SP: ${item.salePrice.toStringAsFixed(2)} • PP: ${item.purchasePrice.toStringAsFixed(2)} • Qty: ${item.quantity} • ${item.active ? 'Active' : 'Inactive'} • ${dateStr(item.createdOn)}',
                          ),
                          trailing: _rowActions(item),
                        ),
                      );
                    },
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Sale Price')),
                        DataColumn(label: Text('Purchase Price')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created On')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _products
                          .map(
                            (e) => DataRow(
                              cells: [
                                DataCell(Text(e.id)),
                                DataCell(Text(e.name)),
                                DataCell(Text(e.category)),
                                DataCell(Text(e.unit)),
                                DataCell(Text(e.salePrice.toStringAsFixed(2))),
                                DataCell(
                                  Text(e.purchasePrice.toStringAsFixed(2)),
                                ),
                                DataCell(Text(e.quantity.toString())),
                                DataCell(_statusChip(e.active)),
                                DataCell(Text(dateStr(e.createdOn))),
                                DataCell(_rowActions(e)),
                              ],
                            ),
                          )
                          .toList(),
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

  Widget _statusChip(bool active) {
    return Chip(
      label: Text(active ? 'Active' : 'Inactive'),
      backgroundColor: active ? Colors.green.shade100 : Colors.grey.shade300,
      side: BorderSide.none,
    );
  }

  Widget _rowActions(ProductItem item) {
    return Wrap(
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit),
          onPressed: () => _createOrEdit(item: item),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete),
          onPressed: () => _delete(item),
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
