import 'package:flutter/material.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/staff.dart';
import '../components/ui/custom_button.dart';
import '../components/ui/custom_card.dart';
import '../components/ui/status_badge.dart';
import '../components/ui/data_table_widget.dart';
import '../components/ui/search_bar_widget.dart';
import '../utils/responsive.dart';
import '../utils/app_spacing.dart';
import '../utils/app_colors.dart';
import '../services/dummy_data_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Staff> _staff = [];
  List<Staff> _filteredStaff = [];
  int _entriesPerPage = 10;
  final Map<String, bool> _attendanceStatus = {};
  int _currentPage = 1;

  int get _totalPages {
    if (_filteredStaff.isEmpty) return 1;
    return (_filteredStaff.length / _entriesPerPage).ceil();
  }

  List<Staff> get _pageItems {
    final start = (_currentPage - 1) * _entriesPerPage;
    final end = (start + _entriesPerPage).clamp(0, _filteredStaff.length);
    return _filteredStaff.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _loadStaff() {
    _staff = DummyDataService.getStaff();
    _filteredStaff = _staff;
    // Initialize attendance status
    for (var staff in _staff) {
      _attendanceStatus[staff.id] = false; // Default to absent
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);

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
                      l10n.attendance,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Track and manage employee attendance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: AppSpacing.md),
                CustomButton(
                  text: 'Add Employee',
                  icon: Icons.person_add,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.sm),
                CustomButton(
                  text: 'Mark Attendance',
                  icon: Icons.access_time,
                  onPressed: () {},
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      if (!isMobile) ...[
                        Row(
                          children: [
                            Text(
                              'Show',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.grey300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _entriesPerPage,
                                  items: [5, 10, 25, 50].map((value) {
                                    return DropdownMenuItem(
                                      value: value,
                                      child: Text('$value'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _entriesPerPage = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'entries',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      if (!isMobile)
                        SizedBox(
                          width: 300,
                          child: SearchBarWidget(
                            hint: 'Search employees...',
                            onChanged: _filterStaff,
                          ),
                        ),
                      if (isMobile) ...[
                        Expanded(
                          child: SearchBarWidget(
                            hint: 'Search employees...',
                            onChanged: _filterStaff,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Row(
                        children: [
                          IconButton(
                            onPressed: _currentPage > 1
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.08,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_currentPage / $_totalPages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            onPressed: _currentPage < _totalPages
                                ? () => setState(() => _currentPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.08,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                DataTableWidget(
                  columns: const [
                    DataColumn(label: Text('No')),
                    DataColumn(label: Text('Employee Role')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Daily Wage')),
                    DataColumn(label: Text('Attendance')),
                    DataColumn(label: Text('Paid')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _pageItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final staff = entry.value;
                    final isPresent = _attendanceStatus[staff.id] ?? false;
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
                          Text('\$${staff.dailyWage.toStringAsFixed(0)}'),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: isPresent,
                                onChanged: (value) {
                                  setState(() {
                                    _attendanceStatus[staff.id] = true;
                                  });
                                },
                              ),
                              const Text('P'),
                              const SizedBox(width: AppSpacing.xs),
                              Radio<bool>(
                                value: false,
                                groupValue: isPresent,
                                onChanged: (value) {
                                  setState(() {
                                    _attendanceStatus[staff.id] = false;
                                  });
                                },
                              ),
                              const Text('A'),
                            ],
                          ),
                        ),
                        const DataCell(Text('0')),
                        const DataCell(Text('28-08-2025')),
                        DataCell(
                          TextButton(
                            onPressed: () {},
                            child: const Text('Detail'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  mobileItemBuilder: (context, index) {
                    final item = _pageItems[index];
                    final isPresent = _attendanceStatus[item.id] ?? false;
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
                                      item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      item.role,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
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
                              StatusBadge(
                                text: isPresent ? 'Present' : 'Absent',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Daily Wage: \$${item.dailyWage.toStringAsFixed(0)}',
                                ),
                              ),
                              Row(
                                children: [
                                  Radio<bool>(
                                    value: true,
                                    groupValue: isPresent,
                                    onChanged: (value) {
                                      setState(() {
                                        _attendanceStatus[item.id] = true;
                                      });
                                    },
                                  ),
                                  const Text('P'),
                                  const SizedBox(width: AppSpacing.xs),
                                  Radio<bool>(
                                    value: false,
                                    groupValue: isPresent,
                                    onChanged: (value) {
                                      setState(() {
                                        _attendanceStatus[item.id] = false;
                                      });
                                    },
                                  ),
                                  const Text('A'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Paid: 0'),
                              const Text('Date: 28-08-2025'),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Detail'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
