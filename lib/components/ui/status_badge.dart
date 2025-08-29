import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

enum BadgeVariant { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final bool outlined;

  const StatusBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.neutral,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    Color getBackgroundColor() {
      if (outlined) return Colors.transparent;
      
      switch (variant) {
        case BadgeVariant.success:
          return AppColors.success.withOpacity(0.1);
        case BadgeVariant.warning:
          return AppColors.warning.withOpacity(0.1);
        case BadgeVariant.error:
          return AppColors.error.withOpacity(0.1);
        case BadgeVariant.info:
          return AppColors.info.withOpacity(0.1);
        case BadgeVariant.neutral:
          return AppColors.grey100;
      }
    }

    Color getTextColor() {
      switch (variant) {
        case BadgeVariant.success:
          return AppColors.success;
        case BadgeVariant.warning:
          return AppColors.warning;
        case BadgeVariant.error:
          return AppColors.error;
        case BadgeVariant.info:
          return AppColors.info;
        case BadgeVariant.neutral:
          return AppColors.grey600;
      }
    }

    Color getBorderColor() {
      if (!outlined) return Colors.transparent;
      return getTextColor();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: outlined ? Border.all(color: getBorderColor()) : null,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: getTextColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
