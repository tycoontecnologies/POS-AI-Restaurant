// utils/table_formatters.dart
import 'package:flutter/material.dart';
import 'package:pos/utils/app_colors.dart';

class TableFormatters {
  static DataCell textCell(String text, {TextAlign? align, int? maxLines}) {
    return DataCell(
      Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: const TextStyle(fontSize: 14, color: AppColors.grey800),
      ),
    );
  }

  static DataCell numberCell(num value, {String? prefix, String? suffix}) {
    return DataCell(
      Text(
        '${prefix ?? ''}${value.toStringAsFixed(0)}${suffix ?? ''}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.grey800,
        ),
      ),
    );
  }

  static DataCell statusCell(String text, bool isActive) {
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.success.withOpacity(0.1)
              : AppColors.grey100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.success : AppColors.grey300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppColors.success : AppColors.grey600,
          ),
        ),
      ),
    );
  }

  static DataCell dateCell(DateTime date) {
    return DataCell(
      Text(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 14, color: AppColors.grey600),
      ),
    );
  }
}
