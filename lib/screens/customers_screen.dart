import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/models/customer.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../utils/app_spacing.dart';
import '../providers/customer_provider.dart';
import '../utils/app_colors.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late CustomerProvider _customerProvider;
  String _searchQuery = '';
  StreamSubscription<List<Customer>>? _subscription;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    _subscription = _customerProvider.getCustomersStream().listen((customers) {
      _customerProvider.setCustomers(customers);
      setState(() {});
    });

    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    _customerProvider.filterCustomers(_searchQuery);
  }

  void _createOrEdit({Customer? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final emailCtrl = TextEditingController(text: item?.email ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    final cityCtrl = TextEditingController(text: item?.city ?? '');
    bool active = item?.active ?? true;
    DateTime createdOn = item?.createdOn ?? DateTime.now();

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            title: Text(item == null ? 'Add Customer' : 'Edit Customer'),
            content: Form(
              key: formKey,
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
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(value)) {
                              return 'Enter a valid email';
                            }
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
                            final digitsOnly = value.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
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
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (phone) {
                              phoneCtrl.text = phone.completeNumber;
                              field.didChange(phone.completeNumber);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Text(
                            'Active',
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
                text: 'Cancel',
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: 'Save',
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      Customer(
                        id: item?.id ?? '',
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        city: cityCtrl.text.trim().isEmpty
                            ? null
                            : cityCtrl.text.trim(),
                        active: active,
                        createdOn: createdOn,
                        totalSpent: item?.totalSpent ?? 0.0,
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
        await _customerProvider.addCustomer(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Customer added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await _customerProvider.updateCustomer(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Customer updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _delete(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${c.name}?'),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: ButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          CustomButton(
            text: 'Delete',
            color: AppColors.error,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _customerProvider.deleteCustomer(c.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Customer deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text('Error deleting customer: $e'),
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

    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        List<Customer> customers = provider.filteredCustomers;
        if (customers.isEmpty && provider.customers.isNotEmpty) {
          customers = List.from(provider.customers);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          'Customers',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.grey800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Manage your customers and their feedback',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  CustomButton(
                    text: 'Add Customer',
                    icon: Icons.person_add,
                    onPressed: () => _createOrEdit(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SearchBarWidget(
                controller: _searchController,
                hint: 'Search customers...',
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

  Widget _buildContent(CustomerProvider provider, AppLocalizations l10n) {
    final customers = provider.filteredCustomers;

    if (provider.isLoading) {
      return _buildShimmerTable();
    }

    if (provider.customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No customers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Create First Customer',
              onPressed: () => _createOrEdit(),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (customers.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No customers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
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
          const DataColumn(label: Text('#')),
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Phone')),
          const DataColumn(label: Text('Address')),
          const DataColumn(label: Text('Created')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: customers.asMap().entries.map((entry) {
          int index = entry.key + 1;
          var c = entry.value;
          return DataRow(
            cells: [
              DataCell(Text(index.toString())),
              DataCell(Text(c.name)),
              DataCell(Text(c.email ?? 'No email')),
              DataCell(Text(c.phone)),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    c.address,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              DataCell(
                Text(DateFormat('d MMM yyyy').format(c.createdOn.toLocal())),
              ),
              DataCell(_rowActions(c)),
            ],
          );
        }).toList(),
        mobileItemBuilder: (context, index) {
          final c = customers[index];
          return CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    StatusBadge(
                      text: c.active ? 'Active' : 'Inactive',
                      variant: c.active
                          ? BadgeVariant.success
                          : BadgeVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Email: ${c.email}'),
                const SizedBox(height: AppSpacing.xs),
                Text('Phone: ${c.phone}'),
                const SizedBox(height: AppSpacing.xs),
                Text('Address: ${c.address}'),
                const SizedBox(height: AppSpacing.xs),
                Text('Total Spent: ${c.totalSpent.toStringAsFixed(2)}'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_rowActions(c)],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rowActions(Customer c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _createOrEdit(item: c),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _delete(c),
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
                  const SizedBox(width: AppSpacing.sm),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 120, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 100, height: 16),
              const SizedBox(height: AppSpacing.sm),
              ShimmerEffect(width: 150, height: 16),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShimmerEffect(
                    width: 36,
                    height: 36,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: AppSpacing.xs),
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
