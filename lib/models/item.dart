/// Represents a predefined Metal / Trading Group (Default Group dropdown)
/// as seen in OrnateStn Add Item → Default Group dropdown.
class MetalGroup {
  final String metalId;   // e.g. "24KT", "18D", "REP"
  final String groupName; // e.g. "GOLD 22KT JEWELLERY", "DIAMOND 18KT JEWELLERY"
  final String? linkedRateId; // Links to Rate Management

  const MetalGroup({required this.metalId, required this.groupName, this.linkedRateId});

  String get display => '$metalId - $groupName';

  /// Predefined Metal Groups from OrnateStn schema.
  static const List<MetalGroup> predefined = [
    MetalGroup(metalId: '24KT',  groupName: 'GOLD 24KT JEWELLERY', linkedRateId: 'gold_24k_trading'),
    MetalGroup(metalId: '22KT',  groupName: 'GOLD 22KT JEWELLERY', linkedRateId: 'gold_22k_jewellery'),
    MetalGroup(metalId: '18KT',  groupName: 'GOLD 18KT JEWELLERY', linkedRateId: 'gold_18k_jewellery'),
    MetalGroup(metalId: '14KT',  groupName: 'GOLD 14KT JEWELLERY', linkedRateId: 'gold_18k_jewellery'),
    MetalGroup(metalId: '18D',   groupName: 'DIAMOND 18KT JEWELLERY', linkedRateId: 'diamond_18k_jewellery'),
    MetalGroup(metalId: '22D',   groupName: 'DIAMOND 22KT JEWELLERY', linkedRateId: 'diamond_22k_jewellery'),
    MetalGroup(metalId: 'DI',    groupName: 'Diamond Trading A/c.', linkedRateId: 'diamond_trading'),
    MetalGroup(metalId: 'ST',    groupName: 'Stone Trading A/c.', linkedRateId: 'stone_trading'),
    MetalGroup(metalId: 'S925',  groupName: 'SILVER 925', linkedRateId: 'silver_925'),
    MetalGroup(metalId: '100T',  groupName: 'Pure Silver Trading A/c.', linkedRateId: 'pure_silver_trading'),
    MetalGroup(metalId: 'OS',    groupName: 'Old Silver Trading A/c.', linkedRateId: 'old_silver_trading'),
    MetalGroup(metalId: 'PT',    groupName: 'PLATINUM', linkedRateId: 'platinum'),
    MetalGroup(metalId: 'OPT',   groupName: 'OLD PLATINUM', linkedRateId: 'old_platinum'),
    MetalGroup(metalId: 'BR',    groupName: 'BRANDED'),
    MetalGroup(metalId: 'PACKI', groupName: 'PACKING / GIFT MATERIAL'),
    MetalGroup(metalId: 'AL',    groupName: 'ALLOYS', linkedRateId: 'alloys'),
    MetalGroup(metalId: 'REP',   groupName: 'REPAIRING / SAMPLE (GOLD)', linkedRateId: 'repairing_sample_gold'),
  ];
}

/// Full JewelryItem model aligned to OrnateStn's Item Master schema.
class JewelryItem {
  // ─── Identity ──────────────────────────────────────────────────────────────
  final String tagId;
  final String name;
  final String shortName;
  final String hsnCode;       // GST HSN Code (default 7113 for jewelry)
  final String supplierCode;

  // ─── Classification ────────────────────────────────────────────────────────
  /// Item Type: "Ornaments" | "Trading" | "Diamond" | "Silver" | "Platinum"
  final String itemType;
  /// Default Group Metal ID (from MetalGroup.predefined e.g. "22KT", "18D")
  final String metalId;
  /// Full group name corresponding to metalId
  final String metalGroupName;
  /// Metal name: Gold | Silver | Platinum | Diamond
  final String metalName;
  /// Metal type indicator: e.g. "Ornaments", "Trading", "Old Metal"
  final String metalType;
  /// Trading account name linked to this item (ItemTradMstId mapped name)
  final String tradName;
  /// Whether the group is fixed and cannot be changed at voucher entry
  final bool isFixGroup;
  /// Whether this is a predefined system item
  final bool isPreDef;
  /// Same metal as linked group flag
  final bool sameMetal;
  /// Whether this item should appear in Counter Report
  final bool reqItemInCounterReport;
  /// Rejection item code reference (e.g. melting loss item)
  final String rejectionItemCode;
  final String rejectionItemName;

  // ─── Label / Barcode ───────────────────────────────────────────────────────
  /// Keep Labels: Y = generate individual barcode labels, N = bulk stock
  final bool keepLabels;
  /// Label prefix (e.g. "GR", "SR")
  final String labelPrefix;
  /// Auto / Manual / Random label numbering
  final String labelNumbering; // Auto | Manual | Random
  /// Starting label number
  final int labelStartFrom;
  /// Counter / display section number for this item
  final String counterNo;

  // ─── Weight Details ────────────────────────────────────────────────────────
  final double grossWt;
  final double stoneWt;
  final double otherWt;
  final double netWt;       // Calculated: grossWt - stoneWt - otherWt
  final double purity;      // e.g. 91.6 for 22K, 75.0 for 18K
  final double alloyWt;     // Calculated: grossWt - fineWt
  final double fineWt;      // Calculated: netWt * (purity/100)
  final int pcs;
  final int availablePcs;
  final List<Map<String, dynamic>> pieces;

  // ─── Stone & Diamond Details ───────────────────────────────────────────────
  final double diamondWt;
  final int diamondPcs;
  final double diamondAmt;
  final String diamondClarity; // IF, VVS, VS, SI, I
  final String diamondColor;   // D-E, G-H, etc.
  final double extraStoneWt;
  final int extraStonePcs;
  final double extraStoneAmt;
  final double extraOtherWt;
  final double extraOtherAmt;

  // ─── Sales Making Charges ──────────────────────────────────────────────────
  /// Basis: "Per Gram Gross Wt" | "Per Gram Net Wt" | "Per Gram Fine Wt" | "Per Piece" | "Percentage" | "Fixed"
  final String salLabRateType;
  final double salLabRate;
  final double labourAmount; // Calculated

  // ─── Purchase / Inward Wastage ─────────────────────────────────────────────
  /// Purchase Labour Rate Type (same options as salLabRateType)
  final String purLabRateType;
  final double purLabRate;
  /// Wastage Calculated On: "Gross Wt" | "Net Wt" | "Fine Wt"
  final String purWastCalcOn;
  final double purWastPer;   // Wastage percentage e.g. 3.5
  /// Wastage Added In: "Net Wt" | "Gross Wt"
  final String purWastAddIn;

  // ─── Valuation & Taxes ─────────────────────────────────────────────────────
  final double todaysRate;
  final double metalAmt;    // Calculated: netWt * todaysRate
  final double amount;      // Subtotal before tax
  final double cgstPer;
  final double cgstAmt;
  final double sgstPer;
  final double sgstAmt;
  final double igstPer;
  final double igstAmt;
  final double totalAmount;

  // ─── Media Details ─────────────────────────────────────────────────────────
  final String productName;
  final String description;
  final bool uploadInWebsite;
  final List<String> imageUrls;
  final String arImageUrl;
  final String videoUrl;
  final String productStatus;
  final bool yetToAdd;

  // ─── Custom UI & Calculations Fields ───────────────────────────────────────
  final String jobNo;
  final String size;
  final String remarks;
  final String rfidNo;
  final String oldBarcode;
  final String jobRef;
  final String labOn;
  final double labRate;
  final double labPer;
  final double labAmt;
  final double metalRate;
  final double metalAmount;
  final double costRate;
  final double costAmount;
  final bool hasOtherWeights;
  final List<Map<String, dynamic>> extraCharges;

  const JewelryItem({
    required this.tagId,
    required this.name,
    required this.shortName,
    required this.hsnCode,
    required this.supplierCode,
    required this.itemType,
    required this.metalId,
    required this.metalGroupName,
    required this.metalName,
    required this.metalType,
    required this.tradName,
    required this.isFixGroup,
    required this.isPreDef,
    required this.sameMetal,
    required this.reqItemInCounterReport,
    required this.rejectionItemCode,
    required this.rejectionItemName,
    required this.keepLabels,
    required this.labelPrefix,
    required this.labelNumbering,
    required this.labelStartFrom,
    required this.counterNo,
    required this.grossWt,
    required this.stoneWt,
    required this.otherWt,
    required this.netWt,
    required this.purity,
    required this.alloyWt,
    required this.fineWt,
    required this.pcs,
    this.availablePcs = 1,
    this.pieces = const [],
    required this.diamondWt,
    required this.diamondPcs,
    required this.diamondAmt,
    required this.diamondClarity,
    required this.diamondColor,
    required this.extraStoneWt,
    required this.extraStonePcs,
    required this.extraStoneAmt,
    required this.extraOtherWt,
    required this.extraOtherAmt,
    required this.salLabRateType,
    required this.salLabRate,
    required this.labourAmount,
    required this.purLabRateType,
    required this.purLabRate,
    required this.purWastCalcOn,
    required this.purWastPer,
    required this.purWastAddIn,
    required this.todaysRate,
    required this.metalAmt,
    required this.amount,
    required this.cgstPer,
    required this.cgstAmt,
    required this.sgstPer,
    required this.sgstAmt,
    required this.igstPer,
    required this.igstAmt,
    required this.totalAmount,
    required this.productName,
    required this.description,
    required this.uploadInWebsite,
    required this.imageUrls,
    required this.arImageUrl,
    required this.videoUrl,
    this.productStatus = 'Shop product',
    this.yetToAdd = false,
    required this.jobNo,
    required this.size,
    required this.remarks,
    required this.rfidNo,
    required this.oldBarcode,
    required this.jobRef,
    required this.labOn,
    required this.labRate,
    required this.labPer,
    required this.labAmt,
    required this.metalRate,
    required this.metalAmount,
    required this.costRate,
    required this.costAmount,
    required this.hasOtherWeights,
    required this.extraCharges,
  });

  Map<String, dynamic> toMap() => {
        // Identity & Website Aliases
        'tagId': tagId,
        'productId': tagId,
        'name': productName.trim().isNotEmpty ? productName.trim() : name,
        'productName': productName.trim().isNotEmpty ? productName.trim() : name,
        'shortName': shortName,
        'hsnCode': hsnCode,
        'supplierCode': supplierCode,
        'category': itemType.isNotEmpty ? itemType : 'Ornaments',
        'subCategory': shortName,
        'details': [metalGroupName, metalName, metalId].where((s) => s.isNotEmpty).toList(),
        'diamonds': diamondWt > 0 ? '$diamondWt ct ($diamondPcs pcs)' : 'None',

        // Classification
        'itemType': itemType,
        'metalId': metalId,
        'metalGroupName': metalGroupName,
        'metalName': metalName,
        'metalType': metalName.isNotEmpty ? metalName : 'Gold',
        'purity': purity > 0 ? '$purity%' : (metalId.isNotEmpty ? metalId : '22KT'),
        'tradName': tradName,
        'isFixGroup': isFixGroup,
        'isPreDef': isPreDef,
        'sameMetal': sameMetal,
        'reqItemInCounterReport': reqItemInCounterReport,
        'rejectionItemCode': rejectionItemCode,
        'rejectionItemName': rejectionItemName,

        // Label
        'keepLabels': keepLabels,
        'labelPrefix': labelPrefix,
        'labelNumbering': labelNumbering,
        'labelStartFrom': labelStartFrom,
        'counterNo': counterNo,

        // Weights & Website Weights
        'grossWt': grossWt,
        'grossWeight': grossWt,
        'stoneWt': stoneWt,
        'otherWt': otherWt,
        'netWt': netWt,
        'netWeight': netWt,
        'purityVal': purity,
        'alloyWt': alloyWt,
        'fineWt': fineWt,
        'pcs': pcs,
        'availablePcs': availablePcs,
        'pieces': pieces,

        // Stones & Diamonds
        'diamondWt': diamondWt,
        'diamondWeight': diamondWt,
        'diamondPcs': diamondPcs,
        'diamondPieceCount': diamondPcs,
        'diamondAmt': diamondAmt,
        'diamondClarity': diamondClarity,
        'diamondColor': diamondColor,
        'extraStoneWt': extraStoneWt,
        'extraStonePcs': extraStonePcs,
        'extraStoneAmt': extraStoneAmt,
        'extraOtherWt': extraOtherWt,
        'extraOtherAmt': extraOtherAmt,

        // Sales Labour
        'salLabRateType': salLabRateType,
        'salLabRate': salLabRate,
        'labourAmount': labourAmount,

        // Purchase Wastage
        'purLabRateType': purLabRateType,
        'purLabRate': purLabRate,
        'purWastCalcOn': purWastCalcOn,
        'purWastPer': purWastPer,
        'purWastAddIn': purWastAddIn,

        // Valuation & Website Price
        'todaysRate': todaysRate,
        'metalAmt': metalAmt,
        'amount': amount,
        'cgstPer': cgstPer,
        'cgstAmt': cgstAmt,
        'sgstPer': sgstPer,
        'sgstAmt': sgstAmt,
        'igstPer': igstPer,
        'igstAmt': igstAmt,
        'totalAmount': totalAmount,
        'calculatedPrice': totalAmount > 0 ? totalAmount : amount,
        'price': totalAmount > 0 ? totalAmount : amount,

        // Media & Website Media
        'description': description,
        'uploadInWebsite': uploadInWebsite,
        'inWebsite': uploadInWebsite,
        'isWebsiteVisible': uploadInWebsite,
        'visibleInWebsite': uploadInWebsite,
        'imageUrls': imageUrls,
        'images': imageUrls,
        'productImages': imageUrls,
        'imagePath': imageUrls.isNotEmpty ? imageUrls.first : '',
        'arImageUrl': arImageUrl,
        'arImagePath': arImageUrl,
        'videoUrl': videoUrl,
        'videoPath': videoUrl,
        'productStatus': productStatus,
        'yetToAdd': yetToAdd,
        'isYetToAdd': yetToAdd,

        // Custom UI & Calculations Fields
        'jobNo': jobNo,
        'size': size,
        'remarks': remarks,
        'rfidNo': rfidNo,
        'oldBarcode': oldBarcode,
        'jobRef': jobRef,
        'labOn': labOn,
        'labRate': labRate,
        'labPer': labPer,
        'labAmt': labAmt,
        'metalRate': metalRate,
        'metalAmount': metalAmount,
        'costRate': costRate,
        'costAmount': costAmount,
        'hasOtherWeights': hasOtherWeights,
        'extraCharges': extraCharges,
      };

  factory JewelryItem.fromMap(Map<String, dynamic> map) => JewelryItem(
        tagId: map['tagId']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        shortName: map['shortName']?.toString() ?? '',
        hsnCode: map['hsnCode']?.toString() ?? '7113',
        supplierCode: map['supplierCode']?.toString() ?? '',
        itemType: map['itemType']?.toString() ?? 'Ornaments',
        metalId: map['metalId']?.toString() ?? '22KT',
        metalGroupName: map['metalGroupName']?.toString() ?? '',
        metalName: map['metalName']?.toString() ?? 'Gold',
        metalType: map['metalType']?.toString() ?? 'Ornaments',
        tradName: map['tradName']?.toString() ?? '',
        isFixGroup: map['isFixGroup'] == true,
        isPreDef: map['isPreDef'] == true,
        sameMetal: map['sameMetal'] == true,
        reqItemInCounterReport: map['reqItemInCounterReport'] == true,
        rejectionItemCode: map['rejectionItemCode']?.toString() ?? '',
        rejectionItemName: map['rejectionItemName']?.toString() ?? '',
        keepLabels: map['keepLabels'] == true,
        labelPrefix: map['labelPrefix']?.toString() ?? '',
        labelNumbering: map['labelNumbering']?.toString() ?? 'Auto',
        labelStartFrom: (map['labelStartFrom'] as num?)?.toInt() ?? 1,
        counterNo: map['counterNo']?.toString() ?? '',
        grossWt: (map['grossWt'] as num?)?.toDouble() ?? 0.0,
        stoneWt: (map['stoneWt'] as num?)?.toDouble() ?? 0.0,
        otherWt: (map['otherWt'] as num?)?.toDouble() ?? 0.0,
        netWt: (map['netWt'] as num?)?.toDouble() ?? 0.0,
        purity: (map['purity'] as num?)?.toDouble() ?? 91.6,
        alloyWt: (map['alloyWt'] as num?)?.toDouble() ?? 0.0,
        fineWt: (map['fineWt'] as num?)?.toDouble() ?? 0.0,
        pcs: (map['pcs'] as num?)?.toInt() ?? 1,
        diamondWt: (map['diamondWt'] as num?)?.toDouble() ?? 0.0,
        diamondPcs: (map['diamondPcs'] as num?)?.toInt() ?? 0,
        diamondAmt: (map['diamondAmt'] as num?)?.toDouble() ?? 0.0,
        diamondClarity: map['diamondClarity']?.toString() ?? 'VVS',
        diamondColor: map['diamondColor']?.toString() ?? 'G-H',
        extraStoneWt: (map['extraStoneWt'] as num?)?.toDouble() ?? 0.0,
        extraStonePcs: (map['extraStonePcs'] as num?)?.toInt() ?? 0,
        extraStoneAmt: (map['extraStoneAmt'] as num?)?.toDouble() ?? 0.0,
        extraOtherWt: (map['extraOtherWt'] as num?)?.toDouble() ?? 0.0,
        extraOtherAmt: (map['extraOtherAmt'] as num?)?.toDouble() ?? 0.0,
        salLabRateType: map['salLabRateType']?.toString() ?? 'Per Gram Net Wt',
        salLabRate: (map['salLabRate'] as num?)?.toDouble() ?? 0.0,
        labourAmount: (map['labourAmount'] as num?)?.toDouble() ?? 0.0,
        purLabRateType: map['purLabRateType']?.toString() ?? 'Per Gram Net Wt',
        purLabRate: (map['purLabRate'] as num?)?.toDouble() ?? 0.0,
        purWastCalcOn: map['purWastCalcOn']?.toString() ?? 'Net Wt',
        purWastPer: (map['purWastPer'] as num?)?.toDouble() ?? 0.0,
        purWastAddIn: map['purWastAddIn']?.toString() ?? 'Net Wt',
        todaysRate: (map['todaysRate'] as num?)?.toDouble() ?? 0.0,
        metalAmt: (map['metalAmt'] as num?)?.toDouble() ?? 0.0,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        cgstPer: (map['cgstPer'] as num?)?.toDouble() ?? 1.5,
        cgstAmt: (map['cgstAmt'] as num?)?.toDouble() ?? 0.0,
        sgstPer: (map['sgstPer'] as num?)?.toDouble() ?? 1.5,
        sgstAmt: (map['sgstAmt'] as num?)?.toDouble() ?? 0.0,
        igstPer: (map['igstPer'] as num?)?.toDouble() ?? 0.0,
        igstAmt: (map['igstAmt'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
        productName: map['productName']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        uploadInWebsite: map['uploadInWebsite'] == true,
        imageUrls: (map['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
            (map['images'] as List?)?.map((e) => e.toString()).toList() ??
            [],
        arImageUrl: map['arImageUrl']?.toString() ?? '',
        videoUrl: map['videoUrl']?.toString() ?? '',
        productStatus: map['productStatus']?.toString() ?? map['status']?.toString() ?? 'Shop product',
        yetToAdd: map['yetToAdd'] == true || map['isYetToAdd'] == true,
        jobNo: map['jobNo']?.toString() ?? 'None',
        size: map['size']?.toString() ?? '',
        remarks: map['remarks']?.toString() ?? '',
        rfidNo: map['rfidNo']?.toString() ?? '',
        oldBarcode: map['oldBarcode']?.toString() ?? '',
        jobRef: map['jobRef']?.toString() ?? '',
        labOn: map['labOn']?.toString() ?? 'Net Wt',
        labRate: (map['labRate'] as num?)?.toDouble() ?? 0.0,
        labPer: (map['labPer'] as num?)?.toDouble() ?? 0.0,
        labAmt: (map['labAmt'] as num?)?.toDouble() ?? 0.0,
        metalRate: (map['metalRate'] as num?)?.toDouble() ?? 0.0,
        metalAmount: (map['metalAmount'] as num?)?.toDouble() ?? 0.0,
        costRate: (map['costRate'] as num?)?.toDouble() ?? 0.0,
        costAmount: (map['costAmount'] as num?)?.toDouble() ?? 0.0,
        hasOtherWeights: map['hasOtherWeights'] == true,
        extraCharges: (map['extraCharges'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );
}
