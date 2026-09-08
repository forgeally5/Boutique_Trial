import 'package:cloud_firestore/cloud_firestore.dart';

class OutsourceManufacturingItem {
  final String tagId;
  final String itemName;
  final int quantity;
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double purity;
  final double fineWeight;
  final double wastageWeight;
  final double labourRate;
  final String labourType; // 'Per Gram' or 'Per Piece'
  final String remarks;
  final List<dynamic> extraCharges;

  OutsourceManufacturingItem({
    this.tagId = '',
    required this.itemName,
    required this.quantity,
    required this.grossWeight,
    required this.stoneWeight,
    required this.netWeight,
    required this.purity,
    required this.fineWeight,
    this.wastageWeight = 0.0,
    this.labourRate = 0.0,
    this.labourType = 'Per Gram',
    required this.remarks,
    this.extraCharges = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'itemName': itemName,
      'quantity': quantity,
      'grossWeight': grossWeight,
      'stoneWeight': stoneWeight,
      'netWeight': netWeight,
      'purity': purity,
      'fineWeight': fineWeight,
      'wastageWeight': wastageWeight,
      'labourRate': labourRate,
      'labourType': labourType,
      'remarks': remarks,
      'extraCharges': extraCharges,
    };
  }

  factory OutsourceManufacturingItem.fromMap(Map<String, dynamic> map) {
    return OutsourceManufacturingItem(
      tagId: map['tagId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      grossWeight: (map['grossWeight'] as num?)?.toDouble() ?? 0.0,
      stoneWeight: (map['stoneWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (map['netWeight'] as num?)?.toDouble() ?? 0.0,
      purity: (map['purity'] as num?)?.toDouble() ?? 0.0,
      fineWeight: (map['fineWeight'] as num?)?.toDouble() ?? 0.0,
      wastageWeight: (map['wastageWeight'] as num?)?.toDouble() ?? 0.0,
      labourRate: (map['labourRate'] as num?)?.toDouble() ?? 0.0,
      labourType: map['labourType'] ?? 'Per Gram',
      remarks: map['remarks'] ?? '',
      extraCharges: map['extraCharges'] as List<dynamic>? ?? const [],
    );
  }
}

class OutsourceManufacturing {
  final String docId;
  final String transactionNo;
  final DateTime date;
  final String transactionType; // 'Outsource Issue' or 'Outsource Receipt'
  final String artisanName;
  final String referenceNo;
  final List<OutsourceManufacturingItem> items;
  final double totalGrossWeight;
  final double totalNetWeight;
  final double totalFineWeight;
  final int totalQuantity;
  final String remarks;
  final String status; // 'DRAFT', 'COMPLETED', 'CANCELLED', 'ON PROCESS'

  // Tax & Labour additions
  final bool isReverseCharge;
  final bool isTdsApplicable;
  final double gstPercent;
  final double tdsPercent;
  final double totalLabourAmt;
  final double cgstAmt;
  final double sgstAmt;
  final double tdsAmt;
  final double netPayableAmt;

  final DateTime createdAt;
  final DateTime? updatedAt;

  OutsourceManufacturing({
    required this.docId,
    required this.transactionNo,
    required this.date,
    required this.transactionType,
    required this.artisanName,
    required this.referenceNo,
    required this.items,
    required this.totalGrossWeight,
    required this.totalNetWeight,
    required this.totalFineWeight,
    required this.totalQuantity,
    required this.remarks,
    required this.status,
    this.isReverseCharge = false,
    this.isTdsApplicable = false,
    this.gstPercent = 5.0,
    this.tdsPercent = 1.0,
    this.totalLabourAmt = 0.0,
    this.cgstAmt = 0.0,
    this.sgstAmt = 0.0,
    this.tdsAmt = 0.0,
    this.netPayableAmt = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIssue => transactionType.toLowerCase().contains('issue');

  Map<String, dynamic> toMap() {
    return {
      'transactionNo': transactionNo,
      'date': Timestamp.fromDate(date),
      'transactionType': transactionType,
      'artisanName': artisanName,
      'referenceNo': referenceNo,
      'items': items.map((i) => i.toMap()).toList(),
      'totalGrossWeight': totalGrossWeight,
      'totalNetWeight': totalNetWeight,
      'totalFineWeight': totalFineWeight,
      'totalQuantity': totalQuantity,
      'remarks': remarks,
      'status': status,
      'isReverseCharge': isReverseCharge,
      'isTdsApplicable': isTdsApplicable,
      'gstPercent': gstPercent,
      'tdsPercent': tdsPercent,
      'totalLabourAmt': totalLabourAmt,
      'cgstAmt': cgstAmt,
      'sgstAmt': sgstAmt,
      'tdsAmt': tdsAmt,
      'netPayableAmt': netPayableAmt,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory OutsourceManufacturing.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return OutsourceManufacturing(
      docId: docId,
      transactionNo: map['transactionNo'] ?? '',
      date: parseDate(map['date']),
      transactionType: map['transactionType'] ?? 'Outsource Issue',
      artisanName: map['artisanName'] ?? '',
      referenceNo: map['referenceNo'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => OutsourceManufacturingItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalGrossWeight: (map['totalGrossWeight'] as num?)?.toDouble() ?? 0.0,
      totalNetWeight: (map['totalNetWeight'] as num?)?.toDouble() ?? 0.0,
      totalFineWeight: (map['totalFineWeight'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 1,
      remarks: map['remarks'] ?? '',
      status: map['status'] ?? 'COMPLETED',
      isReverseCharge: map['isReverseCharge'] ?? false,
      isTdsApplicable: map['isTdsApplicable'] ?? false,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? 5.0,
      tdsPercent: (map['tdsPercent'] as num?)?.toDouble() ?? 1.0,
      totalLabourAmt: (map['totalLabourAmt'] as num?)?.toDouble() ?? 0.0,
      cgstAmt: (map['cgstAmt'] as num?)?.toDouble() ?? 0.0,
      sgstAmt: (map['sgstAmt'] as num?)?.toDouble() ?? 0.0,
      tdsAmt: (map['tdsAmt'] as num?)?.toDouble() ?? 0.0,
      netPayableAmt: (map['netPayableAmt'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}