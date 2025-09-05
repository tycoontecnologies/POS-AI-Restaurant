// staff_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/loading_widget.dart';
import '../models/staff.dart';
import '../providers/staff_provider.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StaffProvider>(context, listen: false);
      provider.loadStaff();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<StaffProvider>(context, listen: false);
    provider.filterStaff(_searchController.text);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final provider = Provider.of<StaffProvider>(context, listen: false);
      await provider.loadMoreStaff();
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _createOrEdit({Staff? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<StaffProvider>(context, listen: false);

    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final roleCtrl = TextEditingController(text: item?.role ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    final wageCtrl = TextEditingController(
      text: item?.dailyWage.toString() ?? '',
    );
    DateTime createdOn = item?.joinDate ?? DateTime.now();

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            title: Text(item == null ? 'Add Employee' : 'Edit Employee'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Employee Role',
                        hintText: 'e.g. Waiter',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: wageCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Daily Wage',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                      ),
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
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Join Date',
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
                text: l10n.cancel,
                variant: ButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                text: l10n.save,
                onPressed: () {
                  final wage = double.tryParse(wageCtrl.text.trim()) ?? 0;
                  if (roleCtrl.text.trim().isEmpty ||
                      nameCtrl.text.trim().isEmpty)
                    return;
                  Navigator.pop(
                    context,
                    _StaffFormResult(
                      role: roleCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      dailyWage: wage,
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
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

    try {
      if (item == null) {
        final newStaff = Staff(
          id: '', // Will be auto-generated by Firebase
          name: result.name,
          role: result.role,
          dailyWage: result.dailyWage,
          phone: result.phone,
          address: result.address,
          joinDate: result.createdOn,
        );
        await provider.addStaff(newStaff);
      } else {
        final updatedStaff = item.copyWith(
          name: result.name,
          role: result.role,
          dailyWage: result.dailyWage,
          phone: result.phone,
          address: result.address,
          joinDate: result.createdOn,
        );
        await provider.updateStaff(updatedStaff);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item == null
                  ? 'Employee added successfully'
                  : 'Employee updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _delete(Staff s) async {
    final provider = Provider.of<StaffProvider>(context, listen: false);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE),
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete Employee'),
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
      try {
        await provider.deleteStaff(s.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting employee: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<StaffProvider>(context);

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
                      l10n.staff,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage your team members',
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
                text: 'Add Employee',
                icon: Icons.person_add,
                onPressed: provider.isLoading ? null : () => _createOrEdit(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search employees...',
            onChanged: (_) => _onSearchChanged(),
            onClear: () {
              _searchController.clear();
              _onSearchChanged();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: provider.isLoading && provider.staff.isEmpty
                ? const CustomCard(
                    child: Center(
                      child: LoadingWidget(message: 'Loading staff data...'),
                    ),
                  )
                : provider.errorMessage != null
                ? CustomCard(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Error loading staff data',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            provider.errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomButton(
                            text: 'Retry',
                            onPressed: () {
                              provider.clearError();
                              provider.loadStaff(refresh: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollEndNotification &&
                          _scrollController.position.pixels ==
                              _scrollController.position.maxScrollExtent) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          _buildStaffContent(provider),

                          // Loading more indicator
                          if (_isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            ),

                          // No more items indicator
                          if (!provider.hasMore && provider.staff.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'No more staff members to load',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffContent(StaffProvider provider) {
    final staffList = provider.filteredStaff;

    if (staffList.isEmpty && _searchController.text.isEmpty) {
      return CustomCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No staff members found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add your first employee to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Add Employee',
                icon: Icons.person_add,
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),
        ),
      );
    }

    if (staffList.isEmpty && _searchController.text.isNotEmpty) {
      return CustomCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No employees found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        CustomCard(
          padding: EdgeInsets.zero,
          child: DataTableWidget(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Employee Role')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Daily Wage')),
              DataColumn(label: Text('Contact Number')),
              DataColumn(label: Text('Join Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: staffList.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;

              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(e.role)),
                  DataCell(Text(e.name)),
                  DataCell(Text('${e.dailyWage.toStringAsFixed(0)}')),
                  DataCell(Text(e.phone)),
                  DataCell(Text('${e.joinDate.toLocal()}'.split(' ').first)),
                  DataCell(StatusBadge(text: e.active ? 'Active' : 'Inactive')),
                  DataCell(_rowActions(e, provider.isLoading)),
                ],
              );
            }).toList(),
            mobileItemBuilder: (context, index) {
              final s = staffList[index];
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
                    Text('${s.role} • Wage: ${s.dailyWage.toStringAsFixed(0)}'),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Phone: ${s.phone}'),
                    if (s.address.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Address: ${s.address}'),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Join Date: ${'${s.joinDate.toLocal()}'.split(' ').first}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [_rowActions(s, provider.isLoading)],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (provider.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: LoadingWidget(message: 'Processing...'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _rowActions(Staff s, bool isLoading) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 18),
          onPressed: isLoading ? null : () => _createOrEdit(item: s),
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
          onPressed: isLoading ? null : () => _delete(s),
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

class _StaffFormResult {
  final String role;
  final String name;
  final double dailyWage;
  final String phone;
  final String address;
  final DateTime createdOn;

  _StaffFormResult({
    required this.role,
    required this.name,
    required this.dailyWage,
    required this.phone,
    required this.address,
    required this.createdOn,
  });
}
