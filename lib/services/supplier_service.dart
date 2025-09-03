import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/supplier.dart';

class SupplierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current vendor ID from authenticated user
  String _getCurrentVendorId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid; // Using user UID as vendor ID
  }

  // Get suppliers collection for current vendor
  CollectionReference _getSuppliersCollection() {
    final vendorId = _getCurrentVendorId();
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('suppliers');
  }

  // Get suppliers stream for current vendor
  Stream<List<Supplier>> getSuppliersStream() {
    return _getSuppliersCollection()
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Supplier.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // Add new supplier to current vendor
  // Add new supplier to current vendor
  Future<void> addSupplier(Supplier supplier) async {
    // Create a new document reference with auto-generated ID
    final docRef = _getSuppliersCollection().doc();

    // Create supplier with the auto-generated ID
    final supplierWithId = supplier.copyWith(id: docRef.id);

    // Set the document with the supplier data
    await docRef.set(supplierWithId.toMap());
  }

  // Update existing supplier for current vendor
  Future<void> updateSupplier(Supplier supplier) async {
    await _getSuppliersCollection().doc(supplier.id).update(supplier.toMap());
  }

  // Delete supplier from current vendor
  Future<void> deleteSupplier(String supplierId) async {
    await _getSuppliersCollection().doc(supplierId).delete();
  }

  // Get single supplier by ID for current vendor
  Future<Supplier?> getSupplierById(String supplierId) async {
    final doc = await _getSuppliersCollection().doc(supplierId).get();
    if (doc.exists) {
      return Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Search suppliers by query for current vendor
  Future<List<Supplier>> searchSuppliers(String query) async {
    final snapshot = await _getSuppliersCollection().orderBy('name').get();

    final suppliers = snapshot.docs
        .map(
          (doc) => Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();

    if (query.isEmpty) {
      return suppliers;
    }

    return suppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(query.toLowerCase()) ||
          supplier.phone.toLowerCase().contains(query.toLowerCase()) ||
          supplier.address.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Get suppliers count for current vendor
  Future<int> getSuppliersCount() async {
    final snapshot = await _getSuppliersCollection().count().get();
    return snapshot.count ?? 0; // return 0 if null
  }

  // Get active suppliers count for current vendor
  Future<int> getActiveSuppliersCount() async {
    final snapshot = await _getSuppliersCollection()
        .where('active', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0; // return 0 if null
  }

  // Check if supplier name already exists for current vendor
  Future<bool> doesSupplierExist(String supplierName) async {
    final snapshot = await _getSuppliersCollection()
        .where('name', isEqualTo: supplierName)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Bulk update suppliers (for batch operations)
  Future<void> bulkUpdateSuppliers(List<Supplier> suppliers) async {
    final batch = _firestore.batch();
    final suppliersCollection = _getSuppliersCollection();

    for (final supplier in suppliers) {
      batch.update(suppliersCollection.doc(supplier.id), supplier.toMap());
    }

    await batch.commit();
  }

  // Import suppliers from list (for data migration)
  Future<void> importSuppliers(List<Supplier> suppliers) async {
    final batch = _firestore.batch();
    final suppliersCollection = _getSuppliersCollection();

    for (final supplier in suppliers) {
      final docRef = suppliersCollection.doc();
      batch.set(docRef, supplier.toMap());
    }

    await batch.commit();
  }
  // Add these methods to the SupplierService class

  // Update amount to receive
  Future<void> updateAmountToReceive(String supplierId, double amount) async {
    await _getSuppliersCollection().doc(supplierId).update({
      'amountToReceive': FieldValue.increment(amount),
    });
  }

  // Update amount to pay
  Future<void> updateAmountToPay(String supplierId, double amount) async {
    await _getSuppliersCollection().doc(supplierId).update({
      'amountToPay': FieldValue.increment(amount),
    });
  }

  // Reset amounts (for reconciliation)
  Future<void> resetSupplierAmounts(String supplierId) async {
    await _getSuppliersCollection().doc(supplierId).update({
      'amountToReceive': 0.0,
      'amountToPay': 0.0,
    });
  }

  // Get supplier financial summary
  Future<Map<String, double>> getSupplierFinancialSummary(
    String supplierId,
  ) async {
    final doc = await _getSuppliersCollection().doc(supplierId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'amountToReceive': (data['amountToReceive'] as num?)?.toDouble() ?? 0.0,
        'amountToPay': (data['amountToPay'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'amountToReceive': 0.0, 'amountToPay': 0.0};
  }
}
