import 'package:cloud_firestore/cloud_firestore.dart';

class ApprovalIssueReceipt {
  final String docId;
  final String transactionNo;
  final DateTime date;
  final String transactionType; // 'Approval Issue' or 'Approval Receipt'
  final String approvalCentre;
  final String referenceIssueNo;
  final String referenceIssueDocId;
  final String tagId;
  final String itemName;
  final int quantity;
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double originalPurity;
  final double approvedPurity;
  final double originalFineWeight;
  final double approvedFineWeight;
  final double difference;
  final String assayResult;
  final String status;
  final String remarks;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Billing fields (only for Approval Receipt)
  final double serviceChargeAmount;
  final double taxPercentage;
  final double taxAmount;
  final double netAmount;
  final String paymentBook;
  final String paymentReference;
  final bool isPaid;

  ApprovalIssueReceipt({
    required this.docId,
    required this.transactionNo,
    required this.date,
    required this.transactionType,
    required this.approvalCentre,
    required this.referenceIssueNo,
    required this.referenceIssueDocId,
    this.tagId = '',
    required this.itemName,
    required this.quantity,
    required this.grossWeight,
    required this.stoneWeight,
    required this.netWeight,
    required this.originalPurity,
    required this.approvedPurity,
    required this.originalFineWeight,
    required this.approvedFineWeight,
    required this.difference,
    required this.assayResult,
    required this.status,
    required this.remarks,
    required this.createdAt,
    this.updatedAt,
    this.serviceChargeAmount = 0.0,
    this.taxPercentage = 18.0,
    this.taxAmount = 0.0,
    this.netAmount = 0.0,
    this.paymentBook = '',
    this.paymentReference = '',
    this.isPaid = false,
  });

  bool get isIssue => transactionType.toLowerCase().contains('issue');

  Map<String, dynamic> toMap() {
    return {
      'transactionNo': transactionNo,
      'date': Timestamp.fromDate(date),
      'transactionType': transactionType,
      'approvalCentre': approvalCentre,
      'referenceIssueNo': referenceIssueNo,
      'referenceIssueDocId': referenceIssueDocId,
      'tagId': tagId,
      'itemName': itemName,
      'quantity': quantity,
      'grossWeight': grossWeight,
      'stoneWeight': stoneWeight,
      'netWeight': netWeight,
      'originalPurity': originalPurity,
      'approvedPurity': approvedPurity,
      'originalFineWeight': originalFineWeight,
      'approvedFineWeight': approvedFineWeight,
      'difference': difference,
      'assayResult': assayResult,
      'status': status,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'serviceChargeAmount': serviceChargeAmount,
      'taxPercentage': taxPercentage,
      'taxAmount': taxAmount,
      'netAmount': netAmount,
      'paymentBook': paymentBook,
      'paymentReference': paymentReference,
      'isPaid': isPaid,
    };
  }

  factory ApprovalIssueReceipt.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ApprovalIssueReceipt(
      docId: docId,
      transactionNo: map['transactionNo'] ?? '',
      date: parseDate(map['date']),
      transactionType: map['transactionType'] ?? 'Approval Issue',
      approvalCentre: map['approvalCentre'] ?? '',
      referenceIssueNo: map['referenceIssueNo'] ?? '',
      referenceIssueDocId: map['referenceIssueDocId'] ?? '',
      tagId: map['tagId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      grossWeight: (map['grossWeight'] as num?)?.toDouble() ?? 0.0,
      stoneWeight: (map['stoneWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (map['netWeight'] as num?)?.toDouble() ?? 0.0,
      originalPurity: (map['originalPurity'] as num?)?.toDouble() ?? 0.0,
      approvedPurity: (map['approvedPurity'] as num?)?.toDouble() ?? 0.0,
      originalFineWeight: (map['originalFineWeight'] as num?)?.toDouble() ?? 0.0,
      approvedFineWeight: (map['approvedFineWeight'] as num?)?.toDouble() ?? 0.0,
      difference: (map['difference'] as num?)?.toDouble() ?? 0.0,
      assayResult: map['assayResult'] ?? '',
      status: map['status'] ?? 'ISSUED',
      remarks: map['remarks'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      serviceChargeAmount: (map['serviceChargeAmount'] as num?)?.toDouble() ?? 0.0,
      taxPercentage: (map['taxPercentage'] as num?)?.toDouble() ?? 18.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      paymentBook: map['paymentBook'] ?? '',
      paymentReference: map['paymentReference'] ?? '',
      isPaid: map['isPaid'] as bool? ?? false,
    );
  }
}
