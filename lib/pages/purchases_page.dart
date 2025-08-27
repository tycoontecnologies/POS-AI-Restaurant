import 'package:flutter/material.dart';
import '../state/purchases_store.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final store = PurchasesStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = store.items;
        final total = items.fold<double>(0, (s, e) => s + e.total);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Purchases',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddPurchasePage(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Purchase'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    if (isMobile) {
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final p = items[index];
                          return Card(
                            child: ListTile(
                              title: Text('Invoice ${p.invoiceNo}'),
                              subtitle: Text(
                                '${p.supplier} • ${_dateStr(p.createdOn)} • ${p.total.toStringAsFixed(2)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    PurchasesStore.instance.remove(p.id),
                              ),
                            ),
                          );
                        },
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Invoice No')),
                            DataColumn(label: Text('Supplier')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Created On')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: [
                            for (final p in items)
                              DataRow(
                                cells: [
                                  DataCell(Text(p.invoiceNo)),
                                  DataCell(Text(p.supplier)),
                                  DataCell(Text(p.total.toStringAsFixed(2))),
                                  DataCell(Text(_dateStr(p.createdOn))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () =>
                                          PurchasesStore.instance.remove(p.id),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
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

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  final TextEditingController _invoiceCtrl = TextEditingController();
  String _supplier = 'Please Select';

  // Demo supplier list and products; later can be wired to suppliers/products stores
  final List<String> _suppliers = const [
    'Please Select',
    'ABC Distributors',
    'XYZ Traders',
  ];

  final Map<String, _SelectablePurchaseProduct> _products = {
    'Sugar': _SelectablePurchaseProduct(name: 'Sugar', unit: 'Kilo', price: 92),
    'test': _SelectablePurchaseProduct(name: 'test', unit: 'Gram', price: 100),
    'test2': _SelectablePurchaseProduct(name: 'test2', unit: 'Gram', price: 5),
  };

  double get _total => _products.values
      .where((p) => p.quantity > 0)
      .fold(0, (sum, p) => sum + p.price * p.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Purchase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _supplier,
                            items: _suppliers
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _supplier = v ?? _supplier),
                            decoration: const InputDecoration(
                              labelText: 'Supplier',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _invoiceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invoice No',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Receipt Price'),
                              Text(
                                _total.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;
                  final gridCount = isMobile ? 2 : 3;
                  return GridView.count(
                    crossAxisCount: gridCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: _products.values.map(_tile).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add Purchase'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(_SelectablePurchaseProduct p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Unit: ${p.unit}  •  Price: ${p.price.toStringAsFixed(2)}'),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(
                    () => p.quantity = (p.quantity - 1).clamp(0, 9999),
                  ),
                ),
                Text('${p.quantity}'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => p.quantity = p.quantity + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final inv = _invoiceCtrl.text.trim();
    final sup = _supplier;
    if (inv.isEmpty || sup == 'Please Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select supplier and enter invoice no')),
      );
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    PurchasesStore.instance.add(
      Purchase(id: id, invoiceNo: inv, supplier: sup, total: _total),
    );
    Navigator.pop(context);
  }
}

class _SelectablePurchaseProduct {
  _SelectablePurchaseProduct({
    required this.name,
    required this.unit,
    required this.price,
  });
  final String name;
  final String unit;
  final double price;
  int quantity = 0;
}
