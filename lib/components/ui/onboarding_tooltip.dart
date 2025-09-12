// onboarding_tooltip.dart
import 'package:flutter/material.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTooltip extends StatefulWidget {
  final String screenKey;
  final String title;
  final String description;
  final VoidCallback? onDismiss;
  final Widget? actionButton;

  const OnboardingTooltip({
    super.key,
    required this.screenKey,
    required this.title,
    required this.description,
    this.onDismiss,
    this.actionButton,
  });

  @override
  State<OnboardingTooltip> createState() => _OnboardingTooltipState();
}

class _OnboardingTooltipState extends State<OnboardingTooltip> {
  bool _showTooltip = true;

  @override
  void initState() {
    super.initState();
    _checkIfTooltipWasDismissed();
  }

  Future<void> _checkIfTooltipWasDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final wasDismissed = prefs.getBool('onboarding_${widget.screenKey}') ?? false;
    setState(() {
      _showTooltip = !wasDismissed;
    });
  }

  Future<void> _dismissTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_${widget.screenKey}', true);
    setState(() {
      _showTooltip = false;
    });
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showTooltip) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey700,
                    ),
              ),
              if (widget.actionButton != null) ...[
                const SizedBox(height: AppSpacing.md),
                widget.actionButton!,
              ],
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _dismissTooltip,
              splashRadius: 16,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}