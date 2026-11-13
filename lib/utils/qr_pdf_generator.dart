import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  // Standard 2.5 inch x 1.0 inch barcode sticker label format (63.5 mm x 25.4 mm)
  // Perfectly matches standard continuous roll boutique / jewelry price tags.
  static const PdfPageFormat labelPageFormat = PdfPageFormat(
    2.5 * PdfPageFormat.inch, // 180 pt (63.5 mm width)
    1.0 * PdfPageFormat.inch, // 72 pt (25.4 mm height)
    marginAll: 0,
  );

  /// Generates and prints a 2.5" x 1.0" QR barcode label for a single product.
  static Future<void> printProductQr(
    Product product, {
    PdfPageFormat? format,
  }) async {
    final pageFormat = format ?? labelPageFormat;
    final doc = await generateProductQrPdf(product, format: pageFormat);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: 'QR_${product.tagId}',
      format: pageFormat,
      dynamicLayout: false,
    );
  }

  /// Generates a PDF Document with 2.5" x 1.0" barcode label.
  static Future<pw.Document> generateProductQrPdf(
    Product product, {
    PdfPageFormat format = labelPageFormat,
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

    // Responsive sizing based on page height (72 pt for 1.0" label)
    final qrSize = (format.height <= 80) ? 46.0 : 60.0;
    final qrColWidth = (format.height <= 80) ? 56.0 : 70.0;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        orientation: pw.PageOrientation.landscape,
        theme: fontRegular != null && fontBold != null
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : pw.ThemeData.base(),
        build: (pw.Context context) {
          return pw.Container(
            width: format.width,
            height: format.height,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // ── LEFT COLUMN: QR Code + Tag ID below QR ──
                pw.Container(
                  width: qrColWidth,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // QR Code
                      pw.BarcodeWidget(
                        data: product.tagId,
                        barcode: pw.Barcode.qrCode(),
                        width: qrSize,
                        height: qrSize,
                      ),
                      pw.SizedBox(height: 1.5),

                      // QR ku keela Tag ID Number
                      pw.Text(
                        product.tagId,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 8),

                // ── RIGHT COLUMN: Product Name, Weight & Price directly underneath ──
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // Product Name
                      pw.Text(
                        product.name.trim().toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: (weightStr.isNotEmpty) ? 9.0 : 10.0,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          lineSpacing: 1.0,
                        ),
                        maxLines: (weightStr.isNotEmpty) ? 1 : 2,
                        overflow: pw.TextOverflow.clip,
                      ),

                      // Only weight if weight-based product
                      if (weightStr.isNotEmpty) ...[
                        pw.SizedBox(height: 1.5),
                        pw.Text(
                          weightStr,
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                          maxLines: 1,
                        ),
                      ],

                      pw.SizedBox(height: 3),

                      // Price below Product Name
                      if (priceStr.isNotEmpty)
                        pw.Text(
                          '$currencySymbol$priceStr',
                          style: pw.TextStyle(
                            fontSize: 14.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          maxLines: 1,
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
