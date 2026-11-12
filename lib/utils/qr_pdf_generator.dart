import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  // 2.5 inch x 1.5 inch barcode sticker label format (63.5 mm x 38.1 mm)
  static const PdfPageFormat labelPageFormat = PdfPageFormat(
    2.5 * PdfPageFormat.inch, // 180 pt
    1.5 * PdfPageFormat.inch, // 108 pt
    marginAll: 0,
  );

  /// Generates and prints a 2.5" x 1.5" QR barcode label for a single product.
  static Future<void> printProductQr(Product product) async {
    final doc = await generateProductQrPdf(product);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'QR_${product.tagId}',
      format: labelPageFormat,
    );
  }

  /// Generates a PDF Document with 2.5" x 1.5" barcode label.
  static Future<pw.Document> generateProductQrPdf(Product product) async {
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
        theme: fontRegular != null && fontBold != null
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : pw.ThemeData.base(),
        build: (pw.Context context) {
          return pw.Container(
            width: 2.5 * PdfPageFormat.inch,
            height: 1.5 * PdfPageFormat.inch,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // ── LEFT COLUMN: Boutique Name above QR, QR Code, Tag ID below QR ──
                pw.Container(
                  width: 76,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // QR ku mela Boutique Name
                      pw.Text(
                        'RituMita Boutique',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: 0.2,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1),

                      // QR Code
                      pw.BarcodeWidget(
                        data: product.tagId,
                        barcode: pw.Barcode.qrCode(),
                        width: 62,
                        height: 62,
                      ),
                      pw.SizedBox(height: 1),

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

                // ── RIGHT COLUMN: QR ku side la Product Name, adhuku keela Price ──
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // Product Name
                      pw.Text(
                        product.name.trim().toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          lineSpacing: 1.1,
                        ),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),

                      // Only weight if weight-based product (No category)
                      if (weightStr.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          weightStr,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                          maxLines: 1,
                        ),
                      ],

                      pw.SizedBox(height: 6),

                      // Adhuku keela Price
                      if (priceStr.isNotEmpty)
                        pw.Text(
                          '$currencySymbol$priceStr',
                          style: pw.TextStyle(
                            fontSize: 18,
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

  /// Only extracts weight for weight-based products (Category is excluded)
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
