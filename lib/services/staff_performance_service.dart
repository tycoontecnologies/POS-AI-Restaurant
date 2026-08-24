import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/staff_adjustment.dart';

class StaffPerformanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _staff(String restaurantId) =>
      _db.collection('vendors').doc(restaurantId).collection('staff');

  static Future<void> addTip({
    required String restaurantId,
    required String staffId,
    required double amount,
    required String saleId,
    required String createdBy,
  }) async {
    if (amount <= 0) return;
    final ref = _staff(restaurantId).doc(staffId);
    final log = ref.collection('performanceLedger').doc();
    final batch = _db.batch();
    batch.set(log, {
      'type': 'tip',
      'amount': amount,
      'saleId': saleId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {'tipsEarned': FieldValue.increment(amount)}, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> addCommission({
    required String restaurantId,
    required String staffId,
    required double amount,
    required String saleId,
    required String createdBy,
  }) async {
    if (amount <= 0) return;
    final ref = _staff(restaurantId).doc(staffId);
    final log = ref.collection('performanceLedger').doc();
    final batch = _db.batch();
    batch.set(log, {
      'type': 'commission',
      'amount': amount,
      'saleId': saleId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {'commissionEarned': FieldValue.increment(amount)}, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> addPoints({
    required String restaurantId,
    required String staffId,
    required int points,
    required String reason,
    required String createdBy,
  }) async {
    if (points == 0) return;
    final ref = _staff(restaurantId).doc(staffId);
    final batch = _db.batch();
    batch.set(ref.collection('performanceLedger').doc(), {
      'type': 'points',
      'points': points,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {'pointsEarned': FieldValue.increment(points)}, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> addReview({
    required String restaurantId,
    required String staffId,
    required double rating,
    required String review,
    String? saleId,
    String? customerId,
  }) async {
    final ref = _staff(restaurantId).doc(staffId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final count = (data['reviewCount'] as num?)?.toInt() ?? 0;
      final average = (data['averageRating'] as num?)?.toDouble() ?? 0;
      final nextCount = count + 1;
      final nextAverage = ((average * count) + rating) / nextCount;
      tx.set(ref, {'reviewCount': nextCount, 'averageRating': nextAverage}, SetOptions(merge: true));
      tx.set(ref.collection('reviews').doc(), {
        'rating': rating,
        'review': review,
        'saleId': saleId,
        'customerId': customerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> recordAdjustment({
    required String restaurantId,
    required StaffAdjustment adjustment,
  }) async {
    final ref = _staff(restaurantId).doc(adjustment.staffId);
    final adjustmentRef = ref.collection('adjustments').doc(adjustment.id);
    final batch = _db.batch();
    batch.set(adjustmentRef, adjustment.toMap());
    batch.set(
      ref,
      {
        'leakageTotal': FieldValue.increment(adjustment.amount),
        'deductionsTotal': FieldValue.increment(adjustment.amount),
      },
      SetOptions(merge: true),
    );
    batch.set(ref.collection('performanceLedger').doc(), {
      'type': adjustment.type,
      'amount': -adjustment.amount,
      'title': adjustment.title,
      'itemId': adjustment.itemId,
      'itemName': adjustment.itemName,
      'recoverySource': adjustment.recoverySource,
      'reason': adjustment.reason,
      'status': adjustment.status,
      'createdBy': adjustment.createdBy,
      'createdAt': adjustment.createdAt.millisecondsSinceEpoch,
    });
    await batch.commit();
  }

  static Future<void> setPhotoPermission({
    required String restaurantId,
    required String staffId,
    required bool allowed,
  }) async {
    await _staff(restaurantId).doc(staffId).set(
      {'canChangePhoto': allowed},
      SetOptions(merge: true),
    );
  }

  static Future<void> setCommissionVisibility({
    required String restaurantId,
    required String staffId,
    required bool visible,
  }) async {
    await _staff(restaurantId).doc(staffId).set(
      {'showCommissionToStaff': visible},
      SetOptions(merge: true),
    );
  }
}
