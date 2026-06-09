// components/ui/data_table_widget.dart (updated)
import 'package:flutter/material.dart';
import 'package:pos/utils/responsive.dart';
import 'consistent_data_table.dart';

class DataTableWidget extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget Function(BuildContext, int)? mobileItemBuilder;
  final bool showSerialNumbers;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.mobileItemBuilder,
    this.showSerialNumbers = true,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    if (Responsive.isMobile(context) && mobileItemBuilder != null) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: mobileItemBuilder!,
      );
    }

    return ConsistentDataTable(
      columns: columns,
      rows: rows,
      showSerialNumbers: showSerialNumbers,
    );
  }
}