import 'package:cloud_firestore/cloud_firestore.dart';

class VendorIssue {
  final String id;
  final String tagId;
  final String productName;
  final String vendor;
  final int quantity;
  final String issueType;
  final String actionTaken;
  final DateTime dateReported;
  final String notes;
  final String photoUrl;
  final double refundAmount;

  VendorIssue({
    required this.id,
    required this.tagId,
    required this.productName,
    required this.vendor,
    required this.quantity,
    required this.issueType,
    required this.actionTaken,
    required this.dateReported,
    this.notes = '',
    this.photoUrl = '',
    this.refundAmount = 0.0,
  });

  VendorIssue copyWith({
    String? id,
    String? tagId,
    String? productName,
    String? vendor,
    int? quantity,
    String? issueType,
    String? actionTaken,
    DateTime? dateReported,
    String? notes,
    String? photoUrl,
    double? refundAmount,
  }) {
    return VendorIssue(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      productName: productName ?? this.productName,
      vendor: vendor ?? this.vendor,
      quantity: quantity ?? this.quantity,
      issueType: issueType ?? this.issueType,
      actionTaken: actionTaken ?? this.actionTaken,
      dateReported: dateReported ?? this.dateReported,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      refundAmount: refundAmount ?? this.refundAmount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tagId': tagId,
      'productName': productName,
      'vendor': vendor,
      'quantity': quantity,
      'issueType': issueType,
      'actionTaken': actionTaken,
      'dateReported': dateReported.toIso8601String(),
      'notes': notes,
      'photoUrl': photoUrl,
      'refundAmount': refundAmount,
    };
  }

  factory VendorIssue.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parsedDate;
    final dynamic dr = json['dateReported'];
    if (dr is Timestamp) {
      parsedDate = dr.toDate();
    } else if (dr is String) {
      parsedDate = DateTime.tryParse(dr) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return VendorIssue(
      id: id ?? json['id'] as String? ?? '',
      tagId: json['tagId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      issueType: json['issueType'] as String? ?? '',
      actionTaken: json['actionTaken'] as String? ?? '',
      dateReported: parsedDate,
      notes: json['notes'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
