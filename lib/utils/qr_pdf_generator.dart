import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  /// Generates and prints a 2.5" x 1.5" QR barcode label for a single product.
  static Future<void> printProductQr(Product product) async {
    final doc = await generateProductQrPdf(product);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'QR_${product.tagId}',
    );
  }

  /// Generates a PDF Document with 2.5" x 1.5" barcode label(s).
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

    // 2.5 inch x 1.5 inch barcode sticker label
    const pageFormat = PdfPageFormat(
      2.5 * PdfPageFormat.inch, // 63.5 mm (180 pt)
      1.5 * PdfPageFormat.inch, // 38.1 mm (108 pt)
      marginAll: 2.5 * PdfPageFormat.mm,
    );

    final priceStr = _formatPrice(product);
    final detailStr = _getDetailString(product);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: fontRegular != null && fontBold != null
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : pw.ThemeData.base(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Text(
                'RituMita Boutique',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
              ),
              pw.SizedBox(height: 2),

              // Main Row: Left (QR + Tag ID), Right (Name, Weight/Details, Price)
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Left Column: QR Code + Tag ID underneath
                    pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.BarcodeWidget(
                          data: product.tagId,
                          barcode: pw.Barcode.qrCode(),
                          width: 54,
                          height: 54,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: 58,
                          child: pw.Text(
                            product.tagId,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(width: 8),

                    // Right Column: Product Name, Details, Price
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // Top section: Name + Weight/Details
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                product.name.trim().toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  lineSpacing: 1.1,
                                ),
                                maxLines: 2,
                                overflow: pw.TextOverflow.clip,
                              ),
                              if (detailStr.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  detailStr,
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey800,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ],
                          ),

                          // Bottom section: Price
                          if (priceStr.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Text(
                                '$currencySymbol$priceStr',
                                style: pw.TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: pw.FontWeight.bold,
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

  /// Extracts additional info like weight, size, or category
  static String _getDetailString(Product product) {
    final weight = product.netWeight > 0 ? product.netWeight : product.grossWeight;
    if (weight > 0) {
      final unit = product.weightUnit.isNotEmpty ? product.weightUnit.toUpperCase() : 'G';
      final weightStr = weight == weight.roundToDouble() ? weight.toInt().toString() : weight.toStringAsFixed(2);
      return '$weightStr$unit';
    }
    if (product.size.trim().isNotEmpty) {
      return product.size.trim().toUpperCase();
    }
    if (product.category.trim().isNotEmpty && product.category.trim().toLowerCase() != 'others') {
      return product.category.trim().toUpperCase();
    }
    return '';
  }
}
