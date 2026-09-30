import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product.dart';
import '../../utils/boutique_theme.dart';

class BatchScannerDialog extends StatefulWidget {
  final List<Product> products;
  final int Function(Product p) getAvailableStock;
  final void Function(Product p) onProductScanned;

  const BatchScannerDialog({
    super.key,
    required this.products,
    required this.getAvailableStock,
    required this.onProductScanned,
  });

  @override
  State<BatchScannerDialog> createState() => _BatchScannerDialogState();
}

class _BatchScannerDialogState extends State<BatchScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _tagInputCtrl = TextEditingController();
  final FocusNode _tagInputFocus = FocusNode();

  final Map<String, DateTime> _lastScanned = {};
  final List<Product> _scannedSessionItems = [];

  String? _statusMessage;
  Color _statusColor = BoutiqueColors.accent;

  @override
  void dispose() {
    _controller.dispose();
    _tagInputCtrl.dispose();
    _tagInputFocus.dispose();
    super.dispose();
  }

  Product? _findProduct(String rawCode) {
    final query = rawCode.trim().toLowerCase();
    if (query.isEmpty) return null;

    // 1. Exact match on tagId
    for (final p in widget.products) {
      if (p.tagId.toLowerCase().trim() == query) return p;
    }
    // 2. Base tag match
    for (final p in widget.products) {
      if (getBaseTagId(p.tagId).toLowerCase() == query) return p;
    }
    // 3. Name exact match
    for (final p in widget.products) {
      if (p.name.toLowerCase().trim() == query) return p;
    }
    // 4. Starts with tag
    final startsWith = widget.products.where((p) => p.tagId.toLowerCase().trim().startsWith(query)).toList();
    if (startsWith.length == 1) return startsWith.first;

    return null;
  }

  void _handleBarcode(String rawCode) {
    final now = DateTime.now();
    final cleanCode = rawCode.trim();
    if (cleanCode.isEmpty) return;

    // Debounce exact same barcode for 1.8 seconds so it doesn't spam
    if (_lastScanned.containsKey(cleanCode)) {
      if (now.difference(_lastScanned[cleanCode]!) < const Duration(milliseconds: 1800)) {
        return;
      }
    }
    _lastScanned[cleanCode] = now;

    final product = _findProduct(cleanCode);
    if (product != null) {
      final available = widget.getAvailableStock(product);
      if (available <= 0) {
        setState(() {
          _statusMessage = '⚠️ "${product.name}" (${product.tagId}) is out of stock!';
          _statusColor = Colors.orange.shade800;
        });
        return;
      }

      widget.onProductScanned(product);
      setState(() {
        _scannedSessionItems.insert(0, product);
        _statusMessage = '✅ Added: ${product.tagId} - ${product.name}';
        _statusColor = Colors.green.shade700;
      });
    } else {
      setState(() {
        _statusMessage = '❌ Tag "$cleanCode" not found in inventory';
        _statusColor = Colors.red.shade700;
      });
    }
  }

  void _submitManualTag() {
    final tag = _tagInputCtrl.text.trim();
    if (tag.isEmpty) return;
    _handleBarcode(tag);
    _tagInputCtrl.clear();
    _tagInputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      child: Container(
        width: 650,
        height: 600,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: BoutiqueColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: BoutiqueColors.accent, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Continuous Barcode Scanner',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Scan multiple product tags one after another to add to bill',
                        style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_scannedSessionItems.length} Added',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: BoutiqueColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Status notification bar
            if (_statusMessage != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _statusColor.withValues(alpha: 0.12),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // Scanner area & Recent list
            Expanded(
              child: Row(
                children: [
                  // Camera preview
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: (capture) {
                            for (final b in capture.barcodes) {
                              if (b.rawValue != null && b.rawValue!.isNotEmpty) {
                                _handleBarcode(b.rawValue!);
                                break;
                              }
                            }
                          },
                        ),
                        // Scanner frame overlay
                        Center(
                          child: Container(
                            width: 220,
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(color: BoutiqueColors.accent, width: 2.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Torch & switch camera
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.flash_on, color: Colors.white),
                                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                onPressed: () => _controller.toggleTorch(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                onPressed: () => _controller.switchCamera(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scanned list sidebar
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: BoutiqueColors.border)),
                        color: BoutiqueColors.bgSubtle,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
                            ),
                            child: const Text(
                              'Scanned Items in Session',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary),
                            ),
                          ),
                          Expanded(
                            child: _scannedSessionItems.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'Point camera at barcode or type Tag ID below.\nItems will be added automatically.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 12),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _scannedSessionItems.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                    itemBuilder: (ctx, i) {
                                      final item = _scannedSessionItems[i];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        leading: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                        title: Text(
                                          '${item.tagId} - ${item.name}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '₹${item.finalPrice > 0 ? item.finalPrice : item.mrp}',
                                          style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom manual entry & Done bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoutiqueColors.border)),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInputCtrl,
                      focusNode: _tagInputFocus,
                      style: const TextStyle(fontSize: 13),
                      decoration: BoutiqueInputDecoration.field(
                        hintText: 'Or enter Tag ID manually...',
                        prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 18, color: BoutiqueColors.textSecondary),
                      ),
                      onSubmitted: (_) => _submitManualTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitManualTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text('Add Tag'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Done (${_scannedSessionItems.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
