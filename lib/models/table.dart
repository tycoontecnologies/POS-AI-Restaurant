enum TableStatus { empty, occupied, served, cleared }

class RestaurantTable {
  final String id;
  final String tableNumber; // Changed from int to String
  final int numberOfSeats;
  final TableStatus status;
  final DateTime createdAt;

  RestaurantTable({
    required this.id,
    required this.tableNumber, // Changed from int to String
    required this.numberOfSeats,
    required this.status,
    required this.createdAt,
  });

  // Convert to status string for Firebase
  String get statusString => status.toString().split('.').last;

  // Get status from string
  static TableStatus statusFromString(String status) {
    switch (status) {
      case 'occupied':
        return TableStatus.occupied;
      case 'served':
        return TableStatus.served;
      default:
        return TableStatus.empty;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableNumber': tableNumber, // Already String
      'numberOfSeats': numberOfSeats,
      'status': statusString,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id'] ?? '',
      tableNumber: map['tableNumber']?.toString() ?? '0', // Convert to String
      numberOfSeats: map['numberOfSeats'] ?? 0,
      status: statusFromString(map['status'] ?? 'empty'),
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  RestaurantTable copyWith({
    String? id,
    String? tableNumber, // Changed from int? to String?
    int? numberOfSeats,
    TableStatus? status,
    DateTime? createdAt,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      numberOfSeats: numberOfSeats ?? this.numberOfSeats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
