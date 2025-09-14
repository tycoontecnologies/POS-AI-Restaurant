// components/ui/consistent_data_table.dart
import 'package:flutter/material.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class ConsistentDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget Function(BuildContext, int)? mobileItemBuilder;
  final bool showSerialNumbers;
  final double rowHeight;
  final double headingRowHeight;

  const ConsistentDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.mobileItemBuilder,
    this.showSerialNumbers = true,
    this.rowHeight = 48.0,
    this.headingRowHeight = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DataTable(
      columns: columns,
      rows: rows,
      headingRowColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => AppColors.grey50,
      ),
      dataRowHeight: rowHeight,
      headingRowHeight: headingRowHeight,
      horizontalMargin: AppSpacing.md,
      columnSpacing: AppSpacing.lg,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: AppColors.grey200,
          width: 1.0,
        ),
        bottom: BorderSide(
          color: AppColors.grey300,
          width: 1.0,
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey200),
      ),
      headingTextStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.grey700,
      ),
      dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.grey800,
      ),
    );
  }
}