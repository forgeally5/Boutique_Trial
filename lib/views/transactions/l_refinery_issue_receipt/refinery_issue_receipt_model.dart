import 'package:cloud_firestore/cloud_firestore.dart';

class RefineryIssueReceipt {
  final String docId;
  final String transactionNo;
  final DateTime date;
  final String transactionType; // 'Refinery Issue' or 'Refinery Receipt'
  final String refineryName;
  final String referenceIssueNo;
  final String referenceIssueDocId;
  final String tagId;
  final String itemName;
  final int quantity;
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double purity;
  final double fineWeight;
  final double issuedFineWeight;
  final double receivedFineWeight;
  final double lossDifference;
  final String status; // 'DRAFT', 'ISSUED', 'PARTIALLY RECEIVED', 'COMPLETED', 'CANCELLED'
  final String remarks;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // New fields for financial/refining details and payment bookkeeping
  final double goldRate;
  final double lossGainAmount;
  final double refiningServiceRate;
  final double refiningServiceAmount;
  final double taxPercentage;
  final double taxAmount;
  final double netAmount;
  final String paymentBook;
  final String paymentReference;
  final bool isPaid;
  final String bankEntryDocId;

  // New fields for separate received weights and refining charge type
  final double receivedGrossWeight;
  final double receivedStoneWeight;
  final double receivedNetWeight;
  final double receivedPurity;
  final String refiningChargeType; // 'Per Gram Gross Wt', 'Per Gram Net Wt', 'Per Gram Fine Wt', 'Fixed'

  RefineryIssueReceipt({
    required this.docId,
    required this.transactionNo,
    required this.date,
    required this.transactionType,
    required this.refineryName,
    required this.referenceIssueNo,
    required this.referenceIssueDocId,
    this.tagId = '',
    required this.itemName,
    required this.quantity,
    required this.grossWeight,
    required this.stoneWeight,
    required this.netWeight,
    required this.purity,
    required this.fineWeight,
    required this.issuedFineWeight,
    required this.receivedFineWeight,
    required this.lossDifference,
    required this.status,
    required this.remarks,
    required this.createdAt,
    this.updatedAt,
    this.goldRate = 0.0,
    this.lossGainAmount = 0.0,
    this.refiningServiceRate = 0.0,
    this.refiningServiceAmount = 0.0,
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.netAmount = 0.0,
    this.paymentBook = '',
    this.paymentReference = '',
    this.isPaid = false,
    this.bankEntryDocId = '',
    this.receivedGrossWeight = 0.0,
    this.receivedStoneWeight = 0.0,
    this.receivedNetWeight = 0.0,
    this.receivedPurity = 0.0,
    this.refiningChargeType = 'Per Gram Fine Wt',
  });

  bool get isIssue => transactionType.toLowerCase().contains('issue');

  Map<String, dynamic> toMap() {
    return {
      'transactionNo': transactionNo,
      'date': Timestamp.fromDate(date),
      'transactionType': transactionType,
      'refineryName': refineryName,
      'referenceIssueNo': referenceIssueNo,
      'referenceIssueDocId': referenceIssueDocId,
      'tagId': tagId,
      'itemName': itemName,
      'quantity': quantity,
      'grossWeight': grossWeight,
      'stoneWeight': stoneWeight,
      'netWeight': netWeight,
      'purity': purity,
      'fineWeight': fineWeight,
      'issuedFineWeight': issuedFineWeight,
      'receivedFineWeight': receivedFineWeight,
      'lossDifference': lossDifference,
      'status': status,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'goldRate': goldRate,
      'lossGainAmount': lossGainAmount,
      'refiningServiceRate': refiningServiceRate,
      'refiningServiceAmount': refiningServiceAmount,
      'taxPercentage': taxPercentage,
      'taxAmount': taxAmount,
      'netAmount': netAmount,
      'paymentBook': paymentBook,
      'paymentReference': paymentReference,
      'isPaid': isPaid,
      'bankEntryDocId': bankEntryDocId,
      'receivedGrossWeight': receivedGrossWeight,
      'receivedStoneWeight': receivedStoneWeight,
      'receivedNetWeight': receivedNetWeight,
      'receivedPurity': receivedPurity,
      'refiningChargeType': refiningChargeType,
    };
  }

  factory RefineryIssueReceipt.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return RefineryIssueReceipt(
      docId: docId,
      transactionNo: map['transactionNo'] ?? '',
      date: parseDate(map['date']),
      transactionType: map['transactionType'] ?? 'Refinery Issue',
      refineryName: map['refineryName'] ?? '',
      referenceIssueNo: map['referenceIssueNo'] ?? '',
      referenceIssueDocId: map['referenceIssueDocId'] ?? '',
      tagId: map['tagId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      grossWeight: (map['grossWeight'] as num?)?.toDouble() ?? 0.0,
      stoneWeight: (map['stoneWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (map['netWeight'] as num?)?.toDouble() ?? 0.0,
      purity: (map['purity'] as num?)?.toDouble() ?? 0.0,
      fineWeight: (map['fineWeight'] as num?)?.toDouble() ?? 0.0,
      issuedFineWeight: (map['issuedFineWeight'] as num?)?.toDouble() ?? 0.0,
      receivedFineWeight: (map['receivedFineWeight'] as num?)?.toDouble() ?? 0.0,
      lossDifference: (map['lossDifference'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'ISSUED',
      remarks: map['remarks'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      goldRate: (map['goldRate'] as num?)?.toDouble() ?? 0.0,
      lossGainAmount: (map['lossGainAmount'] as num?)?.toDouble() ?? 0.0,
      refiningServiceRate: (map['refiningServiceRate'] as num?)?.toDouble() ?? 0.0,
      refiningServiceAmount: (map['refiningServiceAmount'] as num?)?.toDouble() ?? 0.0,
      taxPercentage: (map['taxPercentage'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      paymentBook: map['paymentBook'] ?? '',
      paymentReference: map['paymentReference'] ?? '',
      isPaid: map['isPaid'] ?? false,
      bankEntryDocId: map['bankEntryDocId'] ?? '',
      receivedGrossWeight: (map['receivedGrossWeight'] as num?)?.toDouble() ?? 0.0,
      receivedStoneWeight: (map['receivedStoneWeight'] as num?)?.toDouble() ?? 0.0,
      receivedNetWeight: (map['receivedNetWeight'] as num?)?.toDouble() ?? 0.0,
      receivedPurity: (map['receivedPurity'] as num?)?.toDouble() ?? 0.0,
      refiningChargeType: map['refiningChargeType'] ?? 'Per Gram Fine Wt',
    );
  }
}
