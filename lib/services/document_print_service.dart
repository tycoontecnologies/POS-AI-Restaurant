import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentPrintService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<int> nextPrintNumber({
    required String restaurantId,
    required String documentType,
    required String documentId,
    required String userId,
    String? branchId,
  }) async {
    final doc = _db
        .collection('vendors')
        .doc(restaurantId)
        .collection('documentPrintAudit')
        .doc('${documentType.toLowerCase()}_$documentId');

    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(doc);
      final current = (snap.data()?['printCount'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tx.set(
        doc,
        {
          'documentType': documentType,
          'documentId': documentId,
          'printCount': next,
          'lastPrintedAt': FieldValue.serverTimestamp(),
          'lastPrintedBy': userId,
          'branchId': branchId ?? 'main',
        },
        SetOptions(merge: true),
      );

      final logRef = doc.collection('prints').doc();
      tx.set(logRef, {
        'printNumber': next,
        'printedAt': FieldValue.serverTimestamp(),
        'printedBy': userId,
        'branchId': branchId ?? 'main',
      });
      return next;
    });
  }

  static String ordinal(int n) {
    if (n <= 0) return '$n';
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
