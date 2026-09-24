import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/vendor_issue.dart';
import 'file_downloader.dart';

class ExcelGenerator {
  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _dateTimeFmt = DateFormat('dd/MM/yyyy hh:mm a');

  /// Generate & download Inward Bill for a single or multiple products
  static Future<void> downloadInwardBillExcel({
    required List<Product> products,
    String? vendorName,
    String? inwardRefNo,
  }) async {
    final bytes = generateInwardBillBytes(
      products: products,
      vendorName: vendorName,
      inwardRefNo: inwardRefNo,
    );
    final ref = inwardRefNo ?? 'INW_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await downloadFile(
      bytes,
      'Inward_Bill_$ref.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate bytes for Inward Bill Excel (Compact, fit-to-screen layout)
  static List<int> generateInwardBillBytes({
    required List<Product> products,
    String? vendorName,
    String? inwardRefNo,
  }) {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Inward Bill';

    final ref = inwardRefNo ?? 'INW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final nowStr = _dateTimeFmt.format(DateTime.now());
    final resolvedVendor = vendorName ?? (products.isNotEmpty ? products.first.vendor : '');

    // ── Row 1: Title Banner ──────────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:K1');
    titleRange.merge();
    titleRange.setText('STOCK INWARD BILL');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A3B22';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 2: Compact Metadata (3 Merged Blocks) ────────────────────────────
    final metaRef = sheet.getRangeByName('A2:C2');
    metaRef.merge();
    metaRef.setText('Inward No: $ref');
    metaRef.cellStyle.bold = true;
    metaRef.cellStyle.fontSize = 10;
    metaRef.cellStyle.backColor = '#F5ECE4';
    metaRef.cellStyle.vAlign = VAlignType.center;

    final metaDate = sheet.getRangeByName('D2:G2');
    metaDate.merge();
    metaDate.setText('Date: $nowStr');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#F5ECE4';
    metaDate.cellStyle.hAlign = HAlignType.center;
    metaDate.cellStyle.vAlign = VAlignType.center;

    final metaVendor = sheet.getRangeByName('H2:K2');
    metaVendor.merge();
    metaVendor.setText('Vendor: ${resolvedVendor.isNotEmpty ? resolvedVendor : 'General Supplier'}');
    metaVendor.cellStyle.bold = true;
    metaVendor.cellStyle.fontSize = 10;
    metaVendor.cellStyle.backColor = '#F5ECE4';
    metaVendor.cellStyle.hAlign = HAlignType.right;
    metaVendor.cellStyle.vAlign = VAlignType.center;

    // ── Row 3: Column Headers ────────────────────────────────────────────────
    final headers = [
      'S.No',
      'Tag ID',
      'Item Name',
      'Category',
      'Type',
      'Qty',
      'Unit',
      'Weight',
      'Price (₹)',
      'Total (₹)',
      'Vendor',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = col == 0 || col == 1 || col == 4 || col == 5 || col == 6 || col == 7
          ? HAlignType.center
          : (col == 8 || col == 9 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    // ── Rows 4+: Items Data ──────────────────────────────────────────────────
    int rowIndex = 4;
    int totalQty = 0;
    double totalValue = 0.0;

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final isWeightBased = p.pricingType == 'Weight-Based';
      final price = isWeightBased ? p.ratePerGram : (p.finalPrice > 0 ? p.finalPrice : p.mrp);
      final lineVal = isWeightBased 
          ? (p.grossWeight > 0 ? p.grossWeight * price : p.quantity * price)
          : (p.quantity * price);

      totalQty += p.quantity;
      totalValue += lineVal;

      final c1 = sheet.getRangeByIndex(rowIndex, 1);
      c1.setNumber((i + 1).toDouble());
      c1.cellStyle.hAlign = HAlignType.center;

      final c2 = sheet.getRangeByIndex(rowIndex, 2);
      c2.setText(p.tagId);
      c2.cellStyle.hAlign = HAlignType.center;
      c2.cellStyle.bold = true;

      final c3 = sheet.getRangeByIndex(rowIndex, 3);
      c3.setText(p.name);
      c3.cellStyle.hAlign = HAlignType.left;

      final c4 = sheet.getRangeByIndex(rowIndex, 4);
      c4.setText(p.category);
      c4.cellStyle.hAlign = HAlignType.left;

      final c5 = sheet.getRangeByIndex(rowIndex, 5);
      c5.setText(isWeightBased ? 'Weight' : 'Qty');
      c5.cellStyle.hAlign = HAlignType.center;

      final c6 = sheet.getRangeByIndex(rowIndex, 6);
      c6.setNumber(p.quantity.toDouble());
      c6.cellStyle.hAlign = HAlignType.center;

      final c7 = sheet.getRangeByIndex(rowIndex, 7);
      c7.setText(p.unit);
      c7.cellStyle.hAlign = HAlignType.center;

      final c8 = sheet.getRangeByIndex(rowIndex, 8);
      c8.setText(isWeightBased ? '${p.grossWeight} ${p.weightUnit}' : '—');
      c8.cellStyle.hAlign = HAlignType.center;

      final c9 = sheet.getRangeByIndex(rowIndex, 9);
      c9.setNumber(price);
      c9.cellStyle.hAlign = HAlignType.right;

      final c10 = sheet.getRangeByIndex(rowIndex, 10);
      c10.setNumber(lineVal);
      c10.cellStyle.hAlign = HAlignType.right;
      c10.cellStyle.bold = true;

      final c11 = sheet.getRangeByIndex(rowIndex, 11);
      c11.setText(p.vendor.isNotEmpty ? p.vendor : (p.notes.isNotEmpty ? p.notes : '—'));
      c11.cellStyle.hAlign = HAlignType.left;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 11).cellStyle.backColor = '#FAF6F0';
      }

      rowIndex++;
    }

    // ── Summary / Total Row ──────────────────────────────────────────────────
    final totalLabelRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 5);
    totalLabelRange.merge();
    totalLabelRange.setText('TOTAL');
    totalLabelRange.cellStyle.bold = true;
    totalLabelRange.cellStyle.hAlign = HAlignType.right;

    final totalQtyCell = sheet.getRangeByIndex(rowIndex, 6);
    totalQtyCell.setNumber(totalQty.toDouble());
    totalQtyCell.cellStyle.bold = true;
    totalQtyCell.cellStyle.hAlign = HAlignType.center;

    final totalValCell = sheet.getRangeByIndex(rowIndex, 10);
    totalValCell.setNumber(totalValue);
    totalValCell.cellStyle.bold = true;
    totalValCell.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 11).cellStyle.backColor = '#EAD8C7';

    // ── Compact Explicit Column Widths (Fit completely on standard screen) ────
    sheet.getRangeByIndex(1, 1).columnWidth = 5.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 11.5;  // Tag ID
    sheet.getRangeByIndex(1, 3).columnWidth = 18.0;  // Item Name
    sheet.getRangeByIndex(1, 4).columnWidth = 13.0;  // Category
    sheet.getRangeByIndex(1, 5).columnWidth = 7.5;   // Type
    sheet.getRangeByIndex(1, 6).columnWidth = 6.5;   // Qty
    sheet.getRangeByIndex(1, 7).columnWidth = 6.5;   // Unit
    sheet.getRangeByIndex(1, 8).columnWidth = 9.5;   // Weight
    sheet.getRangeByIndex(1, 9).columnWidth = 11.0;  // Price (₹)
    sheet.getRangeByIndex(1, 10).columnWidth = 12.5; // Total (₹)
    sheet.getRangeByIndex(1, 11).columnWidth = 14.0; // Vendor

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  /// Generate & download Issue Bill for a single vendor issue
  static Future<void> downloadVendorIssueBillExcel({
    required VendorIssue issue,
  }) async {
    final bytes = generateVendorIssueBillBytes(issue: issue);
    final ref = issue.id.isNotEmpty ? issue.id : 'ISS_${issue.tagId}';
    await downloadFile(
      bytes,
      'Issue_Bill_$ref.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate bytes for Vendor Issue Bill Excel (Compact layout)
  static List<int> generateVendorIssueBillBytes({
    required VendorIssue issue,
  }) {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Issue Bill';

    final ref = issue.id.isNotEmpty ? issue.id : 'ISS-${issue.tagId}-${issue.dateReported.millisecondsSinceEpoch.toString().substring(7)}';

    // ── Row 1: Header / Title ───────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:H1');
    titleRange.merge();
    titleRange.setText('VENDOR ISSUE BILL / RETURN SLIP');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#8A252C';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 2: Compact Meta ────────────────────────────────────────────────
    final metaRef = sheet.getRangeByName('A2:C2');
    metaRef.merge();
    metaRef.setText('Issue Ref: $ref');
    metaRef.cellStyle.bold = true;
    metaRef.cellStyle.fontSize = 10;
    metaRef.cellStyle.backColor = '#FBEAEB';

    final metaDate = sheet.getRangeByName('D2:E2');
    metaDate.merge();
    metaDate.setText('Date: ${_fmt.format(issue.dateReported)}');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#FBEAEB';
    metaDate.cellStyle.hAlign = HAlignType.center;

    final metaVendor = sheet.getRangeByName('F2:H2');
    metaVendor.merge();
    metaVendor.setText('Vendor: ${issue.vendor.isNotEmpty ? issue.vendor : '—'}');
    metaVendor.cellStyle.bold = true;
    metaVendor.cellStyle.fontSize = 10;
    metaVendor.cellStyle.backColor = '#FBEAEB';
    metaVendor.cellStyle.hAlign = HAlignType.right;

    // ── Row 3: Column Headers ──────────────────────────────────────────────
    final headers = [
      'S.No',
      'Tag ID',
      'Product Name',
      'Vendor',
      'Qty Affected',
      'Issue Type',
      'Action Taken',
      'Refund (₹)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#A93B42';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = col == 0 || col == 1 || col == 4 ? HAlignType.center : (col == 7 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    // ── Row 4: Single Issue Details ────────────────────────────────────────
    final c1 = sheet.getRangeByIndex(4, 1);
    c1.setNumber(1.0);
    c1.cellStyle.hAlign = HAlignType.center;

    final c2 = sheet.getRangeByIndex(4, 2);
    c2.setText(issue.tagId);
    c2.cellStyle.hAlign = HAlignType.center;
    c2.cellStyle.bold = true;

    final c3 = sheet.getRangeByIndex(4, 3);
    c3.setText(issue.productName);
    c3.cellStyle.hAlign = HAlignType.left;

    final c4 = sheet.getRangeByIndex(4, 4);
    c4.setText(issue.vendor.isNotEmpty ? issue.vendor : '—');
    c4.cellStyle.hAlign = HAlignType.left;

    final c5 = sheet.getRangeByIndex(4, 5);
    c5.setNumber(issue.quantity.toDouble());
    c5.cellStyle.hAlign = HAlignType.center;

    final c6 = sheet.getRangeByIndex(4, 6);
    c6.setText(issue.issueType);
    c6.cellStyle.hAlign = HAlignType.left;

    final c7 = sheet.getRangeByIndex(4, 7);
    c7.setText(issue.actionTaken);
    c7.cellStyle.hAlign = HAlignType.left;

    final c8 = sheet.getRangeByIndex(4, 8);
    c8.setNumber(issue.refundAmount);
    c8.cellStyle.hAlign = HAlignType.right;
    c8.cellStyle.bold = true;

    // ── Row 6: Signatures / Acknowledgement ────────────────────────────────
    final signAuth = sheet.getRangeByName('A6:D6');
    signAuth.merge();
    signAuth.setText('Authorized Signature: __________________');
    signAuth.cellStyle.bold = true;
    signAuth.cellStyle.fontSize = 10;

    final signVendor = sheet.getRangeByName('E6:H6');
    signVendor.merge();
    signVendor.setText('Vendor Acknowledgement: __________________');
    signVendor.cellStyle.bold = true;
    signVendor.cellStyle.fontSize = 10;
    signVendor.cellStyle.hAlign = HAlignType.right;

    // ── Compact Explicit Column Widths ──────────────────────────────────────
    sheet.getRangeByIndex(1, 1).columnWidth = 5.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 12.0;  // Tag ID
    sheet.getRangeByIndex(1, 3).columnWidth = 20.0;  // Product Name
    sheet.getRangeByIndex(1, 4).columnWidth = 15.0;  // Vendor
    sheet.getRangeByIndex(1, 5).columnWidth = 9.0;   // Qty
    sheet.getRangeByIndex(1, 6).columnWidth = 14.0;  // Issue Type
    sheet.getRangeByIndex(1, 7).columnWidth = 15.0;  // Action Taken
    sheet.getRangeByIndex(1, 8).columnWidth = 12.5;  // Refund (₹)

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  /// Generate & download Bulk Issue Report Excel (for issue_report_screen / vendor_issue_tab)
  static Future<void> downloadIssueReportExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime dateFrom,
    required DateTime dateTo,
    String filterType = 'All',
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Issues & Returns';

    // ── Row 1: Title ────────────────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:I1');
    titleRange.merge();
    titleRange.setText('ISSUE & RETURN REGISTER');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A3B22';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 2: Compact Meta ────────────────────────────────────────────────
    final metaPeriod = sheet.getRangeByName('A2:C2');
    metaPeriod.merge();
    metaPeriod.setText('Period: ${_fmt.format(dateFrom)} to ${_fmt.format(dateTo)}');
    metaPeriod.cellStyle.bold = true;
    metaPeriod.cellStyle.fontSize = 10;
    metaPeriod.cellStyle.backColor = '#F5ECE4';

    final metaFilter = sheet.getRangeByName('D2:F2');
    metaFilter.merge();
    metaFilter.setText('Filter: $filterType');
    metaFilter.cellStyle.bold = true;
    metaFilter.cellStyle.fontSize = 10;
    metaFilter.cellStyle.backColor = '#F5ECE4';
    metaFilter.cellStyle.hAlign = HAlignType.center;

    final metaGen = sheet.getRangeByName('G2:I2');
    metaGen.merge();
    metaGen.setText('Generated: ${_dateTimeFmt.format(DateTime.now())}');
    metaGen.cellStyle.bold = true;
    metaGen.cellStyle.fontSize = 10;
    metaGen.cellStyle.backColor = '#F5ECE4';
    metaGen.cellStyle.hAlign = HAlignType.right;

    // ── Row 3: Headers ──────────────────────────────────────────────────────
    final headers = [
      'S.No',
      'Date',
      'Type',
      'Product / Tag ID',
      'Customer / Vendor',
      'Qty',
      'Reason / Issue',
      'Status / Action',
      'Refund (₹)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = col == 0 || col == 1 || col == 2 || col == 5 ? HAlignType.center : (col == 8 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    int rowIndex = 4;
    int totalQty = 0;
    double totalRefund = 0.0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final qty = (r['qty'] as num?)?.toInt() ?? 0;
      final refund = (r['refundAmount'] as num?)?.toDouble() ?? 0.0;
      totalQty += qty;
      totalRefund += refund;

      final c1 = sheet.getRangeByIndex(rowIndex, 1);
      c1.setNumber((i + 1).toDouble());
      c1.cellStyle.hAlign = HAlignType.center;

      final c2 = sheet.getRangeByIndex(rowIndex, 2);
      c2.setText(r['date']?.toString() ?? '');
      c2.cellStyle.hAlign = HAlignType.center;

      final c3 = sheet.getRangeByIndex(rowIndex, 3);
      c3.setText(r['_type']?.toString() ?? 'Vendor Issue');
      c3.cellStyle.hAlign = HAlignType.center;

      final c4 = sheet.getRangeByIndex(rowIndex, 4);
      c4.setText(r['productName']?.toString() ?? '');
      c4.cellStyle.hAlign = HAlignType.left;

      final c5 = sheet.getRangeByIndex(rowIndex, 5);
      c5.setText(r['counterpart']?.toString() ?? (r['vendor']?.toString() ?? '—'));
      c5.cellStyle.hAlign = HAlignType.left;

      final c6 = sheet.getRangeByIndex(rowIndex, 6);
      c6.setNumber(qty.toDouble());
      c6.cellStyle.hAlign = HAlignType.center;

      final c7 = sheet.getRangeByIndex(rowIndex, 7);
      c7.setText(r['issueReason']?.toString() ?? (r['issueType']?.toString() ?? '—'));
      c7.cellStyle.hAlign = HAlignType.left;

      final c8 = sheet.getRangeByIndex(rowIndex, 8);
      c8.setText(r['actionTaken']?.toString() ?? (r['status']?.toString() ?? '—'));
      c8.cellStyle.hAlign = HAlignType.left;

      final c9 = sheet.getRangeByIndex(rowIndex, 9);
      c9.setNumber(refund);
      c9.cellStyle.hAlign = HAlignType.right;
      c9.cellStyle.bold = true;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 9).cellStyle.backColor = '#FAF6F0';
      }
      rowIndex++;
    }

    // ── Summary Row ─────────────────────────────────────────────────────────
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 5);
    totalRange.merge();
    totalRange.setText('TOTAL');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    final totalQtyCell = sheet.getRangeByIndex(rowIndex, 6);
    totalQtyCell.setNumber(totalQty.toDouble());
    totalQtyCell.cellStyle.bold = true;
    totalQtyCell.cellStyle.hAlign = HAlignType.center;

    final totalRefundCell = sheet.getRangeByIndex(rowIndex, 9);
    totalRefundCell.setNumber(totalRefund);
    totalRefundCell.cellStyle.bold = true;
    totalRefundCell.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 9).cellStyle.backColor = '#EAD8C7';

    // ── Compact Explicit Column Widths ──────────────────────────────────────
    sheet.getRangeByIndex(1, 1).columnWidth = 5.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 11.0;  // Date
    sheet.getRangeByIndex(1, 3).columnWidth = 14.0;  // Type
    sheet.getRangeByIndex(1, 4).columnWidth = 18.0;  // Product / Tag ID
    sheet.getRangeByIndex(1, 5).columnWidth = 15.0;  // Customer / Vendor
    sheet.getRangeByIndex(1, 6).columnWidth = 6.0;   // Qty
    sheet.getRangeByIndex(1, 7).columnWidth = 15.0;  // Reason
    sheet.getRangeByIndex(1, 8).columnWidth = 14.0;  // Status / Action
    sheet.getRangeByIndex(1, 9).columnWidth = 12.0;  // Refund (₹)

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'Issue_Report_${_fmt.format(dateFrom)}_${_fmt.format(dateTo)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
