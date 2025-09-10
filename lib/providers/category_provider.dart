// providers/category_provider.dart
import 'package:flutter/foundation.dart' hide Category;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos/models/category.dart';
import 'package:pos/services/category_service.dart';
import 'package:pos/providers/auth_provider.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  final AuthProvider _authProvider;

  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String _searchQuery = '';
  String? _error;

  List<Category> get categories => _filteredCategories;
  List<Category> get allCategories => _categories;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  AuthProvider? get authProvider => _authProvider;

  CategoryProvider(this._authProvider);

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get vendor ID from auth provider
  String? get _vendorId => _authProvider.currentUser?.id;

  // Load initial categories
  Future<void> loadInitialCategories() async {
    if (_vendorId == null) return;

    _isLoading = true;
    _error = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    try {
      final categories = await _categoryService
          .getCategories(vendorId: _vendorId!, limit: 20)
          .first;

      _categories = categories;
      _filteredCategories = _applySearchFilter(_categories);
      _hasMore = categories.length == 20;

      if (categories.isNotEmpty) {
        _lastDocument = await _getLastDocument();
      }
    } catch (e) {
      _error = 'Failed to load categories: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load more categories for pagination
  Future<void> loadMoreCategories() async {
    if (_vendorId == null || _isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final categories = await _categoryService
          .getCategories(
            vendorId: _vendorId!,
            limit: 20,
            lastDocument: _lastDocument,
          )
          .first;

      if (categories.isNotEmpty) {
        _categories.addAll(categories);
        _filteredCategories = _applySearchFilter(_categories);
        _hasMore = categories.length == 20;
        _lastDocument = await _getLastDocument();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      _error = 'Failed to load more categories: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get last document for pagination
  Future<DocumentSnapshot?> _getLastDocument() async {
    if (_categories.isEmpty) return null;

    final lastCategory = _categories.last;
    return await _categoryService
        .getVendorCategoriesCollection(_vendorId!)
        .doc(lastCategory.id)
        .get();
  }

  // Search categories
  void searchCategories(String query) {
    _searchQuery = query.toLowerCase();
    _filteredCategories = _applySearchFilter(_categories);
    notifyListeners();
  }

  // Apply search filter
  List<Category> _applySearchFilter(List<Category> categories) {
    if (_searchQuery.isEmpty) return categories;

    return categories
        .where((category) => category.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // Add category
  Future<bool> addCategory(Category category) async {
    if (_vendorId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _categoryService.addCategory(category, _vendorId!);

      // Reload categories to include the new one
      await loadInitialCategories();
      return true;
    } catch (e) {
      _error = 'Failed to add category: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update category
  Future<bool> updateCategory(Category category) async {
    if (_vendorId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _categoryService.updateCategory(category, _vendorId!);

      // Update local list
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        _filteredCategories = _applySearchFilter(_categories);
      }

      return true;
    } catch (e) {
      _error = 'Failed to update category: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete category
  Future<bool> deleteCategory(String categoryId) async {
    if (_vendorId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _categoryService.deleteCategory(categoryId, _vendorId!);

      // Remove from local list
      _categories.removeWhere((c) => c.id == categoryId);
      _filteredCategories = _applySearchFilter(_categories);

      return true;
    } catch (e) {
      _error = 'Failed to delete category: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh categories
  Future<void> refreshCategories() async {
    _categories.clear();
    _filteredCategories.clear();
    _lastDocument = null;
    _hasMore = true;
    await loadInitialCategories();
  }
}
