class Category {
  Category({
    required this.id,
    required this.name,
    this.active = true,
    this.imageUrl = '',
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  String name;
  bool active;
  String imageUrl;
  DateTime createdOn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'active': active,
    'imageUrl': imageUrl,
    'createdOn': createdOn.toIso8601String(),
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    active: json['active'] ?? true,
    imageUrl: json['imageUrl'] ?? '',
    createdOn: DateTime.parse(json['createdOn']),
  );

  Category copyWith({
    String? id,
    String? name,
    bool? active,
    String? imageUrl,
    DateTime? createdOn,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      imageUrl: imageUrl ?? this.imageUrl,
      createdOn: createdOn ?? this.createdOn,
    );
  }
}