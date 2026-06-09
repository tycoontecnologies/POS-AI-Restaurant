// onboarding_completion.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:pos/utils/app_spacing.dart';

class OnboardingCompletion extends StatelessWidget {
  const OnboardingCompletion({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: AppColors.success, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Setup Complete! 🎉',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You\'ve completed the setup tour! You\'re now ready to start using the system.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              context.go(AppRouter.floorPlan);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Floor'),
          ),
        ],
      ),
    );
  }
}