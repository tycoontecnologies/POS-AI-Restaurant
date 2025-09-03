class Draft {
  final String id;
  final String vendorId;
  final String type;
  final int items;
  final double total;
  final DateTime date;
  final String status;
  final List<Map<String, dynamic>> cartItems; // Add this field

  Draft({
    required this.id,
    required this.vendorId,
    required this.type,
    required this.items,
    required this.total,
    required this.date,
    required this.status,
    required this.cartItems, // Add this parameter
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'type': type,
      'items': items,
      'total': total,
      'date': date.millisecondsSinceEpoch,
      'status': status,
      'cartItems': cartItems, // Include in serialization
    };
  }

  factory Draft.fromMap(Map<String, dynamic> map, String documentId) {
    return Draft(
      id: map['id'] as String? ?? documentId,
      vendorId: map['vendorId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      items: (map['items'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? 0),
      status: map['status'] as String? ?? '',
      cartItems: (map['cartItems'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [], // Handle deserialization
    );
  }
}