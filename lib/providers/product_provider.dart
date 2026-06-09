// providers/product_provider.dart
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/product.dart';
import 'package:pos/services/product_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String _searchQuery = '';

  List<Product> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;

  Future<void> loadProducts(String vendorId, {bool loadMore = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    if (!loadMore) {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      // notifyListeners();
    }

    try {
      final stream = ProductService.getProducts(
        vendorId,
        // limit: 20,
        lastDocument: _lastDocument,
      ).first;

      final newProducts = await stream;

      if (newProducts.isNotEmpty) {
        // Update last document for pagination
        if (loadMore) {
          _products.addAll(newProducts);
        } else {
          _products = newProducts;
        }

        // Set hasMore based on whether we got a full page
        _hasMore = newProducts.length == 20;

        _filterProducts();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      log('Error loading products: $e');
    } finally {
      _isLoading = false;
      if (_products.isNotEmpty || !loadMore) {
        notifyListeners();
      }
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _filterProducts();
    notifyListeners();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products
          .where(
            (product) =>
                product.name.toLowerCase().contains(_searchQuery) ||
                product.category.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
  }

  Stream<List<Product>> getProductsStream(String vendorId) {
    return ProductService.getProducts(vendorId);
  }

  Future<Product> addProduct(String vendorId, Product product) async {
    final newProduct = await ProductService.addProduct(vendorId, product);
    _products.insert(0, newProduct);
    _filterProducts();
    notifyListeners();
    return newProduct;
  }

  Future<void> updateProduct(String vendorId, Product product) async {
    await ProductService.updateProduct(vendorId, product);
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      _filterProducts();
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String vendorId, String productId) async {
    await ProductService.deleteProduct(vendorId, productId);
    _products.removeWhere((p) => p.id == productId);
    _filterProducts();
    notifyListeners();
  }

  Future<void> seedInitialData(String vendorId) async {
    await ProductService.seedInitialData(vendorId);
    await loadProducts(vendorId);
  }

  void clear() {
    _products.clear();
    _filteredProducts.clear();
    _lastDocument = null;
    _hasMore = true;
    _searchQuery = '';
    notifyListeners();
  }
}
