import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

/// Generates and prints a thermal-style estimation slip for one or more products.
class PdfEstimationApi {
  static const PdfColor _black = PdfColor.fromInt(0xFF000000);
  static const PdfColor _grey = PdfColor.fromInt(0xFF666666);
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFEEEEEE);

  static final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs.',
    decimalDigits: 0,
  );
  static final _numFmt = NumberFormat('#,##0.000');

  static Future<void> printEstimation({
    required List<Product> products,
    required String shopName,
  }) async {
    final bytes = await _buildPdf(products: products, shopName: shopName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> sharePdf({
    required List<Product> products,
    required String shopName,
  }) async {
    final bytes = await _buildPdf(products: products, shopName: shopName);
    await Printing.sharePdf(bytes: bytes, filename: 'estimate_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<Uint8List> buildBytes({
    required List<Product> products,
    required String shopName,
  }) async {
    return _buildPdf(products: products, shopName: shopName);
  }

  static Future<Uint8List> _buildPdf({
    required List<Product> products,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Thermal receipt width: 80mm
    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // ── HEADER ──────────────────────────────────────────────
          widgets.add(
            pw.Center(
              child: pw.Text(
                'ESTIMATE ONLY',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(
            pw.Center(
              child: pw.Text(
                shopName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(
            pw.Center(
              child: pw.Text(
                now,
                style: pw.TextStyle(fontSize: 7, color: _grey),
              ),
            ),
          );
          widgets.add(_divider());

          // ── PER PRODUCT SECTIONS ─────────────────────────────────
          double grandTotal = 0.0;
          for (final prod in products) {
            double finalAmt = 0;
            if (prod.pricingType == 'Quantity-Based') {
              finalAmt = prod.sellingPrice;
            } else {
              finalAmt = (prod.grossWeight * prod.ratePerGram) + prod.makingCharges;
            }
            grandTotal += finalAmt;

            // Product heading line: TagId   CATEGORY
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    prod.tagId,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    prod.category.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );
            if (prod.name.isNotEmpty) {
              widgets.add(
                pw.Text(
                  prod.name,
                  style: pw.TextStyle(fontSize: 7, color: _grey),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 3));

            if (prod.pricingType == 'Quantity-Based') {
              widgets.add(_row2('Qty', '${prod.quantity} ${prod.unit}'));
              widgets.add(_row2('MRP', _currencyFmt.format(prod.mrp)));
            } else {
              widgets.add(_row2('Gr. Wt', '${_numFmt.format(prod.grossWeight)} g'));
              widgets.add(_row2('Rate', _currencyFmt.format(prod.ratePerGram)));
              if (prod.makingCharges > 0) {
                widgets.add(_row2('Making', _currencyFmt.format(prod.makingCharges)));
              }
            }

            widgets.add(_dashedLine());

            // Final amount for this product
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Final Amt',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _currencyFmt.format(finalAmt),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );

            widgets.add(_divider());
          }

          // ── MAX TOTAL (only for multiple products) ───────────────
          if (products.length > 1) {
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Container(
                color: _lightGrey,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'MAX TOTAL (${products.length} items)',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _black,
                      ),
                    ),
                    pw.Text(
                      _currencyFmt.format(grandTotal),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          widgets.add(pw.SizedBox(height: 8));

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: widgets,
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _row2(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: _black),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8, color: _black),
          ),
        ],
      ),
    );
  }

  static pw.Widget _divider() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      height: 1,
      color: _black,
    );
  }

  static pw.Widget _dashedLine() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        '----------------------------------------',
        style: pw.TextStyle(fontSize: 6, color: _grey),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
