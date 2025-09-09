import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/l10n/app_localizations.dart';
import 'package:pos/models/staff.dart';
import 'package:pos/models/attendance.dart';
import 'package:pos/providers/attendance_provider.dart';
import 'package:pos/providers/staff_provider.dart';
import 'package:pos/utils/responsive.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/loading_widget.dart';
import 'package:pos/components/ui/data_table_widget.dart';
import 'package:intl/intl.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(context);

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
                      '${l10n.attendance} Report',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Monthly attendance summary for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              CustomButton(
                text: 'Select Month',
                icon: Icons.calendar_today,
                variant: ButtonVariant.outlined,
                onPressed: _selectMonth,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          StreamBuilder<List<Attendance>>(
            stream: attendanceProvider.getAttendanceByMonth(_selectedMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CustomCard(
                  child: Center(
                    child: LoadingWidget(
                      message: 'Loading monthly attendance...',
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return CustomCard(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              final monthlyAttendance = snapshot.data ?? [];

              // Group attendance by staff
              final Map<String, List<Attendance>> attendanceByStaff = {};
              for (final attendance in monthlyAttendance) {
                if (!attendanceByStaff.containsKey(attendance.staffId)) {
                  attendanceByStaff[attendance.staffId] = [];
                }
                attendanceByStaff[attendance.staffId]!.add(attendance);
              }

              return Expanded(
                child: CustomCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Monthly Summary - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          // Export button could be added here
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: DataTableWidget(
                          columns: const [
                            DataColumn(label: Text('Staff Member')),
                            DataColumn(label: Text('Present Days')),
                            DataColumn(label: Text('Total Hours')),
                            DataColumn(
                              label: Text('Total Wage'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: attendanceByStaff.entries.map((entry) {
                            final staffId = entry.key;
                            final staffAttendance = entry.value;

                            // Find staff details
                            final staff = staffProvider.staff.firstWhere(
                              (s) => s.id == staffId,
                              orElse: () => Staff(
                                id: staffId,
                                name: 'Unknown Staff',
                                role: 'Unknown',
                                dailyWage: 0,
                                phone: '',
                                joinDate: DateTime.now(),
                              ),
                            );

                            // Calculate totals
                            final presentDays = staffAttendance
                                .where((a) => a.isPresent)
                                .length;
                            final totalHours = staffAttendance.fold(
                              0.0,
                              (sum, a) => sum + a.calculatedHours,
                            );
                            final totalWage = staffAttendance.fold(
                              0.0,
                              (sum, a) => sum + a.calculatedWage,
                            );

                            return DataRow(
                              cells: [
                                DataCell(Text(staff.name)),
                                DataCell(Text('$presentDays days')),
                                DataCell(
                                  Text(
                                    '${totalHours.toStringAsFixed(1)} hours',
                                  ),
                                ),
                                DataCell(
                                  Text(totalWage.toStringAsFixed(2)),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () {
                                      _showStaffMonthlyDetails(
                                        staff,
                                        staffAttendance,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.input,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  void _showStaffMonthlyDetails(Staff staff, List<Attendance> attendance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${staff.name} - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Hours')),
              DataColumn(label: Text('Wage')),
            ],
            rows: attendance.map((a) {
              return DataRow(
                cells: [
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(a.date))),
                  DataCell(Text(a.isPresent ? 'Present' : 'Absent')),
                  DataCell(Text(a.calculatedHours.toStringAsFixed(1))),
                  DataCell(Text(a.calculatedWage.toStringAsFixed(2))),
                ],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
