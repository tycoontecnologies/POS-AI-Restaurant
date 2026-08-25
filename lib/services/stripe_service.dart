import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

class StripeService {
  static const String backendUrl = 'https://api-3qvfn4xj4a-uc.a.run.app';

  static Future<bool> processPayment({
    required int amount,
    required String currency,
    required String planType,
  }) async {
    try {
      if (amount <= 0) {
        throw Exception('Payment amount must be greater than zero.');
      }
      final origin = html.window.location.origin;
      final response = await http
          .post(
            Uri.parse('$backendUrl/create-checkout-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'amount': amount,
              'currency': currency,
              'planType': planType,
              // Stripe replaces this placeholder after a successful checkout.
              // PaymentSuccessScreen requires the session id to verify payment.
              'successUrl': '$origin/payment-success?session_id={CHECKOUT_SESSION_ID}&planType=$planType',
              'cancelUrl': '$origin/pricing',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['url'] != null) {
          html.window.location.assign(data['url'].toString());
          return true;
        }
      }

      throw Exception('Failed to create checkout session. Status: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Payment request timed out');
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyPayment(String sessionId) async {
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/verify-payment?session_id=$sessionId'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
      throw Exception('Failed to verify payment: ${response.body}');
    } on TimeoutException {
      throw Exception('Payment verification timed out');
    } catch (e) {
      throw Exception('Verification failed: $e');
    }
  }
}
