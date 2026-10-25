import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/vendor_issue.dart';
import 'file_downloader.dart';

class ExcelGenerator {
  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _dateTimeFmt = DateFormat('dd/MM/yyyy hh:mm a');
  static final _fileDateFmt = DateFormat('dd-MM-yyyy');

  /// Generate & download Inward Transactions Report Excel
  static Future<void> downloadInwardReportExcel({
    required List<Map<String, dynamic>> transactions,
    DateTime? dateFrom,
    DateTime? dateTo,
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
    final metaText = (dateFrom != null && dateTo != null)
        ? 'Period: ${_fmt.format(dateFrom)} to ${_fmt.format(dateTo)}   |   Generated: $nowStr'
        : 'Generated on: $nowStr';
    metaDate.setText(metaText);
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
      final items = bill['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final itemDate = item['addedDate'] != null
            ? (DateTime.tryParse(item['addedDate'].toString()) ?? bDate)
            : bDate;
        final dateStr = _dateTimeFmt.format(itemDate);
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

        if (rowIndex % 2 == 1) {
          sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor = '#FAF6F0';
        }

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

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor = '#EAD8C7';

    // ── Explicit Compact Column Widths (Fixed spacing without excessive blank areas) ──
    sheet.getRangeByIndex(1, 1).columnWidth = 17.5; // Date & Time
    sheet.getRangeByIndex(1, 2).columnWidth = 24.0; // Item Name
    sheet.getRangeByIndex(1, 3).columnWidth = 11.0; // Tag ID
    sheet.getRangeByIndex(1, 4).columnWidth = 16.0; // Category
    sheet.getRangeByIndex(1, 5).columnWidth = 9.5;  // Added Qty
    sheet.getRangeByIndex(1, 6).columnWidth = 11.5; // Added Weight
    sheet.getRangeByIndex(1, 7).columnWidth = 13.5; // Total Value (₹)

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final datePart = (dateFrom != null && dateTo != null)
        ? '${_fileDateFmt.format(dateFrom)}_to_${_fileDateFmt.format(dateTo)}'
        : _fileDateFmt.format(DateTime.now());

    await downloadFile(
      bytes,
      'Inward_Report_$datePart.xlsx',
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
    final dateStr = _fileDateFmt.format(DateTime.now());
    await downloadFile(
      bytes,
      'Inward_Bill_${ref}_$dateStr.xlsx',
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
    final dateStr = _fileDateFmt.format(issue.dateReported);
    await downloadFile(
      bytes,
      'Issue_Bill_${ref}_$dateStr.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Customer Return Bill Excel
  static Future<void> downloadCustomerReturnBillExcel({
    required Map<String, dynamic> bill,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Return Bill';

    final billNo = bill['billNo']?.toString() ?? 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final rawDate = bill['billDate'];
    final billDate = rawDate is DateTime
        ? rawDate
        : (rawDate is String ? DateTime.tryParse(rawDate) : null) ?? DateTime.now();
    final customer = bill['customerName']?.toString() ?? 'Customer';

    // ── Row 1: Title ────────────────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:G1');
    titleRange.merge();
    titleRange.setText('CUSTOMER RETURN BILL / CREDIT NOTE');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 13;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 2: Compact Meta ────────────────────────────────────────────────
    final metaRef = sheet.getRangeByName('A2:C2');
    metaRef.merge();
    metaRef.setText('Return No: $billNo');
    metaRef.cellStyle.bold = true;
    metaRef.cellStyle.fontSize = 10;
    metaRef.cellStyle.backColor = '#F5ECE4';

    final metaDate = sheet.getRangeByName('D2:E2');
    metaDate.merge();
    metaDate.setText('Date: ${_fmt.format(billDate)}');
    metaDate.cellStyle.bold = true;
    metaDate.cellStyle.fontSize = 10;
    metaDate.cellStyle.backColor = '#F5ECE4';
    metaDate.cellStyle.hAlign = HAlignType.center;

    final metaCust = sheet.getRangeByName('F2:G2');
    metaCust.merge();
    metaCust.setText('Customer: $customer');
    metaCust.cellStyle.bold = true;
    metaCust.cellStyle.fontSize = 10;
    metaCust.cellStyle.backColor = '#F5ECE4';
    metaCust.cellStyle.hAlign = HAlignType.right;

    // ── Row 3: Headers ──────────────────────────────────────────────────────
    final headers = ['S.No', 'Tag ID', 'Product Description', 'Qty', 'Unit Rate (₹)', 'Refund / Line Total (₹)', 'Reason / Status'];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = (col == 0 || col == 1 || col == 3) ? HAlignType.center : (col == 4 || col == 5 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    final rawItems = bill['items'] as List<dynamic>? ?? [];
    int rowIndex = 4;
    int totalQty = 0;
    double totalRefund = 0.0;

    for (int i = 0; i < rawItems.length; i++) {
      final it = rawItems[i] is Map ? rawItems[i] as Map : {};
      final name = it['name']?.toString() ?? it['productName']?.toString() ?? 'Item';
      final tagId = it['tagId']?.toString() ?? '—';
      final qty = (it['qty'] as num?)?.toInt() ?? 1;
      var amt = (it['lineAmount'] as num?)?.toDouble() ?? (it['amount'] as num?)?.toDouble() ?? 0.0;
      final rate = (it['price'] as num?)?.toDouble() ??
          (it['unitPrice'] as num?)?.toDouble() ??
          (it['rate'] as num?)?.toDouble() ??
          (qty > 0 && amt > 0 ? (amt / qty) : 0.0);
      if (amt <= 0 && rate > 0) amt = rate * qty;
      final reason = it['reason']?.toString() ?? bill['narration']?.toString() ?? 'Return';

      totalQty += qty;
      totalRefund += amt;

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 2).setText(tagId);
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 3).setText(name);
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.left;

      sheet.getRangeByIndex(rowIndex, 4).setNumber(qty.toDouble());
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(rate);
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(amt);
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;

      sheet.getRangeByIndex(rowIndex, 7).setText(reason);
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.left;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor = '#FAF6F0';
      }
      rowIndex++;
    }

    // Totals
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 3);
    totalRange.merge();
    totalRange.setText('TOTAL REFUND');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 4).setNumber(totalQty.toDouble());
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 6).setNumber(totalRefund > 0 ? totalRefund : (bill['totalPayable'] as num?)?.toDouble() ?? 0.0);
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor = '#EAD8C7';

    // Widths
    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 12.0;  // Tag ID
    sheet.getRangeByIndex(1, 3).columnWidth = 24.0;  // Description
    sheet.getRangeByIndex(1, 4).columnWidth = 8.0;   // Qty
    sheet.getRangeByIndex(1, 5).columnWidth = 13.0;  // Unit Rate
    sheet.getRangeByIndex(1, 6).columnWidth = 15.0;  // Refund Total
    sheet.getRangeByIndex(1, 7).columnWidth = 16.0;  // Reason

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final dateStr = _fileDateFmt.format(billDate);
    await downloadFile(
      bytes,
      'Return_Bill_${billNo}_$dateStr.xlsx',
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
    final titleRange = sheet.getRangeByName('A1:H1');
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

    final metaFilter = sheet.getRangeByName('D2:E2');
    metaFilter.merge();
    metaFilter.setText('Filter: $filterType');
    metaFilter.cellStyle.bold = true;
    metaFilter.cellStyle.fontSize = 10;
    metaFilter.cellStyle.backColor = '#F5ECE4';
    metaFilter.cellStyle.hAlign = HAlignType.center;

    final metaGen = sheet.getRangeByName('F2:H2');
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
      'Refund (₹)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(3, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = col == 0 || col == 1 || col == 2 || col == 5
          ? HAlignType.center
          : (col == 7 ? HAlignType.right : HAlignType.left);
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
      c8.setNumber(refund);
      c8.cellStyle.hAlign = HAlignType.right;
      c8.cellStyle.bold = true;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 8).cellStyle.backColor = '#FAF6F0';
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

    final totalRefundCell = sheet.getRangeByIndex(rowIndex, 8);
    totalRefundCell.setNumber(totalRefund);
    totalRefundCell.cellStyle.bold = true;
    totalRefundCell.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 8).cellStyle.backColor = '#EAD8C7';

    // ── Compact Explicit Column Widths ──────────────────────────────────────
    sheet.getRangeByIndex(1, 1).columnWidth = 5.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 11.0;  // Date
    sheet.getRangeByIndex(1, 3).columnWidth = 14.0;  // Type
    sheet.getRangeByIndex(1, 4).columnWidth = 18.0;  // Product / Tag ID
    sheet.getRangeByIndex(1, 5).columnWidth = 15.0;  // Customer / Vendor
    sheet.getRangeByIndex(1, 6).columnWidth = 6.0;   // Qty
    sheet.getRangeByIndex(1, 7).columnWidth = 18.0;  // Reason
    sheet.getRangeByIndex(1, 8).columnWidth = 14.0;  // Refund (₹)

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await downloadFile(
      bytes,
      'Issue_Report_${_fileDateFmt.format(dateFrom)}_to_${_fileDateFmt.format(dateTo)}.xlsx',
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

    final dateStr = _fileDateFmt.format(DateTime.now());
    await downloadFile(
      bytes,
      'closing_stock_category_wise_$dateStr.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Product-Wise Stock Report Excel
  static Future<void> downloadProductStockReportExcel({
    required List<Map<String, dynamic>> rows,
    String categoryFilter = 'All',
    String statusFilter = 'All',
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Stock Report';

    // ── Row 1: Company Title Banner ──────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:L1');
    titleRange.merge();
    titleRange.setText('RITUMITA BOUTIQUE');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.backColor = '#5A121A';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 2: Subtitle & Metadata ────────────────────────────────────
    final subTitleRange = sheet.getRangeByName('A2:L2');
    subTitleRange.merge();
    String periodStr = '';
    if (dateFrom != null && dateTo != null) {
      periodStr = ' • Period: ${_fileDateFmt.format(dateFrom)} to ${_fileDateFmt.format(dateTo)}';
    }
    subTitleRange.setText(
      'PRODUCT-WISE STOCK REPORT • Category: $categoryFilter • Status: $statusFilter$periodStr • Generated: ${_dateTimeFmt.format(DateTime.now())}',
    );
    subTitleRange.cellStyle.bold = true;
    subTitleRange.cellStyle.fontSize = 9;
    subTitleRange.cellStyle.backColor = '#FDFBF7';
    subTitleRange.cellStyle.fontColor = '#5A121A';
    subTitleRange.cellStyle.hAlign = HAlignType.center;
    subTitleRange.cellStyle.vAlign = VAlignType.center;

    // ── Row 3: Table Headers ──────────────────────────────────────────
    final headers = [
      'S.No',
      'Tag ID',
      'Product Name',
      'Category',
      'Total Purchased',
      'Issued Qty',
      'Sold Qty',
      'Balance Qty',
      'Unit',
      'Sell Price (₹)',
      'Stock Value (₹)',
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
          (col == 0 || col == 1 || col == 8 || col == 11)
              ? HAlignType.center
              : (col >= 4 && col <= 7 || col >= 9 && col <= 10)
                  ? HAlignType.right
                  : HAlignType.left;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cell.cellStyle.borders.all.color = '#721E31';
    }

    int rowIndex = 4;
    int totalPurchasedSum = 0;
    int totalIssuedSum = 0;
    int totalSoldSum = 0;
    int totalBalanceSum = 0;
    double totalStockValSum = 0.0;

    String currentCategory = '';

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final itemCat = (r['category']?.toString().trim().isNotEmpty ?? false)
          ? r['category'].toString().trim()
          : 'Uncategorized';

      // Group separator row by Category
      if (itemCat.toUpperCase() != currentCategory.toUpperCase()) {
        currentCategory = itemCat;
        final catBanner = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12);
        catBanner.merge();
        final countInCat = rows
            .where((x) =>
                (x['category']?.toString().trim().toUpperCase() ?? '') ==
                currentCategory.toUpperCase())
            .length;
        catBanner.setText('❖ CATEGORY: ${currentCategory.toUpperCase()} ($countInCat Items)');
        catBanner.cellStyle.bold = true;
        catBanner.cellStyle.fontSize = 10;
        catBanner.cellStyle.backColor = '#F0E5D8';
        catBanner.cellStyle.fontColor = '#5A121A';
        catBanner.cellStyle.vAlign = VAlignType.center;
        catBanner.cellStyle.borders.all.lineStyle = LineStyle.thin;
        catBanner.cellStyle.borders.all.color = '#D8C3B0';
        rowIndex++;
      }

      final pricingType = r['pricingType']?.toString() ?? 'Quantity-Based';
      final grossWeight = (r['grossWeight'] as num?)?.toDouble() ?? 0.0;
      final ratePerGram = (r['ratePerGram'] as num?)?.toDouble() ?? 0.0;
      final weightUnit = r['weightUnit']?.toString() ?? 'g';

      final balance = (r['balance'] as num?)?.toInt() ??
          (r['quantity'] as num?)?.toInt() ??
          0;
      final totalRec = (r['totalReceived'] as num?)?.toInt() ?? 0;
      final issue = (r['issueQty'] as num?)?.toInt() ?? 0;
      final sold = (r['soldQty'] as num?)?.toInt() ?? 0;
      final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0.0;

      final displaySp = pricingType == 'Weight-Based' ? ratePerGram : sp;
      final stockVal = pricingType == 'Weight-Based'
          ? (grossWeight * ratePerGram)
          : (balance * sp);

      totalPurchasedSum += totalRec;
      totalIssuedSum += issue;
      totalSoldSum += sold;
      totalBalanceSum += balance;
      totalStockValSum += stockVal;

      String balanceStr = balance.toString();
      if (pricingType == 'Weight-Based' && grossWeight > 0) {
        balanceStr = '${grossWeight.toStringAsFixed(2)}$weightUnit ($balance pc)';
      }

      // S.No
      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      // Tag ID
      sheet.getRangeByIndex(rowIndex, 2).setText(r['tagId']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.hAlign = HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;

      // Name
      sheet.getRangeByIndex(rowIndex, 3).setText(r['name']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 3).cellStyle.hAlign = HAlignType.left;

      // Category
      sheet.getRangeByIndex(rowIndex, 4).setText(r['category']?.toString() ?? '—');
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.left;

      // Total Purchased
      sheet.getRangeByIndex(rowIndex, 5).setNumber(totalRec.toDouble());
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.right;

      // Issued
      sheet.getRangeByIndex(rowIndex, 6).setNumber(issue.toDouble());
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

      // Sold
      sheet.getRangeByIndex(rowIndex, 7).setNumber(sold.toDouble());
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

      // Balance
      sheet.getRangeByIndex(rowIndex, 8).setText(balanceStr);
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;

      // Unit
      sheet.getRangeByIndex(rowIndex, 9).setText(r['unit']?.toString() ?? 'Piece');
      sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

      // Sell Price
      sheet.getRangeByIndex(rowIndex, 10).setNumber(displaySp);
      sheet.getRangeByIndex(rowIndex, 10).numberFormat = '#,##0.00';
      sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.right;

      // Stock Value
      sheet.getRangeByIndex(rowIndex, 11).setNumber(stockVal);
      sheet.getRangeByIndex(rowIndex, 11).numberFormat = '#,##0.00';
      sheet.getRangeByIndex(rowIndex, 11).cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByIndex(rowIndex, 11).cellStyle.bold = true;

      // Status
      sheet.getRangeByIndex(rowIndex, 12).setText(r['status']?.toString() ?? 'In Stock');
      sheet.getRangeByIndex(rowIndex, 12).cellStyle.hAlign = HAlignType.center;

      for (int c = 1; c <= 12; c++) {
        sheet.getRangeByIndex(rowIndex, c).cellStyle.borders.all.lineStyle = LineStyle.thin;
        sheet.getRangeByIndex(rowIndex, c).cellStyle.borders.all.color = '#EADBCC';
      }

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.backColor = '#FAF7F2';
      }
      rowIndex++;
    }

    // ── Summary Grand Total Row ───────────────────────────────────────
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
    totalRange.merge();
    totalRange.setText('GRAND TOTAL (${rows.length} ITEMS)');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.fontSize = 10;
    totalRange.cellStyle.hAlign = HAlignType.right;
    totalRange.cellStyle.vAlign = VAlignType.center;

    sheet.getRangeByIndex(rowIndex, 5).setNumber(totalPurchasedSum.toDouble());
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 6).setNumber(totalIssuedSum.toDouble());
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 7).setNumber(totalSoldSum.toDouble());
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 8).setNumber(totalBalanceSum.toDouble());
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 8).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 9).setText('—');
    sheet.getRangeByIndex(rowIndex, 9).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 10).setText('—');
    sheet.getRangeByIndex(rowIndex, 10).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 11).setNumber(totalStockValSum);
    sheet.getRangeByIndex(rowIndex, 11).numberFormat = '#,##0.00';
    sheet.getRangeByIndex(rowIndex, 11).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 11).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 12).setText('—');
    sheet.getRangeByIndex(rowIndex, 12).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.backColor = '#F0E5D8';
    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 12).cellStyle.fontColor = '#5A121A';

    for (int c = 1; c <= 12; c++) {
      sheet.getRangeByIndex(rowIndex, c).cellStyle.borders.top.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(rowIndex, c).cellStyle.borders.bottom.lineStyle = LineStyle.medium;
      sheet.getRangeByIndex(rowIndex, c).cellStyle.borders.all.color = '#8B263E';
    }

    // Widths
    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 14.0;  // Tag ID
    sheet.getRangeByIndex(1, 3).columnWidth = 28.0;  // Product Name
    sheet.getRangeByIndex(1, 4).columnWidth = 18.0;  // Category
    sheet.getRangeByIndex(1, 5).columnWidth = 14.0;  // Total Purchased
    sheet.getRangeByIndex(1, 6).columnWidth = 12.0;  // Issued Qty
    sheet.getRangeByIndex(1, 7).columnWidth = 12.0;  // Sold Qty
    sheet.getRangeByIndex(1, 8).columnWidth = 14.0;  // Balance Qty
    sheet.getRangeByIndex(1, 9).columnWidth = 10.0;  // Unit
    sheet.getRangeByIndex(1, 10).columnWidth = 14.0; // Sell Price
    sheet.getRangeByIndex(1, 11).columnWidth = 18.0; // Stock Value
    sheet.getRangeByIndex(1, 12).columnWidth = 14.0; // Status

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final dateStr = _fileDateFmt.format(DateTime.now());
    await downloadFile(
      bytes,
      'Stock_Report_$dateStr.xlsx',
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
      'sales_report_${_fileDateFmt.format(dateFrom)}_to_${_fileDateFmt.format(dateTo)}.xlsx',
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
      'product_wise_sales_${_fileDateFmt.format(dateFrom)}_to_${_fileDateFmt.format(dateTo)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download inward history for a specific single product
  static Future<void> downloadProductInwardHistoryExcel({
    required String productName,
    required String tagId,
    required String category,
    required List<Map<String, dynamic>> historyRows,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Inward History';

    final nowStr = _dateTimeFmt.format(DateTime.now());

    // ── Title Banner ──────────────────────────────────────────────────
    final titleRange = sheet.getRangeByName('A1:G1');
    titleRange.merge();
    titleRange.setText('PRODUCT INWARD HISTORY');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.backColor = '#5A3B22';
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // ── Metadata Rows ─────────────────────────────────────────────────
    final metaRange1 = sheet.getRangeByName('A2:G2');
    metaRange1.merge();
    metaRange1.setText('Product: $productName | Tag ID: $tagId | Category: $category');
    metaRange1.cellStyle.bold = true;
    metaRange1.cellStyle.fontSize = 10;
    metaRange1.cellStyle.backColor = '#F5ECE4';
    metaRange1.cellStyle.hAlign = HAlignType.left;
    metaRange1.cellStyle.vAlign = VAlignType.center;

    final metaRange2 = sheet.getRangeByName('A3:G3');
    metaRange2.merge();
    metaRange2.setText('Export Date: $nowStr | Total Batches: ${historyRows.length}');
    metaRange2.cellStyle.bold = false;
    metaRange2.cellStyle.fontSize = 9;
    metaRange2.cellStyle.backColor = '#F5ECE4';
    metaRange2.cellStyle.hAlign = HAlignType.left;
    metaRange2.cellStyle.vAlign = VAlignType.center;

    // ── Headers ───────────────────────────────────────────────────────
    final headers = [
      'S.No',
      'Date & Time',
      'Narration / Source',
      'Added Qty',
      'Added Weight (g)',
      'Rate (₹)',
      'Total Value (₹)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(4, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#8C6246';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = (col == 0 || col == 3 || col == 4)
          ? HAlignType.center
          : (col >= 5 ? HAlignType.right : HAlignType.left);
      cell.cellStyle.vAlign = VAlignType.center;
    }

    // ── Data Rows ─────────────────────────────────────────────────────
    int rowIndex = 5;
    int totalQty = 0;
    double totalWeight = 0.0;
    double totalValue = 0.0;

    for (int i = 0; i < historyRows.length; i++) {
      final r = historyRows[i];
      final dt = r['date'] is DateTime
          ? r['date'] as DateTime
          : (DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now());
      final narration = r['narration']?.toString() ?? 'Stock Inward';
      final item = r['itemData'] as Map<String, dynamic>? ?? r;
      final q = (item['qty'] as num?)?.toInt() ?? 0;
      final w = (item['weight'] as num?)?.toDouble() ?? 0.0;
      final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
      var amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0 && rate > 0) {
        amt = w > 0 ? (rate * w) : (rate * q);
      }

      totalQty += q;
      totalWeight += w;
      totalValue += amt;

      sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 2).setText(_dateTimeFmt.format(dt));

      sheet.getRangeByIndex(rowIndex, 3).setText(narration);

      sheet.getRangeByIndex(rowIndex, 4).setNumber(q.toDouble());
      sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 5).setNumber(w);
      sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(rowIndex, 6).setNumber(rate);
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByIndex(rowIndex, 7).setNumber(amt);
      sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

      if (i % 2 == 1) {
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor =
            '#FBF8F5';
      }

      rowIndex++;
    }

    // ── Total Footer ──────────────────────────────────────────────────
    final totalRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 3);
    totalRange.merge();
    totalRange.setText('TOTAL INWARD');
    totalRange.cellStyle.bold = true;
    totalRange.cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 4).setNumber(totalQty.toDouble());
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 4).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 5).setNumber(totalWeight);
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 5).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 6).setText('-');
    sheet.getRangeByIndex(rowIndex, 6).cellStyle.hAlign = HAlignType.center;

    sheet.getRangeByIndex(rowIndex, 7).setNumber(totalValue);
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 7).cellStyle.hAlign = HAlignType.right;

    sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7).cellStyle.backColor =
        '#F0E5D8';

    // Set compact column widths
    sheet.getRangeByIndex(1, 1).columnWidth = 6.0;   // S.No
    sheet.getRangeByIndex(1, 2).columnWidth = 17.5;  // Date & Time
    sheet.getRangeByIndex(1, 3).columnWidth = 20.0;  // Narration
    sheet.getRangeByIndex(1, 4).columnWidth = 9.0;   // Qty
    sheet.getRangeByIndex(1, 5).columnWidth = 11.5;  // Weight
    sheet.getRangeByIndex(1, 6).columnWidth = 11.5;  // Rate
    sheet.getRangeByIndex(1, 7).columnWidth = 13.5;  // Total Value

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final safeTag = tagId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dateStr = _fileDateFmt.format(DateTime.now());
    await downloadFile(
      bytes,
      'inward_history_${safeTag}_$dateStr.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate & download Stock Ledger Excel matching user's custom template
  /// Layout matches photo: Category, Product Name, Date, Price, Total Inward, Issue, Sales, Closing
  static Future<void> downloadStockLedgerExcel({
    required List<Map<String, dynamic>> rows,
    String categoryFilter = 'All',
    DateTime? dateFrom,
    DateTime? dateTo,
    String sheetName = 'Stock Ledger',
    String fileName = 'Stock_Ledger',
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = sheetName;

    // ── Row 2: Top Group Headers ─────────────────────────────────────
    // Particulars (over Product Name & Date)
    final particularsRange = sheet.getRangeByName('C2:D2');
    particularsRange.merge();
    particularsRange.setText('Particulars');
    particularsRange.cellStyle.bold = true;
    particularsRange.cellStyle.fontSize = 10;
    particularsRange.cellStyle.backColor = '#8EAADB';
    particularsRange.cellStyle.fontColor = '#002060';
    particularsRange.cellStyle.hAlign = HAlignType.center;
    particularsRange.cellStyle.vAlign = VAlignType.center;

    // Price top header
    final priceTop = sheet.getRangeByName('E2');
    priceTop.setText('PRICE');
    priceTop.cellStyle.bold = true;
    priceTop.cellStyle.fontSize = 10;
    priceTop.cellStyle.backColor = '#8EAADB';
    priceTop.cellStyle.fontColor = '#002060';
    priceTop.cellStyle.hAlign = HAlignType.center;
    priceTop.cellStyle.vAlign = VAlignType.center;

    // Inward Units header
    final inwardTop = sheet.getRangeByName('F2');
    inwardTop.setText('Inward Units');
    inwardTop.cellStyle.bold = true;
    inwardTop.cellStyle.fontSize = 10;
    inwardTop.cellStyle.backColor = '#8EAADB';
    inwardTop.cellStyle.fontColor = '#002060';
    inwardTop.cellStyle.hAlign = HAlignType.center;
    inwardTop.cellStyle.vAlign = VAlignType.center;

    // ISSUE header
    final issueTop = sheet.getRangeByName('G2');
    issueTop.setText('ISSUE');
    issueTop.cellStyle.bold = true;
    issueTop.cellStyle.fontSize = 10;
    issueTop.cellStyle.backColor = '#8EAADB';
    issueTop.cellStyle.fontColor = '#002060';
    issueTop.cellStyle.hAlign = HAlignType.center;
    issueTop.cellStyle.vAlign = VAlignType.center;

    // Sales header
    final salesTop = sheet.getRangeByName('H2');
    salesTop.setText('Sales');
    salesTop.cellStyle.bold = true;
    salesTop.cellStyle.fontSize = 10;
    salesTop.cellStyle.backColor = '#8EAADB';
    salesTop.cellStyle.fontColor = '#002060';
    salesTop.cellStyle.hAlign = HAlignType.center;
    salesTop.cellStyle.vAlign = VAlignType.center;

    // Closing header
    final closingTop = sheet.getRangeByName('I2');
    closingTop.setText('Closing');
    closingTop.cellStyle.bold = true;
    closingTop.cellStyle.fontSize = 10;
    closingTop.cellStyle.backColor = '#8EAADB';
    closingTop.cellStyle.fontColor = '#002060';
    closingTop.cellStyle.hAlign = HAlignType.center;
    closingTop.cellStyle.vAlign = VAlignType.center;

    // ── Row 3: Sub Headers ───────────────────────────────────────────
    final subHeaders = [
      {'col': 2, 'text': 'CATEGORY', 'name': 'B3'},
      {'col': 3, 'text': 'PRODUCT NAME', 'name': 'C3'},
      {'col': 4, 'text': 'DATE', 'name': 'D3'},
      {'col': 5, 'text': 'PRICE', 'name': 'E3'},
      {'col': 6, 'text': 'TOTAL INWARD', 'name': 'F3'},
      {'col': 7, 'text': 'ISSUE', 'name': 'G3'},
      {'col': 8, 'text': 'Sales', 'name': 'H3'},
      {'col': 9, 'text': 'Closing', 'name': 'I3'},
    ];

    for (final sh in subHeaders) {
      final cell = sheet.getRangeByIndex(3, sh['col'] as int);
      cell.setText(sh['text'] as String);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 9;
      cell.cellStyle.backColor = '#D9E1F2';
      cell.cellStyle.fontColor = '#002060';
      cell.cellStyle.hAlign = (sh['col'] == 2 || sh['col'] == 3) ? HAlignType.left : HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cell.cellStyle.borders.all.color = '#8EAADB';
    }

    // Set borders on Row 2 headers
    for (int col = 3; col <= 9; col++) {
      sheet.getRangeByIndex(2, col).cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(2, col).cellStyle.borders.all.color = '#8EAADB';
    }

    // ── Data Rows ───────────────────────────────────────────────────
    int rowIndex = 4;
    String lastCategory = '';
    double sumInward = 0.0;
    double sumIssue = 0.0;
    double sumSales = 0.0;
    double sumClosing = 0.0;

    for (final r in rows) {
      final category = (r['category']?.toString().trim().isNotEmpty ?? false)
          ? r['category'].toString().trim()
          : 'Uncategorized';
      final name = r['name']?.toString() ?? '';
      final isSummary = r['isSummary'] == true;
      final rawDate = r['date'];
      final dateStr = rawDate == null
          ? '-'
          : (rawDate is DateTime
              ? _fmt.format(rawDate)
              : (DateTime.tryParse(rawDate.toString()) != null
                  ? _fmt.format(DateTime.parse(rawDate.toString()))
                  : '-'));
      final price = (r['price'] as num?)?.toDouble() ?? 0.0;
      final inwardQty = (r['inwardQty'] as num?)?.toDouble() ?? 0.0;
      final unit = r['unit']?.toString() ?? 'Nos';
      final isWeight = r['isWeight'] == true;
      final issueQty = (r['issueQty'] as num?)?.toDouble() ?? 0.0;
      final soldQty = (r['soldQty'] as num?)?.toDouble() ?? 0.0;
      final closingQty = (r['closingQty'] as num?)?.toDouble() ?? 0.0;

      sumInward += inwardQty;
      sumIssue += issueQty;
      sumSales += soldQty;
      sumClosing += closingQty;

      // Col B: Category (shown on first row of category or on summary row)
      final cellCat = sheet.getRangeByIndex(rowIndex, 2);
      if (isSummary || category != lastCategory) {
        cellCat.setText(category);
        cellCat.cellStyle.bold = true;
        cellCat.cellStyle.fontColor = '#002060';
        lastCategory = category;
      } else {
        cellCat.setText('');
      }
      cellCat.cellStyle.vAlign = VAlignType.center;
      cellCat.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellCat.cellStyle.borders.all.color = '#E0E7F1';

      // Col C: Product Name
      final cellName = sheet.getRangeByIndex(rowIndex, 3);
      cellName.setText(name);
      cellName.cellStyle.bold = isSummary || cellName.cellStyle.bold;
      cellName.cellStyle.vAlign = VAlignType.center;
      cellName.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellName.cellStyle.borders.all.color = '#E0E7F1';

      // Col D: Date
      final cellDate = sheet.getRangeByIndex(rowIndex, 4);
      cellDate.setText(dateStr);
      cellDate.cellStyle.hAlign = HAlignType.center;
      cellDate.cellStyle.vAlign = VAlignType.center;
      cellDate.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellDate.cellStyle.borders.all.color = '#E0E7F1';

      // Col E: Price
      final cellPrice = sheet.getRangeByIndex(rowIndex, 5);
      if (price > 0) {
        cellPrice.setNumber(price);
        cellPrice.numberFormat = '#,##0.00';
      } else {
        cellPrice.setText('-');
      }
      cellPrice.cellStyle.hAlign = HAlignType.right;
      cellPrice.cellStyle.vAlign = VAlignType.center;
      cellPrice.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellPrice.cellStyle.borders.all.color = '#E0E7F1';

      // Col F: Total Inward (e.g. 3 Nos, 196.00 Gram)
      final cellInward = sheet.getRangeByIndex(rowIndex, 6);
      final displayUnit = unit.isNotEmpty ? unit : (isWeight ? 'Gram' : 'Nos');
      final inwardFormatted = isWeight
          ? inwardQty.toStringAsFixed(2)
          : (inwardQty % 1 == 0 ? inwardQty.toInt().toString() : inwardQty.toStringAsFixed(2));
      cellInward.setText('$inwardFormatted $displayUnit');
      cellInward.cellStyle.hAlign = HAlignType.right;
      cellInward.cellStyle.vAlign = VAlignType.center;
      cellInward.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellInward.cellStyle.borders.all.color = '#E0E7F1';

      // Col G: Issue
      final cellIssue = sheet.getRangeByIndex(rowIndex, 7);
      if (issueQty > 0) {
        cellIssue.setNumber(issueQty);
        cellIssue.numberFormat = isWeight ? '0.00' : (issueQty % 1 == 0 ? '0' : '0.00');
      } else {
        cellIssue.setText('-');
      }
      cellIssue.cellStyle.hAlign = HAlignType.center;
      cellIssue.cellStyle.vAlign = VAlignType.center;
      cellIssue.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellIssue.cellStyle.borders.all.color = '#E0E7F1';

      // Col H: Sales
      final cellSales = sheet.getRangeByIndex(rowIndex, 8);
      if (soldQty > 0) {
        cellSales.setNumber(soldQty);
        cellSales.numberFormat = isWeight ? '0.00' : (soldQty % 1 == 0 ? '0' : '0.00');
      } else {
        cellSales.setText('-');
      }
      cellSales.cellStyle.hAlign = HAlignType.center;
      cellSales.cellStyle.vAlign = VAlignType.center;
      cellSales.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellSales.cellStyle.borders.all.color = '#E0E7F1';

      // Col I: Closing
      final cellClosing = sheet.getRangeByIndex(rowIndex, 9);
      cellClosing.setNumber(closingQty);
      cellClosing.numberFormat = isWeight ? '0.00' : (closingQty % 1 == 0 ? '0' : '0.00');
      cellClosing.cellStyle.bold = true;
      cellClosing.cellStyle.hAlign = HAlignType.center;
      cellClosing.cellStyle.vAlign = VAlignType.center;
      cellClosing.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cellClosing.cellStyle.borders.all.color = '#E0E7F1';

      if (isSummary) {
        for (int col = 2; col <= 9; col++) {
          sheet.getRangeByIndex(rowIndex, col).cellStyle.backColor = '#F2F5F9';
        }
      }

      rowIndex++;
    }

    // ── Summary Grand Total Row ───────────────────────────────────────
    final totalLabel = sheet.getRangeByIndex(rowIndex, 2, rowIndex, 5);
    totalLabel.merge();
    totalLabel.setText('TOTAL');
    totalLabel.cellStyle.bold = true;
    totalLabel.cellStyle.fontSize = 10;
    totalLabel.cellStyle.backColor = '#D9E1F2';
    totalLabel.cellStyle.fontColor = '#002060';
    totalLabel.cellStyle.hAlign = HAlignType.right;
    totalLabel.cellStyle.vAlign = VAlignType.center;

    final cellTotInward = sheet.getRangeByIndex(rowIndex, 6);
    cellTotInward.setNumber(sumInward);
    cellTotInward.numberFormat = sumInward % 1 == 0 ? '#,##0' : '#,##0.00';
    cellTotInward.cellStyle.bold = true;
    cellTotInward.cellStyle.backColor = '#D9E1F2';
    cellTotInward.cellStyle.fontColor = '#002060';
    cellTotInward.cellStyle.hAlign = HAlignType.right;
    cellTotInward.cellStyle.vAlign = VAlignType.center;

    final cellTotIssue = sheet.getRangeByIndex(rowIndex, 7);
    if (sumIssue > 0) {
      cellTotIssue.setNumber(sumIssue);
      cellTotIssue.numberFormat = sumIssue % 1 == 0 ? '#,##0' : '#,##0.00';
    } else {
      cellTotIssue.setText('-');
    }
    cellTotIssue.cellStyle.bold = true;
    cellTotIssue.cellStyle.backColor = '#D9E1F2';
    cellTotIssue.cellStyle.fontColor = '#002060';
    cellTotIssue.cellStyle.hAlign = HAlignType.center;
    cellTotIssue.cellStyle.vAlign = VAlignType.center;

    final cellTotSales = sheet.getRangeByIndex(rowIndex, 8);
    if (sumSales > 0) {
      cellTotSales.setNumber(sumSales);
      cellTotSales.numberFormat = sumSales % 1 == 0 ? '#,##0' : '#,##0.00';
    } else {
      cellTotSales.setText('-');
    }
    cellTotSales.cellStyle.bold = true;
    cellTotSales.cellStyle.backColor = '#D9E1F2';
    cellTotSales.cellStyle.fontColor = '#002060';
    cellTotSales.cellStyle.hAlign = HAlignType.center;
    cellTotSales.cellStyle.vAlign = VAlignType.center;

    final cellTotClosing = sheet.getRangeByIndex(rowIndex, 9);
    cellTotClosing.setNumber(sumClosing);
    cellTotClosing.numberFormat = sumClosing % 1 == 0 ? '#,##0' : '#,##0.00';
    cellTotClosing.cellStyle.bold = true;
    cellTotClosing.cellStyle.backColor = '#D9E1F2';
    cellTotClosing.cellStyle.fontColor = '#002060';
    cellTotClosing.cellStyle.hAlign = HAlignType.center;
    cellTotClosing.cellStyle.vAlign = VAlignType.center;

    for (int col = 2; col <= 9; col++) {
      sheet.getRangeByIndex(rowIndex, col).cellStyle.borders.top.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(rowIndex, col).cellStyle.borders.bottom.lineStyle = LineStyle.medium;
      sheet.getRangeByIndex(rowIndex, col).cellStyle.borders.all.color = '#8EAADB';
    }

    // Set Column Widths
    sheet.getRangeByIndex(1, 1).columnWidth = 3.0;   // A
    sheet.getRangeByIndex(1, 2).columnWidth = 26.0;  // B: CATEGORY
    sheet.getRangeByIndex(1, 3).columnWidth = 36.0;  // C: PRODUCT NAME
    sheet.getRangeByIndex(1, 4).columnWidth = 14.0;  // D: DATE
    sheet.getRangeByIndex(1, 5).columnWidth = 13.0;  // E: PRICE
    sheet.getRangeByIndex(1, 6).columnWidth = 18.0;  // F: TOTAL INWARD
    sheet.getRangeByIndex(1, 7).columnWidth = 12.0;  // G: ISSUE
    sheet.getRangeByIndex(1, 8).columnWidth = 12.0;  // H: Sales
    sheet.getRangeByIndex(1, 9).columnWidth = 14.0;  // I: Closing

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final dateStr = _fileDateFmt.format(DateTime.now());
    await downloadFile(
      bytes,
      '${fileName}_$dateStr.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
