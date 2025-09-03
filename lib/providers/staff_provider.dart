// providers/staff_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pos/services/staff_service.dart';
import '../models/staff.dart';

class StaffProvider with ChangeNotifier {
  final FirebaseStaffService _staffService;
  
  List<Staff> _staff = [];
  List<Staff> _filteredStaff = [];
  bool _isLoading = false;
  String? _errorMessage;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  StaffProvider(this._staffService);

  List<Staff> get staff => _staff;
  List<Staff> get filteredStaff => _filteredStaff;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  // Load initial staff data with pagination
  Future<void> loadStaff({int limit = 10, bool refresh = false}) async {
    if (refresh) {
      _staff.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    if (!_hasMore) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      final staffStream = _staffService.getStaffStream(
        limit: limit,
        lastDocument: _lastDocument,
      );

      // Listen to the first snapshot to get initial data
      final firstSnapshot = await staffStream.first;
      
      if (firstSnapshot.isNotEmpty) {
        _lastDocument = await _staffService.staffCollection
            .doc(firstSnapshot.last.id)
            .get();
        
        if (refresh) {
          _staff = firstSnapshot;
        } else {
          _staff.addAll(firstSnapshot);
        }
        
        _hasMore = firstSnapshot.length == limit;
      } else {
        _hasMore = false;
      }

      _filteredStaff = _staff;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Load more staff for pagination
  Future<void> loadMoreStaff({int limit = 10}) async {
    if (_isLoading || !_hasMore) return;
    
    await loadStaff(limit: limit);
  }

  // Filter staff based on search query
  void filterStaff(String query) {
    if (query.isEmpty) {
      _filteredStaff = _staff;
    } else {
      final q = query.toLowerCase();
      _filteredStaff = _staff.where((staff) {
        return staff.name.toLowerCase().contains(q) ||
               staff.role.toLowerCase().contains(q) ||
               staff.phone.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  // Add new staff
  Future<void> addStaff(Staff staff) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _staffService.addStaff(staff);
      // Reload the first page to include the new staff
      await loadStaff(limit: 10, refresh: true);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update staff
  Future<void> updateStaff(Staff staff) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _staffService.updateStaff(staff);
      
      // Update local list
      final index = _staff.indexWhere((s) => s.id == staff.id);
      if (index != -1) {
        _staff[index] = staff;
        _filteredStaff = _staff;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete staff
  Future<void> deleteStaff(String staffId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _staffService.deleteStaff(staffId);
      
      // Remove from local lists
      _staff.removeWhere((s) => s.id == staffId);
      _filteredStaff = _staff;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}