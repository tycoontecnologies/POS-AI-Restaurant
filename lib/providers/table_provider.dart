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

  TableProvider(this.authProvider);

  // Getters
  List<RestaurantTable> get tables => _tables;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get _vendorId => authProvider.currentUser?.id ?? '';

  Future<void> loadTables() async {
    if (_vendorId.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tables')
          .orderBy('tableNumber')
          .get();

      _tables = snapshot.docs
          .map((doc) => RestaurantTable.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTable(int tableNumber, int numberOfSeats) async {
    if (_vendorId.isEmpty) return;

    try {
      final docRef = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tables')
          .add({
        'tableNumber': tableNumber,
        'numberOfSeats': numberOfSeats,
        'status': 'empty',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      final newTable = RestaurantTable(
        id: docRef.id,
        tableNumber: tableNumber,
        numberOfSeats: numberOfSeats,
        status: TableStatus.empty,
        createdAt: DateTime.now(),
      );

      _tables.add(newTable);
      _tables.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTable(String id, {int? numberOfSeats, TableStatus? status}) async {
    if (_vendorId.isEmpty) return;

    try {
      final updates = <String, dynamic>{};
      if (numberOfSeats != null) updates['numberOfSeats'] = numberOfSeats;
      if (status != null) updates['status'] = status.toString().split('.').last;

      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tables')
          .doc(id)
          .update(updates);

      final index = _tables.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tables[index] = _tables[index].copyWith(
          numberOfSeats: numberOfSeats ?? _tables[index].numberOfSeats,
          status: status ?? _tables[index].status,
        );
        notifyListeners();
      }
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
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tables')
          .doc(id)
          .delete();

      _tables.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshTables() async {
    await loadTables();
  }
}
