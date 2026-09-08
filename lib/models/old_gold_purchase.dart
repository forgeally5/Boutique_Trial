import 'package:cloud_firestore/cloud_firestore.dart';

class OldGoldPurchaseItem {
  final String itemName;
  final String labelNo;
  final String group;
  final double grossWt;
  final bool othReq;
  final double netWt;
  final double purity;
  final double fineWt;
  final int pcs;
  final double metalRate;
  final double metalAmount;
  final double labourRate;
  final double labourAmount;
  final double urdLessWt;

  OldGoldPurchaseItem({
    required this.itemName,
    required this.labelNo,
    required this.group,
    required this.grossWt,
    required this.othReq,
    required this.netWt,
    required this.purity,
    required this.fineWt,
    required this.pcs,
    required this.metalRate,
    required this.metalAmount,
    required this.labourRate,
    required this.labourAmount,
    required this.urdLessWt,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'labelNo': labelNo,
      'group': group,
      'grossWt': grossWt,
      'othReq': othReq,
      'netWt': netWt,
      'purity': purity,
      'fineWt': fineWt,
      'pcs': pcs,
      'metalRate': metalRate,
      'metalAmount': metalAmount,
      'labourRate': labourRate,
      'labourAmount': labourAmount,
      'urdLessWt': urdLessWt,
    };
  }

  factory OldGoldPurchaseItem.fromMap(Map<String, dynamic> map) {
    return OldGoldPurchaseItem(
      itemName: map['itemName']?.toString() ?? '',
      labelNo: map['labelNo']?.toString() ?? '',
      group: map['group']?.toString() ?? '',
      grossWt: (map['grossWt'] as num?)?.toDouble() ?? 0.0,
      othReq: map['othReq'] == true,
      netWt: (map['netWt'] as num?)?.toDouble() ?? 0.0,
      purity: (map['purity'] as num?)?.toDouble() ?? 0.0,
      fineWt: (map['fineWt'] as num?)?.toDouble() ?? 0.0,
      pcs: (map['pcs'] as num?)?.toInt() ?? 1,
      metalRate: (map['metalRate'] as num?)?.toDouble() ?? 0.0,
      metalAmount: (map['metalAmount'] as num?)?.toDouble() ?? 0.0,
      labourRate: (map['labourRate'] as num?)?.toDouble() ?? 0.0,
      labourAmount: (map['labourAmount'] as num?)?.toDouble() ?? 0.0,
      urdLessWt: (map['urdLessWt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OldGoldPurchase {
  final String voucherNo;
  final String bookName;
  final String acName;
  final String salesman;
  final String placeOfSupply;
  final DateTime voucherDate;
  final int dueDateDays;
  final DateTime dueDate;

  final List<OldGoldPurchaseItem> items;

  // Valuation breakdown (Debit)
  final double metalAmtTotal;
  final double labourAmtTotal;
  final double otherCharges;
  final double discountAmt;
  final double totalAmt;
  final double rndDiscount;

  // Payment Breakdown (Credit)
  final double cashAmt;
  final double bankAmt;
  final double cardAmt;
  final double ogPurchase;

  // Outstanding details
  final double voucherAmt;
  final double paymentAmt;
  final double dueAmt;
  final double previousOS;
  final double finalDue;

  final String createdBy;
  final DateTime? createdAt;
  final String voucherType; // 'Purchase' or 'Receipt'
  final String? parentVoucherNo;

  OldGoldPurchase({
    required this.voucherNo,
    required this.bookName,
    required this.acName,
    required this.salesman,
    required this.placeOfSupply,
    required this.voucherDate,
    required this.dueDateDays,
    required this.dueDate,
    required this.items,
    required this.metalAmtTotal,
    required this.labourAmtTotal,
    required this.otherCharges,
    required this.discountAmt,
    required this.totalAmt,
    required this.rndDiscount,
    required this.cashAmt,
    required this.bankAmt,
    required this.cardAmt,
    required this.ogPurchase,
    required this.voucherAmt,
    required this.paymentAmt,
    required this.dueAmt,
    required this.previousOS,
    required this.finalDue,
    required this.createdBy,
    this.createdAt,
    this.voucherType = 'Purchase',
    this.parentVoucherNo,
  });

  Map<String, dynamic> toMap() {
    return {
      'voucherNo': voucherNo,
      'bookName': bookName,
      'acName': acName,
      'salesman': salesman,
      'placeOfSupply': placeOfSupply,
      'voucherDate': Timestamp.fromDate(voucherDate),
      'dueDateDays': dueDateDays,
      'dueDate': Timestamp.fromDate(dueDate),
      'items': items.map((e) => e.toMap()).toList(),
      'metalAmtTotal': metalAmtTotal,
      'labourAmtTotal': labourAmtTotal,
      'otherCharges': otherCharges,
      'discountAmt': discountAmt,
      'totalAmt': totalAmt,
      'rndDiscount': rndDiscount,
      'cashAmt': cashAmt,
      'bankAmt': bankAmt,
      'cardAmt': cardAmt,
      'ogPurchase': ogPurchase,
      'voucherAmt': voucherAmt,
      'paymentAmt': paymentAmt,
      'dueAmt': dueAmt,
      'previousOS': previousOS,
      'finalDue': finalDue,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'voucherType': voucherType,
      'parentVoucherNo': parentVoucherNo,
    };
  }

  factory OldGoldPurchase.fromMap(Map<String, dynamic> map) {
    return OldGoldPurchase(
      voucherNo: map['voucherNo']?.toString() ?? '',
      bookName: map['bookName']?.toString() ?? 'URD Purchase',
      acName: map['acName']?.toString() ?? '',
      salesman: map['salesman']?.toString() ?? '',
      placeOfSupply: map['placeOfSupply']?.toString() ?? '',
      voucherDate: (map['voucherDate'] as Timestamp).toDate(),
      dueDateDays: (map['dueDateDays'] as num?)?.toInt() ?? 0,
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      items: (map['items'] as List? ?? [])
          .map((e) => OldGoldPurchaseItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      metalAmtTotal: (map['metalAmtTotal'] as num?)?.toDouble() ?? 0.0,
      labourAmtTotal: (map['labourAmtTotal'] as num?)?.toDouble() ?? 0.0,
      otherCharges: (map['otherCharges'] as num?)?.toDouble() ?? 0.0,
      discountAmt: (map['discountAmt'] as num?)?.toDouble() ?? 0.0,
      totalAmt: (map['totalAmt'] as num?)?.toDouble() ?? 0.0,
      rndDiscount: (map['rndDiscount'] as num?)?.toDouble() ?? 0.0,
      cashAmt: (map['cashAmt'] as num?)?.toDouble() ?? 0.0,
      bankAmt: (map['bankAmt'] as num?)?.toDouble() ?? 0.0,
      cardAmt: (map['cardAmt'] as num?)?.toDouble() ?? 0.0,
      ogPurchase: (map['ogPurchase'] as num?)?.toDouble() ?? 0.0,
      voucherAmt: (map['voucherAmt'] as num?)?.toDouble() ?? 0.0,
      paymentAmt: (map['paymentAmt'] as num?)?.toDouble() ?? 0.0,
      dueAmt: (map['dueAmt'] as num?)?.toDouble() ?? 0.0,
      previousOS: (map['previousOS'] as num?)?.toDouble() ?? 0.0,
      finalDue: (map['finalDue'] as num?)?.toDouble() ?? 0.0,
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      voucherType: map['voucherType']?.toString() ?? 'Purchase',
      parentVoucherNo: map['parentVoucherNo']?.toString(),
    );
  }
}
