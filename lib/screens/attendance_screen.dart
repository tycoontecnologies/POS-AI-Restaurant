import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos/providers/staff_provider.dart';
import 'package:pos/screens/monthly_attendance_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/staff.dart';
import 'package:pos/models/attendance.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../components/ui/loading_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  List<Staff> _staff = [];
  List<Staff> _filteredStaff = [];
  int _entriesPerPage = 10;
  int _currentPage = 1;
  DateTime _selectedDate = DateTime.now();
  String? _vendorId;
  late TabController _tabController;

  List<Staff> get _pageItems {
    final start = (_currentPage - 1) * _entriesPerPage;
    final end = (start + _entriesPerPage).clamp(0, _filteredStaff.length);
    return _filteredStaff.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _vendorId = authProvider.currentUser?.id;

    // Load staff data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      staffProvider.loadStaff(refresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _filterStaff(String query) {
    setState(() {
      _filteredStaff = _staff
          .where(
            (staff) =>
                staff.name.toLowerCase().contains(query.toLowerCase()) ||
                staff.role.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      _currentPage = 1;
    });
  }

  bool _getAttendanceStatus(String staffId, List<Attendance> todayAttendance) {
    final attendance = todayAttendance.firstWhere(
      (a) => a.staffId == staffId,
      orElse: () =>
          Attendance.create(staffId: staffId, staffName: '', dailyWage: 0),
    );
    return attendance.isPresent;
  }

  Attendance? _getAttendanceRecord(
    String staffId,
    List<Attendance> todayAttendance,
  ) {
    try {
      return todayAttendance.firstWhere((a) => a.staffId == staffId);
    } catch (e) {
      return null;
    }
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
            content: Text('Error updating attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isToday =
        _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(
      context,
    ); // Get StaffProvider
    final isLoading = attendanceProvider.isLoading || staffProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.attendance),
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily View'),
            Tab(text: 'Monthly Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
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
                            l10n.attendance,
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
                            'Track and manage employee attendance for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
                    const SizedBox(width: AppSpacing.md),
                    CustomButton(
                      text: 'Select Date',
                      icon: Icons.calendar_today,
                      variant: ButtonVariant.outlined,
                      onPressed: _selectDate,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                Expanded(
                  child: Consumer<StaffProvider>(
                    builder: (context, staffProvider, child) {
                      // Handle loading state
                      if (staffProvider.isLoading &&
                          staffProvider.staff.isEmpty) {
                        return const CustomCard(
                          child: Center(
                            child: LoadingWidget(
                              message: 'Loading staff data...',
                            ),
                          ),
                        );
                      }

                      // Handle error state
                      if (staffProvider.errorMessage != null) {
                        return CustomCard(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Error loading staff data',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(staffProvider.errorMessage!),
                              ],
                            ),
                          ),
                        );
                      }

                      // Handle empty data
                      if (staffProvider.staff.isEmpty) {
                        return CustomCard(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: colorScheme.onSurface.withOpacity(0.5),
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
                          ),
                        );
                      }

                      _staff = staffProvider.staff;
                      _filteredStaff = _staff;

                      return StreamBuilder<List<Attendance>>(
                        stream: attendanceProvider.getAttendanceByDate(
                          _selectedDate,
                        ),
                        builder: (context, attendanceSnapshot) {
                          // Handle loading state for attendance
                          if (attendanceSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CustomCard(
                              child: Center(
                                child: LoadingWidget(
                                  message: 'Loading attendance...',
                                ),
                              ),
                            );
                          }

                          if (attendanceSnapshot.hasError) {
                            log(
                              'Attendance stream error: ${attendanceSnapshot.error.toString()}',
                            );
                            return CustomCard(
                              child: Center(
                                child: Text(
                                  'Error loading attendance: ${attendanceSnapshot.error}',
                                ),
                              ),
                            );
                          }

                          final todayAttendance = attendanceSnapshot.data ?? [];
                          attendanceProvider.updateAttendanceList(
                            todayAttendance,
                          );

                          log('Attendance records: ${todayAttendance.length}');

                          return Stack(
                            children: [
                              CustomCard(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Show',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.md,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: AppColors.grey300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<int>(
                                                  value: _entriesPerPage,
                                                  items: [5, 10, 25, 50].map((
                                                    value,
                                                  ) {
                                                    return DropdownMenuItem(
                                                      value: value,
                                                      child: Text('$value'),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(
                                                      () => _entriesPerPage =
                                                          value!,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Text(
                                              'entries',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        SizedBox(
                                          width: 300,
                                          child: SearchBarWidget(
                                            hint: 'Search employees...',
                                            onChanged: _filterStaff,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    Expanded(
                                      child: _filteredStaff.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No staff members match your search',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                            )
                                          : DataTableWidget(
                                              columns: const [
                                                DataColumn(label: Text('No')),
                                                DataColumn(
                                                  label: Text('Employee Role'),
                                                ),
                                                DataColumn(label: Text('Name')),
                                                DataColumn(
                                                  label: Text('Daily Wage'),
                                                ),
                                                DataColumn(
                                                  label: Text('Attendance'),
                                                ),
                                              ],
                                              rows: _pageItems.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final staff = entry.value;
                                                final isPresent =
                                                    _getAttendanceStatus(
                                                      staff.id,
                                                      todayAttendance,
                                                    );

                                                return DataRow(
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        '${index + 1 + ((_currentPage - 1) * _entriesPerPage)}',
                                                      ),
                                                    ),
                                                    DataCell(Text(staff.role)),
                                                    DataCell(Text(staff.name)),
                                                    DataCell(
                                                      Text(
                                                        '${staff.dailyWage.toStringAsFixed(0)}',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Radio<bool>(
                                                            value: true,
                                                            groupValue:
                                                                isPresent,
                                                            onChanged: isLoading
                                                                ? null
                                                                : (
                                                                    value,
                                                                  ) => _markAttendance(
                                                                    staff,
                                                                    true,
                                                                    attendanceProvider,
                                                                  ),
                                                          ),
                                                          const Text('Present'),
                                                          const SizedBox(
                                                            width:
                                                                AppSpacing.sm,
                                                          ),
                                                          Radio<bool>(
                                                            value: false,
                                                            groupValue:
                                                                isPresent,
                                                            onChanged: isLoading
                                                                ? null
                                                                : (
                                                                    value,
                                                                  ) => _markAttendance(
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
                                              mobileItemBuilder: (context, index) {
                                                final staff = _pageItems[index];
                                                final isPresent =
                                                    _getAttendanceStatus(
                                                      staff.id,
                                                      todayAttendance,
                                                    );
                                                final attendance =
                                                    _getAttendanceRecord(
                                                      staff.id,
                                                      todayAttendance,
                                                    );

                                                return CustomCard(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  staff.name,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .titleMedium
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                ),
                                                                Text(
                                                                  staff.role,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          StatusBadge(
                                                            text: isPresent
                                                                ? 'Present'
                                                                : 'Absent',
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: AppSpacing.md,
                                                      ),
                                                      Text(
                                                        'Daily Wage: ${staff.dailyWage.toStringAsFixed(0)}',
                                                      ),
                                                      if (attendance !=
                                                          null) ...[
                                                        Text(
                                                          'Hours: ${attendance.calculatedHours.toStringAsFixed(1)}',
                                                        ),
                                                        Text(
                                                          'Wage Earned: ${attendance.calculatedWage.toStringAsFixed(2)}',
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                        height: AppSpacing.sm,
                                                      ),
                                                      Row(
                                                        children: [
                                                          Radio<bool>(
                                                            value: true,
                                                            groupValue:
                                                                isPresent,
                                                            onChanged: isLoading
                                                                ? null
                                                                : (
                                                                    value,
                                                                  ) => _markAttendance(
                                                                    staff,
                                                                    true,
                                                                    attendanceProvider,
                                                                  ),
                                                          ),
                                                          const Text('Present'),
                                                          Radio<bool>(
                                                            value: false,
                                                            groupValue:
                                                                isPresent,
                                                            onChanged: isLoading
                                                                ? null
                                                                : (
                                                                    value,
                                                                  ) => _markAttendance(
                                                                    staff,
                                                                    false,
                                                                    attendanceProvider,
                                                                  ),
                                                          ),
                                                          const Text('Absent'),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLoading)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.3),
                                    child: const Center(
                                      child: LoadingWidget(
                                        message: 'Processing...',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          MonthlyAttendanceScreen(),
        ],
      ),
    );
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
        _currentPage = 1;
      });
    }
  }
}
