import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../utils/app_spacing.dart';
// removed unused AppColors; rely on theme

class DataTableWidget extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget Function(BuildContext, int)? mobileItemBuilder;
  final bool showCheckboxColumn;
  final double? columnSpacing;
  final EdgeInsets? margin;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.mobileItemBuilder,
    this.showCheckboxColumn = false,
    this.columnSpacing,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Responsive.isMobile(context) && mobileItemBuilder != null) {
          return ListView.builder(
            padding: margin ?? EdgeInsets.zero,
            itemCount: rows.length,
            itemBuilder: mobileItemBuilder!,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Container(
              margin: margin,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: DataTable(
                columns: columns,
                rows: rows,
                showCheckboxColumn: showCheckboxColumn,
                columnSpacing: columnSpacing ?? AppSpacing.lg,
                horizontalMargin: AppSpacing.md,
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                ),
                headingTextStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(
                      color: Theme.of(context).textTheme.labelLarge?.color,
                      fontWeight: FontWeight.w600,
                    ),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                border: TableBorder.all(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
