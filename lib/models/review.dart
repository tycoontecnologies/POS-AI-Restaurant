import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String customerId;
  final String customerName;
  final int rating; // 1-5 stars
  final String feedback;
  final DateTime createdOn;
  final DateTime? updatedOn;

  Review({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.feedback,
    required this.createdOn,
    this.updatedOn,
  });

  factory Review.fromMap(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      rating: data['rating'] ?? 5,
      feedback: data['feedback'] ?? '',
      createdOn: data['createdOn'] != null
          ? (data['createdOn'] as Timestamp).toDate()
          : DateTime.now(),
      updatedOn: data['updatedOn'] != null
          ? (data['updatedOn'] as Timestamp).toDate()
          : null,
    );
  }

  Review copyWith({
    String? id,
    String? customerId,
    String? customerName,
    int? rating,
    String? feedback,
    DateTime? createdOn,
    DateTime? updatedOn,
  }) {
    return Review(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      createdOn: createdOn ?? this.createdOn,
      updatedOn: updatedOn ?? this.updatedOn,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'feedback': feedback,
      'createdOn': Timestamp.fromDate(createdOn),
      'updatedOn': updatedOn != null ? Timestamp.fromDate(updatedOn!) : null,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Review &&
        other.id == id &&
        other.customerId == customerId &&
        other.customerName == customerName &&
        other.rating == rating &&
        other.feedback == feedback &&
        other.createdOn == createdOn &&
        other.updatedOn == updatedOn;
  }

  @override
  int get hashCode {
    return Object.hash(id, customerId, customerName, rating, feedback,
        createdOn, updatedOn);
  }
}
