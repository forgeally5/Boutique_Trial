import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerIssueReceiptItem {
  final String tagId;
  final String itemName;
  final String metalType;
  final double purity;
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double ratePerGram;
  final double amount;
  final double makingCharges;
  final double deductionPercent;
  final List<String> photoUrls;
  final String remarks;
  final String branchId;
  final int pcs;

  CustomerIssueReceiptItem({
    required this.tagId,
    required this.itemName,
    required this.metalType,
    required this.purity,
    required this.grossWeight,
    required this.stoneWeight,
    required this.netWeight,
    required this.ratePerGram,
    required this.amount,
    required this.makingCharges,
    this.deductionPercent = 0.0,
    this.photoUrls = const [],
    required this.remarks,
    this.branchId = '',
    this.pcs = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'itemName': itemName,
      'metalType': metalType,
      'purity': purity,
      'grossWeight': grossWeight,
      'stoneWeight': stoneWeight,
      'netWeight': netWeight,
      'ratePerGram': ratePerGram,
      'amount': amount,
      'makingCharges': makingCharges,
      'deductionPercent': deductionPercent,
      'photoUrls': photoUrls,
      'remarks': remarks,
      'branchId': branchId,
      'pcs': pcs,
    };
  }

  factory CustomerIssueReceiptItem.fromMap(Map<String, dynamic> map) {
    return CustomerIssueReceiptItem(
      tagId: map['tagId'] ?? '',
      itemName: map['itemName'] ?? '',
      metalType: map['metalType'] ?? 'Gold',
      purity: (map['purity'] as num?)?.toDouble() ?? 0.0,
      grossWeight: (map['grossWeight'] as num?)?.toDouble() ?? 0.0,
      stoneWeight: (map['stoneWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (map['netWeight'] as num?)?.toDouble() ?? 0.0,
      ratePerGram: (map['ratePerGram'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      makingCharges: (map['makingCharges'] as num?)?.toDouble() ?? 0.0,
      deductionPercent: (map['deductionPercent'] as num?)?.toDouble() ?? 0.0,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      remarks: map['remarks'] ?? '',
      branchId: map['branchId'] ?? '',
      pcs: (map['pcs'] as num?)?.toInt() ?? 1,
    );
  }
}

class CustomerIssueReceipt {
  final String docId;
  final String transactionNo;
  final DateTime date;
  final String transactionType; // 'Customer Issue' or 'Customer Receipt'
  final String receiptSubtype; // 'Approval Return' or 'Old Gold Purchase'
  final String customerName;
  final String referenceNo;
  final String referenceEntryId;
  final String branchId;
  final String staffId;
  final DateTime? expectedReturnDate;
  
  final List<CustomerIssueReceiptItem> items;
  
  final double totalGrossWeight;
  final double totalNetWeight;
  final double totalDiamondWeight;
  final double totalAmount;
  
  final double paymentCash;
  final double paymentBank;
  final double paymentCard;
  
  final String termsText;
  final bool isSignedPhysically;
  final String signatureUrl;

  final String status; // 'DRAFT', 'COMPLETED', 'CANCELLED', 'RETURNED', 'CONVERTED_TO_SALE', 'SETTLED'
  final String remarks;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CustomerIssueReceipt({
    required this.docId,
    required this.transactionNo,
    required this.date,
    required this.transactionType,
    this.receiptSubtype = '',
    required this.customerName,
    required this.referenceNo,
    this.referenceEntryId = '',
    this.branchId = '',
    this.staffId = '',
    this.expectedReturnDate,
    required this.items,
    required this.totalGrossWeight,
    required this.totalNetWeight,
    required this.totalDiamondWeight,
    required this.totalAmount,
    this.paymentCash = 0.0,
    this.paymentBank = 0.0,
    this.paymentCard = 0.0,
    this.termsText = '',
    this.isSignedPhysically = false,
    this.signatureUrl = '',
    required this.status,
    required this.remarks,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIssue => transactionType.toLowerCase().contains('issue');

  Map<String, dynamic> toMap() {
    return {
      'transactionNo': transactionNo,
      'date': Timestamp.fromDate(date),
      'transactionType': transactionType,
      'receiptSubtype': receiptSubtype,
      'customerName': customerName,
      'referenceNo': referenceNo,
      'referenceEntryId': referenceEntryId,
      'branchId': branchId,
      'staffId': staffId,
      'expectedReturnDate': expectedReturnDate != null ? Timestamp.fromDate(expectedReturnDate!) : null,
      'items': items.map((i) => i.toMap()).toList(),
      'totalGrossWeight': totalGrossWeight,
      'totalNetWeight': totalNetWeight,
      'totalDiamondWeight': totalDiamondWeight,
      'totalAmount': totalAmount,
      'paymentCash': paymentCash,
      'paymentBank': paymentBank,
      'paymentCard': paymentCard,
      'termsText': termsText,
      'isSignedPhysically': isSignedPhysically,
      'signatureUrl': signatureUrl,
      'status': status,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory CustomerIssueReceipt.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return CustomerIssueReceipt(
      docId: docId,
      transactionNo: map['transactionNo'] ?? '',
      date: parseDate(map['date']),
      transactionType: map['transactionType'] ?? 'Customer Receipt',
      receiptSubtype: map['receiptSubtype'] ?? '',
      customerName: map['customerName'] ?? '',
      referenceNo: map['referenceNo'] ?? '',
      referenceEntryId: map['referenceEntryId'] ?? '',
      branchId: map['branchId'] ?? '',
      staffId: map['staffId'] ?? '',
      expectedReturnDate: map['expectedReturnDate'] != null ? parseDate(map['expectedReturnDate']) : null,
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => CustomerIssueReceiptItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalGrossWeight: (map['totalGrossWeight'] as num?)?.toDouble() ?? 0.0,
      totalNetWeight: (map['totalNetWeight'] as num?)?.toDouble() ?? 0.0,
      totalDiamondWeight: (map['totalDiamondWeight'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentCash: (map['paymentCash'] as num?)?.toDouble() ?? 0.0,
      paymentBank: (map['paymentBank'] as num?)?.toDouble() ?? 0.0,
      paymentCard: (map['paymentCard'] as num?)?.toDouble() ?? 0.0,
      termsText: map['termsText'] ?? '',
      isSignedPhysically: map['isSignedPhysically'] ?? false,
      signatureUrl: map['signatureUrl'] ?? '',
      status: map['status'] ?? 'COMPLETED',
      remarks: map['remarks'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}
