import 'package:flutter/material.dart';

class StaffItem {
  StaffItem({
    required this.id,
    required this.name,
    required this.role,
    this.contactNumber,
    this.dailyWage,
    this.address,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();
  final String id;
  String name;
  String role;
  String? contactNumber;
  double? dailyWage;
  String? address;
  DateTime createdOn;
}

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final List<StaffItem> _staff = [
    StaffItem(
      id: '1',
      name: 'Alice',
      role: 'Cashier',
      contactNumber: '555-1001',
      dailyWage: 30,
      createdOn: DateTime.now().subtract(const Duration(days: 2)),
    ),
    StaffItem(
      id: '2',
      name: 'Bob',
      role: 'Manager',
      contactNumber: '555-1002',
      dailyWage: 60,
      createdOn: DateTime.now().subtract(const Duration(days: 10)),
    ),
    StaffItem(
      id: '3',
      name: 'Carol',
      role: 'Stock',
      dailyWage: 35,
      createdOn: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<String> _roles = const ['Admin', 'Manager', 'Cashier', 'Stock'];

  void _createOrEdit({StaffItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    String role = item?.role ?? _roles.first;
    final contactCtrl = TextEditingController(text: item?.contactNumber ?? '');
    final wageCtrl = TextEditingController(
      text: item?.dailyWage?.toString() ?? '',
    );
    final addressCtrl = TextEditingController(text: item?.address ?? '');

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Employee' : 'Edit Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => role = v ?? role,
                decoration: const InputDecoration(labelText: 'Employee Role'),
              ),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact number (optional)',
                ),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: wageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Daily wage (optional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
                maxLines: 2,
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
              final wage = double.tryParse(wageCtrl.text.trim());
              Navigator.pop(
                context,
                _StaffFormResult(
                  name: name,
                  role: role,
                  contactNumber: contactCtrl.text.trim().isEmpty
                      ? null
                      : contactCtrl.text.trim(),
                  dailyWage: wage,
                  address: addressCtrl.text.trim().isEmpty
                      ? null
                      : addressCtrl.text.trim(),
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
        _staff.add(
          StaffItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            role: result.role,
            contactNumber: result.contactNumber,
            dailyWage: result.dailyWage,
            address: result.address,
          ),
        );
      } else {
        item.name = result.name;
        item.role = result.role;
        item.contactNumber = result.contactNumber;
        item.dailyWage = result.dailyWage;
        item.address = result.address;
      }
    });
  }

  void _delete(StaffItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
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
    if (ok == true) setState(() => _staff.removeWhere((s) => s.id == item.id));
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
                  'Employees',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Employee'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                if (isMobile) {
                  return ListView.builder(
                    itemCount: _staff.length,
                    itemBuilder: (context, index) {
                      final item = _staff[index];
                      final created = item.createdOn
                          .toIso8601String()
                          .substring(0, 10);
                      return Card(
                        child: ListTile(
                          title: Text('${item.name} • ${item.role}'),
                          subtitle: Text(
                            'Contact: ${item.contactNumber ?? '-'}  •  Wage: ${item.dailyWage?.toStringAsFixed(2) ?? '-'}  •  Created: $created',
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
                        DataColumn(label: Text('Employee Role')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Contact Number')),
                        DataColumn(label: Text('Daily Wage')),
                        DataColumn(label: Text('Created On')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _staff
                          .map(
                            (e) => DataRow(
                              cells: [
                                DataCell(Text(e.role)),
                                DataCell(Text(e.name)),
                                DataCell(Text(e.contactNumber ?? '-')),
                                DataCell(
                                  Text(
                                    e.dailyWage == null
                                        ? '-'
                                        : e.dailyWage!.toStringAsFixed(2),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    e.createdOn.toIso8601String().substring(
                                      0,
                                      10,
                                    ),
                                  ),
                                ),
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

  Widget _rowActions(StaffItem item) {
    return Wrap(
      spacing: 8,
      children: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _createOrEdit(item: item),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _delete(item),
        ),
      ],
    );
  }
}

class _StaffFormResult {
  _StaffFormResult({
    required this.name,
    required this.role,
    this.contactNumber,
    this.dailyWage,
    this.address,
  });
  final String name;
  final String role;
  final String? contactNumber;
  final double? dailyWage;
  final String? address;
}
