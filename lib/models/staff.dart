class Staff {
  final String id;
  final String name;
  final String role;
  final double dailyWage;
  final String phone;
  final String address;
  final bool active;
  final DateTime joinDate;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.dailyWage,
    this.phone = '',
    this.address = '',
    this.active = true,
    required this.joinDate,
  });

  Staff copyWith({
    String? id,
    String? name,
    String? role,
    double? dailyWage,
    String? phone,
    String? address,
    bool? active,
    DateTime? joinDate,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      dailyWage: dailyWage ?? this.dailyWage,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      active: active ?? this.active,
      joinDate: joinDate ?? this.joinDate,
    );
  }
}
