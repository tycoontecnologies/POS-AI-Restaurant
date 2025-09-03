import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos/models/draft.dart';
import 'package:pos/services/draft_service.dart';

class DraftProvider with ChangeNotifier {
  final DraftService _draftService = DraftService();
  String? _vendorId; // Change from final to nullable string

  List<Draft> _drafts = [];
  List<Draft> _filteredDrafts = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _pageSize = 10;

  List<Draft> get drafts => _filteredDrafts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  // Initialize vendorId from AuthProvider
  void initialize(String vendorId) {
    if (_vendorId == null) {
      _vendorId = vendorId;
    }
  }

  Future<void> loadDrafts({bool loadMore = false}) async {
    if (_vendorId == null) {
      _error = 'Vendor ID not initialized';
      notifyListeners();
      return;
    }

    if (!loadMore) {
      _isLoading = true;
      _lastDocument = null;
      _hasMore = true;
      notifyListeners();
    }

    try {
      final query = _draftService.getDraftsQuery(
        _vendorId!,
        limit: _pageSize,
        lastDocument: _lastDocument,
      );
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDocument = snapshot.docs.last;

        final newDrafts = snapshot.docs
            .map(
              (doc) =>
                  Draft.fromMap(doc.data() as Map<String, dynamic>, doc.id),
            )
            .toList();

        if (loadMore) {
          _drafts.addAll(newDrafts);
        } else {
          _drafts = newDrafts;
        }

        _filteredDrafts = _drafts;
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load drafts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchDrafts(String query) async {
    if (query.isEmpty) {
      _filteredDrafts = _drafts;
    } else {
      _filteredDrafts = _drafts
          .where(
            (draft) =>
                draft.id.toLowerCase().contains(query.toLowerCase()) ||
                draft.type.toLowerCase().contains(query.toLowerCase()) ||
                draft.status.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
    notifyListeners();
  }

  Future<String> createDraft(Draft draft) async {
    if (_vendorId == null) {
      throw Exception('Vendor ID not initialized');
    }

    try {
      final id = await _draftService.createDraft(_vendorId!, draft);
      await loadDrafts();
      return id;
    } catch (e) {
      _error = 'Failed to create draft: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDraft(Draft draft) async {
    if (_vendorId == null) {
      throw Exception('Vendor ID not initialized');
    }

    try {
      await _draftService.updateDraft(_vendorId!, draft);
      await loadDrafts();
    } catch (e) {
      _error = 'Failed to update draft: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDraft(String draftId) async {
    if (_vendorId == null) {
      throw Exception('Vendor ID not initialized');
    }

    try {
      await _draftService.deleteDraft(_vendorId!, draftId);
      _drafts.removeWhere((draft) => draft.id == draftId);
      _filteredDrafts.removeWhere((draft) => draft.id == draftId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete draft: $e';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}