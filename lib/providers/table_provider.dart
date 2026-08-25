import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';

class TableProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RestaurantTable> _tables = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tablesSubscription;
  String? _listeningVendorId;

  TableProvider(this.authProvider);

  List<RestaurantTable> get tables => _tables;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get _vendorId => authProvider.currentUser?.id ?? '';

  Future<void> loadTables() async {
    final vendorId = _vendorId;
    if (vendorId.isEmpty) return;
    if (_listeningVendorId == vendorId && _tablesSubscription != null) return;

    await _tablesSubscription?.cancel();
    _listeningVendorId = vendorId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _tablesSubscription = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tables')
        .orderBy('tableNumber')
        .snapshots()
        .listen((snapshot) {
      _tables = snapshot.docs
          .map((doc) => RestaurantTable.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> addTable(String tableNumber, int numberOfSeats) async {
    if (_vendorId.isEmpty) return;
    try {
      await _firestore.collection('vendors').doc(_vendorId).collection('tables').add({
        'tableNumber': tableNumber,
        'numberOfSeats': numberOfSeats,
        'status': 'empty',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTable(String id, {int? numberOfSeats, TableStatus? status}) async {
    if (_vendorId.isEmpty) return;
    try {
      final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (numberOfSeats != null) updates['numberOfSeats'] = numberOfSeats;
      if (status != null) updates['status'] = status.toString().split('.').last;
      await _firestore.collection('vendors').doc(_vendorId).collection('tables').doc(id).update(updates);
      // The snapshot listener is the single source of truth and updates every logged-in terminal.
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTableStatus(String id, TableStatus status) async {
    await updateTable(id, status: status);
  }

  Future<void> deleteTable(String id) async {
    if (_vendorId.isEmpty) return;
    try {
      await _firestore.collection('vendors').doc(_vendorId).collection('tables').doc(id).delete();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshTables() async {
    // Realtime listeners make manual refresh unnecessary. Restart the listener if requested.
    await _tablesSubscription?.cancel();
    _tablesSubscription = null;
    _listeningVendorId = null;
    await loadTables();
  }

  @override
  void dispose() {
    _tablesSubscription?.cancel();
    super.dispose();
  }
}
