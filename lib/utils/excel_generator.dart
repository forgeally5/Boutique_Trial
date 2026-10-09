import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/vendor_issue.dart';
import 'file_downloader.dart';

class ExcelGenerator {
  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _dateTimeFmt = DateFormat('dd/MM/yyyy hh:mm a');

  /// Generate & download Inward Bill for a single or multiple products
  static Future<void> downloadInwardReportExcel({
    required List<Map<String, dynamic>> transactions,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Inward Report';

    final nowStr = _dateTimeFmt.format(DateTime.now());

    // ── Title Banner ──────────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:G1');
    titleRange.merge();
    titleRange.setText('INWARD TRANSACTIONS REPORT');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A3B22';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Metadata ────────────────────────────────────────────────────
    final metaDate = sheet.getRangeByName('A2:G2');
    metaDate.merge();
    metaDate.setText('Generated on: $nowStr');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#F5ECE4';
    metaDate.cellStyle.hAlign = HAlignType.left;
    metaDate.cellStyle.vAlign = VAlignType.center;

    // ── Headers ────────────────────────────────────────────────
    final headers = [
      'Date & Time',
      'Item Name',
      'Tag ID',
      'Category',
      'Added Qty',
      'Added Weight',
      'Total Value (₹)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = col == 0 || col == 2 || col >= 4 ? HAlignType.center : HAlignType.left;
      cell.cellStyle.vAlign = VAlignType.center;
    }

    // ── Data ──────────────────────────────────────────────────
    int rowIndex = 4;
    double grandTotal = 0.0;
    int totalItems = 0;

    for (final bill in transactions) {
      final bDate = DateTime.tryParse(bill['billDate'] ?? '') ?? DateTime.now();
      final dateStr = _dateTimeFmt.format(bDate);
      final items = bill['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final isQty = item['pricingType'] == 'Quantity-Based';
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
        final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;

        grandTotal += amt;
        totalItems++;

        sheet.getRangeByIndex(rowIndex, 1).setText(dateStr);
        sheet.getRangeByIndex(rowIndex, 2).setText(item['name']?.toString() ?? '');
        sheet.getRangeByIndex(rowIndex, 3).setText(item['tagId']?.toString() ?? '');
        sheet.getRangeByIndex(rowIndex, 4).setText(item['category']?.toString() ?? '');
        
        final c5 = sheet.getRangeByIndex(rowIndex, 5);
        c5.setNumber(qty.toDouble());
        c5.cellStyle.hAlign = HAlignType.center;

        final c6 = sheet.getRangeByIndex(rowIndex, 6);
        c6.setNumber(weight);
        c6.cellStyle.hAlign = HAlignType.center;

        final c7 = sheet.getRangeByIndex(rowIndex, 7);
        c7.setNumber(amt);
        c7.cellStyle.hAlign = HAlignType.right;

        rowIndex++;
      }
    }

    // ── Footer ──────────────────────────────────────────────────
    final footerLabel = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6);
    footerLabel.merge();
    footerLabel.setText('TOTAL (Items: $totalItems)');
    footerLabel.cellStyle.bold = true;
    footerLabel.cellStyle.hAlign = HAlignType.right;

    final footerTotal = sheet.getRangeByIndex(rowIndex, 7);
    footerTotal.setNumber(grandTotal);
    footerTotal.cellStyle.bold = true;
    footerTotal.cellStyle.hAlign = HAlignType.right;

    // Auto-fit columns
    for (int i = 1; i <= 7; i++) {
      sheet.autoFitColumn(i);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'Inward_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

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

  /// Generate & download Category-Wise Closing Stock Report Excel
  static Future<void> downloadCategoryClosingStockExcel({
    required List<Map<String, dynamic>> rows,
    String statusFilter = 'All',
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Closing Stock Category-Wise';

    // Title Banner
    final titleRange = sheet.getRangeByName('A1:J1');
    titleRange.merge();
    titleRange.setText('CLOSING STOCK REPORT — CATEGORY WISE');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // Metadata
    final metaFilter = sheet.getRangeByName('A2:E2');
    metaFilter.merge();
    metaFilter.setText(
      statusFilter != 'All'
          ? 'Category Closing Summary (Filter: $statusFilter)'
          : 'Category Closing Stock Statement (All Categories)',
    );
    metaFilter.cellStyle.bold = true;
    metaFilter.cellStyle.fontSize = 10;
    metaFilter.cellStyle.backColor = '#FDFBF7';
    metaFilter.cellStyle.vAlign = VAlignType.center;

    final metaDate = sheet.getRangeByName('F2:J2');
    metaDate.merge();
    metaDate.setText('Generated: ${_dateTimeFmt.format(DateTime.now())}');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#FDFBF7';
    metaDate.cellStyle.hAlign = HAlignType.right;
    metaDate.cellStyle.vAlign = VAlignType.center;

    // Headers
    final headers = [
      'S.No',
      'Category Name',
      'Total Items (SKUs)',
      'Purchased Qty',
      'Issued Qty',
      'Sold Qty',
      'Closing Stock Qty',
      'Closing Value (Rs.)',
      'Stock Share (%)',
      'Status',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8B263E';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign =
          (col == 0 || col >= 2 && col <= 6 || col == 8 || col == 9)
              ? HAlignType.center
              : (col == 7 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    int rowIndex = 4;
    int totalSkus = 0;
    int totalPurchased = 0;
    int totalIssued = 0;
    int totalSold = 0;
    int totalClosingQty = 0;
    double totalClosingValue = 0.0;

    for (final r in rows) {
      totalClosingValue += (r['closingValue'] as num?)?.toDouble() ?? 0.0;
    }

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final skus = (r['skuCount'] as num?)?.toInt() ?? 0;
      final purchased = (r['totalPurchased'] as num?)?.toInt() ?? 0;
      final issued = (r['totalIssued'] as num?)?.toInt() ?? 0;
      final sold = (r['totalSold'] as num?)?.toInt() ?? 0;
      final closing = (r['closingQty'] as num?)?.toInt() ?? 0;
      final val = (r['closingValue'] as num?)?.toDouble() ?? 0.0;
      final share = totalClosingValue > 0
          ? (val / totalClosingValue) * 100
          : 0.0;

      totalSkus += skus;
      totalPurchased += purchased;
      totalIssued += issued;
      totalSold += sold;
      totalClosingQty += closing;

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet
          .getRangeByIndex(rowIndex, 2)
          .setText(r['category']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.left;

      sheet.getRangeByIndex(rowIndex, 3).setNumber(skus.toDouble());
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 4).setNumber(purchased.toDouble());
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(issued.toDouble());
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(sold.toDouble());
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 7).setNumber(closing.toDouble());
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;

      sheet.getRangeByIndex(rowIndex, 8).setNumber(val);
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 9)
          .setText('${share.toStringAsFixed(1)}%');
      sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

      sheet
          .getRangeByIndex(rowIndex, 10)
          .setText(r['status']?.toString() ?? 'In Stock');
      sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.center;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 10).cellStyle.backColor =
            '#FAF7F2';
      }
      rowIndex++;
    }

    // Grand Total Row
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 2);
    totalRange.merge();
    totalRange.setText('GRAND TOTAL');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 3).setNumber(totalSkus.toDouble());
    sheet.getRangeByIndex(rowIndex, 3).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 4).setNumber(totalPurchased.toDouble());
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 5).setNumber(totalIssued.toDouble());
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 6).setNumber(totalSold.toDouble());
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 7).setNumber(totalClosingQty.toDouble());
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 8).setNumber(totalClosingValue);
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 9).setText('100.0%');
    sheet.getRangeByIndex(rowIndex, 9).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 10).cellStyle.backColor =
        '#F0E5D8';

    // Column widths
    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;
    sheet.getRangeByIndex(1, 2).columnWidth = 24.0;
    sheet.getRangeByIndex(1, 3).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 4).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 5).columnWidth = 12.0;
    sheet.getRangeByIndex(1, 6).columnWidth = 12.0;
    sheet.getRangeByIndex(1, 7).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 8).columnWidth = 18.0;
    sheet.getRangeByIndex(1, 9).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 10).columnWidth = 14.0;

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'closing_stock_category_wise_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Product-Wise Stock Report Excel
  static Future<void> downloadProductStockReportExcel({
    required List<Map<String, dynamic>> rows,
    String categoryFilter = 'All',
    String statusFilter = 'All',
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Stock Report';

    final titleRange = sheet.getRangeByName('A1:L1');
    titleRange.merge();
    titleRange.setText('PRODUCT-WISE STOCK REPORT');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    final metaRange = sheet.getRangeByName('A2:F2');
    metaRange.merge();
    metaRange.setText(
      'Category: $categoryFilter • Status: $statusFilter',
    );
    metaRange.cellStyle.bold = true;
    metaRange.cellStyle.fontSize = 10;
    metaRange.cellStyle.backColor = '#FDFBF7';
    metaRange.cellStyle.vAlign = VAlignType.center;

    final metaDate = sheet.getRangeByName('G2:L2');
    metaDate.merge();
    metaDate.setText('Generated: ${_dateTimeFmt.format(DateTime.now())}');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#FDFBF7';
    metaDate.cellStyle.hAlign = HAlignType.right;
    metaDate.cellStyle.vAlign = VAlignType.center;

    final headers = [
      'S.No',
      'Tag ID',
      'Product Name',
      'Category',
      'Total Recv',
      'Issued',
      'Sold',
      'Stock Balance',
      'Unit',
      'Sell Price (Rs.)',
      'Stock Value (Rs.)',
      'Status',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8B263E';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign =
          (col == 0 || col == 1 || col >= 4 && col <= 8 || col == 11)
              ? HAlignType.center
              : (col == 9 || col == 10 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    int rowIndex = 4;
    int totalBalance = 0;
    double totalStockVal = 0.0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final pricingType = r['pricingType']?.toString() ?? 'Quantity-Based';
      final grossWeight = (r['grossWeight'] as num?)?.toDouble() ?? 0.0;
      final ratePerGram = (r['ratePerGram'] as num?)?.toDouble() ?? 0.0;
      final weightUnit = r['weightUnit']?.toString() ?? 'g';

      final balance =
          (r['balance'] as num?)?.toInt() ??
          (r['quantity'] as num?)?.toInt() ??
          0;
      final totalRec = (r['totalReceived'] as num?)?.toInt() ?? 0;
      final issue = (r['issueQty'] as num?)?.toInt() ?? 0;
      final sold = (r['soldQty'] as num?)?.toInt() ?? 0;
      final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      
      final displaySp = pricingType == 'Weight-Based' ? ratePerGram : sp;
      final stockVal = pricingType == 'Weight-Based' ? (grossWeight * ratePerGram) : (balance * sp);

      totalBalance += balance;
      totalStockVal += stockVal;
      
      String balanceStr = balance.toString();
      if (pricingType == 'Weight-Based' && grossWeight > 0) {
        balanceStr = '${grossWeight.toStringAsFixed(2)}$weightUnit ($balance pc)';
      }

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet
          .getRangeByIndex(rowIndex, 2)
          .setText(r['tagId']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 3)
          .setText(r['name']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.left;

      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(r['category']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.left;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(totalRec.toDouble());
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(issue.toDouble());
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 7).setNumber(sold.toDouble());
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 8).setText(balanceStr);
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 9)
          .setText(r['unit']?.toString() ?? 'Piece');
      sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 10).setNumber(displaySp);
      sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 11).setNumber(stockVal);
      sheet.getRangeByIndex(rowIndex, 11).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 11).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 12)
          .setText(r['status']?.toString() ?? 'In Stock');
      sheet.getRangeByIndex(rowIndex, 12).cellStyle.hAlign = HAlignType.center;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.backColor =
            '#FAF7F2';
      }
      rowIndex++;
    }

    // Total Row
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7);
    totalRange.merge();
    totalRange.setText('TOTAL');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 8).setNumber(totalBalance.toDouble());
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 11).setNumber(totalStockVal);
    sheet.getRangeByIndex(rowIndex, 11).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 11).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.backColor =
        '#F0E5D8';

    // Widths
    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;
    sheet.getRangeByIndex(1, 2).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 3).columnWidth = 24.0;
    sheet.getRangeByIndex(1, 4).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 5).columnWidth = 12.0;
    sheet.getRangeByIndex(1, 6).columnWidth = 10.0;
    sheet.getRangeByIndex(1, 7).columnWidth = 10.0;
    sheet.getRangeByIndex(1, 8).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 9).columnWidth = 10.0;
    sheet.getRangeByIndex(1, 10).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 11).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 12).columnWidth = 12.0;

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'stock_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Bill-Wise Sales Report Excel
  static Future<void> downloadBillWiseSalesExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Sales Register';

    final titleRange = sheet.getRangeByName('A1:J1');
    titleRange.merge();
    titleRange.setText('SALES REPORT — BILL-WISE REGISTER');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    final metaPeriod = sheet.getRangeByName('A2:E2');
    metaPeriod.merge();
    metaPeriod.setText(
      'Period: ${_fmt.format(dateFrom)} to ${_fmt.format(dateTo)}',
    );
    metaPeriod.cellStyle.bold = true;
    metaPeriod.cellStyle.fontSize = 10;
    metaPeriod.cellStyle.backColor = '#FDFBF7';

    final metaGen = sheet.getRangeByName('F2:J2');
    metaGen.merge();
    metaGen.setText('Generated: ${_dateTimeFmt.format(DateTime.now())}');
    metaGen.cellStyle.bold = true;
    metaGen.cellStyle.fontSize = 10;
    metaGen.cellStyle.backColor = '#FDFBF7';
    metaGen.cellStyle.hAlign = HAlignType.right;

    final headers = [
      'S.No',
      'Bill No',
      'Date',
      'Customer',
      'Subtotal (Rs.)',
      'Discount (Rs.)',
      'Tax (Rs.)',
      'Total Payable (Rs.)',
      'Payment Mode',
      'Received (Rs.)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8B263E';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = (col == 0 || col == 1 || col == 2 || col == 8)
          ? HAlignType.center
          : (col >= 4 && col <= 7 || col == 9
              ? HAlignType.right
              : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    int rowIndex = 4;
    double totalSub = 0.0;
    double totalDisc = 0.0;
    double totalTax = 0.0;
    double totalPay = 0.0;
    double totalRec = 0.0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final sub = (r['subtotal'] as num?)?.toDouble() ?? 0.0;
      final disc = (r['discount'] as num?)?.toDouble() ?? 0.0;
      final tax = (r['tax'] as num?)?.toDouble() ?? 0.0;
      final pay = (r['totalPayable'] as num?)?.toDouble() ?? 0.0;
      final rec = (r['amountReceived'] as num?)?.toDouble() ?? 0.0;

      totalSub += sub;
      totalDisc += disc;
      totalTax += tax;
      totalPay += pay;
      totalRec += rec;

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 2).setText(r['billNo']?.toString() ?? '');
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;

      sheet.getRangeByIndex(rowIndex, 3).setText(r['date']?.toString() ?? '');
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.center;

      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(r['customer']?.toString() ?? 'Walk-in');
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.left;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(sub);
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(disc);
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 7).setNumber(tax);
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 8).setNumber(pay);
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 9)
          .setText(r['paymentMode']?.toString() ?? 'Cash');
      sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 10).setNumber(rec);
      sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.right;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 10).cellStyle.backColor =
            '#FAF7F2';
      }
      rowIndex++;
    }

    // Totals
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
    totalRange.merge();
    totalRange.setText('TOTAL');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 5).setNumber(totalSub);
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 6).setNumber(totalDisc);
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 7).setNumber(totalTax);
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 8).setNumber(totalPay);
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 10).setNumber(totalRec);
    sheet.getRangeByIndex(rowIndex, 10).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 10).cellStyle.backColor =
        '#F0E5D8';

    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;
    sheet.getRangeByIndex(1, 2).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 3).columnWidth = 13.0;
    sheet.getRangeByIndex(1, 4).columnWidth = 20.0;
    sheet.getRangeByIndex(1, 5).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 6).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 7).columnWidth = 12.0;
    sheet.getRangeByIndex(1, 8).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 9).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 10).columnWidth = 14.0;

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'sales_report_${_fmt.format(dateFrom)}_${_fmt.format(dateTo)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Product-Wise Sales Report Excel
  static Future<void> downloadProductWiseSalesExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Product Sales';

    final titleRange = sheet.getRangeByName('A1:I1');
    titleRange.merge();
    titleRange.setText('SALES REPORT — PRODUCT-WISE SUMMARY');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    final metaPeriod = sheet.getRangeByName('A2:E2');
    metaPeriod.merge();
    metaPeriod.setText(
      'Period: ${_fmt.format(dateFrom)} to ${_fmt.format(dateTo)}',
    );
    metaPeriod.cellStyle.bold = true;
    metaPeriod.cellStyle.fontSize = 10;
    metaPeriod.cellStyle.backColor = '#FDFBF7';

    final metaGen = sheet.getRangeByName('F2:I2');
    metaGen.merge();
    metaGen.setText('Generated: ${_dateTimeFmt.format(DateTime.now())}');
    metaGen.cellStyle.bold = true;
    metaGen.cellStyle.fontSize = 10;
    metaGen.cellStyle.backColor = '#FDFBF7';
    metaGen.cellStyle.hAlign = HAlignType.right;

    final headers = [
      'S.No',
      'Tag ID',
      'Product Name',
      'Category',
      'Qty Sold',
      'Revenue (Rs.)',
      'Discount (Rs.)',
      'Avg Price (Rs.)',
      'Orders',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8B263E';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign =
          (col == 0 || col == 1 || col == 4 || col == 8)
              ? HAlignType.center
              : (col >= 5 && col <= 7 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    int rowIndex = 4;
    int totalQty = 0;
    double totalRevenue = 0.0;
    double totalDiscount = 0.0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final qty = (r['qty'] as num?)?.toInt() ?? 0;
      final rev = (r['revenue'] as num?)?.toDouble() ?? 0.0;
      final disc = (r['discount'] as num?)?.toDouble() ?? 0.0;
      final avg = (r['avgPrice'] as num?)?.toDouble() ?? 0.0;
      final orders = (r['orders'] as num?)?.toInt() ?? 0;

      totalQty += qty;
      totalRevenue += rev;
      totalDiscount += disc;

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 2).setText(r['tagId']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;

      sheet
          .getRangeByIndex(rowIndex, 3)
          .setText(r['productName']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.left;

      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(r['category']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.left;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(qty.toDouble());
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(rev);
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;

      sheet.getRangeByIndex(rowIndex, 7).setNumber(disc);
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 8).setNumber(avg);
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 9).setNumber(orders.toDouble());
      sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 9).cellStyle.backColor =
            '#FAF7F2';
      }
      rowIndex++;
    }

    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
    totalRange.merge();
    totalRange.setText('TOTAL');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 5).setNumber(totalQty.toDouble());
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 6).setNumber(totalRevenue);
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 7).setNumber(totalDiscount);
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 9).cellStyle.backColor =
        '#F0E5D8';

    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;
    sheet.getRangeByIndex(1, 2).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 3).columnWidth = 24.0;
    sheet.getRangeByIndex(1, 4).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 5).columnWidth = 12.0;
    sheet.getRangeByIndex(1, 6).columnWidth = 16.0;
    sheet.getRangeByIndex(1, 7).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 8).columnWidth = 14.0;
    sheet.getRangeByIndex(1, 9).columnWidth = 10.0;

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'product_wise_sales_${_fmt.format(dateFrom)}_${_fmt.format(dateTo)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
