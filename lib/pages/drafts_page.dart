import 'package:flutter/material.dart';
import '../state/sales_store.dart';
import 'sales_page.dart';

class DraftsPage extends StatelessWidget {
  const DraftsPage({super.key});

  String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final store = SalesStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = store.drafts;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drafts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddSalePage()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Draft'),
                  ),
                ],
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
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    SalesStore.instance.removeDraft(s.id),
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
                            DataColumn(label: Text('Delete')),
                          ],
                          rows: [
                            for (int i = 0; i < items.length; i++)
                              DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(Text(items[i].invoiceNo)),
                                  DataCell(Text(items[i].customer)),
                                  DataCell(
                                    Text(items[i].total.toStringAsFixed(2)),
                                  ),
                                  DataCell(Text(_dateStr(items[i].createdOn))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => SalesStore.instance
                                          .removeDraft(items[i].id),
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
