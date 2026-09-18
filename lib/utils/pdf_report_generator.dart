import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── Theme Constants ────────────────────────────────────────────────────────
const _kBurgundyPdf = PdfColor.fromInt(0xFF8B263E);
const _kTextDark = PdfColor.fromInt(0xFF2C2523);
const _kTextMid = PdfColor.fromInt(0xFF706663);
const _kBgLight = PdfColor.fromInt(0xFFF7F3ED);
const _kBgHeader = PdfColor.fromInt(0xFF8B263E);
const _kBorderColor = PdfColor.fromInt(0xFFE8E2D9);
const _kRowAlt = PdfColor.fromInt(0xFFFAF7F2);
const _kWhite70 = PdfColor(1, 1, 1, 0.7);

const _kCompanyName = 'FORGEALLY BOUTIQUE';
const _kCompanySubtitle = 'High-End Fashion & Custom Couture';
const _kCompanyGstin = 'GSTIN: 33AAAAA0000A1Z5';
const _kCompanyPhone = 'Ph: +91 98765 43210';

final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');
final _dateFmt = DateFormat('dd/MM/yyyy');

// ─── Shared PDF Header Widget ───────────────────────────────────────────────
pw.Widget _buildPdfHeader({
  required String reportTitle,
  required String subtitle,
  required pw.Font boldFont,
  required pw.Font regularFont,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const pw.BoxDecoration(color: _kBgHeader),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _kCompanyName,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    color: PdfColors.white,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _kCompanySubtitle,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 9,
                    color: _kWhite70,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  _kCompanyGstin,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                    color: _kWhite70,
                  ),
                ),
                pw.Text(
                  _kCompanyPhone,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                    color: _kWhite70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: const pw.BoxDecoration(
          color: _kBgLight,
          border: pw.Border(bottom: pw.BorderSide(color: _kBorderColor)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                    color: _kBurgundyPdf,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 9,
                      color: _kTextMid,
                    ),
                  ),
              ],
            ),
            pw.Text(
              'Generated: ${_dateFmt.format(DateTime.now())}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: _kTextMid,
              ),
            ),
          ],
        ),
      ),
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

// ─── Summary Footer ──────────────────────────────────────────────────────────
pw.Widget _buildSummaryBox(
  Map<String, String> summaryFields,
  pw.Font boldFont,
  pw.Font regularFont,
) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _kBgLight,
      border: pw.Border.all(color: _kBorderColor),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Wrap(
      spacing: 24,
      runSpacing: 8,
      children: summaryFields.entries.map((e) {
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '${e.key}: ',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 9,
                color: _kTextMid,
              ),
            ),
            pw.Text(
              e.value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 9,
                color: _kBurgundyPdf,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
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

  final subtitle =
      'Period: ${_dateFmt.format(dateFrom)} → ${_dateFmt.format(dateTo)}';

  double totalRefund = 0;
  for (final r in rows) {
    totalRefund += (r['refundAmount'] as num?)?.toDouble() ?? 0;
  }

  final columns = [
    'S.No', 'Return Bill No', 'Orig. Bill', 'Date',
    'Customer', 'Product', 'Qty', 'Value (₹)', 'Reason', 'Status'
  ];
  final flexes = [1, 2, 2, 2, 3, 3, 1, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'ISSUE / RETURN REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
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
                  '₹${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}',
                  r['reason']?.toString() ?? '—',
                  r['status']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Returns': '${rows.length}',
          'Total Refund': '₹${_numFmt.format(totalRefund)}',
        }, boldFont, regularFont),
        pw.SizedBox(height: 8),
        _buildFooter(regularFont),
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

  double totalStockValue = 0;
  int totalQty = 0;
  int lowStockCount = 0;

  for (final r in rows) {
    final qty = (r['quantity'] as num?)?.toInt() ?? 0;
    final price = (r['sellingPrice'] as num?)?.toDouble() ?? 0;
    totalStockValue += qty * price;
    totalQty += qty;
    final status = r['status']?.toString() ?? '';
    if (status == 'Low Stock') lowStockCount++;
  }

  final filters = [
    if (categoryFilter != 'All') 'Category: $categoryFilter',
    if (statusFilter != 'All') 'Status: $statusFilter',
  ].join(' | ');

  final columns = [
    'S.No', 'Tag ID', 'Product Name', 'Category', 'Type',
    'Qty', 'Unit', 'MRP (₹)', 'Sell Price (₹)', 'Stock Value (₹)', 'Status'
  ];
  final flexes = [1, 2, 4, 2, 2, 1, 1, 2, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'STOCK REPORT',
          subtitle: filters.isNotEmpty ? filters : 'All Categories • All Status',
          boldFont: boldFont,
          regularFont: regularFont,
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
                final qty = (r['quantity'] as num?)?.toInt() ?? 0;
                final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0;
                return _buildTableRow([
                  '${i + 1}',
                  r['tagId']?.toString() ?? '—',
                  r['name']?.toString() ?? '—',
                  r['category']?.toString() ?? '—',
                  r['pricingType']?.toString() ?? '—',
                  '$qty',
                  r['unit']?.toString() ?? '—',
                  '₹${_numFmt.format((r['mrp'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format(sp)}',
                  '₹${_numFmt.format(qty * sp)}',
                  r['status']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Products': '${rows.length}',
          'Total Qty': '$totalQty',
          'Total Stock Value': '₹${_numFmt.format(totalStockValue)}',
          'Low Stock Items': '$lowStockCount',
        }, boldFont, regularFont),
        pw.SizedBox(height: 8),
        _buildFooter(regularFont),
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
    'Product', 'Category', 'Qty', 'Unit Price (₹)', 'Discount (₹)', 'Total (₹)', 'Payment'
  ];
  final flexes = [1, 2, 2, 3, 2, 3, 2, 1, 2, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'INDIVIDUAL PRODUCT SALES REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
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
                  '₹${_numFmt.format((r['price'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format((r['discountAmt'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format((r['lineAmount'] as num?)?.toDouble() ?? 0)}',
                  r['paymentMode']?.toString() ?? '—',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Line Items': '${rows.length}',
          'Total Qty Sold': '${totalQty.toInt()}',
          'Total Revenue': '₹${_numFmt.format(totalRevenue)}',
          'Total Discount': '₹${_numFmt.format(totalDiscount)}',
        }, boldFont, regularFont),
        pw.SizedBox(height: 8),
        _buildFooter(regularFont),
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
    'S.No', 'Bill No', 'Date', 'Customer', 'Subtotal (₹)',
    'Discount (₹)', 'Tax (₹)', 'Total Payable (₹)', 'Payment Mode', 'Received (₹)'
  ];
  final flexes = [1, 2, 2, 3, 2, 2, 2, 2, 2, 2];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        _buildPdfHeader(
          reportTitle: 'TOTAL SALES REPORT',
          subtitle: subtitle,
          boldFont: boldFont,
          regularFont: regularFont,
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
                  '₹${_numFmt.format((r['subtotal'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format((r['discount'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format((r['tax'] as num?)?.toDouble() ?? 0)}',
                  '₹${_numFmt.format((r['totalPayable'] as num?)?.toDouble() ?? 0)}',
                  r['paymentMode']?.toString() ?? '—',
                  '₹${_numFmt.format((r['amountReceived'] as num?)?.toDouble() ?? 0)}',
                ], flexes, regularFont, i.isOdd);
              }),
            ],
          ),
        ),
        _buildSummaryBox({
          'Total Bills': '${rows.length}',
          'Total Revenue': '₹${_numFmt.format(totalPayable)}',
          'Total Discount': '₹${_numFmt.format(totalDiscount)}',
          'Total Tax': '₹${_numFmt.format(totalTax)}',
        }, boldFont, regularFont),
        pw.SizedBox(height: 8),
        _buildFooter(regularFont),
      ],
    ),
  );

  return pdf.save();
}

// ─── Footer ─────────────────────────────────────────────────────────────────
pw.Widget _buildFooter(pw.Font regularFont) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kBorderColor)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '$_kCompanyName • Confidential Report',
          style: pw.TextStyle(font: regularFont, fontSize: 7, color: _kTextMid),
        ),
        pw.Text(
          'This is a computer-generated report. No signature required.',
          style: pw.TextStyle(font: regularFont, fontSize: 7, color: _kTextMid),
        ),
      ],
    ),
  );
}

// ─── Font Helpers ────────────────────────────────────────────────────────────
Future<pw.Font> _boldFont() async => pw.Font.helveticaBold();
Future<pw.Font> _regularFont() async => pw.Font.helvetica();
