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
  int _copies = 1;
  bool _isPrinting = false;
  late final TextEditingController _copiesCtrl;

  @override
  void initState() {
    super.initState();
    _copiesCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _copiesCtrl.dispose();
    super.dispose();
  }

  void _onCopiesChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null && parsed > 0 && parsed <= 999) {
      setState(() => _copies = parsed);
    }
  }

  void _incrementCopies() {
    setState(() {
      _copies++;
      _copiesCtrl.text = _copies.toString();
    });
  }

  void _decrementCopies() {
    if (_copies > 1) {
      setState(() {
        _copies--;
        _copiesCtrl.text = _copies.toString();
      });
    }
  }

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await QrPdfGenerator.printBulkProductQr(
        widget.selectedProducts,
        copies: _copies,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStickers = widget.selectedProducts.length * _copies;

    return Dialog(
      backgroundColor: BoutiqueColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Close Button ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print_rounded, color: BoutiqueColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Tag Print Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: BoutiqueColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.selectedProducts.length} products selected • $totalStickers total stickers ($totalStickers pages)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: BoutiqueColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: BoutiqueColors.borderLight),
              const SizedBox(height: 16),

              // ── Copies Per Tag Selector ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: BoutiqueColors.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BoutiqueColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 18, color: BoutiqueColors.accent),
                    const SizedBox(width: 10),
                    const Text(
                      'Copies per tag:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: BoutiqueColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: BoutiqueColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BoutiqueColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: _copies > 1 ? _decrementCopies : null,
                          ),
                          SizedBox(
                            width: 44,
                            child: TextField(
                              controller: _copiesCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
                              ),
                              onChanged: _onCopiesChanged,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: _incrementCopies,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Scrollable Tag Previews (Horizontal 2.5cm x 1.5cm Aspect Ratio) ──
              const Text(
                'Tag Preview (2.5 cm × 1.5 cm horizontal stickers):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: BoutiqueColors.bgSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoutiqueColors.borderLight),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.selectedProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = widget.selectedProducts[index];
                      return _buildTagPreviewCard(product);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Bottom Action Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: BoutiqueColors.borderLight),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _isPrinting ? 'Preparing Tags...' : 'Print $totalStickers Tags',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  /// Builds a visual preview card matching the 2.5cm x 1.5cm horizontal tag format
  Widget _buildTagPreviewCard(Product product) {
    final priceStr = _formatPrice(product);
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
          // Left: QR Code + Tag ID underneath
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Right: Item Name, Weight, and Price
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
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: BoutiqueColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price Tag
          if (priceStr.isNotEmpty)
            Text(
              '₹$priceStr',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatPrice(Product product) {
    double price = 0.0;
    if (product.finalPrice > 0) {
      price = product.finalPrice;
    } else if (product.sellingPrice > 0) {
      price = product.sellingPrice;
    } else if (product.mrp > 0) {
      price = product.mrp;
    } else if (product.pricingType == 'Weight-Based' && product.ratePerGram > 0) {
      final weight = product.netWeight > 0 ? product.netWeight : product.grossWeight;
      if (weight > 0) {
        price = product.ratePerGram * weight;
      } else {
        price = product.ratePerGram;
      }
    }
    if (price <= 0) return '';
    return price == price.roundToDouble() ? price.toInt().toString() : price.toStringAsFixed(2);
  }

  static String _getWeightString(Product product) {
    if (product.pricingType == 'Weight-Based') {
      final weight = product.netWeight > 0 ? product.netWeight : product.grossWeight;
      if (weight > 0) {
        final unit = product.weightUnit.isNotEmpty ? product.weightUnit.toUpperCase() : 'G';
        final weightStr = weight == weight.roundToDouble() ? weight.toInt().toString() : weight.toStringAsFixed(2);
        return '$weightStr$unit';
      }
    }
    return '';
  }
}

