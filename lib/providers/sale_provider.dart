import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';

class SaleProvider with ChangeNotifier {
  final SaleService _saleService = SaleService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _salesSubscription;
  String? _listeningVendorId;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Creates the completed sale first, then records usage billing exactly once.
  /// The usage ledger document is keyed by receipt id, so refreshes/retries do
  /// not double-charge the restaurant.
  Future<void> createSale(String vendorId, Sale sale) async {
    try {
      _error = null;
      await _saleService.createSale(vendorId, sale);
      await _recordSuccessfulReceiptUsage(vendorId, sale);
      if (_listeningVendorId != vendorId) {
        _sales.insert(0, sale);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _recordSuccessfulReceiptUsage(String vendorId, Sale sale) async {
    final vendorRef = _firestore.collection('vendors').doc(vendorId);
    final usageRef = vendorRef.collection('billingUsage').doc(sale.id);

    await _firestore.runTransaction((tx) async {
      final vendorSnap = await tx.get(vendorRef);
      if (!vendorSnap.exists) return;
      final data = vendorSnap.data() ?? <String, dynamic>{};
      final plan = (data['billingPlanId'] ?? data['subscriptionType'] ?? '').toString();
      if (plan != 'perTransaction') return;

      final existing = await tx.get(usageRef);
      if (existing.exists) return;

      final rawRate = data['transactionRate'];
      final rate = rawRate is num ? rawRate.toDouble() : 1.0;
      tx.set(usageRef, {
        'receiptId': sale.id,
        'saleId': sale.id,
        'saleTotal': sale.total,
        'rate': rate,
        'amount': rate,
        'billableAmount': rate,
        'status': 'billable',
        'paymentMethod': sale.paymentMethod,
        'completedAt': Timestamp.fromDate(sale.createdAt),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'checkout',
      });
      tx.set(vendorRef, {
        'successfulReceiptCount': FieldValue.increment(1),
        'unbilledReceiptCount': FieldValue.increment(1),
        'transactionUsageAmount': FieldValue.increment(rate),
        'transactionRate': rate,
        'billingStatus': 'active',
        'accessMode': 'full',
        'transactionUsageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Deleting/cancelling a previously completed receipt removes it from the
  /// current Rs 1 billing total exactly once. The audit ledger is retained and
  /// marked cancelled rather than deleted.
  Future<void> _cancelReceiptUsage(String vendorId, String saleId) async {
    final vendorRef = _firestore.collection('vendors').doc(vendorId);
    final usageRef = vendorRef.collection('billingUsage').doc(saleId);
    await _firestore.runTransaction((tx) async {
      final usage = await tx.get(usageRef);
      if (!usage.exists) return;
      final usageData = usage.data() ?? <String, dynamic>{};
      if ((usageData['status'] ?? '').toString() != 'billable') return;

      final rawRate = usageData['amount'] ?? usageData['billableAmount'] ?? usageData['rate'] ?? 1;
      final rate = rawRate is num ? rawRate.toDouble() : 1.0;
      tx.set(usageRef, {
        'status': 'cancelled',
        'billableAmount': 0,
        'amount': 0,
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(vendorRef, {
        'successfulReceiptCount': FieldValue.increment(-1),
        'unbilledReceiptCount': FieldValue.increment(-1),
        'transactionUsageAmount': FieldValue.increment(-rate),
        'transactionUsageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> fetchSales(String vendorId) async {
    if (_listeningVendorId == vendorId && _salesSubscription != null) return;
    await _salesSubscription?.cancel();
    _listeningVendorId = vendorId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _salesSubscription = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _sales = snapshot.docs.map((doc) => Sale.fromMap(doc.data())).toList();
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> updateSale(String vendorId, Sale sale) async {
    try {
      await _saleService.updateSale(vendorId, sale);
      if (_listeningVendorId != vendorId) {
        final index = _sales.indexWhere((s) => s.id == sale.id);
        if (index != -1) _sales[index] = sale;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSale(String vendorId, String saleId) async {
    try {
      await _saleService.deleteSale(vendorId, saleId);
      await _cancelReceiptUsage(vendorId, saleId);
      if (_listeningVendorId != vendorId) {
        _sales.removeWhere((s) => s.id == saleId);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearSales() {
    _sales.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }
}
