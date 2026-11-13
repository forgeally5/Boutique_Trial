import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  // ─────────────────────────────────────────────────────────────
  // PRINTER ORIENTATION SETTINGS  (change only these if needed)
  // ─────────────────────────────────────────────────────────────

  /// true  -> PDF page is PORTRAIT (15 x 25 mm), same as the printer's paper
  ///          definition. The landscape tag design is rotated inside the page,
  ///          so the printer/driver has nothing to rotate. (Fixes sideways print)
  /// false -> PDF page is LANDSCAPE (25 x 15 mm). Use this only if the printer
  ///          driver paper is set to landscape / 25 x 15 mm.
  static const bool printerPaperIsPortrait = true;

  /// Direction of rotation when [printerPaperIsPortrait] is true.
  /// 3 = -90 degrees, 1 = +90 degrees.
  /// Print once. If the text comes out upside down, change 3 -> 1 (or 1 -> 3).
  static const int rotationQuarterTurns = 3;

  // ─────────────────────────────────────────────────────────────
  // PAGE FORMATS
  // ─────────────────────────────────────────────────────────────

  // The DESIGN of the tag is always 25 mm wide x 15 mm tall (landscape).
  static const double _tagWidth = 2.5 * PdfPageFormat.cm;
  static const double _tagHeight = 1.5 * PdfPageFormat.cm;

  // The PAGE sent to the printer. Portrait pages are 15 x 25 mm.
  static const PdfPageFormat labelPageFormat = printerPaperIsPortrait
      ? PdfPageFormat(_tagHeight, _tagWidth, marginAll: 0) // 15 x 25 mm
      : PdfPageFormat(_tagWidth, _tagHeight, marginAll: 0); // 25 x 15 mm

  /// Generates and prints a QR barcode label for a single product.
  static Future<void> printProductQr(Product product) async {
    final doc = await generateProductQrPdf(product);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: 'QR_${product.tagId}',
      format: labelPageFormat,
      dynamicLayout: false,
    );
  }

  /// Generates and prints bulk QR labels (N products x copies = total stickers).
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

  /// PDF with a single label page.
  static Future<pw.Document> generateProductQrPdf(Product product) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    pdf.addPage(_buildLabelPage(product, fonts));
    return pdf;
  }

  /// Multi-page PDF. Each label is its own page.
  static Future<pw.Document> generateBulkProductQrPdf(
    List<Product> products, {
    int copies = 1,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    final safeCopies = copies < 1 ? 1 : copies;

    for (final product in products) {
      for (int i = 0; i < safeCopies; i++) {
        pdf.addPage(_buildLabelPage(product, fonts));
      }
    }
    return pdf;
  }

  /// Builds ONE page. The page shape matches the printer paper, and the
  /// landscape tag is rotated inside it when the printer paper is portrait.
  static pw.Page _buildLabelPage(Product product, _LoadedFonts fonts) {
    return pw.Page(
      pageFormat: labelPageFormat,
      // No `orientation:` here. The page format already has the right shape.
      theme: fonts.theme,
      build: (pw.Context context) {
        final tag = buildTagWidget(product, fonts.currencySymbol);

        if (!printerPaperIsPortrait) {
          return tag;
        }

        return pw.Center(
          child: pw.Transform.rotateBox(
            angle: rotationQuarterTurns * math.pi / 2,
            child: tag,
          ),
        );
      },
    );
  }

  /// Tag design (always landscape 25 x 15 mm):
  /// Left: QR Code + Tag ID below QR.
  /// Right: Item Name & Price (and weight if applicable).
  static pw.Widget buildTagWidget(Product product, String currencySymbol) {
    final priceStr = _formatPrice(product);
    final weightStr = _getWeightString(product);

    return pw.Container(
      width: _tagWidth,
      height: _tagHeight,
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

          // ── RIGHT COLUMN: Item Name & Price ──
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
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