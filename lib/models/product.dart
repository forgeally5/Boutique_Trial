String getBaseTagId(String tagId) {
  final match = RegExp(r'^(.+?)\[\d+\]$').firstMatch(tagId.trim());
  if (match != null) {
    return match.group(1)!.trim();
  }
  return tagId.trim();
}

class Product {
  final String tagId;
  final String name;
  final String category;
  final String deity;
  final String material;
  final String size;
  final String status;
  final String vendor;
  final String notes;
  final String pricingType; // "Weight-Based" or "Quantity-Based"
  final String imageUrl;

  // Weight-based fields
  final double grossWeight;
  final double netWeight;
  final String weightUnit;
  final double ratePerGram;
  final double makingCharges;

  // Quantity-based fields
  final int quantity;
  final int issueQuantity; // units marked as damaged or pending vendor return
  final int reservedQuantity; // units reserved for a specific customer
  final String unit;
  
  /// Available stock = total - damaged/issue - reserved
  int get sellableQuantity => (quantity - issueQuantity - reservedQuantity).clamp(0, quantity);
  final double mrp;
  final double sellingPrice;

  // Discount fields (default discount stored on product)
  final double discountValue;   // The discount amount (% or flat ₹)
  final String discountType;    // "%" or "₹"
  final double finalPrice;      // Computed: sellingPrice after discount

  final double gstRate;         // Product level GST rate (e.g. 0.0, 5.0)

  // Flags
  final bool isFestivalStock;
  final bool isReserved;
  final String reservedFor;

  final DateTime? addedDate;

  final Map<String, dynamic>? rawJson;

  bool get isLowStock => quantity > 0 && quantity < 5;
  bool get isOutOfStock => quantity <= 0;

  Product({
    required this.tagId,
    required this.name,
    required this.category,
    this.deity = '',
    this.material = '',
    this.size = '',
    this.status = 'In Stock',
    this.vendor = '',
    this.notes = '',
    this.pricingType = 'Quantity-Based',
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.weightUnit = 'g',
    this.ratePerGram = 0.0,
    this.makingCharges = 0.0,
    this.quantity = 0,
    this.issueQuantity = 0,
    this.reservedQuantity = 0,
    this.unit = 'piece',
    this.mrp = 0.0,
    this.sellingPrice = 0.0,
    this.discountValue = 0.0,
    this.discountType = '%',
    this.finalPrice = 0.0,
    this.gstRate = 0.0,
    this.isFestivalStock = false,
    this.isReserved = false,
    this.reservedFor = '',
    this.addedDate,
    this.imageUrl = '',
    this.rawJson,
  });

  Product copyWith({
    String? tagId,
    String? name,
    String? category,
    String? deity,
    String? material,
    String? size,
    String? status,
    String? vendor,
    String? notes,
    String? pricingType,
    double? grossWeight,
    double? netWeight,
    String? weightUnit,
    double? ratePerGram,
    double? makingCharges,
    int? quantity,
    int? issueQuantity,
    int? reservedQuantity,
    String? unit,
    double? mrp,
    double? sellingPrice,
    double? discountValue,
    String? discountType,
    double? finalPrice,
    double? gstRate,
    bool? isFestivalStock,
    bool? isReserved,
    String? reservedFor,
    DateTime? addedDate,
    String? imageUrl,
    Map<String, dynamic>? rawJson,
  }) {
    return Product(
      tagId: tagId ?? this.tagId,
      name: name ?? this.name,
      category: category ?? this.category,
      deity: deity ?? this.deity,
      material: material ?? this.material,
      size: size ?? this.size,
      status: status ?? this.status,
      vendor: vendor ?? this.vendor,
      notes: notes ?? this.notes,
      pricingType: pricingType ?? this.pricingType,
      grossWeight: grossWeight ?? this.grossWeight,
      netWeight: netWeight ?? this.netWeight,
      weightUnit: weightUnit ?? this.weightUnit,
      ratePerGram: ratePerGram ?? this.ratePerGram,
      makingCharges: makingCharges ?? this.makingCharges,
      quantity: quantity ?? this.quantity,
      issueQuantity: issueQuantity ?? this.issueQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      unit: unit ?? this.unit,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      finalPrice: finalPrice ?? this.finalPrice,
      gstRate: gstRate ?? this.gstRate,
      isFestivalStock: isFestivalStock ?? this.isFestivalStock,
      isReserved: isReserved ?? this.isReserved,
      reservedFor: reservedFor ?? this.reservedFor,
      addedDate: addedDate ?? this.addedDate,
      imageUrl: imageUrl ?? this.imageUrl,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagId': tagId,
      'name': name,
      'category': category,
      'deity': deity,
      'material': material,
      'size': size,
      'status': status,
      'vendor': vendor,
      'notes': notes,
      'pricingType': pricingType,
      'grossWeight': grossWeight,
      'netWeight': netWeight,
      'weightUnit': weightUnit,
      'ratePerGram': ratePerGram,
      'makingCharges': makingCharges,
      'quantity': quantity,
      'issueQuantity': issueQuantity,
      'reservedQuantity': reservedQuantity,
      'unit': unit,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'discountValue': discountValue,
      'discountType': discountType,
      'finalPrice': finalPrice,
      'gstRate': gstRate,
      'isFestivalStock': isFestivalStock,
      'isReserved': isReserved,
      'reservedFor': reservedFor,
      if (addedDate != null) 'addedDate': addedDate,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Hostinger/MySQL APIs return ALL numeric columns as Strings (e.g. "0.000").
    // These helpers safely parse either a String or a real num.
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int toI(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    bool toB(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    final sp = toD(json['sellingPrice']);
    final dv = toD(json['discountValue']);
    final dt = json['discountType'] as String? ?? '%';

    double fp;
    if (json['finalPrice'] != null) {
      fp = toD(json['finalPrice']);
    } else {
      fp = dt == '%' ? sp - (sp * dv / 100) : sp - dv;
      if (fp < 0) fp = 0;
    }

    return Product(
      tagId: json['tagId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      deity: json['deity']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      status: json['status']?.toString() ?? 'In Stock',
      vendor: json['vendor']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      pricingType: json['pricingType']?.toString() ?? 'Quantity-Based',
      grossWeight: toD(json['grossWeight']),
      netWeight: toD(json['netWeight']),
      weightUnit: json['weightUnit']?.toString() ?? 'g',
      ratePerGram: toD(json['ratePerGram']),
      makingCharges: toD(json['makingCharges']),
      quantity: toI(json['quantity']),
      issueQuantity: toI(json['issueQuantity']),
      reservedQuantity: toI(json['reservedQuantity']),
      unit: json['unit']?.toString() ?? 'piece',
      mrp: toD(json['mrp']),
      sellingPrice: sp,
      discountValue: dv,
      discountType: dt,
      finalPrice: fp,
      gstRate: toD(json['gstRate']),
      isFestivalStock: toB(json['isFestivalStock']),
      isReserved: toB(json['isReserved']),
      reservedFor: json['reservedFor']?.toString() ?? '',
      addedDate: json['addedDate'] != null
          ? (json['addedDate'] is DateTime
              ? json['addedDate'] as DateTime
              : DateTime.tryParse(json['addedDate'].toString()))
          : null,
      imageUrl: json['imageUrl']?.toString() ?? '',
      rawJson: json,
    );
  }
}
