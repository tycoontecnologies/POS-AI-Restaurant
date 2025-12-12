// staff_screen.dart - COMBINED VERSION WITH STAFF AND ATTENDANCE
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pos/components/ui/custom_input.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/data_table_widget.dart';
import '../models/staff.dart';
import '../models/attendance.dart';
import '../providers/staff_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_spacing.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _initialLoadComplete = false;
  bool _isProcessing = false;

  // For attendance tab
  DateTime _selectedDate = DateTime.now();
  String? _vendorId;
  late TabController _tabController;
  List<Staff> _filteredStaff = [];
  String _searchQuery = '';

  // Tutorial keys
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _staffTableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _vendorId = authProvider.currentUser?.id;

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfHasData();
      _loadAttendanceData();
    });
  }

  Future<void> _checkIfHasData() async {
    final provider = Provider.of<StaffProvider>(context, listen: false);
    await provider.loadStaff();
    setState(() {
      _initialLoadComplete = true;
    });
  }

  void _loadAttendanceData() {
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );

    // Load staff data
    staffProvider.loadStaff(refresh: true);

    // Pre-load today's attendance
    attendanceProvider.getAttendanceByDate(_selectedDate).first.then((_) {
      // Data loaded
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_tabController.index == 0) {
      // Staff tab search
      final provider = Provider.of<StaffProvider>(context, listen: false);
      provider.filterStaff(_searchController.text);
    } else {
      // Attendance tab search
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterStaff();
      });
    }
  }

  void _filterStaff() {
    final staffProvider = context.read<StaffProvider>();
    if (_searchQuery.isEmpty) {
      _filteredStaff = List.from(staffProvider.staff);
    } else {
      _filteredStaff = staffProvider.staff.where((staff) {
        return staff.name.toLowerCase().contains(_searchQuery) ||
            staff.role.toLowerCase().contains(_searchQuery);
      }).toList();
    }
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

  bool _getAttendanceStatus(String staffId, List<Attendance> todayAttendance) {
    final attendance = todayAttendance.firstWhere(
      (a) => a.staffId == staffId,
      orElse: () =>
          Attendance.create(staffId: staffId, staffName: '', dailyWage: 0),
    );
    return attendance.isPresent;
  }

  Future<void> _markAttendance(
    Staff staff,
    bool isPresent,
    AttendanceProvider attendanceProvider,
  ) async {
    try {
      final existingAttendance = await attendanceProvider
          .getAttendanceByStaffAndDate(staff.id, _selectedDate);

      if (existingAttendance != null) {
        // Update existing attendance
        final updatedAttendance = existingAttendance.copyWith(
          isPresent: isPresent,
          updatedAt: DateTime.now(),
        );
        await attendanceProvider.markAttendance(updatedAttendance);
      } else {
        // Create new attendance record
        final newAttendance = Attendance.create(
          staffId: staff.id,
          staffName: staff.name,
          dailyWage: staff.dailyWage,
          date: _selectedDate,
          isPresent: isPresent,
        ).copyWith(vendorId: _vendorId);
        await attendanceProvider.markAttendance(newAttendance);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text(
              '${staff.name} marked as ${isPresent ? 'Present' : 'Absent'}',
            ),
            backgroundColor: isPresent ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text('Error updating attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Staff CRUD methods (same as before)
  void _createOrEdit({Staff? item}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

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

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Validation functions
          String? validateRequired(String? value, String fieldName) {
            if (value == null || value.isEmpty) {
              return '$fieldName is required';
            }
            return null;
          }

          String? validateWage(String? value) {
            if (value == null || value.isEmpty) {
              return null; // Wage is optional
            }
            final wage = double.tryParse(value);
            if (wage == null) {
              return 'Please enter a valid number';
            }
            if (wage < 0) {
              return 'Wage cannot be negative';
            }
            return null;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFFDFDFE),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              item == null ? 'Add Employee' : 'Edit Employee',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// Employee Role
                      CustomInput(
                        label: 'Employee Role',
                        hint: 'e.g. Waiter',
                        controller: roleCtrl,
                        validator: (value) => validateRequired(value, 'Role'),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Name
                      CustomInput(
                        label: 'Name',
                        controller: nameCtrl,
                        validator: (value) => validateRequired(value, 'Name'),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Daily Wage
                      CustomInput(
                        label: 'Daily Wage',
                        controller: wageCtrl,
                        validator: validateWage,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Phone Number
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
                      const SizedBox(height: AppSpacing.sm),

                      /// Address
                      CustomInput(
                        label: 'Address',
                        controller: addressCtrl,
                        maxLines: 1,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      /// Join Date
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Join Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Text(
                                  '${createdOn.toLocal()}'.split(' ').first,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            height: 48,
                            child: CustomButton(
                              text: 'Pick Date',
                              variant: ButtonVariant.outlined,
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: createdOn,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setDialogState(() => createdOn = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            actionsAlignment: MainAxisAlignment.end,
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
                    final wage = double.tryParse(wageCtrl.text.trim()) ?? 0;
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
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      if (item == null) {
        final newStaff = Staff(
          id: '',
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
            duration: Duration(seconds: 1),
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
            duration: Duration(seconds: 1),
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _delete(Staff s) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

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
              duration: Duration(seconds: 1),
              content: Text('Employee deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text('Error deleting employee: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = Provider.of<StaffProvider>(context);

    if (!_initialLoadComplete) {
      if (staffProvider.errorMessage != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${staffProvider.errorMessage}'),
              ElevatedButton(
                onPressed: () => _checkIfHasData(),
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }
      return _buildShimmerTable();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondaryDark,
        toolbarHeight: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          // indicator: BoxDecoration(color: Colors.white),
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: 'Staff Management'),
            Tab(text: 'Attendance'),
          ],
          onTap: (index) {
            setState(() {
              _searchController.clear();
              if (index == 1) {
                _filteredStaff = List.from(staffProvider.staff);
              }
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab Content
            // Search Bar and Add Button Row
            Row(
              children: [
                // Search Bar (only for current tab)
                if (_tabController.index == 0 || _tabController.index == 1)
                  Expanded(
                    child: SearchBarWidget(
                      key: _searchBarKey,
                      controller: _searchController,
                      hint: _tabController.index == 0
                          ? 'Search employees...'
                          : 'Search for attendance...',
                      onChanged: (_) => _onSearchChanged(),
                      onClear: () {
                        _searchController.clear();
                        _onSearchChanged();
                      },
                    ),
                  ),

                // Add Button (only for Staff Management tab)
                if (_tabController.index == 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: CustomButton(
                      key: _addButtonKey,
                      text: 'Add Employee',
                      icon: Icons.person_add,
                      onPressed: (staffProvider.isLoading || _isProcessing)
                          ? null
                          : () => _createOrEdit(),
                    ),
                  ),

                // Date Picker for Attendance Tab
                if (_tabController.index == 1)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Row(
                      children: [
                        Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Change Date',
                          icon: Icons.calendar_today,
                          variant: ButtonVariant.outlined,
                          onPressed: _selectDate,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              key: _staffTableKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Staff Management Tab
                  _buildStaffContent(staffProvider),

                  // Attendance Tab
                  _buildAttendanceContent(),
                ],
              ),
            ),
          ],
        ),
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
                onPressed: _isProcessing ? null : () => _createOrEdit(),
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

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        width: double.infinity,
        child: DataTableWidget(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Employee Role')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Daily Wage')),
            DataColumn(label: Text('Contact Number')),
            DataColumn(label: Text('Join Date')),
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
                DataCell(Text(e.dailyWage.toStringAsFixed(0))),
                DataCell(Text(e.phone)),
                DataCell(
                  Text(DateFormat('d MMM yyyy').format(e.joinDate.toLocal())),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: _isProcessing
                            ? null
                            : () => _createOrEdit(item: e),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: _isProcessing ? null : () => _delete(e),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withOpacity(0.1),
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAttendanceContent() {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(context);

    // Update filtered staff when staff data changes
    if (_filteredStaff.isEmpty && staffProvider.staff.isNotEmpty) {
      _filteredStaff = List.from(staffProvider.staff);
    }

    if (staffProvider.isLoading && staffProvider.staff.isEmpty) {
      return _buildShimmerAttendanceTable();
    }

    if (staffProvider.errorMessage != null) {
      return Center(
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
            Text(staffProvider.errorMessage!),
            const SizedBox(height: AppSpacing.md),
            CustomButton(
              text: 'Retry',
              onPressed: () => staffProvider.loadStaff(refresh: true),
              variant: ButtonVariant.filled,
            ),
          ],
        ),
      );
    }

    if (staffProvider.staff.isEmpty) {
      return Center(
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
              'Add staff members to manage attendance',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_filteredStaff.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
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
              'No staff members found',
              style: Theme.of(context).textTheme.titleLarge,
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
                _onSearchChanged();
              },
              variant: ButtonVariant.outlined,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<Attendance>>(
      stream: attendanceProvider.getAttendanceByDate(_selectedDate),
      builder: (context, attendanceSnapshot) {
        if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerAttendanceTable();
        }

        if (attendanceSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Error loading attendance: ${attendanceSnapshot.error}'),
              ],
            ),
          );
        }

        final todayAttendance = attendanceSnapshot.data ?? [];
        attendanceProvider.updateAttendanceList(todayAttendance);

        return SingleChildScrollView(
          child: DataTableWidget(
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Employee Role')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Daily Wage')),
              DataColumn(label: Text('Attendance')),
            ],
            rows: _filteredStaff.asMap().entries.map((entry) {
              final index = entry.key;
              final staff = entry.value;
              final isPresent = _getAttendanceStatus(staff.id, todayAttendance);

              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(staff.role)),
                  DataCell(Text(staff.name)),
                  DataCell(Text(staff.dailyWage.toStringAsFixed(0))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: isPresent,
                          onChanged: attendanceProvider.isLoading
                              ? null
                              : (value) => _markAttendance(
                                  staff,
                                  true,
                                  attendanceProvider,
                                ),
                        ),
                        const Text('Present'),
                        const SizedBox(width: AppSpacing.sm),
                        Radio<bool>(
                          value: false,
                          groupValue: isPresent,
                          onChanged: attendanceProvider.isLoading
                              ? null
                              : (value) => _markAttendance(
                                  staff,
                                  false,
                                  attendanceProvider,
                                ),
                        ),
                        const Text('Absent'),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildShimmerTable() {
    return DataTableWidget(
      columns: List.generate(
        7,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            7,
            (index) => DataCell(ShimmerEffect(width: 80, height: 20)),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerAttendanceTable() {
    return DataTableWidget(
      columns: List.generate(
        5,
        (index) => DataColumn(label: ShimmerEffect(width: 80, height: 20)),
      ),
      rows: List.generate(
        5,
        (index) => DataRow(
          cells: List.generate(
            5,
            (index) => DataCell(
              index == 4
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShimmerEffect(
                          width: 20,
                          height: 20,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        ShimmerEffect(width: 40, height: 20),
                        SizedBox(width: AppSpacing.sm),
                        ShimmerEffect(
                          width: 20,
                          height: 20,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        ShimmerEffect(width: 40, height: 20),
                      ],
                    )
                  : ShimmerEffect(width: 80, height: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper class to pass form results
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
