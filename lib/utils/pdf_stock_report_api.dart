import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/master/c_stock_reports/stock_reports_dummy_data.dart';

class PdfStockReportApi {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  static final _numberFormat = NumberFormat('#,##0.00', 'en_US');

  // Colors
  static const PdfColor primaryBrown = PdfColor.fromInt(0xFF3E2723);
  static const PdfColor secondaryBrown = PdfColor.fromInt(0xFF5D4037);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFB45309);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFFAF6F0);
  static const PdfColor headerBg = PdfColor.fromInt(0xFF4A342E);
  static const PdfColor tableHeaderBg = PdfColor.fromInt(0xFF3E2723);
  static const PdfColor altRowBg = PdfColor.fromInt(0xFFFBF8F3);
  static const PdfColor borderLine = PdfColor.fromInt(0xFFE5DDD0);
  static const PdfColor greenText = PdfColor.fromInt(0xFF15803D);
  static const PdfColor redText = PdfColor.fromInt(0xFFB91C1C);

  // ───────────────────────────────────────────────────────────────────────────
  // 1. STOCK SUMMARY REPORT PDF
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateStockSummaryPdf({
    required List<StockSummaryItem> items,
    required String financialYear,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    int totalQty = 0;
    double totalWeight = 0.0;
    double totalValue = 0.0;

    for (final item in items) {
      totalQty += item.closingQty;
      totalWeight += item.weight;
      totalValue += item.value;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildPdfHeader(
          title: 'STOCK SUMMARY REPORT',
          financialYear: financialYear,
          dateRange: dateRange,
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          // Summary Metrics Cards
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderLine),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Categories', '${items.length}'),
                _buildSummaryStat('Total Closing Qty', '$totalQty Pcs'),
                _buildSummaryStat('Total Weight', '${_numberFormat.format(totalWeight)} g'),
                _buildSummaryStat('Total Stock Value', _currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Table
          pw.TableHelper.fromTextArray(
            headers: [
              'Category',
              'Group Head',
              'Items',
              'Opening',
              'Stock In',
              'Stock Out',
              'Closing Qty',
              'Weight (g)',
              'Value (Rs.)',
            ],
            data: items.map((item) {
              return [
                item.category,
                item.groupHead,
                item.itemCount.toString(),
                item.openingQty.toString(),
                '+${item.stockIn}',
                '-${item.stockOut}',
                item.closingQty.toString(),
                _numberFormat.format(item.weight),
                _currencyFormat.format(item.value),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: altRowBg),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: borderLine, width: 0.5),
          ),
          pw.SizedBox(height: 8),

          // Total Footer Row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: primaryBrown,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL STOCK SUMMARY:',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Qty: $totalQty Pcs  |  Wt: ${_numberFormat.format(totalWeight)} g  |  Val: ${_currencyFormat.format(totalValue)}',
                  style: pw.TextStyle(
                    color: PdfColors.amber100,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. ITEM WISE STOCK BALANCE PDF
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateItemWisePdf({
    required List<ItemWiseStockItem> items,
    required String financialYear,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    int totalQty = 0;
    double totalGross = 0.0;
    double totalNet = 0.0;
    double totalValue = 0.0;

    for (final item in items) {
      totalQty += item.quantity;
      totalGross += item.grossWeight;
      totalNet += item.netWeight;
      totalValue += item.value;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildPdfHeader(
          title: 'ITEM WISE STOCK BALANCE REPORT',
          financialYear: financialYear,
          dateRange: dateRange,
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderLine),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Items', '${items.length}'),
                _buildSummaryStat('Available Qty', '$totalQty Pcs'),
                _buildSummaryStat('Total Net Wt', '${_numberFormat.format(totalNet)} g'),
                _buildSummaryStat('Total Value', _currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Item Code',
              'Item Name',
              'Category',
              'Purity',
              'Qty',
              'Gross Wt (g)',
              'Net Wt (g)',
              'Value (Rs.)',
            ],
            data: items.map((item) {
              return [
                item.itemCode,
                item.itemName,
                item.category,
                item.purity,
                item.quantity.toString(),
                _numberFormat.format(item.grossWeight),
                _numberFormat.format(item.netWeight),
                _currencyFormat.format(item.value),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            oddRowDecoration: const pw.BoxDecoration(color: altRowBg),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: borderLine, width: 0.5),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: primaryBrown,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ITEM BALANCE TOTALS:',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Total Qty: $totalQty Pcs  |  Gross: ${_numberFormat.format(totalGross)}g  |  Net: ${_numberFormat.format(totalNet)}g  |  Val: ${_currencyFormat.format(totalValue)}',
                  style: pw.TextStyle(
                    color: PdfColors.amber100,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. TAG WISE STOCK REPORT PDF
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateTagWisePdf({
    required List<TagWiseStockItem> items,
    required String financialYear,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    int totalTags = items.length;
    double totalGross = 0.0;
    double totalNet = 0.0;

    for (final item in items) {
      totalGross += item.grossWeight;
      totalNet += item.netWeight;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildPdfHeader(
          title: 'TAG WISE STOCK REPORT',
          financialYear: financialYear,
          dateRange: dateRange,
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderLine),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Tags', '$totalTags'),
                _buildSummaryStat(
                  'Available Tags',
                  '${items.where((e) => e.status == 'Available').length}',
                ),
                _buildSummaryStat(
                  'Sold Tags',
                  '${items.where((e) => e.status == 'Sold').length}',
                ),
                _buildSummaryStat('Total Net Wt', '${_numberFormat.format(totalNet)} g'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Tag No',
              'Barcode',
              'Item Name',
              'Purity',
              'Gross (g)',
              'Net (g)',
              'Status',
              'Counter Location',
            ],
            data: items.map((item) {
              return [
                item.tagNumber,
                item.barcode,
                item.itemName,
                item.purity,
                _numberFormat.format(item.grossWeight),
                _numberFormat.format(item.netWeight),
                item.status,
                item.counter,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            oddRowDecoration: const pw.BoxDecoration(color: altRowBg),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.center,
              7: pw.Alignment.centerLeft,
            },
            border: pw.TableBorder.all(color: borderLine, width: 0.5),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: primaryBrown,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TAG REPORT SUMMARY:',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Total Tags: $totalTags  |  Gross Wt: ${_numberFormat.format(totalGross)} g  |  Net Wt: ${_numberFormat.format(totalNet)} g',
                  style: pw.TextStyle(
                    color: PdfColors.amber100,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. COUNTER STOCK REPORT PDF
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateCounterStockPdf({
    required List<CounterStockItem> items,
    required String financialYear,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    int totalQty = 0;
    double totalWeight = 0.0;
    double totalValue = 0.0;

    for (final item in items) {
      totalQty += item.quantity;
      totalWeight += item.weight;
      totalValue += item.value;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildPdfHeader(
          title: 'COUNTER STOCK REPORT',
          financialYear: financialYear,
          dateRange: dateRange,
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderLine),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Counters', '${items.length}'),
                _buildSummaryStat('Total Quantity', '$totalQty Pcs'),
                _buildSummaryStat('Total Weight', '${_numberFormat.format(totalWeight)} g'),
                _buildSummaryStat('Total Value', _currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Counter Name',
              'In-Charge Staff',
              'Category',
              'Item Count',
              'Quantity',
              'Weight (g)',
              'Value (Rs.)',
            ],
            data: items.map((item) {
              return [
                item.counterName,
                item.staff,
                item.category,
                item.itemCount.toString(),
                item.quantity.toString(),
                _numberFormat.format(item.weight),
                _currencyFormat.format(item.value),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            oddRowDecoration: const pw.BoxDecoration(color: altRowBg),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: borderLine, width: 0.5),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: primaryBrown,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'COUNTER OVERALL TOTALS:',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Total Qty: $totalQty Pcs  |  Total Weight: ${_numberFormat.format(totalWeight)} g  |  Total Value: ${_currencyFormat.format(totalValue)}',
                  style: pw.TextStyle(
                    color: PdfColors.amber100,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER PDF WIDGETS
  // ───────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildPdfHeader({
    required String title,
    required String financialYear,
    required String dateRange,
  }) {
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TRILOK',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBrown,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.Text(
                  'OM SRI JEWEL',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: goldAccent,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: secondaryBrown,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: borderLine),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Financial Year: $financialYear',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryBrown,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date Range: $dateRange',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: secondaryBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Printed On: $nowStr',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: goldAccent, thickness: 1.5),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: borderLine, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Confidential - Trilok MCET Jewellery ERP System',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: primaryBrown,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7, color: secondaryBrown),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: primaryBrown,
          ),
        ),
      ],
    );
  }

  // Direct Print helper
  static Future<void> printPdf(Uint8List pdfBytes, String jobName) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: jobName,
    );
  }
}
