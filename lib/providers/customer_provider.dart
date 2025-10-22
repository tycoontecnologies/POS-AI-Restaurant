import 'package:flutter/foundation.dart';
import 'package:pos/models/customer.dart';
import 'package:pos/models/review.dart';
import 'package:pos/services/customer_service.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerService _customerService = CustomerService();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<Review> _reviews = [];
  bool _isLoading = true;

  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers => _filteredCustomers;
  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;

  Stream<List<Customer>> getCustomersStream() {
    return _customerService.getCustomersStream();
  }

  Stream<List<Review>> getReviewsStream() {
    return _customerService.getReviewsStream();
  }

  Stream<List<Review>> getCustomerReviewsStream(String customerId) {
    return _customerService.getCustomerReviewsStream(customerId);
  }

  void filterCustomers(String query) {
    if (query.isEmpty) {
      _filteredCustomers = List.from(_customers);
    } else {
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(query.toLowerCase()) ||
            customer.phone.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  void setCustomers(List<Customer> customers) {
    _customers = customers;
    _filteredCustomers = List.from(_customers);
    _isLoading = false;
    notifyListeners();
  }

  void setReviews(List<Review> reviews) {
    _reviews = reviews;
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    await _customerService.addCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _customerService.updateCustomer(customer);
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customerService.deleteCustomer(customerId);
  }

  Future<void> addReview(Review review) async {
    await _customerService.addReview(review);
  }

  Future<void> updateReview(Review review) async {
    await _customerService.updateReview(review);
  }

  Future<void> deleteReview(String reviewId) async {
    await _customerService.deleteReview(reviewId);
  }

  Future<int> getCustomersCount() async {
    return await _customerService.getCustomersCount();
  }

  Future<double> getTotalCustomerSpent() async {
    return await _customerService.getTotalCustomerSpent();
  }

  Future<double> getAverageRating() async {
    return await _customerService.getAverageRating();
  }
}
