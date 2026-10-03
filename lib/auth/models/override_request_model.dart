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
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp'] as DateTime
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterUid': requesterUid,
      'requesterName': requesterName,
      'actionType': actionType,
      'status': status,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}
