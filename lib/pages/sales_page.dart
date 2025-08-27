import 'package:flutter/material.dart';
import '../state/sales_store.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final store = SalesStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = store.sales;
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
                      'Sales',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddSalePage()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Sale'),
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
                          final s = items[index];
                          return Card(
                            child: ListTile(
                              title: Text('Invoice ${s.invoiceNo}'),
                              subtitle: Text(
                                '${s.customer} • ${_dateStr(s.createdOn)} • Total ${s.total.toStringAsFixed(2)}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long),
                                    tooltip: 'View Receipt',
                                    onPressed: () => _showReceipt(context, s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        SalesStore.instance.removeSale(s.id),
                                  ),
                                ],
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
                            DataColumn(label: Text('Invoice No')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Original Price')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: [
                            for (int i = 0; i < items.length; i++)
                              DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(Text(items[i].invoiceNo)),
                                  DataCell(Text(items[i].customer)),
                                  DataCell(
                                    Text(
                                      items[i].total.toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_dateStr(items[i].createdOn))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.receipt_long),
                                          tooltip: 'View Receipt',
                                          onPressed: () =>
                                              _showReceipt(context, items[i]),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => SalesStore.instance
                                              .removeSale(items[i].id),
                                        ),
                                      ],
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

  void _showReceipt(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invoice ${sale.invoiceNo}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${sale.customer}'),
                const SizedBox(height: 8),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: [
                    for (final l in sale.lines)
                      DataRow(
                        cells: [
                          DataCell(Text(l.productName)),
                          DataCell(Text('${l.quantity}')),
                          DataCell(Text(l.unitPrice.toStringAsFixed(2))),
                          DataCell(Text(l.lineTotal.toStringAsFixed(2))),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class AddSalePage extends StatefulWidget {
  const AddSalePage({super.key});

  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  final TextEditingController _customerCtrl = TextEditingController(
    text: 'Walk In Customer',
  );
  final Map<String, _SelectableProduct> _selectables = {};

  @override
  void initState() {
    super.initState();
    // Seed with some selectable products; in a real app we would read from the products state
    final demo = [
      _SelectableProduct(name: 'Cola 330ml', price: 1.20),
      _SelectableProduct(name: 'Chips', price: 1.49),
      _SelectableProduct(name: 'Notebook', price: 2.99),
    ];
    for (final p in demo) {
      _selectables[p.name] = p;
    }
  }

  double get _total => _selectables.values
      .where((p) => p.quantity > 0)
      .fold(0, (sum, p) => sum + p.price * p.quantity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customerCtrl,
                    decoration: const InputDecoration(labelText: 'Customer'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saveSale,
                  child: const Text('Save Sale'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saveDraft,
                  child: const Text('Save Draft'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;
                  final gridCount = isMobile ? 2 : 4;
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: GridView.count(
                          crossAxisCount: gridCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: _selectables.values
                              .map((p) => _productTile(p))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _summaryCard()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTile(_SelectableProduct p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Price: ${p.price.toStringAsFixed(2)}'),
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

  Widget _summaryCard() {
    final selected = _selectables.values.where((p) => p.quantity > 0).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: selected
                    .map(
                      (p) => ListTile(
                        dense: true,
                        title: Text(p.name),
                        subtitle: Text(
                          'Qty: ${p.quantity}  •  Rate: ${p.price.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          (p.price * p.quantity).toStringAsFixed(2),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:'),
                Text(
                  _total.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveSale() {
    final lines = _selectables.values
        .where((p) => p.quantity > 0)
        .map(
          (p) => SaleLineItem(
            productName: p.name,
            unitPrice: p.price,
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
    final invoice = 'INV-$id';
    SalesStore.instance.addSale(
      Sale(
        id: id,
        invoiceNo: invoice,
        customer: _customerCtrl.text.trim().isEmpty
            ? 'Walk In Customer'
            : _customerCtrl.text.trim(),
        lines: lines,
      ),
    );
    Navigator.pop(context);
  }

  void _saveDraft() {
    final lines = _selectables.values
        .where((p) => p.quantity > 0)
        .map(
          (p) => SaleLineItem(
            productName: p.name,
            unitPrice: p.price,
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
    final invoice = 'DRAFT-$id';
    SalesStore.instance.addDraft(
      Sale(
        id: id,
        invoiceNo: invoice,
        customer: _customerCtrl.text.trim().isEmpty
            ? 'Walk In Customer'
            : _customerCtrl.text.trim(),
        lines: lines,
      ),
    );
    Navigator.pop(context);
  }
}

class _SelectableProduct {
  _SelectableProduct({required this.name, required this.price});
  final String name;
  final double price;
  int quantity = 0;
}
