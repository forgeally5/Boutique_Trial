import '../../models/product.dart';

/// Represents a single line-item row in a bill/invoice.
/// All items are piece-based — qty is always an integer count.
class BillRow {
  Product? product;
  double qty;        // always integer quantity (piece-based)
  double weight;     // weight in grams for Weight-Based items
  double price;      // selling price per unit or rate per gram
  double discountValue;
  String discountType; // "%" or "₹"
  bool isFromReserve; // True if this row was added from the Reserved Items list

  BillRow({
    this.product,
    this.qty = 1,
    this.weight = 0,
    this.price = 0,
    this.discountValue = 0,
    this.discountType = '%',
    this.isFromReserve = false,
  });

  /// Unit label shown in the table
  String get unitLabel => product?.unit ?? 'Piece';

  /// Raw amount before item discount
  double get grossAmount {
    if (product?.pricingType == 'Weight-Based') {
      return weight * price; // weight * ratePerGram
    }
    return qty * price;
  }

  /// Item discount in ₹
  double get itemDiscountAmount {
    if (discountValue <= 0) return 0;
    if (discountType == '%') {
      return (grossAmount * discountValue / 100).clamp(0, grossAmount);
    }
    return discountValue.clamp(0, grossAmount);
  }

  /// Final line amount after item discount but BEFORE GST
  double get lineAmount => (grossAmount - itemDiscountAmount).clamp(0, double.infinity);

  /// GST Rate from Product
  double get gstRate => product?.gstRate ?? 0.0;

  /// Line GST amount
  double get lineGstAmount => lineAmount * (gstRate / 100);

  /// Serialise for Firestore
  Map<String, dynamic> toMap() => {
    'tagId': product?.tagId ?? '',
    'name': product?.name ?? '',
    'category': product?.category ?? '',
    'pricingType': product?.pricingType ?? 'Quantity-Based',
    'qty': qty,
    'weight': weight,
    'unit': product?.unit ?? '',
    'price': price,
    'discountValue': discountValue,
    'discountType': discountType,
    'itemDiscountAmount': itemDiscountAmount,
    'lineAmount': lineAmount,
    'gstRate': gstRate,
    'lineGstAmount': lineGstAmount,
    'isFromReserve': isFromReserve,
  };

  /// Whether this row has enough data to be counted as valid
  bool get isValid =>
      product != null && qty > 0 && price > 0 && lineAmount >= 0;
}
