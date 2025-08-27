import 'package:flutter/foundation.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._internal();
  static final SettingsStore instance = SettingsStore._internal();

  String businessName = 'My POS';
  String currency = 'USD';
  double taxRate = 0.0; // percent
  String phone = '';
  String address = '';

  void update({
    String? businessName,
    String? currency,
    double? taxRate,
    String? phone,
    String? address,
  }) {
    if (businessName != null) this.businessName = businessName;
    if (currency != null) this.currency = currency;
    if (taxRate != null) this.taxRate = taxRate;
    if (phone != null) this.phone = phone;
    if (address != null) this.address = address;
    notifyListeners();
  }
}
