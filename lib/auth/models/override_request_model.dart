import 'package:cloud_firestore/cloud_firestore.dart';

class OverrideRequestModel {
  final String id;
  final String requesterUid;
  final String requesterName;
  final String actionType; // e.g., 'Delete Bill #104'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? timestamp;

  const OverrideRequestModel({
    required this.id,
    required this.requesterUid,
    required this.requesterName,
    required this.actionType,
    required this.status,
    this.timestamp,
  });

  factory OverrideRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return OverrideRequestModel(
      id: docId,
      requesterUid: map['requesterUid'] ?? '',
      requesterName: map['requesterName'] ?? '',
      actionType: map['actionType'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterUid': requesterUid,
      'requesterName': requesterName,
      'actionType': actionType,
      'status': status,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }
}
