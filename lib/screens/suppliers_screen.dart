import 'package:flutter/material.dart';
import 'package:pos/models/supplier.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../providers/supplier_provider.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late SupplierProvider _supplierProvider;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    _supplierProvider.filterSuppliers(_searchController.text);
  }

  // In the _createOrEdit method, add text fields for financial information:
  void _createOrEdit({Supplier? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    final toReceiveCtrl = TextEditingController(
      text: item?.amountToReceive.toStringAsFixed(2) ?? '0.00',
    );
    final toPayCtrl = TextEditingController(
      text: item?.amountToPay.toStringAsFixed(2) ?? '0.00',
    );
    bool active = item?.active ?? true;
    DateTime createdOn = item?.createdOn ?? DateTime.now();

    final result = await showDialog<Supplier>(
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: toReceiveCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amount to Receive',
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: toPayCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amount to Pay',
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // ... rest of the existing fields
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
                    Supplier(
                      id: item?.id ?? '',
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      active: active,
                      createdOn: createdOn,
                      amountToReceive:
                          double.tryParse(toReceiveCtrl.text) ?? 0.0,
                      amountToPay: double.tryParse(toPayCtrl.text) ?? 0.0,
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

    if (item == null) {
      await _supplierProvider.addSupplier(result);
    } else {
      await _supplierProvider.updateSupplier(result);
    }
  }

  void _delete(Supplier s) async {
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
      await _supplierProvider.deleteSupplier(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<Supplier>>(
      stream: _supplierProvider.getSuppliersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _supplierProvider.setSuppliers(snapshot.data!);
        }

        return Consumer<SupplierProvider>(
          builder: (context, provider, child) {
            final filteredSuppliers = provider.filteredSuppliers;

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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Manage your suppliers and vendors',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.8),
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
                    onClear: () {
                      _searchController.clear();
                      _applyFilter();
                    },
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
                          DataColumn(label: Text('Receiveable')),
                          DataColumn(label: Text('Payable')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Created On')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: filteredSuppliers
                            .map(
                              (e) => DataRow(
                                cells: [
                                  DataCell(Text(e.name)),
                                  DataCell(Text(e.phone)),
                                  DataCell(
                                    Text(
                                      e.amountToReceive.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: e.amountToReceive > 0
                                            ? Colors.green
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      e.amountToPay.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: e.amountToPay > 0
                                            ? Colors.red
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(e.address)),
                                  DataCell(
                                    Text(
                                      '${e.createdOn.toLocal()}'
                                          .split(' ')
                                          .first,
                                    ),
                                  ),
                                  DataCell(_rowActions(e)),
                                ],
                              ),
                            )
                            .toList(),
                        mobileItemBuilder: (context, index) {
                          final s = filteredSuppliers[index];
                          return CustomCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    StatusBadge(
                                      text: s.active ? 'Active' : 'Inactive',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text('Phone: ${s.phone}'),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Text('Receiveable: '),
                                    Text(
                                      s.amountToReceive.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: s.amountToReceive > 0
                                            ? Colors.green
                                            : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Text('Payable: '),
                                    Text(
                                      s.amountToPay.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: s.amountToPay > 0
                                            ? Colors.red
                                            : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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
          },
        );
      },
    );
  }

  Widget _rowActions(Supplier s) {
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
