import 'dart:async';

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
import '../utils/app_colors.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late SupplierProvider _supplierProvider;
  String _searchQuery = '';
  StreamSubscription<List<Supplier>>? _subscription;

  @override
  void initState() {
    super.initState();
    _supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    _subscription = _supplierProvider.getSuppliersStream().listen((suppliers) {
      _supplierProvider.setSuppliers(suppliers);
      setState(() {}); // To trigger rebuild
    });
    _searchController.addListener(_applyFilter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Clean up the stream
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    _supplierProvider.filterSuppliers(_searchQuery);
  }

  void _createOrEdit({Supplier? item}) async {
    final l10n = AppLocalizations.of(context)!;
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
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            title: Text(item == null ? l10n.addSupplier : l10n.editSupplier),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: l10n.name),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.contactNumber,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(labelText: l10n.address),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: toReceiveCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.amountToReceive,
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
                            decoration: InputDecoration(
                              labelText: l10n.amountToPay,
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          l10n.active,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Switch(
                          value: active,
                          onChanged: (v) => setDialogState(() => active = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CustomButton(
                text: l10n.cancel,
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: l10n.save,
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

    try {
      if (item == null) {
        await _supplierProvider.addSupplier(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.supplier} ${l10n.addedSuccessfully}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await _supplierProvider.updateSupplier(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.supplier} ${l10n.updatedSuccessfully}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _delete(Supplier s) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.deleteConfirmTitle(l10n.supplier)),
        content: Text(l10n.deleteConfirmMessage(s.name)),
        actions: [
          CustomButton(
            text: l10n.cancel,
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: l10n.delete,
            color: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _supplierProvider.deleteSupplier(s.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.supplier} ${l10n.deletedSuccessfully}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.errorDeleting} ${l10n.supplier}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<SupplierProvider>(
      builder: (context, provider, child) {
        List<Supplier> suppliers = provider.filteredSuppliers;
        // Update filtered suppliers when data changes
        if (suppliers.isEmpty && provider.suppliers.isNotEmpty) {
          suppliers = List.from(provider.suppliers);
        }

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
                                color: AppColors.grey800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Manage your suppliers and vendors',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  CustomButton(
                    text: l10n.addSupplier,
                    icon: Icons.add_business,
                    onPressed: () => _createOrEdit(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              SearchBarWidget(
                controller: _searchController,
                hint: '${l10n.search} ${l10n.suppliers}...',
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
                  child: _buildContent(provider, l10n),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(SupplierProvider provider, AppLocalizations l10n) {
    final suppliers = provider.filteredSuppliers;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No suppliers found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Create First Supplier',
              onPressed: () => _createOrEdit(),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    // Handle search with no results
    if (suppliers.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No suppliers found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No results for "$_searchQuery"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Clear Search',
              onPressed: () {
                _searchController.clear();
                _applyFilter();
              },
              variant: ButtonVariant.outlined,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          DataTableWidget(
            columns: [
              DataColumn(label: Text('#')),
              DataColumn(label: Text(l10n.name)),
              DataColumn(label: Text(l10n.contact)),
              DataColumn(label: Text(l10n.receivable)),
              DataColumn(label: Text(l10n.payable)),
              DataColumn(label: Text(l10n.address)),
              DataColumn(label: Text(l10n.createdOn)),
              DataColumn(label: Text(l10n.status)),
              DataColumn(label: Text(l10n.actions)),
            ],
            rows: suppliers.asMap().entries.map((entry) {
              int index = entry.key + 1; // +1 to start from 1 instead of 0
              var e = entry.value;
              return DataRow(
                cells: [
                  DataCell(
                    Text(index.toString()),
                  ), // <-- Your numbered entry here
                  DataCell(Text(e.name)),
                  DataCell(Text(e.phone)),
                  DataCell(
                    Text(
                      e.amountToReceive.toStringAsFixed(2),
                      style: TextStyle(
                        color: e.amountToReceive > 0
                            ? Colors.green
                            : AppColors.grey600,
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
                            : AppColors.grey600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        e.address,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  DataCell(Text('${e.createdOn.toLocal()}'.split(' ').first)),
                  DataCell(
                    StatusBadge(
                      text: e.active ? l10n.active : l10n.inactive,
                      variant: e.active
                          ? BadgeVariant.success
                          : BadgeVariant.neutral,
                    ),
                  ),
                  DataCell(_rowActions(e)),
                ],
              );
            }).toList(),
            mobileItemBuilder: (context, index) {
              final s = suppliers[index];
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
                        StatusBadge(
                          text: s.active ? l10n.active : l10n.inactive,
                          variant: s.active
                              ? BadgeVariant.success
                              : BadgeVariant.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${l10n.contact}: ${s.phone}'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text('${l10n.receivable}: '),
                        Text(
                          s.amountToReceive.toStringAsFixed(2),
                          style: TextStyle(
                            color: s.amountToReceive > 0 ? Colors.green : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text('${l10n.payable}: '),
                        Text(
                          s.amountToPay.toStringAsFixed(2),
                          style: TextStyle(
                            color: s.amountToPay > 0 ? Colors.red : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${l10n.address}: ${s.address}'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.createdOn}: ${'${s.createdOn.toLocal()}'.split(' ').first}',
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

          // Show message if search has results
          if (_searchQuery.isNotEmpty && suppliers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Showing ${suppliers.length} result(s) for "$_searchQuery"',
                style: TextStyle(
                  color: AppColors.grey600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _rowActions(Supplier s) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: s),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(s),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withOpacity(0.1),
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}
