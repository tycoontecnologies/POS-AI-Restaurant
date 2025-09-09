import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pos/models/store_out.dart';
import 'package:pos/services/store_out_service.dart';

class StoreOutProvider with ChangeNotifier {
  final StoreOutService _storeOutService = StoreOutService();

  List<StoreOut> _storeOuts = [];
  List<StoreOut> _filteredStoreOuts = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _pageSize = 20;
  String _searchQuery = '';

  List<StoreOut> get storeOuts => _filteredStoreOuts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;

  Future<void> loadStoreOuts({bool loadMore = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    if (!loadMore) {
      _storeOuts.clear();
      _lastDocument = null;
      _hasMore = true;
      _error = null;
    }
    notifyListeners();

    try {
      final result = await _storeOutService.getStoreOutsWithPagination(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      final newStoreOuts = result['storeOuts'] as List<StoreOut>;
      final newLastDocument = result['lastDocument'] as DocumentSnapshot?;

      if (newStoreOuts.isEmpty) {
        _hasMore = false;
      } else {
        _lastDocument = newLastDocument;

        if (loadMore) {
          _storeOuts.addAll(newStoreOuts);
        } else {
          _storeOuts = newStoreOuts;
        }

        _filterStoreOuts();
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load store outs: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentSnapshot?> _getLastDocument() async {
    if (_storeOuts.isEmpty) return null;

    final lastStoreOut = _storeOuts.last;
    final storeOutsCollection = _storeOutService.getStoreOutsQuery(limit: 1);
    final snapshot = await storeOutsCollection.get();

    for (final doc in snapshot.docs) {
      final storeOut = StoreOut.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
      if (storeOut.id == lastStoreOut.id) {
        return doc;
      }
    }
    return null;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filterStoreOuts();
    notifyListeners();
  }

  void _filterStoreOuts() {
    if (_searchQuery.isEmpty) {
      _filteredStoreOuts = List.from(_storeOuts);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredStoreOuts = _storeOuts
          .where(
            (storeOut) =>
                storeOut.id.toLowerCase().contains(query) ||
                storeOut.reason.toLowerCase().contains(query) ||
                storeOut.handledBy.toLowerCase().contains(query),
          )
          .toList();
    }
  }

  Stream<List<StoreOut>> getStoreOutsStream() {
    return _storeOutService.streamStoreOuts(limit: _pageSize);
  }

  Future<String> createStoreOut(StoreOut storeOut) async {
    try {
      _isLoading = true;
      notifyListeners();

      final id = await _storeOutService.createStoreOut(storeOut);

      // Reload to get the latest data
      await loadStoreOuts();

      return id;
    } catch (e) {
      _error = 'Failed to create store out: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStoreOut(StoreOut storeOut) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _storeOutService.updateStoreOut(storeOut);

      // Update local list
      final index = _storeOuts.indexWhere((s) => s.id == storeOut.id);
      if (index != -1) {
        _storeOuts[index] = storeOut;
        _filterStoreOuts();
      }
    } catch (e) {
      _error = 'Failed to update store out: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteStoreOut(String storeOutId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _storeOutService.deleteStoreOut(storeOutId);

      // Remove from local lists
      _storeOuts.removeWhere((s) => s.id == storeOutId);
      _filteredStoreOuts.removeWhere((s) => s.id == storeOutId);

      _error = null;
    } catch (e) {
      _error = 'Failed to delete store out: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hardDeleteStoreOut(String storeOutId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _storeOutService.hardDeleteStoreOut(storeOutId);

      // Remove from local lists
      _storeOuts.removeWhere((s) => s.id == storeOutId);
      _filteredStoreOuts.removeWhere((s) => s.id == storeOutId);

      _error = null;
    } catch (e) {
      _error = 'Failed to delete store out: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<StoreOut>> searchStoreOuts(String query) async {
    return await _storeOutService.searchStoreOuts(query);
  }

  Future<int> getStoreOutsCount() async {
    return await _storeOutService.getStoreOutsCount();
  }

  Future<List<StoreOut>> getStoreOutsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _storeOutService.getStoreOutsByDateRange(startDate, endDate);
  }

  Future<List<StoreOut>> getStoreOutsByReason(String reason) async {
    return await _storeOutService.getStoreOutsByReason(reason);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _storeOuts.clear();
    _filteredStoreOuts.clear();
    _lastDocument = null;
    _hasMore = true;
    _searchQuery = '';
    _error = null;
    notifyListeners();
  }
}
