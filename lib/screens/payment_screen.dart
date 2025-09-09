import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatefulWidget {
  final String plan;

  const PaymentScreen({super.key, required this.plan});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

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
          'price': 'PKR 1,050,000',
          'period': 'one-time payment',
          'amount': 1050000,
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

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_validateForm()) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Integrate with Stripe payment processing
      // This is where you'll call your Stripe API
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Simulate payment processing

      await Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      ).updateSubscription(planType: widget.plan);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful! ${_planDetails['name']} plan activated.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to dashboard
      if (mounted) {
        context.go(AppRouter.dashboard);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  bool _validateForm() {
    if (_cardNumberController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter card number')));
      return false;
    }
    if (_expiryController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter expiry date')));
      return false;
    }
    if (_cvcController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter CVC')));
      return false;
    }
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cardholder name')),
      );
      return false;
    }
    return true;
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
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Summary
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _planDetails['name'],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(_planDetails['period']),
                      ],
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
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Payment Form
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),

            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _cvcController,
                            decoration: const InputDecoration(
                              labelText: 'CVC',
                              hintText: '123',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Security Note
            const Row(
              children: [
                Icon(Icons.lock, size: 16, color: Colors.green),
                SizedBox(width: AppSpacing.sm),
                Text('Your payment details are secure and encrypted'),
              ],
            ),

            const Spacer(),

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
    );
  }
}
