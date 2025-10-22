import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';
import '../models/review.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getCurrentVendorId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  CollectionReference _getCustomersCollection() {
    final vendorId = _getCurrentVendorId();
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('customers');
  }

  CollectionReference _getReviewsCollection() {
    final vendorId = _getCurrentVendorId();
    return _firestore.collection('vendors').doc(vendorId).collection('reviews');
  }

  Stream<List<Customer>> getCustomersStream() {
    return _getCustomersCollection()
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Customer.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> addCustomer(Customer customer) async {
    final docRef = _getCustomersCollection().doc();
    final customerWithId = customer.copyWith(id: docRef.id);
    await docRef.set(customerWithId.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    await _getCustomersCollection().doc(customer.id).update(customer.toMap());
  }

  Future<void> deleteCustomer(String customerId) async {
    await _getCustomersCollection().doc(customerId).delete();
  }

  Future<Customer?> getCustomerById(String customerId) async {
    final doc = await _getCustomersCollection().doc(customerId).get();
    if (doc.exists) {
      return Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final snapshot = await _getCustomersCollection().orderBy('name').get();
    final customers = snapshot.docs
        .map(
          (doc) => Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();

    if (query.isEmpty) {
      return customers;
    }

    return customers.where((customer) {
      return customer.name.toLowerCase().contains(query.toLowerCase()) ||
          customer.phone.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Stream<List<Review>> getReviewsStream() {
    return _getReviewsCollection()
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Review.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList(),
        );
  }

  Stream<List<Review>> getCustomerReviewsStream(String customerId) {
    return _getReviewsCollection()
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Review.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList(),
        );
  }

  Future<void> addReview(Review review) async {
    final docRef = _getReviewsCollection().doc();
    final reviewWithId = review.copyWith(id: docRef.id);
    await docRef.set(reviewWithId.toMap());
  }

  Future<void> updateReview(Review review) async {
    await _getReviewsCollection().doc(review.id).update({
      ...review.toMap(),
      'updatedOn': Timestamp.now(),
    });
  }

  Future<void> deleteReview(String reviewId) async {
    await _getReviewsCollection().doc(reviewId).delete();
  }

  Future<int> getCustomersCount() async {
    final snapshot = await _getCustomersCollection().count().get();
    return snapshot.count ?? 0;
  }

  Future<double> getTotalCustomerSpent() async {
    final snapshot = await _getCustomersCollection().get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['totalSpent'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<double> getAverageRating() async {
    final snapshot = await _getReviewsCollection().get();
    if (snapshot.docs.isEmpty) return 0.0;
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['rating'] as num?)?.toDouble() ?? 0.0;
    }
    return total / snapshot.docs.length;
  }
}
