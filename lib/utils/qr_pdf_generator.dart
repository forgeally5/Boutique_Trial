import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  // 2.5 cm (25 mm) Left to Right  x  1.5 cm (15 mm) Top to Bottom
  // Exact micro-sticker size: Left is QR Code + Tag ID, Right is Item Name + Price.
  static const PdfPageFormat labelPageFormat = PdfPageFormat(
    2.5 * PdfPageFormat.cm, // 70.87 pt (25.0 mm) - Left to right width
    1.5 * PdfPageFormat.cm, // 42.52 pt (15.0 mm) - Top to bottom height
    marginAll: 0,
  );

  /// Generates and prints a horizontal 2.5 cm x 1.5 cm QR barcode label for a single product.
  static Future<void> printProductQr(Product product) async {
    final doc = await generateProductQrPdf(product);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: 'QR_${product.tagId}',
      format: labelPageFormat,
      dynamicLayout: false,
    );
  }

  /// Generates and prints bulk QR labels for multiple products (N products x copies = total stickers).
  static Future<void> printBulkProductQr(
    List<Product> products, {
    int copies = 1,
  }) async {
    if (products.isEmpty) return;
    final doc = await generateBulkProductQrPdf(products, copies: copies);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: 'Bulk_QR_Tags_${products.length}',
      format: labelPageFormat,
      dynamicLayout: false,
    );
  }

  /// Generates a PDF Document with a single 2.5 cm x 1.5 cm horizontal barcode label.
  static Future<pw.Document> generateProductQrPdf(Product product) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    pdf.addPage(
      pw.Page(
        pageFormat: labelPageFormat,
        orientation: pw.PageOrientation.landscape,
        theme: fonts.theme,
        build: (pw.Context context) {
          return buildTagWidget(product, fonts.currencySymbol);
        },
      ),
    );

    return pdf;
  }

  /// Generates a multi-page PDF Document for bulk products with copies.
  /// Each tag is on its own separate page of 2.5 cm x 1.5 cm size.
  static Future<pw.Document> generateBulkProductQrPdf(
    List<Product> products, {
    int copies = 1,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    final safeCopies = copies < 1 ? 1 : copies;

    for (final product in products) {
      for (int i = 0; i < safeCopies; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: labelPageFormat,
            orientation: pw.PageOrientation.landscape,
            theme: fonts.theme,
            build: (pw.Context context) {
              return buildTagWidget(product, fonts.currencySymbol);
            },
          ),
        );
      }
    }

    return pdf;
  }

  /// Shared reusable Tag Widget:
  /// Left: QR Code + Tag ID below QR.
  /// Right: Item Name & Price (and weight if applicable).
  /// Dimensions: 2.5 cm width x 1.5 cm height.
  static pw.Widget buildTagWidget(Product product, String currencySymbol) {
    final priceStr = _formatPrice(product);
    final weightStr = _getWeightString(product);

    return pw.Container(
      width: 2.5 * PdfPageFormat.cm,
      height: 1.5 * PdfPageFormat.cm,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // ── LEFT COLUMN: QR Code + Tag ID below it ──
          pw.Container(
            width: 30.0,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  data: product.tagId,
                  barcode: pw.Barcode.qrCode(),
                  width: 27.0,
                  height: 27.0,
                ),
                pw.SizedBox(height: 1.0),
                pw.Text(
                  product.tagId,
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 3.0),

          // ── RIGHT COLUMN: Item Name & Price directly underneath/beside ──
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Item Name & Weight
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      product.name.trim().toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        lineSpacing: 1.0,
                      ),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                    ),
                    if (weightStr.isNotEmpty) ...[
                      pw.SizedBox(height: 0.8),
                      pw.Text(
                        weightStr,
                        style: pw.TextStyle(
                          fontSize: 4.8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),

                // Price (Prominent)
                if (priceStr.isNotEmpty)
                  pw.Container(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Text(
                      '$currencySymbol$priceStr',
                      style: pw.TextStyle(
                        fontSize: 10.0,
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
    );
  }

  /// Loads fonts safely with fallback
  static Future<_LoadedFonts> _loadFonts() async {
    pw.Font? fontRegular;
    pw.Font? fontBold;

    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (e) {
      debugPrint('[QrPdfGenerator] Fallback to standard font: $e');
    }

    final currencySymbol = (fontRegular != null) ? '₹' : 'Rs. ';
    final theme = fontRegular != null && fontBold != null
        ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
        : pw.ThemeData.base();

    return _LoadedFonts(theme: theme, currencySymbol: currencySymbol);
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

class _LoadedFonts {
  final pw.ThemeData theme;
  final String currencySymbol;
  _LoadedFonts({required this.theme, required this.currencySymbol});
}
