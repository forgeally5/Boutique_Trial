import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/services.dart' show rootBundle;

// ─── Theme Constants ────────────────────────────────────────────────────────
const _kBurgundyPdf = PdfColor.fromInt(0xFF8B263E);
const _kTextDark = PdfColor.fromInt(0xFF2C2523);
const _kTextMid = PdfColor.fromInt(0xFF706663);
const _kBgLight = PdfColor.fromInt(0xFFF7F3ED);
const _kBorderColor = PdfColor.fromInt(0xFFE8E2D9);
const _kRowAlt = PdfColor.fromInt(0xFFFAF7F2);

const _kCompanyName = 'RITUMITA BOUTIQUE';

final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');
final _dateFmt = DateFormat('dd/MM/yyyy');

pw.MemoryImage? _cachedPdfLogo;
Future<pw.MemoryImage?> _getPdfLogo() async {
  if (_cachedPdfLogo != null) return _cachedPdfLogo;
  try {
    final bytes =
        (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
    _cachedPdfLogo = pw.MemoryImage(bytes);
    return _cachedPdfLogo;
  } catch (_) {
    return null;
  }
}

// ─── Shared PDF Header Widget (Image 2 Format) ──────────────────────────────
pw.Widget _buildPdfHeader({
  required String reportTitle,
  required String subtitle,
  required pw.Font boldFont,
  required pw.Font regularFont,
  pw.MemoryImage? logoImage,
}) {
  final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left: Brand Logo
          if (logoImage != null)
            pw.Image(logoImage, height: 42, fit: pw.BoxFit.contain)
          else
            pw.Text(
              'RituMita Boutique',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: _kBurgundyPdf,
              ),
            ),
          // Right: Report title & Period / Date
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 13,
                  color: _kTextDark,
                ),
              ),
              if (subtitle.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 7.5,
                      color: _kTextMid,
                    ),
                  ),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  'Date: $nowStr',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 7.5,
                    color: _kTextMid,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 1.5, color: _kBurgundyPdf),
      pw.SizedBox(height: 10),
    ],
  );
}

// ─── Table Header Row ────────────────────────────────────────────────────────
pw.Widget _buildTableHeader(
  List<String> columns,
  List<int> flexes,
  pw.Font boldFont,
) {
  return pw.Container(
    color: _kBurgundyPdf,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Row(
      children: List.generate(columns.length, (i) {
        return pw.Expanded(
          flex: flexes[i],
          child: pw.Text(
            columns[i],
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 8,
              color: PdfColors.white,
            ),
          ),
        );
      }),
    ),
  );
}

// ─── Table Data Row ──────────────────────────────────────────────────────────
pw.Widget _buildTableRow(
  List<String> cells,
  List<int> flexes,
  pw.Font font,
  bool isAlt,
) {
  return pw.Container(
    color: isAlt ? _kRowAlt : PdfColors.white,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Row(
      children: List.generate(cells.length, (i) {
        return pw.Expanded(
          flex: flexes[i],
          child: pw.Text(
            cells[i],
            style: pw.TextStyle(font: font, fontSize: 7.5, color: _kTextDark),
          ),
        );
      }),
    ),
  );
}

// ─── Summary Footer (Image 2 Format) ─────────────────────────────────────────
pw.Widget _buildSummaryBox(
  Map<String, String> summaryFields,
  pw.Font boldFont,
  pw.Font regularFont,
) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: pw.BoxDecoration(
      color: _kBgLight,
      border: pw.Border.all(color: _kBorderColor, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Wrap(
      spacing: 18,
      runSpacing: 5,
      children: summaryFields.entries.map((e) {
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '${e.key}: ',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: _kTextMid,
              ),
            ),
            pw.Text(
              e.value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8.5,
                color: _kBurgundyPdf,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

// ─── Footer (Image 2 Format - No Unicode Bullets) ───────────────────────────
pw.Widget _buildFooter(pw.Font regularFont, pw.Context context) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kBorderColor, width: 0.5)),
    ),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$_kCompanyName - Confidential Report',
              style:
                  pw.TextStyle(font: regularFont, fontSize: 7, color: _kTextMid),
            ),
            pw.Text(
              'This is a computer-generated report. No signature required.',
              style:
                  pw.TextStyle(font: regularFont, fontSize: 7, color: _kTextMid),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style:
                pw.TextStyle(font: regularFont, fontSize: 7, color: _kTextMid),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// UNIFIED ISSUE REPORT PDF (Customer Returns + Vendor Issues combined)
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateUnifiedIssueReportPdf({
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();

  final subtitle =
      'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  int totalQty = 0;
  double totalRefund = 0;
  int customerCount = 0;
  int vendorCount = 0;

  for (final r in rows) {
    totalRefund += (r['refundAmount'] as num?)?.toDouble() ?? 0;
    totalQty += (r['qty'] as num?)?.toInt() ?? 0;
    if (r['_type'] == 'Customer Return') {
      customerCount++;
    } else {
      vendorCount++;
    }
  }

  const columns = [
    'S.No', 'Date', 'Type', 'Product',
    'Qty', 'Issue / Reason', 'Refund (Rs.)', 'Status'
  ];
  const flexes = [1, 2, 2, 4, 1, 3, 2, 2];

  // Colours for type badges
  const kCustomerBlue = PdfColor.fromInt(0xFF1565C0);
  const kVendorAmber = PdfColor.fromInt(0xFFE65100);
  const kCustomerBlueBg = PdfColor.fromInt(0xFFE3F2FD);
  const kVendorAmberBg = PdfColor.fromInt(0xFFFFF3E0);

  final logoImage = await _getPdfLogo();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'ISSUE REPORT — All Returns & Vendor Issues',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                final isVendor = r['_type'] == 'Vendor Issue';
                final typeLabel = isVendor ? 'Vendor Issue' : 'Customer Return';
                final typeBg = isVendor ? kVendorAmberBg : kCustomerBlueBg;
                final typeColor = isVendor ? kVendorAmber : kCustomerBlue;

                return pw.Container(
                  color: i.isOdd ? _kRowAlt : PdfColors.white,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: flexes[0],
                          child: pw.Text('${i + 1}',
                              style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 7.5,
                                  color: _kTextDark))),
                      pw.Expanded(
                          flex: flexes[1],
                          child: pw.Text(r['date']?.toString() ?? '—',
                              style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 7.5,
                                  color: _kTextDark))),
                      pw.Expanded(
                        flex: flexes[2],
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: typeBg,
                            borderRadius:
                                const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Text(typeLabel,
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 7,
                                  color: typeColor)),
                        ),
                      ),
                      pw.Expanded(
                          flex: flexes[3],
                          child: pw.Text(r['productName']?.toString() ?? '—',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 7.5,
                                  color: _kTextDark))),
                      pw.Expanded(
                          flex: flexes[4],
                          child: pw.Text(r['qty']?.toString() ?? '0',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 7.5,
                                  color: _kTextDark))),
                      pw.Expanded(
                          flex: flexes[5],
                          child: pw.Text(
                              r['issueReason']?.toString() ?? '—',
                              style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 7.5,
                                  color: _kTextDark))),
                      pw.Expanded(
                          flex: flexes[6],
                          child: pw.Text(
                              'Rs. ${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 7.5,
                                  color: _kBurgundyPdf))),
                      pw.Expanded(
                          flex: flexes[7],
                          child: pw.Text(r['status']?.toString() ?? '—',
                              style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 7.5,
                                  color: _kTextMid))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Issues': '${rows.length}',
          'Customer Returns': '$customerCount',
          'Vendor Issues': '$vendorCount',
          'Total Qty Affected': '$totalQty',
          'Total Refund': 'Rs. ${_numFmt.format(totalRefund)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ═══════════════════════════════════════════════════════════════════════════
// ISSUE REPORT PDF
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateIssueReportPdf({
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  final subtitle =
      'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  double totalRefund = 0;
  for (final r in rows) {
    totalRefund += (r['refundAmount'] as num?)?.toDouble() ?? 0;
  }

  final columns = [
    'S.No', 'Return Bill No', 'Orig. Bill', 'Date',
    'Customer', 'Product', 'Qty', 'Value (Rs.)', 'Reason', 'Status'
  ];
  final flexes = [1, 2, 2, 2, 3, 3, 1, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'ISSUE / RETURN REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                return _buildTableRow([
                  '${i + 1}',
                  r['billNo']?.toString() ?? '—',
                  r['originalBillNo']?.toString() ?? '—',
                  r['date']?.toString() ?? '—',
                  r['customerName']?.toString() ?? '—',
                  r['productName']?.toString() ?? '—',
                  r['qty']?.toString() ?? '0',
                  'Rs. ${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}',
                  r['reason']?.toString() ?? '—',
                  r['status']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Returns': '${rows.length}',
          'Total Refund': 'Rs. ${_numFmt.format(totalRefund)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ═══════════════════════════════════════════════════════════════════════════
// STOCK REPORT PDF
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateStockReportPdf({
  required List<Map<String, dynamic>> rows,
  required String categoryFilter,
  required String statusFilter,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  double totalStockValue = 0;
  int totalPurchased = 0;
  int totalIssued = 0;
  int totalSold = 0;
  int totalBalance = 0;
  int lowStockCount = 0;

  for (final r in rows) {
    final pricingType = r['pricingType']?.toString() ?? 'Quantity-Based';
    final grossWeight = (r['grossWeight'] as num?)?.toDouble() ?? 0.0;
    final ratePerGram = (r['ratePerGram'] as num?)?.toDouble() ?? 0.0;
    
    final balance = (r['balance'] as num?)?.toInt() ?? (r['quantity'] as num?)?.toInt() ?? 0;
    final totalRec = (r['totalReceived'] as num?)?.toInt() ?? 0;
    final issue = (r['issueQty'] as num?)?.toInt() ?? 0;
    final sold = (r['soldQty'] as num?)?.toInt() ?? 0;
    final price = (r['sellingPrice'] as num?)?.toDouble() ?? 0;

    if (pricingType == 'Weight-Based' && grossWeight > 0 && ratePerGram > 0) {
      totalStockValue += balance * grossWeight * ratePerGram;
    } else {
      totalStockValue += balance * price;
    }
    
    totalPurchased += totalRec;
    totalIssued += issue;
    totalSold += sold;
    totalBalance += balance;

    final status = r['status']?.toString() ?? '';
    if (status == 'Low Stock') lowStockCount++;
  }

  final filters = [
    if (categoryFilter != 'All') 'Category: $categoryFilter',
    if (statusFilter != 'All') 'Status: $statusFilter',
  ].join(' | ');

  final columns = [
    'S.No', 'Tag ID', 'Product Name', 'Category',
    'Tot. Purchased', 'Issued Qty', 'Sold Qty', 'Balance Qty',
    'Unit', 'Sell Price (Rs.)', 'Stock Value (Rs.)', 'Status'
  ];
  final flexes = [1, 2, 4, 2, 2, 2, 2, 2, 1, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'STOCK REPORT',
          subtitle: filters.isNotEmpty ? filters : 'All Categories | All Status',
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                final pricingType = r['pricingType']?.toString() ?? 'Quantity-Based';
                final grossWeight = (r['grossWeight'] as num?)?.toDouble() ?? 0.0;
                final ratePerGram = (r['ratePerGram'] as num?)?.toDouble() ?? 0.0;
                final weightUnit = r['weightUnit']?.toString() ?? 'g';
                
                final balance = (r['balance'] as num?)?.toInt() ?? (r['quantity'] as num?)?.toInt() ?? 0;
                final totalRec = (r['totalReceived'] as num?)?.toInt() ?? 0;
                final issue = (r['issueQty'] as num?)?.toInt() ?? 0;
                final sold = (r['soldQty'] as num?)?.toInt() ?? 0;
                final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0;
                
                final displaySp = pricingType == 'Weight-Based' ? ratePerGram : sp;
                final stockVal = (pricingType == 'Weight-Based' && grossWeight > 0 && ratePerGram > 0) ? (balance * grossWeight * ratePerGram) : (balance * sp);
                
                String balanceStr = balance.toString();
                if (pricingType == 'Weight-Based' && grossWeight > 0) {
                  balanceStr = '${grossWeight.toStringAsFixed(2)}$weightUnit ($balance pc)';
                }

                return _buildTableRow([
                  '${i + 1}',
                  r['tagId']?.toString() ?? '—',
                  r['name']?.toString() ?? '—',
                  r['category']?.toString() ?? '—',
                  '$totalRec',
                  '$issue',
                  '$sold',
                  balanceStr,
                  r['unit']?.toString() ?? '—',
                  'Rs. ${_numFmt.format(displaySp)}',
                  'Rs. ${_numFmt.format(stockVal)}',
                  r['status']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Products': '${rows.length}',
          'Total Purchased': '$totalPurchased',
          'Total Issued': '$totalIssued',
          'Total Sold': '$totalSold',
          'Balance Stock': '$totalBalance',
          'Stock Value': 'Rs. ${_numFmt.format(totalStockValue)}',
          'Low Stock Items': '$lowStockCount',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY-WISE CLOSING STOCK REPORT PDF
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateCategoryClosingStockPdf({
  required List<Map<String, dynamic>> rows,
  required String statusFilter,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  double totalClosingValue = 0;
  int totalSkus = 0;
  int totalPurchased = 0;
  int totalIssued = 0;
  int totalSold = 0;
  int totalClosingQty = 0;

  for (final r in rows) {
    totalSkus += (r['skuCount'] as num?)?.toInt() ?? 0;
    totalPurchased += (r['totalPurchased'] as num?)?.toInt() ?? 0;
    totalIssued += (r['totalIssued'] as num?)?.toInt() ?? 0;
    totalSold += (r['totalSold'] as num?)?.toInt() ?? 0;
    totalClosingQty += (r['closingQty'] as num?)?.toInt() ?? 0;
    totalClosingValue += (r['closingValue'] as num?)?.toDouble() ?? 0.0;
  }

  final subtitle = statusFilter != 'All'
      ? 'Category-wise Summary | Status: $statusFilter'
      : 'Category-wise Closing Stock Statement | All Categories';

  const columns = [
    'S.No',
    'Category Name',
    'Total Items (SKUs)',
    'Purchased Qty',
    'Issued Qty',
    'Sold Qty',
    'Closing Stock Qty',
    'Closing Stock Value (Rs.)',
  ];
  const flexes = [1, 3, 2, 2, 2, 2, 2, 3];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'CLOSING STOCK REPORT — CATEGORY WISE',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                final closingVal =
                    (r['closingValue'] as num?)?.toDouble() ?? 0.0;

                return _buildTableRow([
                  '${i + 1}',
                  r['category']?.toString() ?? '—',
                  '${r['skuCount'] ?? 0}',
                  '${r['totalPurchased'] ?? 0}',
                  '${r['totalIssued'] ?? 0}',
                  '${r['totalSold'] ?? 0}',
                  '${r['closingQty'] ?? 0}',
                  'Rs. ${_numFmt.format(closingVal)}',
                ], flexes, regularFont, i.isOdd);
              }),
              // Grand Total Row
              pw.Container(
                color: _kBgLight,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: flexes[0],
                      child: pw.Text('',
                          style: pw.TextStyle(font: boldFont, fontSize: 8)),
                    ),
                    pw.Expanded(
                      flex: flexes[1],
                      child: pw.Text('GRAND TOTAL',
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: _kBurgundyPdf)),
                    ),
                    pw.Expanded(
                      flex: flexes[2],
                      child: pw.Text('$totalSkus',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8, color: _kTextDark)),
                    ),
                    pw.Expanded(
                      flex: flexes[3],
                      child: pw.Text('$totalPurchased',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8, color: _kTextDark)),
                    ),
                    pw.Expanded(
                      flex: flexes[4],
                      child: pw.Text('$totalIssued',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8, color: _kTextDark)),
                    ),
                    pw.Expanded(
                      flex: flexes[5],
                      child: pw.Text('$totalSold',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8, color: _kTextDark)),
                    ),
                    pw.Expanded(
                      flex: flexes[6],
                      child: pw.Text('$totalClosingQty',
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: _kBurgundyPdf)),
                    ),
                    pw.Expanded(
                      flex: flexes[7],
                      child: pw.Text('Rs. ${_numFmt.format(totalClosingValue)}',
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: _kBurgundyPdf)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Categories': '${rows.length}',
          'Total SKUs': '$totalSkus',
          'Total Purchased': '$totalPurchased',
          'Total Issued': '$totalIssued',
          'Total Sold': '$totalSold',
          'Closing Stock Qty': '$totalClosingQty',
          'Total Closing Stock Value': 'Rs. ${_numFmt.format(totalClosingValue)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ═══════════════════════════════════════════════════════════════════════════
// SALES REPORT PDF
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateSalesIndividualPdf({
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  final subtitle =
      'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  double totalQty = 0;
  double totalRevenue = 0;
  double totalDiscount = 0;

  for (final r in rows) {
    totalQty += (r['qty'] as num?)?.toDouble() ?? 0;
    totalRevenue += (r['lineAmount'] as num?)?.toDouble() ?? 0;
    totalDiscount += (r['discountAmt'] as num?)?.toDouble() ?? 0;
  }

  final columns = [
    'S.No', 'Bill No', 'Date', 'Customer', 'Tag ID',
    'Product', 'Category', 'Qty', 'Unit Price (Rs.)', 'Discount (Rs.)', 'Total (Rs.)', 'Payment'
  ];
  final flexes = [1, 2, 2, 3, 2, 3, 2, 1, 2, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'INDIVIDUAL PRODUCT SALES REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                return _buildTableRow([
                  '${i + 1}',
                  r['billNo']?.toString() ?? '—',
                  r['date']?.toString() ?? '—',
                  r['customerName']?.toString() ?? '—',
                  r['tagId']?.toString() ?? '—',
                  r['productName']?.toString() ?? '—',
                  r['category']?.toString() ?? '—',
                  '${(r['qty'] as num?)?.toInt() ?? 0}',
                  'Rs. ${_numFmt.format((r['price'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['discountAmt'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['lineAmount'] as num?)?.toDouble() ?? 0)}',
                  r['paymentMode']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Line Items': '${rows.length}',
          'Total Qty Sold': '${totalQty.toInt()}',
          'Total Revenue': 'Rs. ${_numFmt.format(totalRevenue)}',
          'Total Discount': 'Rs. ${_numFmt.format(totalDiscount)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

Future<Uint8List> generateSalesTotalPdf({
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  final subtitle =
      'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  double totalDiscount = 0;
  double totalTax = 0;
  double totalPayable = 0;

  for (final r in rows) {
    totalDiscount += (r['discount'] as num?)?.toDouble() ?? 0;
    totalTax += (r['tax'] as num?)?.toDouble() ?? 0;
    totalPayable += (r['totalPayable'] as num?)?.toDouble() ?? 0;
  }

  final columns = [
    'S.No', 'Bill No', 'Date', 'Customer', 'Subtotal (Rs.)',
    'Discount (Rs.)', 'Tax (Rs.)', 'Total Payable (Rs.)', 'Payment Mode', 'Received (Rs.)'
  ];
  final flexes = [1, 2, 2, 3, 2, 2, 2, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'TOTAL SALES REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                return _buildTableRow([
                  '${i + 1}',
                  r['billNo']?.toString() ?? '—',
                  r['date']?.toString() ?? '—',
                  r['customerName']?.toString() ?? '—',
                  'Rs. ${_numFmt.format((r['subtotal'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['discount'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['tax'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['totalPayable'] as num?)?.toDouble() ?? 0)}',
                  r['paymentMode']?.toString() ?? '—',
                  'Rs. ${_numFmt.format((r['amountReceived'] as num?)?.toDouble() ?? 0)}',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Bills': '${rows.length}',
          'Total Revenue': 'Rs. ${_numFmt.format(totalPayable)}',
          'Total Discount': 'Rs. ${_numFmt.format(totalDiscount)}',
          'Total Tax': 'Rs. ${_numFmt.format(totalTax)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ═══════════════════════════════════════════════════════════════════════════
// PRODUCT-WISE SALES SUMMARY PDF
// ═══════════════════════════════════════════════════════════════════════════
Future<Uint8List> generateProductWisePdf({
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
}) async {
  final pdf = pw.Document();
  final boldFont = await _boldFont();
  final regularFont = await _regularFont();
  final logoImage = await _getPdfLogo();

  final subtitle = 'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  int totalQty = 0;
  double totalRevenue = 0;
  double totalDiscount = 0;

  for (final r in rows) {
    totalQty += (r['qty'] as int?) ?? 0;
    totalRevenue += (r['revenue'] as num?)?.toDouble() ?? 0;
    totalDiscount += (r['discount'] as num?)?.toDouble() ?? 0;
  }

  const columns = [
    'S.No', 'Tag ID', 'Product', 'Category',
    'Qty Sold', 'Revenue (Rs.)', 'Discount (Rs.)', 'Avg Price (Rs.)', 'Orders'
  ];
  const flexes = [1, 2, 4, 2, 2, 2, 2, 2, 1];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => _buildFooter(regularFont, context),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'SALES REPORT — Product-wise Summary',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildTableHeader(columns, flexes, boldFont),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                return _buildTableRow([
                  '${i + 1}',
                  r['tagId']?.toString() ?? '—',
                  r['productName']?.toString() ?? '—',
                  r['category']?.toString() ?? '—',
                  r['qty']?.toString() ?? '0',
                  'Rs. ${_numFmt.format((r['revenue'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['discount'] as num?)?.toDouble() ?? 0)}',
                  'Rs. ${_numFmt.format((r['avgPrice'] as num?)?.toDouble() ?? 0)}',
                  r['orders']?.toString() ?? '0',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Unique Products': '${rows.length}',
          'Total Qty Sold': '$totalQty',
          'Total Revenue': 'Rs. ${_numFmt.format(totalRevenue)}',
          'Total Discount': 'Rs. ${_numFmt.format(totalDiscount)}',
        }, boldFont, regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ─── Font Helpers ────────────────────────────────────────────────────────────
pw.Font? _cachedRobotoBold;
pw.Font? _cachedRobotoRegular;

Future<pw.Font> _boldFont() async {
  try {
    _cachedRobotoBold ??= await PdfGoogleFonts.robotoBold();
    return _cachedRobotoBold!;
  } catch (_) {
    return pw.Font.helveticaBold();
  }
}

Future<pw.Font> _regularFont() async {
  try {
    _cachedRobotoRegular ??= await PdfGoogleFonts.robotoRegular();
    return _cachedRobotoRegular!;
  } catch (_) {
    return pw.Font.helvetica();
  }
}
