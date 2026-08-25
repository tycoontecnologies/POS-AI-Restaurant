import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/stripe_service.dart';

class PaymentScreen extends StatefulWidget {
  final String plan;
  const PaymentScreen({super.key, required this.plan});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const burgundy = Color(0xFF7A1026);
  bool _isProcessing = false;
  String? _errorMessage;

  Map<String, dynamic> get _planDetails {
    switch (widget.plan) {
      case 'perTransaction':
        return {'name': 'Pay per Transaction', 'price': 'Rs 1', 'period': 'per successful receipt', 'amount': 0};
      case 'monthly':
        return {'name': 'Monthly', 'price': 'PKR 7,000', 'period': 'per month', 'amount': 7000};
      case 'yearly':
        return {'name': 'Yearly', 'price': 'PKR 80,000', 'period': 'per year', 'amount': 80000};
      case 'fiveYears':
        return {'name': '5 Years', 'price': 'PKR 200,000', 'period': 'five-year package', 'amount': 200000};
      default:
        return {'name': 'Monthly', 'price': 'PKR 7,000', 'period': 'per month', 'amount': 7000};
    }
  }

  Future<void> _process() async {
    setState(() { _isProcessing = true; _errorMessage = null; });
    try {
      if (widget.plan == 'perTransaction') {
        final user = context.read<AuthProvider>().currentUser;
        if (user == null) throw Exception('Please sign in again.');
        await FirebaseFirestore.instance.collection('vendors').doc(user.id).set({
          'billingPlanId': 'perTransaction',
          'transactionRate': 1,
          'successfulReceiptCount': FieldValue.increment(0),
          'billingStatus': 'active',
          'accessMode': 'full',
          'hasActiveSubscription': true,
          'packageActivatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pay per Transaction package activated.'), backgroundColor: Color(0xFF059669)));
        context.go(AppRouter.dashboard);
        return;
      }

      final success = await StripeService.processPayment(
        amount: (_planDetails['amount'] as int) * 100,
        currency: 'pkr',
        planType: widget.plan,
      ).timeout(const Duration(seconds: 30));

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 1), content: Text('Redirecting to secure payment...'), backgroundColor: Color(0xFF2563EB)));
      }
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = 'Payment request timed out. Please try again.');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUsagePlan = widget.plan == 'perTransaction';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 5))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(onPressed: () => context.go(AppRouter.pricing), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 6),
                  const Text('TYCOON POS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Color(0xFFD80000), fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 16),
                Text(_planDetails['name'] as String, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text(_planDetails['price'] as String, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: burgundy)),
                Text(_planDetails['period'] as String, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isUsagePlan ? 'How usage billing works' : 'Secure payment', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      isUsagePlan
                          ? 'Only successfully completed receipts are counted. Cancelled receipts are excluded. Your restaurant admin can see the successful receipt count and running usage amount from the Tycoon account menu.'
                          : widget.plan == 'monthly'
                              ? 'The monthly payment window opens on the 25th. Payment should be completed by month-end. If payment remains overdue, the system moves to Basic Mode until payment is recorded.'
                              : 'You will be redirected to the configured secure payment flow for this package.',
                      style: const TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFF475569)),
                    ),
                  ]),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDA4AF))), child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFBE123C), fontSize: 11.5))),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _process,
                    style: FilledButton.styleFrom(backgroundColor: burgundy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isUsagePlan ? 'Activate Rs 1 / receipt plan' : 'Proceed to payment', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: TextButton(onPressed: () => context.go(AppRouter.dashboard), child: const Text('Cancel and return to dashboard'))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
