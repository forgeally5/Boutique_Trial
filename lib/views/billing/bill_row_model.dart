import '../../models/product.dart';

/// Represents a single line-item row in a bill/invoice.
class BillRow {
  Product? product;
  double qty;        // integer qty for Quantity-Based, decimal weight for Weight-Based
  double price;      // selling price per unit/gram — editable
  double discountValue;
  String discountType; // "%" or "₹"

  BillRow({
    this.product,
    this.qty = 1,
    this.price = 0,
    this.discountValue = 0,
    this.discountType = '%',
  });

  /// Unit label shown in the table
  String get unitLabel => product?.unit ?? 'pc';

  /// Whether this row is weight-based
  bool get isWeightBased => product?.pricingType == 'Weight-Based';

  /// Raw amount before item discount
  double get grossAmount => qty * price;

  /// Item discount in ₹
  double get itemDiscountAmount {
    if (discountValue <= 0) return 0;
    if (discountType == '%') {
      return (grossAmount * discountValue / 100).clamp(0, grossAmount);
    }
    return discountValue.clamp(0, grossAmount);
  }

  /// Final line amount after item discount
  double get lineAmount => (grossAmount - itemDiscountAmount).clamp(0, double.infinity);

  /// Serialise for Firestore
  Map<String, dynamic> toMap() => {
    'tagId': product?.tagId ?? '',
    'name': product?.name ?? '',
    'category': product?.category ?? '',
    'pricingType': product?.pricingType ?? 'Quantity-Based',
    'qty': qty,
    'unit': product?.unit ?? '',
    'price': price,
    'discountValue': discountValue,
    'discountType': discountType,
    'itemDiscountAmount': itemDiscountAmount,
    'lineAmount': lineAmount,
  };

  /// Whether this row has enough data to be counted as valid
  bool get isValid =>
      product != null && qty > 0 && price > 0 && lineAmount >= 0;
}
