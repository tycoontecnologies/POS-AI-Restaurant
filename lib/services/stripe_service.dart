import 'dart:async';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class StripeService {
  static const String backendUrl = 'https://api-3qvfn4xj4a-uc.a.run.app';

  static Future<bool> processPayment({
    required int amount,
    required String currency,
    required String planType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/create-checkout-session'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'amount': amount,
              'currency': currency,
              'planType': planType,
              'successUrl': '${html.window.location.origin}/payment-success',
              'cancelUrl': '${html.window.location.origin}/pricing',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['url'] != null) {
          html.window.open(data['url'], '_blank');
          return true;
        } 
      }

      throw Exception(
        'Failed to create checkout session. Status: ${response.statusCode}',
      );
    } on TimeoutException {
      throw Exception('Payment request timed out');
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }

  // Verify payment status after redirect
  static Future<Map<String, dynamic>> verifyPayment(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/verify-payment?session_id=$sessionId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to verify payment: ${response.body}');
      }
    } catch (e) {
      throw Exception('Verification failed: $e');
    }
  }
}
