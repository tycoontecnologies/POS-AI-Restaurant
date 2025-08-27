import 'package:flutter/material.dart';

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.role,
    required this.name,
    this.dailyWage,
    this.present = false,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final String id;
  final String role;
  final String name;
  final double? dailyWage;
  bool present;
  DateTime date;
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final List<AttendanceRecord> _rows = [
    AttendanceRecord(id: '1', role: 'Cashier', name: 'Alice', dailyWage: 30),
    AttendanceRecord(id: '2', role: 'Manager', name: 'Bob', dailyWage: 60),
    AttendanceRecord(id: '3', role: 'Stock', name: 'Carol', dailyWage: 35),
  ];

  void _markAll(bool present) {
    setState(() {
      for (final r in _rows) {
        r.present = present;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _markAll(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark All Present'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _markAll(false),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Mark All Absent'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                final dateStr = (DateTime d) =>
                    d.toIso8601String().substring(0, 10);
                if (isMobile) {
                  return ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final r = _rows[index];
                      return Card(
                        child: ListTile(
                          title: Text('${r.name} • ${r.role}'),
                          subtitle: Text(
                            'Wage: ${r.dailyWage?.toStringAsFixed(2) ?? '-'} • Date: ${dateStr(r.date)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: r.present,
                                onChanged: (v) =>
                                    setState(() => r.present = v ?? false),
                              ),
                              const Text('Present'),
                              const SizedBox(width: 6),
                              Radio<bool>(
                                value: false,
                                groupValue: r.present,
                                onChanged: (v) =>
                                    setState(() => r.present = v ?? false),
                              ),
                              const Text('Absent'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Employee Role')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Daily Wage')),
                        DataColumn(label: Text('Attendance')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: _rows
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.role)),
                                DataCell(Text(r.name)),
                                DataCell(
                                  Text(r.dailyWage?.toStringAsFixed(2) ?? '-'),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: r.present,
                                        onChanged: (v) => setState(
                                          () => r.present = v ?? false,
                                        ),
                                      ),
                                      const Text('Present'),
                                      const SizedBox(width: 8),
                                      Radio<bool>(
                                        value: false,
                                        groupValue: r.present,
                                        onChanged: (v) => setState(
                                          () => r.present = v ?? false,
                                        ),
                                      ),
                                      const Text('Absent'),
                                    ],
                                  ),
                                ),
                                DataCell(Text(dateStr(r.date))),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
