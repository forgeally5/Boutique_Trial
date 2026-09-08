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

  // Weight-based fields
  final double grossWeight;
  final double netWeight;
  final double ratePerGram;
  final double makingCharges;

  // Quantity-based fields
  final int quantity;
  final String unit;
  final double mrp;
  final double sellingPrice;

  // Discount fields (default discount stored on product)
  final double discountValue;   // The discount amount (% or flat ₹)
  final String discountType;    // "%" or "₹"
  final double finalPrice;      // Computed: sellingPrice after discount

  // Flags
  final bool isFestivalStock;

  final Map<String, dynamic>? rawJson;

  bool get isLowStock => pricingType == 'Quantity-Based' && quantity < 5;

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
    this.ratePerGram = 0.0,
    this.makingCharges = 0.0,
    this.quantity = 0,
    this.unit = 'piece',
    this.mrp = 0.0,
    this.sellingPrice = 0.0,
    this.discountValue = 0.0,
    this.discountType = '%',
    this.finalPrice = 0.0,
    this.isFestivalStock = false,
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
    double? ratePerGram,
    double? makingCharges,
    int? quantity,
    String? unit,
    double? mrp,
    double? sellingPrice,
    double? discountValue,
    String? discountType,
    double? finalPrice,
    bool? isFestivalStock,
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
      ratePerGram: ratePerGram ?? this.ratePerGram,
      makingCharges: makingCharges ?? this.makingCharges,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      finalPrice: finalPrice ?? this.finalPrice,
      isFestivalStock: isFestivalStock ?? this.isFestivalStock,
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
      'ratePerGram': ratePerGram,
      'makingCharges': makingCharges,
      'quantity': quantity,
      'unit': unit,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'discountValue': discountValue,
      'discountType': discountType,
      'finalPrice': finalPrice,
      'isFestivalStock': isFestivalStock,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final sp = (json['sellingPrice'] as num?)?.toDouble() ?? 0.0;
    final dv = (json['discountValue'] as num?)?.toDouble() ?? 0.0;
    final dt = json['discountType'] as String? ?? '%';
    // Recalculate finalPrice on load to ensure consistency
    double fp;
    if (json['finalPrice'] != null) {
      fp = (json['finalPrice'] as num).toDouble();
    } else {
      fp = dt == '%' ? sp - (sp * dv / 100) : sp - dv;
      if (fp < 0) fp = 0;
    }
    return Product(
      tagId: json['tagId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      deity: json['deity'] as String? ?? '',
      material: json['material'] as String? ?? '',
      size: json['size'] as String? ?? '',
      status: json['status'] as String? ?? 'In Stock',
      vendor: json['vendor'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      pricingType: json['pricingType'] as String? ?? 'Quantity-Based',
      grossWeight: (json['grossWeight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['netWeight'] as num?)?.toDouble() ?? 0.0,
      ratePerGram: (json['ratePerGram'] as num?)?.toDouble() ?? 0.0,
      makingCharges: (json['makingCharges'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'piece',
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: sp,
      discountValue: dv,
      discountType: dt,
      finalPrice: fp,
      isFestivalStock: json['isFestivalStock'] as bool? ?? false,
      rawJson: json,
    );
  }
}
