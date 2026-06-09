import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/subscription_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/services/stripe_service.dart';
import 'package:universal_html/html.dart' as html;

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String _message = 'Verifying your payment...';
  Map<String, dynamic>? _paymentDetails;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      final url = html.window.location.href;
      final uri = Uri.parse(url);
      final sessionId = uri.queryParameters['session_id'];
      final planTypeFromUrl = uri.queryParameters['planType'];

      if (sessionId == null) {
        throw Exception('No session ID found');
      }

      final paymentStatus = await StripeService.verifyPayment(
        sessionId,
      ).timeout(const Duration(seconds: 30));

      final effectivePlanType =
          paymentStatus['planType'] ?? planTypeFromUrl ?? 'monthly';

      if (paymentStatus['status'] == 'paid') {
        await Provider.of<SubscriptionProvider>(
          context,
          listen: false,
        ).updateSubscription(planType: effectivePlanType);

        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _message = 'Payment successful! Your subscription is now active.';
          _paymentDetails = paymentStatus;
        });

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.go(AppRouter.floorPlan);
      } else {
        throw Exception('Payment not completed');
      }
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message =
            'Verification timed out. Please check your subscription status.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'Payment verification failed. Please contact support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isLoading
                  ? const CircularProgressIndicator()
                  : Icon(
                      _isSuccess ? Icons.check_circle : Icons.error,
                      color: _isSuccess ? Colors.green : Colors.red,
                      size: 64,
                    ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _message,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),

              if (_paymentDetails != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Amount: ${_paymentDetails!['amountTotal'] / 100} ${_paymentDetails!['currency']?.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              if (!_isLoading && !_isSuccess)
                ElevatedButton(
                  onPressed: () => context.go(AppRouter.pricing),
                  child: const Text('Back to Pricing'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
