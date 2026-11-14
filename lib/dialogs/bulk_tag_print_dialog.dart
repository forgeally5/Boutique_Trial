import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/product.dart';
import '../utils/boutique_theme.dart';
import '../utils/qr_pdf_generator.dart';

class BulkTagPrintDialog extends StatefulWidget {
  final List<Product> selectedProducts;

  const BulkTagPrintDialog({
    super.key,
    required this.selectedProducts,
  });

  @override
  State<BulkTagPrintDialog> createState() => _BulkTagPrintDialogState();
}

class _BulkTagPrintDialogState extends State<BulkTagPrintDialog> {
  // Per-product copy count — defaults to each product's current stock quantity
  late final Map<String, int> _copiesMap;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _copiesMap = {
      for (final p in widget.selectedProducts)
        p.tagId: p.sellableQuantity > 0
            ? p.sellableQuantity
            : (p.quantity > 0 ? p.quantity : 1),
    };
  }

  int _copiesFor(Product p) => _copiesMap[p.tagId] ?? 1;

  void _increment(Product p) {
    setState(() {
      _copiesMap[p.tagId] = (_copiesMap[p.tagId] ?? 1) + 1;
    });
  }

  void _decrement(Product p) {
    final cur = _copiesMap[p.tagId] ?? 1;
    if (cur > 1) {
      setState(() => _copiesMap[p.tagId] = cur - 1);
    }
  }

  int get _totalStickers =>
      widget.selectedProducts.fold(0, (sum, p) => sum + _copiesFor(p));

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      // Build expanded list: each product repeated by its copy count
      final expanded = <Product>[
        for (final p in widget.selectedProducts)
          for (int i = 0; i < _copiesFor(p); i++) p,
      ];
      await QrPdfGenerator.printBulkProductQr(expanded, copies: 1);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalStickers;

    return Dialog(
      backgroundColor: BoutiqueColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Close ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print_rounded,
                        color: BoutiqueColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Tag Print',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: BoutiqueColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.selectedProducts.length} products • $total total tags',
                          style: const TextStyle(
                              fontSize: 12, color: BoutiqueColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: BoutiqueColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: BoutiqueColors.borderLight),
              const SizedBox(height: 4),

              // ── Column header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: const [
                    SizedBox(width: 64),
                    Expanded(
                      child: Text(
                        'Product',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 100,
                      child: Text(
                        'Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    SizedBox(width: 110,
                      child: Text(
                        'Copies',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Product list ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: BoutiqueColors.bgSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoutiqueColors.borderLight),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.selectedProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = widget.selectedProducts[index];
                      return _buildProductRow(product);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Bottom actions ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        _isPrinting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: BoutiqueColors.borderLight),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: BoutiqueColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _isPrinting
                          ? 'Preparing Tags...'
                          : 'Print $total Tags',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    final copies = _copiesFor(product);
    final hasDiscount = product.finalPrice > 0 &&
        product.sellingPrice > 0 &&
        product.finalPrice < product.sellingPrice;
    final basePrice = product.sellingPrice > 0
        ? product.sellingPrice
        : (product.mrp > 0 ? product.mrp : 0.0);
    final weightStr = _getWeightString(product);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BoutiqueColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // QR + Tag ID
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: QrImageView(
                  data: product.tagId,
                  version: QrVersions.auto,
                  gapless: false,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.tagId,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name + weight
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name.trim().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (weightStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    weightStr,
                    style: const TextStyle(
                        fontSize: 10, color: BoutiqueColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Stock: ${product.sellableQuantity > 0 ? product.sellableQuantity : product.quantity} ${product.unit.isNotEmpty ? product.unit : (product.pricingType == 'Weight-Based' ? 'piece' : 'pcs')}',
                  style: const TextStyle(
                      fontSize: 10, color: BoutiqueColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Price — with strikethrough if discounted
          SizedBox(
            width: 100,
            child: hasDiscount
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Old price with strikethrough
                      Text(
                        '₹${_priceStr(basePrice)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: BoutiqueColors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red,
                          decorationThickness: 2.0,
                        ),
                      ),
                      // New discounted price
                      Text(
                        '₹${_priceStr(product.finalPrice)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  )
                : Text(
                    _formatPriceDisplay(product),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BoutiqueColors.textPrimary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Per-product +/- copies counter
          Container(
            decoration: BoxDecoration(
              color: BoutiqueColors.bgSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoutiqueColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: copies > 1 ? () => _decrement(product) : null,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$copies',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _increment(product),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _priceStr(double price) {
    if (price <= 0) return '';
    return price == price.roundToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
  }

  static String _formatPriceDisplay(Product product) {
    double price = 0.0;
    if (product.finalPrice > 0) {
      price = product.finalPrice;
    } else if (product.sellingPrice > 0) {
      price = product.sellingPrice;
    } else if (product.mrp > 0) {
      price = product.mrp;
    } else if (product.pricingType == 'Weight-Based' &&
        product.ratePerGram > 0) {
      final weight = product.netWeight > 0
          ? product.netWeight
          : product.grossWeight;
      price = weight > 0 ? product.ratePerGram * weight : product.ratePerGram;
    }
    if (price <= 0) return '';
    return '₹${_priceStr(price)}';
  }

  static String _getWeightString(Product product) {
    if (product.pricingType == 'Weight-Based') {
      final weight =
          product.netWeight > 0 ? product.netWeight : product.grossWeight;
      if (weight > 0) {
        final unit = product.weightUnit.isNotEmpty
            ? product.weightUnit.toUpperCase()
            : 'G';
        final w = weight == weight.roundToDouble()
            ? weight.toInt().toString()
            : weight.toStringAsFixed(2);
        return '$w$unit';
      }
    }
    return '';
  }
}
