import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// fillRow       : 3 tags per row (one per sticker column). Fewer pages, no waste.
/// singleColumn  : one tag per page, only in [LabelRollConfig.startColumn].
enum LabelPrintMode { fillRow, singleColumn }

/// Everything that can differ between rolls / printers. The client can change
/// these from the settings dialog (label_settings_dialog.dart), no code change.
class LabelRollConfig {
  double labelWidthMm; // one sticker
  double labelHeightMm;
  int columns; // stickers across the roll
  double hGapMm; // gap between stickers, left-right
  double vGapMm; // gap between rows, top-bottom
  double sideMarginMm; // liner margin on the left AND right of the 3 stickers
  int rotationQuarterTurns; // 0, 1, 2, 3  (0, 90, 180, 270 degrees)
  double offsetXmm; // nudge everything right (+) / left (-)
  double offsetYmm; // nudge everything down (+) / up (-)
  int startColumn; // 1..columns, used in singleColumn mode
  LabelPrintMode mode;

  LabelRollConfig({
    this.labelWidthMm = 34,
    this.labelHeightMm = 21,
    this.columns = 3,
    this.hGapMm = 1,
    this.vGapMm = 3,
    this.sideMarginMm = 2,
    this.rotationQuarterTurns = 0,
    this.offsetXmm = 0,
    this.offsetYmm = 0,
    this.startColumn = 1,
    this.mode = LabelPrintMode.fillRow,
  });

  Map<String, dynamic> toJson() => {
        'labelWidthMm': labelWidthMm,
        'labelHeightMm': labelHeightMm,
        'columns': columns,
        'hGapMm': hGapMm,
        'vGapMm': vGapMm,
        'sideMarginMm': sideMarginMm,
        'rotationQuarterTurns': rotationQuarterTurns,
        'offsetXmm': offsetXmm,
        'offsetYmm': offsetYmm,
        'startColumn': startColumn,
        'mode': mode.name,
      };

  factory LabelRollConfig.fromJson(Map<String, dynamic> j) {
    final d = LabelRollConfig();
    double dbl(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int integer(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return LabelRollConfig(
      labelWidthMm: dbl('labelWidthMm', d.labelWidthMm),
      labelHeightMm: dbl('labelHeightMm', d.labelHeightMm),
      columns: integer('columns', d.columns).clamp(1, 6),
      hGapMm: dbl('hGapMm', d.hGapMm),
      vGapMm: dbl('vGapMm', d.vGapMm),
      sideMarginMm: dbl('sideMarginMm', d.sideMarginMm),
      rotationQuarterTurns: integer('rotationQuarterTurns', 0).clamp(0, 3),
      offsetXmm: dbl('offsetXmm', 0),
      offsetYmm: dbl('offsetYmm', 0),
      startColumn: integer('startColumn', 1).clamp(1, 6),
      mode: j['mode'] == 'singleColumn'
          ? LabelPrintMode.singleColumn
          : LabelPrintMode.fillRow,
    );
  }
}

class QrPdfGenerator {
  static const double _mm = PdfPageFormat.mm;
  static const String _prefsKey = 'label_roll_config_v1';

  static LabelRollConfig config = LabelRollConfig();
  static bool _loaded = false;

  // ─────────────────────────── CONFIG STORAGE ───────────────────────────

  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        config = LabelRollConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[QrPdfGenerator] Could not load label config: $e');
    }
    _loaded = true;
  }

  static Future<void> saveConfig(LabelRollConfig newConfig) async {
    config = newConfig;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(newConfig.toJson()));
    } catch (e) {
      debugPrint('[QrPdfGenerator] Could not save label config: $e');
    }
  }

  static Future<void> _ensureLoaded() async {
    if (!_loaded) await loadConfig();
  }

  // ─────────────────────────── PAGE SIZE ───────────────────────────
  // The PDF page is ONE ROW of stickers (3 across) and nothing else, so it can
  // match the printer driver's custom paper size exactly:
  //   width  = 2*sideMargin + 3*labelWidth + 2*hGap   (default 108 mm)
  //   height = labelHeight + vGap                     (default 24 mm)

  static double get _rowW =>
      (config.sideMarginMm * 2 +
          config.columns * config.labelWidthMm +
          (config.columns - 1) * config.hGapMm) *
      _mm;

  static double get _rowH => (config.labelHeightMm + config.vGapMm) * _mm;

  static bool get _swapPage => config.rotationQuarterTurns.isOdd;

  /// Size of the PDF page sent to the printer.
  /// Rotation 90/270 swaps width and height (portrait paper in the driver).
  static PdfPageFormat get labelPageFormat => _swapPage
      ? PdfPageFormat(_rowH, _rowW, marginAll: 0)
      : PdfPageFormat(_rowW, _rowH, marginAll: 0);

  // ─────────────────────────── PRINT ENTRY POINTS ───────────────────────────

  /// Prints one tag (in the start column).
  static Future<void> printProductQr(Product product) async {
    await _ensureLoaded();
    final doc = await generateProductQrPdf(product);
    await _send(doc, 'QR_${product.tagId}');
  }

  /// Prints N products x copies. In fillRow mode 3 stickers share one row.
  static Future<void> printBulkProductQr(
    List<Product> products, {
    int copies = 1,
  }) async {
    if (products.isEmpty) return;
    await _ensureLoaded();
    final doc = await generateBulkProductQrPdf(products, copies: copies);
    await _send(doc, 'Bulk_QR_Tags_${products.length}');
  }

  /// Prints 2 rows of empty bordered cells with column numbers and a
  /// "TOP / FEED" marker. Use it to check: which sticker each cell lands on,
  /// whether stickers are skipped, and which way the content is rotated.
  static Future<void> printCalibrationTest() async {
    await _ensureLoaded();
    final fonts = await _loadFonts();
    final pdf = pw.Document();
    for (int r = 0; r < 2; r++) {
      final cells = List<pw.Widget?>.generate(
        config.columns,
        (i) => _calibrationCell(i + 1, r + 1),
      );
      pdf.addPage(_rowPage(cells, fonts.theme));
    }
    await _send(pdf, 'Label_Calibration_Test');
  }

  static Future<void> _send(pw.Document doc, String name) async {
    final f = labelPageFormat;
    debugPrint(
      '[QrPdfGenerator] page ${(f.width / _mm).toStringAsFixed(1)} x '
      '${(f.height / _mm).toStringAsFixed(1)} mm | config ${jsonEncode(config.toJson())}',
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat layoutFormat) async => doc.save(),
      name: name,
      format: f,
      dynamicLayout: false,
    );
  }

  // ─────────────────────────── PDF BUILDERS ───────────────────────────

  static Future<pw.Document> generateProductQrPdf(Product product) async {
    return _buildDoc([product], forceSingle: true);
  }

  static Future<pw.Document> generateBulkProductQrPdf(
    List<Product> products, {
    int copies = 1,
  }) async {
    final safeCopies = copies < 1 ? 1 : copies;
    final expanded = <Product>[
      for (final p in products)
        for (int i = 0; i < safeCopies; i++) p,
    ];
    return _buildDoc(expanded);
  }

  static Future<pw.Document> _buildDoc(
    List<Product> items, {
    bool forceSingle = false,
  }) async {
    await _ensureLoaded();
    final pdf = pw.Document();
    final fonts = await _loadFonts();
    final cols = config.columns;
    final fill = config.mode == LabelPrintMode.fillRow && !forceSingle;

    if (fill) {
      for (int i = 0; i < items.length; i += cols) {
        final chunk = items.skip(i).take(cols).toList();
        final cells = <pw.Widget?>[
          for (final p in chunk) buildTagWidget(p, fonts.currencySymbol),
        ];
        pdf.addPage(_rowPage(cells, fonts.theme));
      }
    } else {
      final col = (config.startColumn.clamp(1, cols)) - 1;
      for (final p in items) {
        final cells = List<pw.Widget?>.filled(cols, null);
        cells[col] = buildTagWidget(p, fonts.currencySymbol);
        pdf.addPage(_rowPage(cells, fonts.theme));
      }
    }
    return pdf;
  }

  /// One PDF page = one row of stickers. Rotates the whole row when needed.
  static pw.Page _rowPage(List<pw.Widget?> cells, pw.ThemeData theme) {
    return pw.Page(
      pageFormat: labelPageFormat,
      margin: pw.EdgeInsets.zero,
      theme: theme,
      build: (pw.Context context) {
        final row = _buildRow(cells);
        final q = config.rotationQuarterTurns % 4;
        if (q == 0) return row;

        // OverflowBox gives the row its REAL size, so the rotated content is
        // not squeezed by the (swapped) page constraints.
        return pw.Center(
          child: pw.Transform.rotateBox(
            angle: q * math.pi / 2,
            child: pw.OverflowBox(
              minWidth: _rowW,
              maxWidth: _rowW,
              minHeight: _rowH,
              maxHeight: _rowH,
              alignment: pw.Alignment.center,
              child: row,
            ),
          ),
        );
      },
    );
  }

  /// Places each sticker at its exact x position in the row.
  static pw.Widget _buildRow(List<pw.Widget?> cells) {
    final c = config;
    final cellW = c.labelWidthMm * _mm;
    final cellH = c.labelHeightMm * _mm;
    final children = <pw.Widget>[];

    for (int i = 0; i < c.columns && i < cells.length; i++) {
      final cell = cells[i];
      if (cell == null) continue;
      final left =
          (c.sideMarginMm + i * (c.labelWidthMm + c.hGapMm) + c.offsetXmm) *
              _mm;
      final top = c.offsetYmm * _mm;
      children.add(
        pw.Positioned(
          left: left,
          top: top,
          child: pw.SizedBox(width: cellW, height: cellH, child: cell),
        ),
      );
    }

    return pw.SizedBox(
      width: _rowW,
      height: _rowH,
      child: pw.Stack(overflow: pw.Overflow.visible, children: children),
    );
  }

  // ─────────────────────────── TAG DESIGN (34 x 21 mm) ───────────────────────────
  // Left : QR code, Tag ID below it.
  // Right: Item name (max 3 lines), weight (if weight-based), price at bottom.

  static pw.Widget buildTagWidget(Product product, String currencySymbol) {
    final c = config;
    final w = c.labelWidthMm * _mm;
    final h = c.labelHeightMm * _mm;
    final pad = 1.0 * _mm;
    final qrSize = math.min(h * 0.66, w * 0.43);
    final leftW = qrSize + 1.0 * _mm;

    final priceStr = _formatPrice(product);
    final weightStr = _getWeightString(product);

    return pw.Container(
      width: w,
      height: h,
      padding: pw.EdgeInsets.all(pad),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // LEFT: QR + Tag ID
          pw.Container(
            width: leftW,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  data: product.tagId,
                  barcode: pw.Barcode.qrCode(),
                  width: qrSize,
                  height: qrSize,
                ),
                pw.SizedBox(height: 1.0),
                pw.Text(
                  product.tagId,
                  style: pw.TextStyle(
                    fontSize: 6.0,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 1.5 * _mm),

          // RIGHT: name, weight, price
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
                        fontSize: 7.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        lineSpacing: 0.5,
                      ),
                      maxLines: 3,
                      overflow: pw.TextOverflow.clip,
                    ),
                    if (weightStr.isNotEmpty) ...[
                      pw.SizedBox(height: 1.0),
                      pw.Text(
                        weightStr,
                        style: pw.TextStyle(
                          fontSize: 5.5,
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
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.bottomRight,
                      child: pw.Text(
                        '$currencySymbol$priceStr',
                        style: pw.TextStyle(
                          fontSize: 12.0,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _calibrationCell(int column, int row) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            '^ TOP / FEED',
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'COL $column',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('ROW $row', style: const pw.TextStyle(fontSize: 6)),
          pw.Text(
            '${config.labelWidthMm.toStringAsFixed(0)} x ${config.labelHeightMm.toStringAsFixed(0)} mm',
            style: const pw.TextStyle(fontSize: 5),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── HELPERS (unchanged logic) ───────────────────────────

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