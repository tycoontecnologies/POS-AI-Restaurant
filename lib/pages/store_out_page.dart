import 'package:flutter/material.dart';
import '../state/store_out_store.dart';

class StoreOutPage extends StatelessWidget {
  const StoreOutPage({super.key});

  String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final store = StoreOutStore.instance;
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
                      'Store Out',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddStoreOutPage(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Store Out'),
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
                          final so = items[index];
                          return Card(
                            child: ListTile(
                              title: Text('Store Out #${so.id}'),
                              subtitle: Text(
                                '${_dateStr(so.createdOn)} • Total ${so.total.toStringAsFixed(2)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    StoreOutStore.instance.remove(so.id),
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
                            DataColumn(label: Text('No')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Created On')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: [
                            for (int i = 0; i < items.length; i++)
                              DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(
                                    Text(items[i].total.toStringAsFixed(2)),
                                  ),
                                  DataCell(Text(_dateStr(items[i].createdOn))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => StoreOutStore.instance
                                          .remove(items[i].id),
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

class AddStoreOutPage extends StatefulWidget {
  const AddStoreOutPage({super.key});

  @override
  State<AddStoreOutPage> createState() => _AddStoreOutPageState();
}

class _AddStoreOutPageState extends State<AddStoreOutPage> {
  final Map<String, _SelectableStoreProduct> _products = {};

  @override
  void initState() {
    super.initState();
    final demo = [
      _SelectableStoreProduct(name: 'Sugar', unit: 'Kilo', price: 92),
      _SelectableStoreProduct(name: 'test', unit: 'Gram', price: 100),
      _SelectableStoreProduct(name: 'test2', unit: 'Gram', price: 5),
    ];
    for (final p in demo) {
      _products[p.name] = p;
    }
  }

  double get _total => _products.values
      .where((p) => p.quantity > 0)
      .fold(0, (s, p) => s + p.price * p.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Store Out')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Receipt Price'),
                    const SizedBox(width: 12),
                    Text(
                      _total.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Include in Kitchen'),
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
          ],
        ),
      ),
    );
  }

  Widget _tile(_SelectableStoreProduct p) {
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
    final lines = _products.values
        .where((p) => p.quantity > 0)
        .map(
          (p) => StoreOutLineItem(
            product: p.name,
            unit: p.unit,
            price: p.price,
            quantity: p.quantity,
          ),
        )
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one product')),
      );
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    StoreOutStore.instance.add(StoreOut(id: id, lines: lines));
    Navigator.pop(context);
  }
}

class _SelectableStoreProduct {
  _SelectableStoreProduct({
    required this.name,
    required this.unit,
    required this.price,
  });
  final String name;
  final String unit;
  final double price;
  int quantity = 0;
}
