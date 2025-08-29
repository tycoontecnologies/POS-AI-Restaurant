class Category {
  Category({
    required this.id,
    required this.name,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  String name;
  bool active;
  DateTime createdOn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'active': active,
    'createdOn': createdOn.toIso8601String(),
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    active: json['active'] ?? true,
    createdOn: DateTime.parse(json['createdOn']),
  );
}
