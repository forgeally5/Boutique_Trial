import 'package:flutter/material.dart';
import 'qr_scanner_dialog.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../state/admin_state.dart';
import '../utils/pdf_estimation_api.dart';

const _brown = Color(0xFF3E2723);
const _bg = Color(0xFFFCFAF5);

class EstimationDialog extends StatefulWidget {
  final AdminState state;

  const EstimationDialog({super.key, required this.state});

  @override
  State<EstimationDialog> createState() => _EstimationDialogState();
}

class _EstimationDialogState extends State<EstimationDialog> {
  final List<Product> _estimatedProducts = [];
  final TextEditingController _tagController = TextEditingController();
  String? _errorMessage;
  
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  void _searchProduct(String tagId) {
    final clean = tagId.trim();
    if (clean.isEmpty) return;
    
    final prod = widget.state.lookupProduct(clean);
    if (prod != null) {
      if (prod.status.toLowerCase() == 'sold out' || prod.status.toLowerCase() == 'sold') {
        setState(() {
          _errorMessage = 'Piece "$clean" is SOLD OUT.';
        });
        return;
      }

      setState(() {
        _errorMessage = null;
        final exists = _estimatedProducts.any(
          (p) => p.tagId.trim().toLowerCase() == prod.tagId.trim().toLowerCase(),
        );
        if (!exists) {
          _estimatedProducts.add(prod);
        }
        _tagController.clear();
      });
    } else {
      setState(() {
        _errorMessage = 'Product with Tag ID "$clean" not found in inventory.';
      });
    }
  }

  void _removeProduct(int index) {
    setState(() {
      _estimatedProducts.removeAt(index);
    });
  }

  Future<void> _printEstimation() async {
    if (_estimatedProducts.isEmpty) return;
    await PdfEstimationApi.printEstimation(
      products: _estimatedProducts,
      shopName: 'DEVOTIONAL BOUTIQUE', // Replace with real setting if available
    );
  }

  Future<void> _shareEstimation() async {
    if (_estimatedProducts.isEmpty) return;
    await PdfEstimationApi.sharePdf(
      products: _estimatedProducts,
      shopName: 'DEVOTIONAL BOUTIQUE',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _bg,
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Generate Estimate', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _brown)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      labelText: 'Scan or enter Tag ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: _searchProduct,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _searchProduct(_tagController.text),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final scanned = await openQrScanner(context);
                    if (scanned != null) {
                      _tagController.text = scanned;
                      _searchProduct(scanned);
                    }
                  },
                ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _estimatedProducts.length,
                itemBuilder: (context, index) {
                  final p = _estimatedProducts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('${p.tagId} - ${p.name}'),
                      subtitle: Text(p.pricingType == 'Quantity-Based' 
                          ? 'MRP: ${_currencyFormatter.format(p.mrp)}'
                          : 'Gross Wt: ${p.grossWeight}g | Rate: ${_currencyFormatter.format(p.ratePerGram)}/g'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeProduct(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _estimatedProducts.isEmpty ? null : _shareEstimation,
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _estimatedProducts.isEmpty ? null : _printEstimation,
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text('Print Estimate', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: _brown),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
