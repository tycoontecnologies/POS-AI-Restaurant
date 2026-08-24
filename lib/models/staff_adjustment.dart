class StaffAdjustment {
  final String id;
  final String staffId;
  final String staffName;
  final String type;
  final String title;
  final String? itemId;
  final String? itemName;
  final double amount;
  final String recoverySource;
  final String reason;
  final String? evidenceNote;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  const StaffAdjustment({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.type,
    required this.title,
    this.itemId,
    this.itemName,
    required this.amount,
    required this.recoverySource,
    required this.reason,
    this.evidenceNote,
    this.status = 'pending',
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffId': staffId,
        'staffName': staffName,
        'type': type,
        'title': title,
        'itemId': itemId,
        'itemName': itemName,
        'amount': amount,
        'recoverySource': recoverySource,
        'reason': reason,
        'evidenceNote': evidenceNote,
        'status': status,
        'createdBy': createdBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory StaffAdjustment.fromMap(Map<String, dynamic> map) => StaffAdjustment(
        id: (map['id'] ?? '').toString(),
        staffId: (map['staffId'] ?? '').toString(),
        staffName: (map['staffName'] ?? '').toString(),
        type: (map['type'] ?? 'leakage').toString(),
        title: (map['title'] ?? '').toString(),
        itemId: map['itemId']?.toString(),
        itemName: map['itemName']?.toString(),
        amount: (map['amount'] ?? 0).toDouble(),
        recoverySource: (map['recoverySource'] ?? 'salary').toString(),
        reason: (map['reason'] ?? '').toString(),
        evidenceNote: map['evidenceNote']?.toString(),
        status: (map['status'] ?? 'pending').toString(),
        createdBy: (map['createdBy'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      );
}
