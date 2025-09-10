import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:pos/services/stripe_service.dart';

class PaymentScreen extends StatefulWidget {
  final String plan;

  const PaymentScreen({super.key, required this.plan});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  Map<String, dynamic> get _planDetails {
    switch (widget.plan) {
      case 'monthly':
        return {
          'name': 'Monthly',
          'price': 'PKR 6,000',
          'period': 'per month',
          'amount': 6000,
        };
      case 'yearly':
        return {
          'name': 'Yearly',
          'price': 'PKR 60,000',
          'period': 'per year',
          'amount': 60000,
        };
      case 'lifetime':
        return {
          'name': 'Lifetime',
          'price': 'PKR 150,000',
          'period': 'one-time payment',
          'amount': 150000,
        };
      default:
        return {
          'name': 'Monthly',
          'price': 'PKR 6,000',
          'period': 'per month',
          'amount': 6000,
        };
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final success = await StripeService.processPayment(
        amount: (_planDetails['amount'] as int) * 100,
        currency: 'pkr',
        planType: widget.plan,
      ).timeout(const Duration(seconds: 30)); // ADD TIMEOUT HERE

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecting to secure payment...'),
            backgroundColor: Colors.blue,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Payment request timed out. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      // ... rest of error handling
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment - ${_planDetails['name']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRouter.pricing),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null) const SizedBox(height: AppSpacing.lg),

            // Plan Summary
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _planDetails['name'],
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              Text(_planDetails['period']),
                            ],
                          ),
                        ),
                        Text(
                          _planDetails['price'],
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Secure Payment',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),

            // Web payment UI
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Icon(Icons.credit_card, size: 48, color: Colors.blue),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Secure Payment with Stripe',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'You will be redirected to Stripe Checkout to complete your payment securely. We accept all major credit and debit cards.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.green),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'SSL encrypted and PCI compliant',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Pay Button
                    CustomButton(
                      text: 'Pay ${_planDetails['price']}',
                      onPressed: _isProcessing ? null : _processPayment,
                      isLoading: _isProcessing,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl * 2),

            // Cancel Button
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => context.go(AppRouter.pricing),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
