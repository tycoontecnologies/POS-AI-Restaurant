// models/staff.dart
class Staff {
  final String id;
  final String name;
  final String role;
  final double dailyWage;
  final String phone;
  final String address;
  final bool active;
  final DateTime joinDate;
  final List<String> searchKeywords;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.dailyWage,
    this.phone = '',
    this.address = '',
    this.active = true,
    required this.joinDate,
    List<String>? searchKeywords,
  }) : searchKeywords = searchKeywords ?? _generateSearchKeywords(name, role, phone);

  static List<String> _generateSearchKeywords(String name, String role, String phone) {
    final keywords = <String>[];
    
    // Add full strings
    keywords.addAll([name.toLowerCase(), role.toLowerCase(), phone.toLowerCase()]);
    
    // Add individual words
    keywords.addAll(name.toLowerCase().split(' '));
    keywords.addAll(role.toLowerCase().split(' '));
    
    // Remove empty strings and duplicates
    return keywords.where((keyword) => keyword.isNotEmpty).toSet().toList();
  }

  Staff copyWith({
    String? id,
    String? name,
    String? role,
    double? dailyWage,
    String? phone,
    String? address,
    bool? active,
    DateTime? joinDate,
    List<String>? searchKeywords,
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
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'dailyWage': dailyWage,
    'phone': phone,
    'address': address,
    'active': active,
    'joinDate': joinDate.toIso8601String(),
    'searchKeywords': searchKeywords,
  };

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
    id: json['id'],
    name: json['name'],
    role: json['role'],
    dailyWage: json['dailyWage']?.toDouble() ?? 0.0,
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    active: json['active'] ?? true,
    joinDate: DateTime.parse(json['joinDate']),
    searchKeywords: (json['searchKeywords'] as List<dynamic>?)?.cast<String>() ?? [],
  );
}