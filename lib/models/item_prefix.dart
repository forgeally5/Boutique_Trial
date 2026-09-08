import 'package:cloud_firestore/cloud_firestore.dart';

class ItemPrefix {
  final String? id;
  final String itemName;
  final String prefix;
  final String type;
  final String pieces;
  final String counterNo;
  final bool reqOtherWeight;
  final bool reqDesignNo;
  final bool reqHuid;
  final bool netWtAccessible;
  final bool reqDiamondMarkup;
  final bool reqLabourMarkup;
  final String allowChangeCounterNo;
  final String startFrom;
  final String endNo;
  final String qty;
  final String reusable;
  final String inputPcsReq;
  final String groupName;
  final String tagWeight;
  final String allowChangeDiamond;
  final String allowChangeLabour;
  final String prefixDescription;
  final String pcsName;
  final DateTime? createdAt;

  ItemPrefix({
    this.id,
    required this.itemName,
    required this.prefix,
    required this.type,
    required this.pieces,
    required this.counterNo,
    required this.reqOtherWeight,
    required this.reqDesignNo,
    required this.reqHuid,
    required this.netWtAccessible,
    required this.reqDiamondMarkup,
    required this.reqLabourMarkup,
    required this.allowChangeCounterNo,
    required this.startFrom,
    required this.endNo,
    required this.qty,
    required this.reusable,
    required this.inputPcsReq,
    required this.groupName,
    required this.tagWeight,
    required this.allowChangeDiamond,
    required this.allowChangeLabour,
    required this.prefixDescription,
    required this.pcsName,
    this.createdAt,
  });

  factory ItemPrefix.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemPrefix(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      prefix: data['prefix'] ?? '',
      type: data['type'] ?? '',
      pieces: data['pieces'] ?? '',
      counterNo: data['counterNo'] ?? '',
      reqOtherWeight: data['reqOtherWeight'] ?? false,
      reqDesignNo: data['reqDesignNo'] ?? false,
      reqHuid: data['reqHuid'] ?? false,
      netWtAccessible: data['netWtAccessible'] ?? false,
      reqDiamondMarkup: data['reqDiamondMarkup'] ?? false,
      reqLabourMarkup: data['reqLabourMarkup'] ?? false,
      allowChangeCounterNo: data['allowChangeCounterNo'] ?? '',
      startFrom: data['startFrom'] ?? '',
      endNo: data['endNo'] ?? '',
      qty: data['qty'] ?? '',
      reusable: data['reusable'] ?? '',
      inputPcsReq: data['inputPcsReq'] ?? '',
      groupName: data['groupName'] ?? '',
      tagWeight: data['tagWeight'] ?? '',
      allowChangeDiamond: data['allowChangeDiamond'] ?? '',
      allowChangeLabour: data['allowChangeLabour'] ?? '',
      prefixDescription: data['prefixDescription'] ?? '',
      pcsName: data['pcsName'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'prefix': prefix,
      'type': type,
      'pieces': pieces,
      'counterNo': counterNo,
      'reqOtherWeight': reqOtherWeight,
      'reqDesignNo': reqDesignNo,
      'reqHuid': reqHuid,
      'netWtAccessible': netWtAccessible,
      'reqDiamondMarkup': reqDiamondMarkup,
      'reqLabourMarkup': reqLabourMarkup,
      'allowChangeCounterNo': allowChangeCounterNo,
      'startFrom': startFrom,
      'endNo': endNo,
      'qty': qty,
      'reusable': reusable,
      'inputPcsReq': inputPcsReq,
      'groupName': groupName,
      'tagWeight': tagWeight,
      'allowChangeDiamond': allowChangeDiamond,
      'allowChangeLabour': allowChangeLabour,
      'prefixDescription': prefixDescription,
      'pcsName': pcsName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
