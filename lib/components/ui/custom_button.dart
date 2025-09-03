import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

enum ButtonVariant { filled, outlined, text }

enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final Color? color;
  final Color? textColor;
  final bool isLoading;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.filled,
    this.size = ButtonSize.medium,
    this.color,
    this.textColor,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? AppColors.primary;

    EdgeInsets getPadding() {
      switch (size) {
        case ButtonSize.small:
          return const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          );
        case ButtonSize.medium:
          return const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );
        case ButtonSize.large:
          return const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          );
      }
    }

    double getHeight() {
      switch (size) {
        case ButtonSize.small:
          return 36;
        case ButtonSize.medium:
          return AppSpacing.buttonHeight;
        case ButtonSize.large:
          return 56;
      }
    }

    TextStyle getTextStyle() {
      switch (size) {
        case ButtonSize.small:
          return AppTypography.labelSmall;
        case ButtonSize.medium:
          return AppTypography.button;
        case ButtonSize.large:
          return AppTypography.button.copyWith(fontSize: 16);
      }
    }

    Widget buildButton() {
      switch (variant) {
        case ButtonVariant.filled:
          return FilledButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: buttonColor,
              padding: getPadding(),
              minimumSize: Size(fullWidth ? double.infinity : 0, getHeight()),
              textStyle: getTextStyle(),
            ),
            icon: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
            label: Text(text, style: TextStyle(color: textColor)),
          );
        case ButtonVariant.outlined:
          return OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: buttonColor,
              side: BorderSide(color: buttonColor),
              padding: getPadding(),
              minimumSize: Size(fullWidth ? double.infinity : 0, getHeight()),
              textStyle: getTextStyle(),
            ),
            icon: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                    ),
                  )
                : icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
            label: Text(text),
          );
        case ButtonVariant.text:
          return TextButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: buttonColor,
              padding: getPadding(),
              minimumSize: Size(fullWidth ? double.infinity : 0, getHeight()),
              textStyle: getTextStyle(),
            ),
            icon: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                    ),
                  )
                : icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
            label: Text(text),
          );
      }
    }

    return buildButton();
  }
}
