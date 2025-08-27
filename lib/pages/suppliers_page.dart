import 'package:flutter/material.dart';

class SupplierItem {
  SupplierItem({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  String name;
  String? contact;
  String? address;
  bool active;
  DateTime createdOn;
}

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final List<SupplierItem> _suppliers = [
    SupplierItem(
      id: '1',
      name: 'ABC Distributors',
      contact: '+92 300 0000000',
      address: 'Main Street',
    ),
    SupplierItem(
      id: '2',
      name: 'XYZ Traders',
      contact: '+92 301 1111111',
      active: false,
    ),
  ];

  void _createOrEdit({SupplierItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final contactCtrl = TextEditingController(text: item?.contact ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    bool isActive = item?.active ?? true;

    final result = await showDialog<_SupplierFormResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact No'),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(
                context,
                _SupplierFormResult(
                  name: name,
                  contact: contactCtrl.text.trim().isEmpty
                      ? null
                      : contactCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty
                      ? null
                      : addressCtrl.text.trim(),
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
        _suppliers.add(
          SupplierItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            contact: result.contact,
            address: result.address,
            active: result.active,
          ),
        );
      } else {
        item.name = result.name;
        item.contact = result.contact;
        item.address = result.address;
        item.active = result.active;
      }
    });
  }

  void _delete(SupplierItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete ${item.name}?'),
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
      setState(() => _suppliers.removeWhere((s) => s.id == item.id));
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
                  'Suppliers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
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
                    itemCount: _suppliers.length,
                    itemBuilder: (context, index) {
                      final s = _suppliers[index];
                      return Card(
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                            'Contact: ${s.contact ?? '-'} • ${s.address ?? '-'} • ${s.active ? 'Active' : 'Inactive'} • ${dateStr(s.createdOn)}',
                          ),
                          trailing: _rowActions(s),
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
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Contact No')),
                        DataColumn(label: Text('Address')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created On')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _suppliers
                          .map(
                            (s) => DataRow(
                              cells: [
                                DataCell(Text(s.name)),
                                DataCell(Text(s.contact ?? '-')),
                                DataCell(Text(s.address ?? '-')),
                                DataCell(_statusChip(s.active)),
                                DataCell(Text(dateStr(s.createdOn))),
                                DataCell(_rowActions(s)),
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

  Widget _rowActions(SupplierItem item) {
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

class _SupplierFormResult {
  _SupplierFormResult({
    required this.name,
    this.contact,
    this.address,
    required this.active,
  });
  final String name;
  final String? contact;
  final String? address;
  final bool active;
}
