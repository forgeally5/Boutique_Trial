import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  // 2.5 cm (25 mm) Left to Right  x  1.5 cm (15 mm) Top to Bottom
  // Matches Photo 2 (Horizontal Micro-Tag: Store Header at top, QR on left, Name/Weight/Price on right)
  static const PdfPageFormat labelPageFormat = PdfPageFormat(
    2.5 * PdfPageFormat.cm, // 70.87 pt (25.0 mm) - Left to right width
    1.5 * PdfPageFormat.cm, // 42.52 pt (15.0 mm) - Top to bottom height
    marginAll: 0,
  );

  /// Generates and prints a horizontal 2.5 cm x 1.5 cm QR barcode label for a single product.
  static Future<void> printProductQr(
    Product product, {
    String storeName = 'VilakkuKadai',
  }) async {
    final doc = await generateProductQrPdf(product, storeName: storeName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: 'QR_${product.tagId}',
      format: labelPageFormat,
      dynamicLayout: false,
    );
  }

  /// Generates a PDF Document with the horizontal barcode label matching Photo 2 (2.5 cm x 1.5 cm).
  static Future<pw.Document> generateProductQrPdf(
    Product product, {
    String storeName = 'VilakkuKadai',
  }) async {
    final pdf = pw.Document();

    pw.Font? fontRegular;
    pw.Font? fontBold;

    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (e) {
      debugPrint('[QrPdfGenerator] Fallback to standard font: $e');
    }

    final currencySymbol = (fontRegular != null) ? '₹' : 'Rs. ';

    final priceStr = _formatPrice(product);
    final weightStr = _getWeightString(product);

    pdf.addPage(
      pw.Page(
        pageFormat: labelPageFormat,
        orientation: pw.PageOrientation.landscape,
        theme: fontRegular != null && fontBold != null
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : pw.ThemeData.base(),
        build: (pw.Context context) {
          return pw.Container(
            width: 2.5 * PdfPageFormat.cm,
            height: 1.5 * PdfPageFormat.cm,
            padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── 1. STORE HEADER (Matching Photo 2: "VilakkuKadai") ──
                if (storeName.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 1.0, bottom: 0.5),
                    child: pw.Text(
                      storeName,
                      style: pw.TextStyle(
                        fontSize: 4.8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),

                // ── 2. MAIN HORIZONTAL CONTENT ROW (Matching Photo 2) ──
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // ── LEFT COLUMN: QR Code + Tag ID underneath ──
                      pw.Container(
                        width: 28.0,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisAlignment: pw.MainAxisAlignment.start,
                          children: [
                            pw.BarcodeWidget(
                              data: product.tagId,
                              barcode: pw.Barcode.qrCode(),
                              width: 24.5,
                              height: 24.5,
                            ),
                            pw.SizedBox(height: 0.8),
                            pw.Text(
                              product.tagId,
                              style: pw.TextStyle(
                                fontSize: 4.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                              textAlign: pw.TextAlign.center,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(width: 2.0),

                      // ── RIGHT COLUMN: Product Name, Weight & Price (Bottom Right) ──
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            // Product Name & Weight
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  product.name.trim().toUpperCase(),
                                  style: pw.TextStyle(
                                    fontSize: 5.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                    lineSpacing: 0.95,
                                  ),
                                  maxLines: 2,
                                  overflow: pw.TextOverflow.clip,
                                ),
                                if (weightStr.isNotEmpty) ...[
                                  pw.SizedBox(height: 0.8),
                                  pw.Text(
                                    weightStr,
                                    style: pw.TextStyle(
                                      fontSize: 4.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),

                            // Price (Bottom Right in Photo 2)
                            if (priceStr.isNotEmpty)
                              pw.Container(
                                alignment: pw.Alignment.bottomRight,
                                child: pw.Text(
                                  '$currencySymbol$priceStr',
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  /// Calculates the best price to display for the label
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
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(2);
  }

  /// Only extracts weight for weight-based products
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
