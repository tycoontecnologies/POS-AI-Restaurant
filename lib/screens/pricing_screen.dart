import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRouter.dashboard),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Upgrade Your Plan',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose the plan that works best for your business',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Pricing Cards
            Row(
              children: [
                // Monthly Plan
                _PricingCard(
                  title: 'Monthly',
                  price: 'PKR 6,000',
                  period: 'per month',
                  features: const [
                    'All features included',
                    '24/7 support',
                    'Regular updates',
                  ],
                  onSelect: () => _handleSubscription(context, 'monthly'),
                ),

                // Yearly Plan
                _PricingCard(
                  title: 'Yearly',
                  price: 'PKR 60,000',
                  period: 'per year',
                  features: const [
                    'All features included',
                    '24/7 support',
                    'Regular updates',
                    'Save 17% compared to monthly',
                  ],
                  onSelect: () => _handleSubscription(context, 'yearly'),
                  isPopular: true,
                ),

                // Lifetime Plan
                _PricingCard(
                  title: 'Lifetime',
                  price: 'PKR 1,050,000',
                  period: 'one-time payment',
                  features: const [
                    'All features included',
                    '24/7 support',
                    'Lifetime updates',
                    'No recurring payments',
                  ],
                  onSelect: () => _handleSubscription(context, 'lifetime'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubscription(BuildContext context, String plan) {
    // TODO: Integrate with Stripe payment
    // For now, just navigate to a payment processing screen
    context.go('${AppRouter.payment}/$plan');
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final VoidCallback onSelect;
  final bool isPopular;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.onSelect,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        color: isPopular ? Colors.blue[50] : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                price,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(period, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      Text(feature),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Select Plan',
                onPressed: onSelect,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
