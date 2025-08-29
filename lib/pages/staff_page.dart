import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../models/staff.dart';
import '../services/dummy_data_service.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  List<Staff> _staff = [];
  List<Staff> _filtered = [];
  final TextEditingController _searchController = TextEditingController();

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
      _staff = DummyDataService.getStaff();
      _filtered = _staff;
    });
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _staff
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.role.toLowerCase().contains(q) ||
                s.phone.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  void _createOrEdit({Staff? item}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final roleCtrl = TextEditingController(text: item?.role ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    final wageCtrl = TextEditingController(
      text: item?.dailyWage.toString() ?? '',
    );
    DateTime createdOn = item?.joinDate ?? DateTime.now();

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
            surfaceTintColor:
                Colors.transparent, // Prevents Material 3 color overlay
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
        _staff.add(
          Staff(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            role: result.role,
            dailyWage: result.dailyWage,
            phone: result.phone,
            joinDate: result.createdOn,
          ),
        );
      } else {
        final idx = _staff.indexWhere((s) => s.id == item.id);
        if (idx >= 0) {
          _staff[idx] = _staff[idx].copyWith(
            name: result.name,
            role: result.role,
            dailyWage: result.dailyWage,
            phone: result.phone,
            joinDate: result.createdOn,
          );
        }
      }
      _applyFilter();
    });
  }

  void _delete(Staff s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDFDFE), // Soft off-white
        surfaceTintColor:
            Colors.transparent, // Prevents Material 3 color overlay

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
      setState(() {
        _staff.removeWhere((e) => e.id == s.id);
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
                onPressed: () => _createOrEdit(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search employees...',
            onChanged: (_) => _applyFilter(),
            onClear: () => _applyFilter(),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Employee Role')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Daily Wage')),
                  DataColumn(label: Text('Contact Number')),
                  DataColumn(label: Text('Created On')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filtered
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.id)),
                          DataCell(Text(e.role)),
                          DataCell(Text(e.name)),
                          DataCell(Text('\$${e.dailyWage.toStringAsFixed(0)}')),
                          DataCell(Text(e.phone)),
                          DataCell(
                            Text('${e.joinDate.toLocal()}'.split(' ').first),
                          ),
                          DataCell(
                            StatusBadge(text: e.active ? 'Active' : 'Inactive'),
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
                        Text(
                          '${s.role} • Wage: \$${s.dailyWage.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Phone: ${s.phone}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Created On: ${'${s.joinDate.toLocal()}'.split(' ').first}',
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

  Widget _rowActions(Staff s) {
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

class _StaffFormResult {
  final String role;
  final String name;
  final double dailyWage;
  final String phone;
  final DateTime createdOn;
  _StaffFormResult({
    required this.role,
    required this.name,
    required this.dailyWage,
    required this.phone,
    required this.createdOn,
  });
}
