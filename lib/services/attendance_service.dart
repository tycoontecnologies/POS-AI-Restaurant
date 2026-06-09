import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/attendance.dart';

class FirebaseAttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _getVendorCollectionPath(String vendorId) =>
      'vendors/$vendorId/attendance';

  static Stream<List<Attendance>> getAttendanceByDate(
    String vendorId,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data()))
              .toList(),
        );
  }

  static Future<Attendance?> getAttendanceByStaffAndDate(
    String vendorId,
    String staffId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final querySnapshot = await _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .where('staffId', isEqualTo: staffId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return Attendance.fromMap(querySnapshot.docs.first.data());
  }

  static Future<String> addAttendance(
    String vendorId,
    Attendance attendance,
  ) async {
    final docRef = _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .doc();
    final attendanceWithId = attendance.copyWith(id: docRef.id);

    await docRef.set(attendanceWithId.toMap());
    return docRef.id;
  }

  static Future<void> updateAttendance(
    String vendorId,
    Attendance attendance,
  ) async {
    await _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .doc(attendance.id)
        .update(attendance.copyWith(updatedAt: DateTime.now()).toMap());
  }

  static Future<void> markBulkAttendance(
    String vendorId,
    List<Attendance> attendanceList,
  ) async {
    final batch = _firestore.batch();
    final collectionRef = _firestore.collection(
      _getVendorCollectionPath(vendorId),
    );

    for (final attendance in attendanceList) {
      if (attendance.id.isEmpty) {
        // New attendance - generate ID
        final docRef = collectionRef.doc();
        final attendanceWithId = attendance.copyWith(id: docRef.id);
        batch.set(docRef, attendanceWithId.toMap());
      } else {
        // Existing attendance - update
        batch.update(
          collectionRef.doc(attendance.id),
          attendance.copyWith(updatedAt: DateTime.now()).toMap(),
        );
      }
    }

    await batch.commit();
  }

  static Future<void> checkInStaff(String vendorId, String staffId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingAttendance = await getAttendanceByStaffAndDate(
      vendorId,
      staffId,
      today,
    );

    if (existingAttendance != null) {
      await updateAttendance(
        vendorId,
        existingAttendance.copyWith(checkInTime: now, updatedAt: now),
      );
    } else {
      // This should not happen normally, but handle it gracefully
      final staffDoc = await _firestore
          .collection('vendors/$vendorId/staff')
          .doc(staffId)
          .get();
      if (staffDoc.exists) {
        final staffData = staffDoc.data() as Map<String, dynamic>;
        final attendance =
            Attendance.create(
              staffId: staffId,
              staffName: staffData['name'] ?? '',
              dailyWage: (staffData['dailyWage'] ?? 0.0).toDouble(),
            ).copyWith(
              id: '', // Will be generated
              vendorId: vendorId,
              checkInTime: now,
              isPresent: true,
            );

        await addAttendance(vendorId, attendance);
      }
    }
  }

  static Future<void> checkOutStaff(String vendorId, String staffId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingAttendance = await getAttendanceByStaffAndDate(
      vendorId,
      staffId,
      today,
    );

    if (existingAttendance != null) {
      await updateAttendance(
        vendorId,
        existingAttendance.copyWith(checkOutTime: now, updatedAt: now),
      );
    }
  }

  // Add these methods to FirebaseAttendanceService in attendance_service.dart

  static Stream<List<Attendance>> getAttendanceByMonth(
    String vendorId,
    DateTime month,
  ) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data()))
              .toList(),
        );
  }

  static Stream<List<Attendance>> getStaffAttendanceByMonth(
    String vendorId,
    String staffId,
    DateTime month,
  ) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection(_getVendorCollectionPath(vendorId))
        .where('staffId', isEqualTo: staffId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data()))
              .toList(),
        );
  }
}
