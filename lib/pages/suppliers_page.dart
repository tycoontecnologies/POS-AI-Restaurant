import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_Supplier> _suppliers = [];
  List<_Supplier> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _suppliers = [
        _Supplier(
          name: 'ABC Traders',
          phone: '+92 300 0000001',
          address: 'Street 1, Lahore',
          active: true,
          createdOn: DateTime(2024, 2, 10),
        ),
        _Supplier(
          name: 'Global Foods',
          phone: '+92 300 0000002',
          address: 'Main Rd, Karachi',
          active: true,
          createdOn: DateTime(2023, 12, 20),
        ),
        _Supplier(
          name: 'Stationery Hub',
          phone: '+92 300 0000003',
          address: 'Bazaar, Islamabad',
          active: false,
          createdOn: DateTime(2024, 1, 5),
        ),
      ];
      _filtered = _suppliers;
    });
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _suppliers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.phone.toLowerCase().contains(q) ||
                s.address.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  void _createOrEdit({_Supplier? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    bool active = item?.active ?? true;
    DateTime createdOn = item?.createdOn ?? DateTime.now();

    final result = await showDialog<_Supplier>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(item == null ? 'Add Supplier' : 'Edit Supplier'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                      title: const Text('Active'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Created On',
                            ),
                            child: Text(
                              '${createdOn.toLocal()}'.split(' ').first,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        CustomButton(
                          text: 'Pick Date',
                          variant: ButtonVariant.outlined,
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: createdOn,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null)
                              setDialogState(() => createdOn = picked);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CustomButton(
                text: 'Cancel',
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: 'Save',
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(
                    context,
                    _Supplier(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      active: active,
                      createdOn: createdOn,
                    ),
                  );
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
        _suppliers.add(result);
      } else {
        final idx = _suppliers.indexOf(item);
        if (idx >= 0) _suppliers[idx] = result;
      }
      _applyFilter();
    });
  }

  void _delete(_Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete ${s.name}?'),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: 'Delete',
            color: Colors.red,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _suppliers.remove(s);
        _applyFilter();
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
                      l10n.suppliers,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your suppliers and vendors',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Add Supplier',
                icon: Icons.add_business,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search suppliers...',
            onChanged: (_) => _applyFilter(),
            onClear: () => _applyFilter(),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Address')),
                  DataColumn(label: Text('Created On')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _filtered
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.name)),
                          DataCell(Text(e.phone)),
                          DataCell(
                            StatusBadge(text: e.active ? 'Active' : 'Inactive'),
                          ),
                          DataCell(Text(e.address)),
                          DataCell(
                            Text('${e.createdOn.toLocal()}'.split(' ').first),
                          ),
                          DataCell(_rowActions(e)),
                        ],
                      ),
                    )
                    .toList(),
                mobileItemBuilder: (context, index) {
                  final s = _filtered[index];
                  return CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusBadge(text: s.active ? 'Active' : 'Inactive'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Phone: ${s.phone}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Address: ${s.address}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Created On: ${'${s.createdOn.toLocal()}'.split(' ').first}',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [_rowActions(s)],
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

  Widget _rowActions(_Supplier s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: s),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.1),
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(s),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.error.withOpacity(0.1),
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _Supplier {
  final String name;
  final String phone;
  final bool active;
  final String address;
  final DateTime createdOn;
  const _Supplier({
    required this.name,
    required this.phone,
    required this.address,
    required this.active,
    required this.createdOn,
  });
}
