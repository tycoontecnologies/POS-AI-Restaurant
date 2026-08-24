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
  final String? photoUrl;
  final bool canChangePhoto;
  final double commissionRate;
  final bool showCommissionToStaff;
  final double tipsEarned;
  final double commissionEarned;
  final double serviceChargesEarned;
  final int pointsEarned;
  final double averageRating;
  final int reviewCount;
  final double leakageTotal;
  final double deductionsTotal;

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
    this.photoUrl,
    this.canChangePhoto = false,
    this.commissionRate = 0,
    this.showCommissionToStaff = false,
    this.tipsEarned = 0,
    this.commissionEarned = 0,
    this.serviceChargesEarned = 0,
    this.pointsEarned = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.leakageTotal = 0,
    this.deductionsTotal = 0,
  }) : searchKeywords = searchKeywords ?? _generateSearchKeywords(name, role, phone);

  static List<String> _generateSearchKeywords(String name, String role, String phone) {
    final keywords = <String>[];
    keywords.addAll([name.toLowerCase(), role.toLowerCase(), phone.toLowerCase()]);
    keywords.addAll(name.toLowerCase().split(' '));
    keywords.addAll(role.toLowerCase().split(' '));
    return keywords.where((keyword) => keyword.isNotEmpty).toSet().toList();
  }

  double get grossVariableIncome => tipsEarned + commissionEarned + serviceChargesEarned;
  double get netVariableIncome => grossVariableIncome - deductionsTotal;

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
    String? photoUrl,
    bool? canChangePhoto,
    double? commissionRate,
    bool? showCommissionToStaff,
    double? tipsEarned,
    double? commissionEarned,
    double? serviceChargesEarned,
    int? pointsEarned,
    double? averageRating,
    int? reviewCount,
    double? leakageTotal,
    double? deductionsTotal,
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
      photoUrl: photoUrl ?? this.photoUrl,
      canChangePhoto: canChangePhoto ?? this.canChangePhoto,
      commissionRate: commissionRate ?? this.commissionRate,
      showCommissionToStaff: showCommissionToStaff ?? this.showCommissionToStaff,
      tipsEarned: tipsEarned ?? this.tipsEarned,
      commissionEarned: commissionEarned ?? this.commissionEarned,
      serviceChargesEarned: serviceChargesEarned ?? this.serviceChargesEarned,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      leakageTotal: leakageTotal ?? this.leakageTotal,
      deductionsTotal: deductionsTotal ?? this.deductionsTotal,
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
    'photoUrl': photoUrl,
    'canChangePhoto': canChangePhoto,
    'commissionRate': commissionRate,
    'showCommissionToStaff': showCommissionToStaff,
    'tipsEarned': tipsEarned,
    'commissionEarned': commissionEarned,
    'serviceChargesEarned': serviceChargesEarned,
    'pointsEarned': pointsEarned,
    'averageRating': averageRating,
    'reviewCount': reviewCount,
    'leakageTotal': leakageTotal,
    'deductionsTotal': deductionsTotal,
  };

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    role: json['role'] ?? '',
    dailyWage: json['dailyWage']?.toDouble() ?? 0.0,
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    active: json['active'] ?? true,
    joinDate: DateTime.tryParse((json['joinDate'] ?? '').toString()) ?? DateTime.now(),
    searchKeywords: (json['searchKeywords'] as List<dynamic>?)?.cast<String>() ?? [],
    photoUrl: json['photoUrl']?.toString(),
    canChangePhoto: json['canChangePhoto'] == true,
    commissionRate: (json['commissionRate'] ?? 0).toDouble(),
    showCommissionToStaff: json['showCommissionToStaff'] == true,
    tipsEarned: (json['tipsEarned'] ?? 0).toDouble(),
    commissionEarned: (json['commissionEarned'] ?? 0).toDouble(),
    serviceChargesEarned: (json['serviceChargesEarned'] ?? 0).toDouble(),
    pointsEarned: (json['pointsEarned'] ?? 0).toInt(),
    averageRating: (json['averageRating'] ?? 0).toDouble(),
    reviewCount: (json['reviewCount'] ?? 0).toInt(),
    leakageTotal: (json['leakageTotal'] ?? 0).toDouble(),
    deductionsTotal: (json['deductionsTotal'] ?? 0).toDouble(),
  );
}
