import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCounterStockEntry {
  final String docId;
  final String transactionNo;
  final DateTime date;
  final String fromCounter;
  final String toCounter;
  final String labelNo;
  final String itemName;
  final int pcs;
  final double grossWeight;
  final double netWeight;
  final String remarks;
  final String status; // 'DRAFT', 'COMPLETED', 'CANCELLED'
  final DateTime createdAt;
  final DateTime? updatedAt;

  DailyCounterStockEntry({
    required this.docId,
    required this.transactionNo,
    required this.date,
    required this.fromCounter,
    required this.toCounter,
    required this.labelNo,
    required this.itemName,
    required this.pcs,
    required this.grossWeight,
    required this.netWeight,
    required this.remarks,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionNo': transactionNo,
      'date': Timestamp.fromDate(date),
      'fromCounter': fromCounter,
      'toCounter': toCounter,
      'labelNo': labelNo,
      'itemName': itemName,
      'pcs': pcs,
      'grossWeight': grossWeight,
      'netWeight': netWeight,
      'remarks': remarks,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory DailyCounterStockEntry.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return DailyCounterStockEntry(
      docId: docId,
      transactionNo: map['transactionNo'] ?? '',
      date: parseDate(map['date']),
      fromCounter: map['fromCounter'] ?? '',
      toCounter: map['toCounter'] ?? '',
      labelNo: map['labelNo'] ?? '',
      itemName: map['itemName'] ?? '',
      pcs: (map['pcs'] as num?)?.toInt() ?? 1,
      grossWeight: (map['grossWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (map['netWeight'] as num?)?.toDouble() ?? 0.0,
      remarks: map['remarks'] ?? '',
      status: map['status'] ?? 'COMPLETED',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}