import 'package:flutter/material.dart';
import 'package:pos/components/ui/shimmer_effect.dart';
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
import '../utils/app_spacing.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  String? _vendorId;
  late TabController _tabController;
  List<Staff> _filteredStaff = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    _searchController.addListener(_onSearchChanged);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _vendorId = authProvider.currentUser?.id;

    // Load staff data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );

      // Load staff data
      staffProvider.loadStaff(refresh: true);

      // Pre-load today's attendance
      attendanceProvider.getAttendanceByDate(_selectedDate).first.then((_) {
        // Data loaded, no need to do anything else
      });
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
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterStaff();
    });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(context);

    // Update filtered staff when staff data changes
    if (_filteredStaff.isEmpty && staffProvider.staff.isNotEmpty) {
      _filteredStaff = List.from(staffProvider.staff);
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kToolbarHeight,
        ), // Adjust height if needed
        child: AppBar(
          automaticallyImplyLeading: false,
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
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
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
                            l10n.attendance,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                const SizedBox(height: AppSpacing.md),

                SearchBarWidget(
                  controller: _searchController,
                  hint: 'Search employees...',
                  onChanged: (_) => _onSearchChanged(),
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                ),

                const SizedBox(height: AppSpacing.sm),

                Expanded(
                  child: _buildContent(staffProvider, attendanceProvider, l10n),
                ),
              ],
            ),
          ),
          MonthlyAttendanceScreen(),
        ],
      ),
    );
  }

  Widget _buildContent(
    StaffProvider staffProvider,
    AttendanceProvider attendanceProvider,
    AppLocalizations l10n,
  ) {
    // Handle loading state
    if (staffProvider.isLoading && staffProvider.staff.isEmpty) {
      return _buildShimmerTable();
    }

    // Handle error state
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

    // Handle empty data
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

    // Handle search with no results
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
        // Handle loading state for attendance
        if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerTable();
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
          controller: _scrollController,
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
            mobileItemBuilder: (context, index) {
              final staff = _filteredStaff[index];
              final isPresent = _getAttendanceStatus(staff.id, todayAttendance);
              final attendance = _getAttendanceRecord(
                staff.id,
                todayAttendance,
              );

              return CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                staff.role,
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
                        StatusBadge(text: isPresent ? 'Present' : 'Absent'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Daily Wage: ${staff.dailyWage.toStringAsFixed(0)}'),
                    if (attendance != null) ...[
                      Text(
                        'Hours: ${attendance.calculatedHours.toStringAsFixed(1)}',
                      ),
                      Text(
                        'Wage Earned: ${attendance.calculatedWage.toStringAsFixed(0)}',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
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
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerTable() {
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
      mobileItemBuilder: (context, index) {
        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerEffect(width: 120, height: 20),
                        SizedBox(height: AppSpacing.xs),
                        ShimmerEffect(width: 80, height: 16),
                      ],
                    ),
                  ),
                  ShimmerEffect(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              ShimmerEffect(width: 100, height: 16),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  ShimmerEffect(
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(width: 40, height: 16),
                  SizedBox(width: AppSpacing.sm),
                  ShimmerEffect(
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  ShimmerEffect(width: 40, height: 16),
                ],
              ),
            ],
          ),
        );
      },
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
      });
    }
  }
}
