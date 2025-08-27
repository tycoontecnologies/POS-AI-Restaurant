import 'package:flutter/material.dart';

class CategoryItem {
  CategoryItem({
    required this.id,
    required this.name,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();
  final String id;
  String name;
  bool active;
  DateTime createdOn;
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final List<CategoryItem> _categories = [
    CategoryItem(id: '1', name: 'Beverages', active: true),
    CategoryItem(id: '2', name: 'Snacks', active: true),
    CategoryItem(id: '3', name: 'Stationery', active: false),
  ];

  void _createOrEdit({CategoryItem? item}) async {
    final controller = TextEditingController(text: item?.name ?? '');
    bool isActive = item?.active ?? true;

    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? 'Add Category' : 'Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Name'),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _CategoryFormResult(
                    name: controller.text.trim(),
                    active: isActive,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (item == null) {
        _categories.add(
          CategoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            active: result.active,
          ),
        );
      } else {
        item.name = result.name;
        item.active = result.active;
      }
    });
  }

  void _delete(CategoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
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
    if (ok == true) {
      setState(() => _categories.removeWhere((c) => c.id == item.id));
    }
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
                  'Categories',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                final dateStr = (DateTime d) =>
                    d.toIso8601String().substring(0, 10);
                if (isMobile) {
                  return ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final item = _categories[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.active ? 'Active' : 'Inactive'} • Created: ${dateStr(item.createdOn)}',
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
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created On')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _categories
                          .map(
                            (e) => DataRow(
                              cells: [
                                DataCell(Text(e.id)),
                                DataCell(Text(e.name)),
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

  Widget _rowActions(CategoryItem item) {
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

class _CategoryFormResult {
  _CategoryFormResult({required this.name, required this.active});
  final String name;
  final bool active;
}
