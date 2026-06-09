// services/firebase_staff_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';
import '../providers/auth_provider.dart';

class FirebaseStaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider _authProvider;

  FirebaseStaffService(this._authProvider);

  String get _vendorId => _authProvider.currentUser?.id ?? '';

  String get _staffCollectionPath => 'vendors/$_vendorId/staff';

  CollectionReference get staffCollection =>
      _firestore.collection(_staffCollectionPath);

  // Create staff with auto-generated ID
  Future<String> addStaff(Staff staff) async {
    try {
      final docRef = staffCollection.doc();
      final staffWithId = staff.copyWith(id: docRef.id);

      await docRef.set(staffWithId.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add staff: $e');
    }
  }

  // Update staff
  Future<void> updateStaff(Staff staff) async {
    try {
      await staffCollection.doc(staff.id).update(staff.toJson());
    } catch (e) {
      throw Exception('Failed to update staff: $e');
    }
  }

  // Delete staff
  Future<void> deleteStaff(String staffId) async {
    try {
      await staffCollection.doc(staffId).delete();
    } catch (e) {
      throw Exception('Failed to delete staff: $e');
    }
  }

  // Get staff stream with pagination
  Stream<List<Staff>> getStaffStream({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) {
    try {
      Query query = staffCollection.orderBy('name').limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Staff.fromJson({
            ...doc.data() as Map<String, dynamic>,
            'id': doc.id,
          });
        }).toList();
      });
    } catch (e) {
      throw Exception('Failed to fetch staff: $e');
    }
  }

  // Get single staff by ID
  Future<Staff?> getStaffById(String staffId) async {
    try {
      final doc = await staffCollection.doc(staffId).get();
      if (doc.exists) {
        return Staff.fromJson({
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch staff: $e');
    }
  }

  // Search staff
  Stream<List<Staff>> searchStaff(String queryText, {int limit = 20}) {
    try {
      final query = queryText.toLowerCase();

      return staffCollection
          .where('searchKeywords', arrayContains: query)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Staff.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              });
            }).toList();
          });
    } catch (e) {
      throw Exception('Failed to search staff: $e');
    }
  }
}
