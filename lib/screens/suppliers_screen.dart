import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/models/supplier.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
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
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    _subscription = _supplierProvider.getSuppliersStream().listen((suppliers) {
      _supplierProvider.setSuppliers(suppliers);
      // Check if has data after suppliers are loaded
      _checkIfHasData();
      setState(() {}); // To trigger rebuild
    });

    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Clean up the stream
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkIfHasData() async {
    setState(() {});
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
      text: item?.amountToReceive.toStringAsFixed(0) ?? '0.00',
    );
    final toPayCtrl = TextEditingController(
      text: item?.amountToPay.toStringAsFixed(0) ?? '0.00',
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
            content: Form(
              key: formKey, // <-- GlobalKey<FormState>
              child: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.grey300,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.grey50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                        child: FormField<String>(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }

                            // Extract just the digits for validation
                            final digitsOnly = value.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );

                            // Check if we have a reasonable number of digits
                            // (country code + phone number, typically at least 8 digits)
                            if (digitsOnly.length < 8) {
                              return 'Please enter a valid phone number';
                            }

                            return null;
                          },
                          builder: (field) => IntlPhoneField(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              errorText: field.errorText,
                              labelText: 'Phone Number',
                            ),
                            initialCountryCode: 'PK',
                            // disableLengthCheck: true,
                            keyboardType:
                                TextInputType.phone, // Numeric keyboard
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // Only allow digits
                            ],
                            onChanged: (phone) {
                              // Set full number for backend use
                              phoneCtrl.text = phone.completeNumber;

                              // Notify FormField about the change
                              field.didChange(phone.completeNumber);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      TextFormField(
                        controller: addressCtrl,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: toReceiveCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Receiveable',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (double.tryParse(value) == null) {
                                    return 'Enter valid amount';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextFormField(
                              controller: toPayCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Payable',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (double.tryParse(value) == null) {
                                    return 'Enter valid amount';
                                  }
                                }
                                return null;
                              },
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
                  if (formKey.currentState!.validate()) {
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
                  }
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
              duration: Duration(seconds: 1),
              content: Text(
                '${l10n.supplier} ${item == null ? l10n.addedSuccessfully : l10n.updatedSuccessfully}',
              ),
              backgroundColor: AppColors.success,
            ),
          );

          // Check if this was the first supplier added
          // if (item == null) {
          //   final prefs = await SharedPreferences.getInstance();
          //   final hasCompletedOnboarding =
          //       prefs.getBool('onboarding_completed') ?? false;

          //   if (!hasCompletedOnboarding) {
          //     // Mark onboarding as completed
          //     await prefs.setBool('onboarding_completed', true);

          //     // Show completion message and navigate to dashboard
          //     setState(() {
          //       _showCompletion = true;
          //     });

          //     // Navigate to dashboard after 3 seconds
          //     Future.delayed(const Duration(seconds: 3), () {
          //       if (mounted) {
          //         context.go(AppRouter.dashboard);
          //       }
          //     });
          //   }
          // }
        }
      } else {
        await _supplierProvider.updateSupplier(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
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
            duration: Duration(seconds: 1),
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
              duration: Duration(seconds: 1),
              content: Text('${l10n.supplier} ${l10n.deletedSuccessfully}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
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
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              const SizedBox(height: AppSpacing.md),

              SearchBarWidget(
                controller: _searchController,
                hint: '${l10n.search} ${l10n.suppliers}...',
                onChanged: (_) => _applyFilter(),
                onClear: () {
                  _searchController.clear();
                  _applyFilter();
                },
              ),

              const SizedBox(height: AppSpacing.sm),

              Expanded(child: _buildContent(provider, l10n)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(SupplierProvider provider, AppLocalizations l10n) {
    final suppliers = provider.filteredSuppliers;

    if (provider.isLoading) {
      return _buildShimmerTable();
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
      child: DataTableWidget(
        columns: [
          DataColumn(label: Text('#')),
          DataColumn(label: Text(l10n.name)),
          DataColumn(label: Text(l10n.contact)),
          DataColumn(label: Text(l10n.receivable)),
          DataColumn(label: Text(l10n.payable)),
          DataColumn(label: Text(l10n.address)),
          DataColumn(label: Text(l10n.createdOn)),
          DataColumn(label: Text(l10n.actions)),
        ],
        rows: suppliers.asMap().entries.map((entry) {
          int index = entry.key + 1; // +1 to start from 1 instead of 0
          var e = entry.value;
          return DataRow(
            cells: [
              DataCell(Text(index.toString())), // <-- Your numbered entry here
              DataCell(Text(e.name)),
              DataCell(Text(e.phone)),
              DataCell(
                Text(
                  e.amountToReceive.toStringAsFixed(0),
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
                  e.amountToPay.toStringAsFixed(0),
                  style: TextStyle(
                    color: e.amountToPay > 0 ? Colors.red : AppColors.grey600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    e.address.trim().isNotEmpty ? e.address : "N/A",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
              DataCell(
                Text(DateFormat('d MMM yyyy').format(e.createdOn.toLocal())),
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
                      s.amountToReceive.toStringAsFixed(0),
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
                      s.amountToPay.toStringAsFixed(0),
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

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        8,
        (index) => DataColumn(label: ShimmerEffect(width: 70, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            8,
            (index) => DataCell(ShimmerEffect(width: 70, height: 20)),
          ),
        ),
      ),
      mobileItemBuilder: (context, index) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ShimmerEffect(width: double.infinity, height: 20),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 120, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 150, height: 16),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
