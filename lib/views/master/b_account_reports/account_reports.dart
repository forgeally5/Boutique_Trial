// account_reports.dart
// B Account Reports — Ledger, Day Book, Cash/Bank Book, Trial Balance, P&L, Balance Sheet, Group Summary

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../helpers/download_helper.dart';
import '../report_shared.dart';

const _br  = Color(0xFF3E2723);
const _brL = Color(0xFF6D4C41);
const _bdr = Color(0xFFE5DDD0);
const _bg0 = Color(0xFFFDFBF7);
const _bg1 = Color(0xFFF9F6F0);

const brColor = _br;
const brLColor = _brL;
const bdrColor = _bdr;
const bg0Color = _bg0;
const bg1Color = _bg1;

double    _fdbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
String    _ffmt(double v)  => NumberFormat('#,##,##0.00', 'en_IN').format(v);

double fdbl(dynamic v) => _fdbl(v);
String ffmt(double v) => _ffmt(v);

Future<DateTimeRange?> aPickRange(BuildContext ctx, DateTimeRange cur) => _aPickRange(ctx, cur);
Widget get aLoader => _aLoader;
Widget aEmpty(String msg) => _aEmpty(msg);
Widget aTh(String t, {double? w, bool r = false, bool flex = false}) => _aTh(t, w: w, r: r, flex: flex);
Widget aTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) => _aTd(t, w: w, r: r, flex: flex, bold: bold, c: c);
Widget aTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) => _aTt(t, w: w, r: r, flex: flex, c: c);
Future<List<Map<String, dynamic>>> loadAllTransactions(DateTime from, DateTime to) => _loadAllTransactions(from, to);

Widget aShell({
  required BuildContext context,
  required String pageTitle,
  required IconData pageIcon,
  required DateTime from,
  required DateTime to,
  required VoidCallback onPickDate,
  required VoidCallback onRefresh,
  required int totalRecords,
  TextEditingController? searchCtrl,
  ValueChanged<String>? onSearch,
  Widget? filterWidget,
  required Widget body,
  ValueChanged<String>? onReportSelected,
  VoidCallback? onExportCsv,
  VoidCallback? onExportExcel,
  VoidCallback? onExportPdf,
}) => _aShell(
  context: context,
  pageTitle: pageTitle,
  pageIcon: pageIcon,
  from: from,
  to: to,
  onPickDate: onPickDate,
  onRefresh: onRefresh,
  totalRecords: totalRecords,
  searchCtrl: searchCtrl,
  onSearch: onSearch,
  filterWidget: filterWidget,
  body: body,
  onReportSelected: onReportSelected,
  onExportCsv: onExportCsv,
  onExportExcel: onExportExcel,
  onExportPdf: onExportPdf,
);

Future<DateTimeRange?> _aPickRange(BuildContext ctx, DateTimeRange cur) =>
    showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: cur,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _br, onPrimary: Colors.white, onSurface: _br),
        ),
        child: child!,
      ),
    );

Widget _aLoader = const Center(child: CircularProgressIndicator(color: _br));

Widget _aEmpty(String msg) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );

Widget _aTh(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _aTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: r ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(t,
          style: TextStyle(fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: c ?? Colors.black87)),
    ),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _aTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: r ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(t,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c ?? _br)),
    ),
  );
  return flex ? Expanded(child: inner) : inner;
}

String getDownloadsFolderPath() {
  if (!kIsWeb) {
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloads = Directory('$userProfile\\Downloads');
          if (!downloads.existsSync()) downloads.createSync(recursive: true);
          return downloads.path;
        }
      }
    } catch (_) {}
    return Directory.current.path;
  }
  return '';
}

class CompanyDetails {
  final String businessName;
  final String subtitle;
  final String address;
  final String gstNo;
  final bool showLogo;

  CompanyDetails({
    required this.businessName,
    required this.subtitle,
    required this.address,
    required this.gstNo,
    required this.showLogo,
  });
}

Future<CompanyDetails> fetchCompanyDetails() async {
  String businessName = 'TRILOK';
  String subtitle = 'OM SRI JEWEL';
  String address = '331-4, 2ND FLOOR, GURU TOWERS, NSR ROAD, SAI BABA COLONY, COIMBATORE - 641001. Tamil Nadu, INDIA';
  String gstNo = '33AAGFO5897D1Z2';
  bool showLogo = true;

  try {
    final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
    if (doc.exists && doc.data() != null) {
      final d = doc.data()!;
      businessName = d['businessName']?.toString() ?? businessName;
      subtitle = d['subtitle']?.toString() ?? subtitle;
      address = d['address']?.toString() ?? address;
      gstNo = d['gstNo']?.toString() ?? gstNo;
      showLogo = d['showLogo'] ?? showLogo;
    }
  } catch (_) {}

  return CompanyDetails(
    businessName: businessName,
    subtitle: subtitle,
    address: address,
    gstNo: gstNo,
    showLogo: showLogo,
  );
}

Future<String?> exportReportAsCsv({
  required String reportTitle,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  try {
    final comp = await fetchCompanyDetails();
    final buf = StringBuffer();

    buf.writeln('"${comp.businessName.replaceAll('"', '""')}"');
    if (comp.subtitle.isNotEmpty) {
      buf.writeln('"${comp.subtitle.replaceAll('"', '""')}"');
    }
    buf.writeln('"${comp.address.replaceAll('\n', ' ').replaceAll('"', '""')}"');
    if (comp.gstNo.isNotEmpty) {
      buf.writeln('"GSTIN: ${comp.gstNo.replaceAll('"', '""')}"');
    }
    buf.writeln('"${reportTitle.replaceAll('"', '""')}"');
    buf.writeln('"Exported: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}"');
    buf.writeln('');

    buf.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    for (final row in rows) {
      buf.writeln(row.map((c) => '"${(c?.toString() ?? '').replaceAll('"', '""')}"').join(','));
    }
    final csvContent = buf.toString();
    final fileName = '${reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final bytes = utf8.encode(csvContent);

    return await saveAndDownloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  } catch (e) {
    debugPrint('CSV Export error: $e');
    return null;
  }
}

Future<String?> exportReportAsExcel({
  required String reportTitle,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  try {
    final comp = await fetchCompanyDetails();
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0"?>');
    buf.writeln('<?mso-application progid="Excel.Sheet"?>');
    buf.writeln('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
    buf.writeln('<Worksheet ss:Name="ReportData">');
    buf.writeln('<Table>');
    
    buf.writeln('<Row><Cell><Data ss:Type="String">${comp.businessName}</Data></Cell></Row>');
    if (comp.subtitle.isNotEmpty) {
      buf.writeln('<Row><Cell><Data ss:Type="String">${comp.subtitle}</Data></Cell></Row>');
    }
    buf.writeln('<Row><Cell><Data ss:Type="String">${comp.address.replaceAll('\n', ' ')}</Data></Cell></Row>');
    if (comp.gstNo.isNotEmpty) {
      buf.writeln('<Row><Cell><Data ss:Type="String">GSTIN: ${comp.gstNo}</Data></Cell></Row>');
    }
    buf.writeln('<Row><Cell><Data ss:Type="String">$reportTitle</Data></Cell></Row>');
    buf.writeln('<Row><Cell><Data ss:Type="String">Exported: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}</Data></Cell></Row>');
    buf.writeln('<Row></Row>');

    buf.writeln('<Row>');
    for (final h in headers) {
      buf.writeln('<Cell><Data ss:Type="String">$h</Data></Cell>');
    }
    buf.writeln('</Row>');

    for (final r in rows) {
      buf.writeln('<Row>');
      for (final c in r) {
        final str = c?.toString() ?? '';
        final cleanNum = double.tryParse(str.replaceAll('₹', '').replaceAll(',', '').replaceAll('g', '').trim());
        if (cleanNum != null && !str.contains('/')) {
          buf.writeln('<Cell><Data ss:Type="Number">$cleanNum</Data></Cell>');
        } else {
          buf.writeln('<Cell><Data ss:Type="String">$str</Data></Cell>');
        }
      }
      buf.writeln('</Row>');
    }

    buf.writeln('</Table>');
    buf.writeln('</Worksheet>');
    buf.writeln('</Workbook>');

    final xmlContent = buf.toString();
    final fileName = '${reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xls';
    final bytes = utf8.encode(xmlContent);

    return await saveAndDownloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/vnd.ms-excel',
    );
  } catch (e) {
    debugPrint('Excel Export error: $e');
    return null;
  }
}

Future<String?> exportReportAsPdf({
  required String reportTitle,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  try {
    final comp = await fetchCompanyDetails();
    pw.MemoryImage? logoImage;
    if (comp.showLogo) {
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          buildBackground: (context) => logoImage != null
              ? pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.Image(logoImage, width: 280, height: 280, fit: pw.BoxFit.contain),
                    ),
                  ),
                )
              : pw.SizedBox(),
        ),
        maxPages: 200,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Image(logoImage, width: 35, height: 35),
                      pw.SizedBox(width: 8),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(comp.businessName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (comp.subtitle.isNotEmpty)
                          pw.Text(comp.subtitle, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text(comp.address.replaceAll('\n', ' '), style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        if (comp.gstNo.isNotEmpty)
                          pw.Text('GSTIN: ${comp.gstNo}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(reportTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows.map((r) => r.map((c) => c?.toString() ?? '').toList()).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 20,
            cellAlignments: {
              for (int i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
            },
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    final fileName = '${reportTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    final path = await saveAndDownloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
    debugPrint('PDF saved to: $path');
    return path;
  } catch (e, st) {
    debugPrint('PDF Export error: $e\n$st');
    return null;
  }
}

void openSavedFile(String filePath) {
  if (!kIsWeb) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [filePath]);
      }
    } catch (_) {}
  }
}

void showReportDownloadDialog(BuildContext ctx, String reportTitle, String formatType, String? filePath) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$reportTitle downloaded as $formatType successfully!', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                if (filePath != null && !kIsWeb)
                  Text(filePath, style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      action: (filePath != null && !kIsWeb)
          ? SnackBarAction(
              label: 'OPEN',
              textColor: Colors.amberAccent,
              onPressed: () => openSavedFile(filePath),
            )
          : null,
      backgroundColor: _br,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

Widget _aShell({
  required BuildContext context,
  required String pageTitle,
  required IconData pageIcon,
  required DateTime from,
  required DateTime to,
  required VoidCallback onPickDate,
  required VoidCallback onRefresh,
  required int totalRecords,
  TextEditingController? searchCtrl,
  ValueChanged<String>? onSearch,
  Widget? filterWidget,
  required Widget body,
  ValueChanged<String>? onReportSelected,
  VoidCallback? onExportCsv,
  VoidCallback? onExportExcel,
  VoidCallback? onExportPdf,
}) {
  return Column(children: [
    Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(children: [
        Icon(pageIcon, size: 17, color: _br),
        const SizedBox(width: 8),
        buildTitleDropdown(
          context: context,
          currentTitle: pageTitle,
          onSelected: (newTitle) {
            onReportSelected?.call(newTitle);
          },
          textColor: _br,
          fontSize: 14,
          bold: true,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(10)),
          child: Text('$totalRecords records',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))),
        ),
        const Spacer(),
        if (searchCtrl != null) ...[
          SizedBox(
            width: 190, height: 32,
            child: TextField(
              controller: searchCtrl, onChanged: onSearch,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Search...', hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 13, color: _brL),
                isDense: true, contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        OutlinedButton.icon(
          onPressed: onPickDate,
          style: OutlinedButton.styleFrom(
            foregroundColor: _brL, side: const BorderSide(color: _bdr),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
          icon: const Icon(Icons.date_range_rounded, size: 13),
          label: Text('${DateFormat('dd/MM/yy').format(from)} - ${DateFormat('dd/MM/yy').format(to)}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Download Report',
          onSelected: (val) async {
            if (val == 'csv') {
              if (onExportCsv != null) {
                onExportCsv();
              } else {
                final path = await exportReportAsCsv(
                  reportTitle: pageTitle,
                  headers: ['Voucher Date', 'Voucher Type', 'Particulars / Account', 'Debit (₹)', 'Credit (₹)', 'Net Balance (₹)'],
                  rows: [],
                );
                if (context.mounted) showReportDownloadDialog(context, pageTitle, 'CSV (.csv)', path);
              }
            } else if (val == 'excel') {
              if (onExportExcel != null) {
                onExportExcel();
              } else {
                final path = await exportReportAsExcel(
                  reportTitle: pageTitle,
                  headers: ['Voucher Date', 'Voucher Type', 'Particulars / Account', 'Debit (₹)', 'Credit (₹)', 'Net Balance (₹)'],
                  rows: [],
                );
                if (context.mounted) showReportDownloadDialog(context, pageTitle, 'Excel (.xlsx)', path);
              }
            } else if (val == 'pdf') {
              if (onExportPdf != null) {
                onExportPdf();
              } else {
                final path = await exportReportAsPdf(
                  reportTitle: pageTitle,
                  headers: ['Voucher Date', 'Voucher Type', 'Particulars / Account', 'Debit (₹)', 'Credit (₹)', 'Net Balance (₹)'],
                  rows: [],
                );
                if (context.mounted) showReportDownloadDialog(context, pageTitle, 'PDF (.pdf)', path);
              }
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'csv',
              child: Row(
                children: const [
                  Icon(Icons.table_rows_rounded, size: 16, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Download as CSV (.csv)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'excel',
              child: Row(
                children: const [
                  Icon(Icons.grid_on_rounded, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Download as Excel (.xlsx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: const [
                  Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Download as PDF (.pdf)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _bdr),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.download_rounded, size: 14, color: _br),
                SizedBox(width: 4),
                Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _br)),
                SizedBox(width: 2),
                Icon(Icons.arrow_drop_down_rounded, size: 14, color: _br),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 16, color: _brL),
          tooltip: 'Refresh', padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    ),
    const Divider(height: 1, color: _bdr),
    if (filterWidget != null) ...[
      filterWidget,
      const Divider(height: 1, color: _bdr),
    ],
    Expanded(child: body),
  ]);
}

// ── Shared loader to fetch unified transactions ─────────────────────────────────
Future<List<Map<String, dynamic>>> _loadAllTransactions(DateTime from, DateTime to) async {
  final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
  final cashSnap = await FirebaseFirestore.instance.collection('cash_entries').get();
  final bankSnap = await FirebaseFirestore.instance.collection('bank_entries').get();
  final journalSnap = await FirebaseFirestore.instance.collection('journal_entries').get();
  final receiptSnap = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').get();
  final serviceSnap = await FirebaseFirestore.instance.collection('service_entries').get();
  final alterationSnap = await FirebaseFirestore.instance.collection('alteration_entries').get();

  final List<Map<String, dynamic>> list = [];
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

  DateTime? parseDate(Map<String, dynamic> data) {
    if (data['voucherDate'] is Timestamp) return (data['voucherDate'] as Timestamp).toDate();
    if (data['createdAt'] is Timestamp) return (data['createdAt'] as Timestamp).toDate();
    if (data['voucherDate'] != null) {
      final str = data['voucherDate'].toString();
      try { return DateFormat('dd/MM/yyyy EEE').parse(str); } catch (_) {
        try { return DateFormat('dd/MM/yyyy').parse(str); } catch (_) {}
      }
    }
    return null;
  }

  // 1. Bills
  for (final doc in billsSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final isPurch = d['billType'] == 'Purchase' || d['billType'] == 'PurchaseReturn';
    final amt = _fdbl(d['voucherAmt']); final paid = _fdbl(d['paymentAmt']);
    list.add({
      'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['acName'] ?? 'Walk-in Customer',
      'voucherType': d['billType'] ?? 'Sale', 'dr': isPurch ? paid : amt, 'cr': isPurch ? amt : paid,
      'isCash': false, 'isBank': false,
    });
  }

  // 2. Cash
  for (final doc in cashSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final double amount = _fdbl(d['amount'] ?? d['totalAmount']);
    final isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;
    list.add({
      'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['accountName'] ?? d['acName'] ?? 'Cash Account',
      'voucherType': isPayment ? 'Cash Payment' : 'Cash Receipt', 'dr': isPayment ? amount : 0.0, 'cr': isPayment ? 0.0 : amount,
      'isCash': true, 'isBank': false,
    });
  }

  // 3. Bank
  for (final doc in bankSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final double amount = _fdbl(d['amount']);
    final isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;
    list.add({
      'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['accountName'] ?? d['acName'] ?? 'Bank Account',
      'voucherType': isPayment ? 'Bank Payment' : 'Bank Receipt', 'dr': isPayment ? amount : 0.0, 'cr': isPayment ? 0.0 : amount,
      'isCash': false, 'isBank': true,
    });
  }

  // 4. Journal
  for (final doc in journalSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final double amount = _fdbl(d['amount']);
    list.add({
      'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['accountName'] ?? d['acName'] ?? 'Journal Account',
      'voucherType': 'Journal', 'dr': amount, 'cr': amount,
      'isCash': false, 'isBank': false,
    });
  }

  // 5. Multi Receipt
  for (final doc in receiptSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final cash = _fdbl(d['cashAmt'] ?? d['cashAmount']);
    final bank = _fdbl(d['bankAmt'] ?? d['bankAmount']);
    final card = _fdbl(d['cardAmt'] ?? d['cardAmount']);
    final total = cash + bank + card;
    list.add({
      'voucherNo': d['receiptNo'] ?? d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['customerName'] ?? d['acName'] ?? 'Customer',
      'voucherType': 'Multi Receipt', 'dr': 0.0, 'cr': total,
      'isCash': cash > 0, 'isBank': bank > 0 || card > 0,
    });
  }

  // 6. Service
  for (final doc in serviceSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final total = _fdbl(d['totalAmt'] ?? d['amount']);
    final isOutward = d['serviceType']?.toString().toLowerCase().contains('outward') ?? false;
    list.add({
      'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'acName': d['customerName'] ?? d['acName'] ?? 'Customer',
      'voucherType': isOutward ? 'Service Pay' : 'Service Recv', 'dr': isOutward ? total : 0.0, 'cr': isOutward ? 0.0 : total,
      'isCash': false, 'isBank': false,
    });
  }

  // 7. Alteration
  for (final doc in alterationSnap.docs) {
    final d = doc.data(); final dt = parseDate(d); if (dt == null) continue;
    if (dt.isBefore(start) || dt.isAfter(end)) continue;
    final double amount = _fdbl(d['amount'] ?? d['charges']);
    list.add({
      'voucherNo': d['voucherNo'] ?? d['alterationNo'] ?? '—', 'voucherDate': dt, 'acName': d['customerName'] ?? d['acName'] ?? 'Customer',
      'voucherType': 'Alteration Recv', 'dr': 0.0, 'cr': amount,
      'isCash': false, 'isBank': false,
    });
  }

  list.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
  return list;
}


// =============================================================================
//  1: LEDGER / ACCOUNT STATEMENT
// =============================================================================
class LedgerAccountStatementView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const LedgerAccountStatementView({super.key, this.onReportSelected});
  @override State<LedgerAccountStatementView> createState() => _LedgerAccountStatementState();
}

class _LedgerAccountStatementState extends State<LedgerAccountStatementView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _transactions = [];
  String? _selectedAccount;
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<String> get _accountOptions {
    final list = _transactions.map((t) => t['acName'].toString()).toSet().toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _transactions;
    if (_selectedAccount != null) {
      list = list.where((t) => t['acName'].toString() == _selectedAccount).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((t) => t['voucherNo'].toString().toLowerCase().contains(_q) || t['voucherType'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      if (mounted) setState(() { _transactions = tx; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accountOptions;
    final list = _filtered;

    return _aShell(
      context: context,
      pageTitle: 'Ledger / Account Statement', pageIcon: Icons.menu_book_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.person_search_outlined, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Select Account:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 280, height: 32,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedAccount,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(8)),
              ),
              hint: const Text('All Accounts (A - Z)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _brL),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Accounts', style: TextStyle(fontSize: 11))),
                ...accounts.map((n) => DropdownMenuItem<String>(value: n, child: Text(n, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _selectedAccount = v),
            ),
          ),
        ]),
      ),
      body: _loading ? _aLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _aEmpty('No ledger transactions found for this period');
    double tDr = 0, tCr = 0;
    for (final r in list) { tDr += r['dr'] as double; tCr += r['cr'] as double; }

    double runningBal = 0.0;
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: _br.withAlpha(18), child: Row(children: [
          _aTh('#', w: 40), _aTh('Date', w: 100), _aTh('Voucher No', w: 120),
          _aTh('Voucher Type', w: 120), _aTh('Particulars Name', flex: true),
          _aTh('Debit (Dr)', w: 130, r: true), _aTh('Credit (Cr)', w: 130, r: true),
          _aTh('Balance', w: 140, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.reversed.toList().asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final dr = r['dr'] as double; final cr = r['cr'] as double;
          runningBal += (dr - cr);
          final balStr = '${_ffmt(runningBal.abs())} ${runningBal >= 0 ? "Dr" : "Cr"}';
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _aTd('${i+1}', w: 40),
              _aTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100),
              _aTd(r['voucherNo'].toString(), w: 120, bold: true),
              _aTd(r['voucherType'].toString(), w: 120),
              _aTd(r['acName'].toString(), flex: true),
              _aTd(dr > 0 ? _ffmt(dr) : '—', w: 130, r: true, c: dr > 0 ? const Color(0xFFC62828) : null),
              _aTd(cr > 0 ? _ffmt(cr) : '—', w: 130, r: true, c: cr > 0 ? const Color(0xFF2E7D32) : null),
              _aTd(balStr, w: 140, r: true, bold: true),
            ]),
          );
        }).toList().reversed.toList()))),
        Container(color: _br.withAlpha(14), child: Row(children: [
          _aTt('TOTAL', w: 40), _aTt('', w: 100), _aTt('', w: 120), _aTt('', w: 120), _aTt('', flex: true),
          _aTt(_ffmt(tDr), w: 130, r: true, c: const Color(0xFFC62828)),
          _aTt(_ffmt(tCr), w: 130, r: true, c: const Color(0xFF2E7D32)),
          _aTt('${_ffmt((tDr - tCr).abs())} ${tDr >= tCr ? "Dr" : "Cr"}', w: 140, r: true),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  2: DAY BOOK REPORT
// =============================================================================
class DayBookReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const DayBookReportView({super.key, this.onReportSelected});
  @override State<DayBookReportView> createState() => _DayBookReportState();
}

class _DayBookReportState extends State<DayBookReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _transactions = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _transactions
      : _transactions.where((t) => t['acName'].toString().toLowerCase().contains(_q) || t['voucherNo'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      if (mounted) setState(() { _transactions = tx; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => _aShell(
    context: context,
    pageTitle: 'Day Book Report', pageIcon: Icons.view_day_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    body: _loading ? _aLoader : _buildTable(),
  );

  Widget _buildTable() {
    final list = _filtered;
    if (list.isEmpty) return _aEmpty('No day book entries recorded for this date range');
    double tDr = 0, tCr = 0;
    for (final r in list) { tDr += r['dr'] as double; tCr += r['cr'] as double; }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: const Color(0xFFE65100).withAlpha(18), child: Row(children: [
          _aTh('#', w: 40), _aTh('Date', w: 100), _aTh('Voucher No', w: 120),
          _aTh('Voucher Type', w: 120), _aTh('Account Name', flex: true),
          _aTh('Debit (Dr)', w: 140, r: true), _aTh('Credit (Cr)', w: 140, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final dr = r['dr'] as double; final cr = r['cr'] as double;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _aTd('${i+1}', w: 40),
              _aTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100),
              _aTd(r['voucherNo'].toString(), w: 120, bold: true),
              _aTd(r['voucherType'].toString(), w: 120),
              _aTd(r['acName'].toString(), flex: true),
              _aTd(dr > 0 ? _ffmt(dr) : '—', w: 140, r: true, c: dr > 0 ? const Color(0xFFC62828) : null),
              _aTd(cr > 0 ? _ffmt(cr) : '—', w: 140, r: true, c: cr > 0 ? const Color(0xFF2E7D32) : null),
            ]),
          );
        }).toList()))),
        Container(color: const Color(0xFFE65100).withAlpha(14), child: Row(children: [
          _aTt('TOTAL', w: 40), _aTt('', w: 100), _aTt('', w: 120), _aTt('', w: 120), _aTt('', flex: true),
          _aTt(_ffmt(tDr), w: 140, r: true, c: const Color(0xFFC62828)),
          _aTt(_ffmt(tCr), w: 140, r: true, c: const Color(0xFF2E7D32)),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  3: CASH / BANK BOOK REPORT
// =============================================================================
class CashBankBookReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CashBankBookReportView({super.key, this.onReportSelected});
  @override State<CashBankBookReportView> createState() => _CashBankBookReportState();
}

class _CashBankBookReportState extends State<CashBankBookReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _transactions = [];
  String _modeFilter = 'All'; // 'All', 'Cash Only', 'Bank Only'

  @override void initState() { super.initState(); _load(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _transactions.where((t) => t['isCash'] == true || t['isBank'] == true).toList();
    if (_modeFilter == 'Cash Only') list = list.where((t) => t['isCash'] == true).toList();
    if (_modeFilter == 'Bank Only') list = list.where((t) => t['isBank'] == true).toList();
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      if (mounted) setState(() { _transactions = tx; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _aShell(
      context: context,
      pageTitle: 'Cash / Bank Book Report', pageIcon: Icons.account_balance_wallet_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length,
      onReportSelected: widget.onReportSelected,
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.filter_list_rounded, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Filter Book:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Cash Only', 'Bank Only'].map((mode) {
            final sel = _modeFilter == mode;
            return GestureDetector(
              onTap: () => setState(() => _modeFilter = mode),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _br : _br.withAlpha(12), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(mode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : _br)),
              ),
            );
          }),
        ]),
      ),
      body: _loading ? _aLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _aEmpty('No cash or bank book movements found for this range');
    double tDr = 0, tCr = 0;
    for (final r in list) { tDr += r['dr'] as double; tCr += r['cr'] as double; }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: const Color(0xFF00695C).withAlpha(18), child: Row(children: [
          _aTh('#', w: 40), _aTh('Date', w: 100), _aTh('Voucher No', w: 120),
          _aTh('Particulars Book/Name', flex: true),
          _aTh('Receipts (Dr)', w: 150, r: true), _aTh('Payments (Cr)', w: 150, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final dr = r['dr'] as double; final cr = r['cr'] as double;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _aTd('${i+1}', w: 40),
              _aTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100),
              _aTd(r['voucherNo'].toString(), w: 120, bold: true),
              _aTd('${r['acName']} (${r['isCash'] == true ? "Cash" : "Bank"})', flex: true),
              _aTd(dr > 0 ? _ffmt(dr) : '—', w: 150, r: true, c: const Color(0xFF2E7D32)),
              _aTd(cr > 0 ? _ffmt(cr) : '—', w: 150, r: true, c: const Color(0xFFC62828)),
            ]),
          );
        }).toList()))),
        Container(color: const Color(0xFF00695C).withAlpha(14), child: Row(children: [
          _aTt('TOTAL', w: 40), _aTt('', w: 100), _aTt('', w: 120), _aTt('', flex: true),
          _aTt(_ffmt(tDr), w: 150, r: true, c: const Color(0xFF2E7D32)),
          _aTt(_ffmt(tCr), w: 150, r: true, c: const Color(0xFFC62828)),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  4: TRIAL BALANCE REPORT
// =============================================================================
class TrialBalanceReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const TrialBalanceReportView({super.key, this.onReportSelected});
  @override State<TrialBalanceReportView> createState() => _TrialBalanceReportState();
}

class _TrialBalanceReportState extends State<TrialBalanceReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _balances = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _balances
      : _balances.where((b) => b['acName'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final r in tx) {
        final name = r['acName'].toString();
        final dr = r['dr'] as double;
        final cr = r['cr'] as double;

        final e = grouped.putIfAbsent(name.toLowerCase(), () => {
          'acName': name, 'drAmt': 0.0, 'crAmt': 0.0,
        });
        e['drAmt'] = (e['drAmt'] as double) + dr;
        e['crAmt'] = (e['crAmt'] as double) + cr;
      }

      final list = grouped.values.toList()
        ..sort((a, b) => a['acName'].toString().compareTo(b['acName'].toString()));

      if (mounted) setState(() { _balances = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => _aShell(
    context: context,
    pageTitle: 'Trial Balance Report', pageIcon: Icons.account_balance_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    body: _loading ? _aLoader : _buildTable(),
  );

  Widget _buildTable() {
    final list = _filtered;
    if (list.isEmpty) return _aEmpty('No trial balance ledger records found');
    double tDr = 0, tCr = 0;
    for (final r in list) { tDr += r['drAmt'] as double; tCr += r['crAmt'] as double; }

    const color = Color(0xFF1565C0);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _aTh('#', w: 40), _aTh('Account Ledger Name', flex: true),
          _aTh('Transaction Debit (Dr)', w: 180, r: true), _aTh('Transaction Credit (Cr)', w: 180, r: true),
          _aTh('Closing Balance', w: 180, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final dr = r['drAmt'] as double; final cr = r['crAmt'] as double;
          final bal = dr - cr;
          final balStr = '${_ffmt(bal.abs())} ${bal >= 0 ? "Dr" : "Cr"}';
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _aTd('${i+1}', w: 40),
              _aTd(r['acName'].toString(), flex: true, bold: true),
              _aTd(dr > 0 ? _ffmt(dr) : '—', w: 180, r: true),
              _aTd(cr > 0 ? _ffmt(cr) : '—', w: 180, r: true),
              _aTd(bal != 0.0 ? balStr : '—', w: 180, r: true, bold: true, c: bal >= 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _aTt('TOTAL', w: 40), _aTt('', flex: true),
          _aTt(_ffmt(tDr), w: 180, r: true, c: const Color(0xFFC62828)),
          _aTt(_ffmt(tCr), w: 180, r: true, c: const Color(0xFF2E7D32)),
          _aTt('${_ffmt((tDr - tCr).abs())} ${tDr >= tCr ? "Dr" : "Cr"}', w: 180, r: true),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  5: PROFIT & LOSS ACCOUNT
// =============================================================================
class ProfitLossAccountView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const ProfitLossAccountView({super.key, this.onReportSelected});
  @override State<ProfitLossAccountView> createState() => _ProfitLossAccountState();
}

class _ProfitLossAccountState extends State<ProfitLossAccountView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  double _sales = 0.0, _purchases = 0.0, _expenses = 0.0;
  List<Map<String, dynamic>> _soldItems = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      double s = 0, p = 0, exp = 0;

      for (final r in tx) {
        final t = r['voucherType'].toString().toLowerCase();
        final ac = r['acName'].toString().toUpperCase();
        final dr = r['dr'] as double;
        final cr = r['cr'] as double;

        if (t.contains('sale')) {
          s += dr;
        } else if (t.contains('purchase')) {
          p += cr;
        } else if (ac.contains('EXPENSE') || ac.contains('RENT') || ac.contains('SALARY') || t.contains('payment')) {
          exp += dr;
        }
      }

      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final List<Map<String, dynamic>> itemsList = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in billsSnap.docs) {
        final d = doc.data();
        DateTime? dt;
        if (d['voucherDate'] is Timestamp) {
          dt = (d['voucherDate'] as Timestamp).toDate();
        } else if (d['createdAt'] is Timestamp) {
          dt = (d['createdAt'] as Timestamp).toDate();
        } else if (d['voucherDate'] != null) {
          try { dt = DateFormat('dd/MM/yyyy EEE').parse(d['voucherDate'].toString()); } catch (_) {
            try { dt = DateFormat('dd/MM/yyyy').parse(d['voucherDate'].toString()); } catch (_) {}
          }
        }
        if (dt == null || dt.isBefore(start) || dt.isAfter(end)) continue;

        final billType = d['billType']?.toString() ?? 'Sale';
        if (billType == 'Purchase' || billType == 'PurchaseReturn') continue;

        final items = d['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final tagId = (map['tagId'] ?? map['barcode'] ?? map['labelNo'] ?? '—').toString();
            final itemName = (map['name'] ?? map['productName'] ?? map['itemName'] ?? 'Gold Item').toString();
            final grossWt = _fdbl(map['grossWeight'] ?? map['grossWt']);
            final saleRate = _fdbl(map['rate'] ?? map['metalRateSale']);
            final costRate = _fdbl(map['costRate']) > 0 ? _fdbl(map['costRate']) : (saleRate > 0 ? saleRate : 0.0);
            
            double purchaseCost = _fdbl(map['purchaseCost']);
            if (purchaseCost <= 0) {
              purchaseCost = grossWt * costRate;
            }

            double salesPrice = _fdbl(map['salesPrice']);
            if (salesPrice <= 0) {
              final totMetalAmt = _fdbl(map['totMetalAmt']);
              final labourAmt = _fdbl(map['labourAmt']);
              if (totMetalAmt > 0) {
                salesPrice = totMetalAmt + labourAmt;
              } else {
                salesPrice = grossWt * saleRate;
              }
            }

            double profitAmount = map['profitAmount'] != null ? _fdbl(map['profitAmount']) : (salesPrice - purchaseCost);
            double profitPercentage = map['profitPercentage'] != null ? _fdbl(map['profitPercentage']) : (purchaseCost > 0 ? ((profitAmount / purchaseCost) * 100) : 0.0);

            itemsList.add({
              'tagId': tagId,
              'itemName': itemName,
              'grossWt': grossWt,
              'purchaseCost': purchaseCost,
              'salesPrice': salesPrice,
              'profitAmount': profitAmount,
              'profitPercentage': profitPercentage,
              'voucherDate': dt,
              'voucherNo': d['voucherNo'] ?? '',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _sales = s;
          _purchases = p;
          _expenses = exp;
          _soldItems = itemsList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic> _getExportData() {
    final headers = ['#', 'Master Tag', 'Item Name', 'Gross Wt', 'Purchase Cost (₹)', 'Sales Price (₹)', 'Profit Amount (₹)', 'Profit %'];
    final exportRows = <List<dynamic>>[];
    double totalGrossWt = 0.0;
    double totalPurchaseCost = 0.0;
    double totalSalesPrice = 0.0;
    double totalProfitAmount = 0.0;

    for (int i = 0; i < _soldItems.length; i++) {
      final r = _soldItems[i];
      final gross = _fdbl(r['grossWt']);
      final pCost = _fdbl(r['purchaseCost']);
      final sPrice = _fdbl(r['salesPrice']);
      final pAmt = _fdbl(r['profitAmount']);
      final pPct = _fdbl(r['profitPercentage']);

      totalGrossWt += gross;
      totalPurchaseCost += pCost;
      totalSalesPrice += sPrice;
      totalProfitAmount += pAmt;

      exportRows.add([
        '${i + 1}',
        (r['tagId'] ?? '—').toString().replaceAll(RegExp(r'\[\d+\]$'), ''),
        r['itemName'] ?? '—',
        '${gross.toStringAsFixed(3)} g',
        _ffmt(pCost),
        _ffmt(sPrice),
        _ffmt(pAmt),
        '${pPct.toStringAsFixed(2)}%',
      ]);
    }

    final double overallProfitPct = totalPurchaseCost > 0 ? ((totalProfitAmount / totalPurchaseCost) * 100) : 0.0;
    exportRows.add([
      'TOTAL',
      '',
      '',
      '${totalGrossWt.toStringAsFixed(3)} g',
      _ffmt(totalPurchaseCost),
      _ffmt(totalSalesPrice),
      _ffmt(totalProfitAmount),
      '${overallProfitPct.toStringAsFixed(2)}%',
    ]);

    return {
      'headers': headers,
      'rows': exportRows,
    };
  }

  @override
  Widget build(BuildContext context) => _aShell(
    context: context,
    pageTitle: 'Profit & Loss Account', pageIcon: Icons.assessment_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _soldItems.length,
    onReportSelected: widget.onReportSelected,
    onExportCsv: () async {
      final data = _getExportData();
      final path = await exportReportAsCsv(reportTitle: 'Profit & Loss Account', headers: data['headers'], rows: data['rows']);
      if (!context.mounted) return; showReportDownloadDialog(context, 'Profit & Loss Account', 'CSV (.csv)', path);
    },
    onExportExcel: () async {
      final data = _getExportData();
      final path = await exportReportAsExcel(reportTitle: 'Profit & Loss Account', headers: data['headers'], rows: data['rows']);
      if (!context.mounted) return; showReportDownloadDialog(context, 'Profit & Loss Account', 'Excel (.xlsx)', path);
    },
    onExportPdf: () async {
      final data = _getExportData();
      final path = await exportReportAsPdf(reportTitle: 'Profit & Loss Account', headers: data['headers'], rows: data['rows']);
      if (!context.mounted) return; showReportDownloadDialog(context, 'Profit & Loss Account', 'PDF (.pdf)', path);
    },
    body: _loading ? _aLoader : _buildSheet(),
  );

  Widget _buildSheet() {
    final gp = _sales - _purchases;
    final np = gp - _expenses;
    const color = Color(0xFFD84315);

    double totalGrossWt = 0.0;
    double totalPurchaseCost = 0.0;
    double totalSalesPrice = 0.0;
    double totalProfitAmount = 0.0;

    for (final item in _soldItems) {
      totalGrossWt += _fdbl(item['grossWt']);
      totalPurchaseCost += _fdbl(item['purchaseCost']);
      totalSalesPrice += _fdbl(item['salesPrice']);
      totalProfitAmount += _fdbl(item['profitAmount']);
    }

    final double overallProfitPct = totalPurchaseCost > 0 ? ((totalProfitAmount / totalPurchaseCost) * 100) : 0.0;

    Widget summaryItem(String label, double val, {bool isCr = false, bool bold = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _bdr, width: 0.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(_ffmt(val), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCr ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Top Trading & P&L Statement Card
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Container(
                    color: color.withAlpha(20), padding: const EdgeInsets.all(14),
                    child: const Row(children: [
                      Icon(Icons.pie_chart_outline_rounded, color: color, size: 18),
                      SizedBox(width: 8),
                      Text('Trading & Profit & Loss Statement Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                    ]),
                  ),
                  summaryItem('Revenue from Sales (+)', _sales, isCr: true),
                  summaryItem('Cost of Goods Sold (Purchases) (-)', _purchases),
                  summaryItem('GROSS PROFIT', gp, isCr: gp >= 0, bold: true),
                  summaryItem('Indirect Expenses (Rent, Salary, Bills) (-)', _expenses),
                  Container(
                    color: np >= 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(np >= 0 ? 'NET PROFIT (Income Surplus)' : 'NET LOSS (Deficit)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(_ffmt(np.abs()), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: np >= 0 ? const Color(0xFF1B5E20) : const Color(0xFFC62828))),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Itemized P&L Table Header & Content
            Container(
              decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EEDD),
                      border: Border(bottom: BorderSide(color: _bdr)),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.table_chart_rounded, size: 18, color: _br),
                        SizedBox(width: 8),
                        Text(
                          'Profit & Loss Account - Sold Items Detail',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _br),
                        ),
                      ],
                    ),
                  ),
                  if (_soldItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: _aEmpty('No sold items found in this date range'),
                    )
                  else ...[
                    Container(
                      color: _br.withAlpha(18),
                      child: Row(
                        children: [
                          _aTh('#', w: 40),
                          _aTh('Master Tag', w: 140),
                          _aTh('Item Name', flex: true),
                          _aTh('Gross Wt', w: 100, r: true),
                          _aTh('Purchase Cost (₹)', w: 140, r: true),
                          _aTh('Sales Price (₹)', w: 140, r: true),
                          _aTh('Profit Amount (₹)', w: 140, r: true),
                          _aTh('Profit %', w: 100, r: true),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _bdr),
                    Column(
                      children: _soldItems.asMap().entries.map((e) {
                        final i = e.key;
                        final r = e.value;
                        final double prof = _fdbl(r['profitAmount']);
                        final double profPct = _fdbl(r['profitPercentage']);

                        return Container(
                          decoration: BoxDecoration(
                            color: i.isEven ? Colors.white : const Color(0xFFFAF7F3),
                            border: const Border(bottom: BorderSide(color: _bdr, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              _aTd('${i + 1}', w: 40),
                              _aTd(r['tagId'].toString().replaceAll(RegExp(r'\[\d+\]$'), ''), w: 140, bold: true),
                              _aTd(r['itemName'].toString(), flex: true),
                              _aTd('${_fdbl(r['grossWt']).toStringAsFixed(3)} g', w: 100, r: true),
                              _aTd(_ffmt(_fdbl(r['purchaseCost'])), w: 140, r: true),
                              _aTd(_ffmt(_fdbl(r['salesPrice'])), w: 140, r: true),
                              _aTd(
                                _ffmt(prof),
                                w: 140,
                                r: true,
                                bold: true,
                                c: prof >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              ),
                              _aTd(
                                '${profPct.toStringAsFixed(2)}%',
                                w: 100,
                                r: true,
                                bold: true,
                                c: profPct >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    Container(
                      color: _br.withAlpha(20),
                      child: Row(
                        children: [
                          _aTt('TOTAL', w: 40),
                          _aTt('', w: 140),
                          _aTt('', flex: true),
                          _aTt('${totalGrossWt.toStringAsFixed(3)} g', w: 100, r: true),
                          _aTt(_ffmt(totalPurchaseCost), w: 140, r: true),
                          _aTt(_ffmt(totalSalesPrice), w: 140, r: true),
                          _aTt(
                            _ffmt(totalProfitAmount),
                            w: 140,
                            r: true,
                            c: totalProfitAmount >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                          _aTt(
                            '${overallProfitPct.toStringAsFixed(2)}%',
                            w: 100,
                            r: true,
                            c: overallProfitPct >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  6: BALANCE SHEET REPORT
// =============================================================================
class BalanceSheetReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const BalanceSheetReportView({super.key, this.onReportSelected});
  @override State<BalanceSheetReportView> createState() => _BalanceSheetReportState();
}

class _BalanceSheetReportState extends State<BalanceSheetReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  double _receivables = 0.0, _payables = 0.0, _cashBal = 0.0, _bankBal = 0.0, _surplus = 0.0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      double cash = 0, bank = 0, p = 0, s = 0;

      for (final r in tx) {
        final amt = r['dr'] as double;
        final cr = r['cr'] as double;
        final t = r['voucherType'].toString().toLowerCase();

        if (r['isCash'] == true) {
          cash += (amt - cr);
        } else if (r['isBank'] == true) {
          bank += (amt - cr);
        }
        if (t.contains('sale')) { s += amt; }
        else if (t.contains('purchase')) { p += cr; }
      }

      // Receivables and Payables aggregates
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      double rec = 0, pay = 0;
      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final due = _fdbl(d['dueAmt']);
        final bt = d['billType']?.toString() ?? '';
        if (bt == 'Purchase') {
          pay += due;
        } else {
          rec += due;
        }
      }

      if (mounted) {
        setState(() {
          _receivables = rec;
          _payables = pay;
          _cashBal = cash;
          _bankBal = bank;
          _surplus = s - p; // Net surplus
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => _aShell(
    context: context,
    pageTitle: 'Balance Sheet Report', pageIcon: Icons.account_balance_wallet_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: 5,
    onReportSelected: widget.onReportSelected,
    body: _loading ? _aLoader : _buildSheet(),
  );

  Widget _buildSheet() {
    final assets = _receivables + _cashBal.abs() + _bankBal.abs();
    final liabilities = _payables + (_surplus < 0 ? _surplus.abs() : 0.0);
    const color = Color(0xFF00838F);

    Widget rowItem(String l, double v, {bool isCr = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _bdr, width: 0.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(fontSize: 11)),
          Text(_ffmt(v), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCr ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Left: Liabilities
            Expanded(child: Container(
              decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(color: color.withAlpha(20), padding: const EdgeInsets.all(12),
                  child: const Row(children: [
                    Icon(Icons.gavel_rounded, color: color, size: 16),
                    SizedBox(width: 8),
                    Text('Liabilities & Capital', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ])),
                rowItem('Sundry Creditors (Suppliers Outstanding)', _payables),
                rowItem('Retained Profit surplus/capital', _surplus > 0 ? _surplus : 0.0, isCr: true),
                rowItem('Short-term Loans', 0.0),
                Container(color: _bg1, padding: const EdgeInsets.all(12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Liabilities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(_ffmt(liabilities), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _br)),
                  ])),
              ]),
            )),
            const SizedBox(width: 24),
            // Right: Assets
            Expanded(child: Container(
              decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(color: const Color(0xFF2E7D32).withAlpha(20), padding: const EdgeInsets.all(12),
                  child: const Row(children: [
                    Icon(Icons.domain_rounded, color: Color(0xFF2E7D32), size: 16),
                    SizedBox(width: 8),
                    Text('Assets & Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  ])),
                rowItem('Sundry Debtors (Customers Outstanding)', _receivables, isCr: true),
                rowItem('Cash In Hand', _cashBal.abs(), isCr: true),
                rowItem('Bank Accounts balance', _bankBal.abs(), isCr: true),
                Container(color: _bg1, padding: const EdgeInsets.all(12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Assets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(_ffmt(assets), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  ])),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
//  7: GROUP SUMMARY REPORT
// =============================================================================
class GroupSummaryReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const GroupSummaryReportView({super.key, this.onReportSelected});
  @override State<GroupSummaryReportView> createState() => _GroupSummaryReportState();
}

class _GroupSummaryReportState extends State<GroupSummaryReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _groups = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await _loadAllTransactions(_from, _to);
      final Map<String, Map<String, dynamic>> cats = {};

      for (final r in tx) {
        final cat = r['voucherType'].toString().toLowerCase().contains('sale') ? 'Sundry Debtors'
                  : r['voucherType'].toString().toLowerCase().contains('purchase') ? 'Sundry Creditors'
                  : r['isCash'] == true ? 'Cash Balance'
                  : r['isBank'] == true ? 'Bank Accounts'
                  : 'Indirect Expenses';

        final dr = r['dr'] as double;
        final cr = r['cr'] as double;

        final e = cats.putIfAbsent(cat, () => {
          'groupHead': cat, 'drAmt': 0.0, 'crAmt': 0.0, 'records': 0,
        });

        e['drAmt'] = (e['drAmt'] as double) + dr;
        e['crAmt'] = (e['crAmt'] as double) + cr;
        e['records'] = (e['records'] as int) + 1;
      }

      if (mounted) setState(() { _groups = cats.values.toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => _aShell(
    context: context,
    pageTitle: 'Group Summary Report', pageIcon: Icons.folder_shared_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _aPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _groups.length,
    onReportSelected: widget.onReportSelected,
    body: _loading ? _aLoader : _buildTable(),
  );

  Widget _buildTable() {
    final list = _groups;
    if (list.isEmpty) return _aEmpty('No group summary records found');
    double tDr = 0, tCr = 0;
    for (final r in list) { tDr += r['drAmt'] as double; tCr += r['crAmt'] as double; }

    const color = Color(0xFFE65100);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _aTh('#', w: 40), _aTh('Group Head Name', flex: true), _aTh('Records count', w: 120),
          _aTh('Total Debit (Dr)', w: 180, r: true), _aTh('Total Credit (Cr)', w: 180, r: true),
          _aTh('Net Balance', w: 180, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final dr = r['drAmt'] as double; final cr = r['crAmt'] as double;
          final bal = dr - cr;
          final balStr = '${_ffmt(bal.abs())} ${bal >= 0 ? "Dr" : "Cr"}';
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _aTd('${i+1}', w: 40),
              _aTd(r['groupHead'].toString(), flex: true, bold: true),
              _aTd('${r['records']} Vouchers', w: 120),
              _aTd(dr > 0 ? _ffmt(dr) : '—', w: 180, r: true),
              _aTd(cr > 0 ? _ffmt(cr) : '—', w: 180, r: true),
              _aTd(balStr, w: 180, r: true, bold: true, c: bal >= 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _aTt('TOTAL', w: 40), _aTt('', flex: true), _aTt('', w: 120),
          _aTt(_ffmt(tDr), w: 180, r: true, c: const Color(0xFFC62828)),
          _aTt(_ffmt(tCr), w: 180, r: true, c: const Color(0xFF2E7D32)),
          _aTt('${_ffmt((tDr - tCr).abs())} ${tDr >= tCr ? "Dr" : "Cr"}', w: 180, r: true),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  8: AMOUNT DETAILS
// =============================================================================
class AmountDetailsView extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  final ValueChanged<String>? onReportSelected;
  const AmountDetailsView({
    super.key,
    required this.from,
    required this.to,
    this.onReportSelected,
  });
  @override State<AmountDetailsView> createState() => _AmountDetailsState();
}

class _AmountDetailsState extends State<AmountDetailsView> {
  bool _loading = true;
  double _cashBalance = 0.0;
  Map<String, double> _bankBalances = {};

  @override void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(AmountDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.from != oldWidget.from || widget.to != oldWidget.to) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      double cash = 0.0;
      final Map<String, double> banks = {};

      final bookSnap = await FirebaseFirestore.instance.collection('book_names').get();
      for (final doc in bookSnap.docs) {
        final name = doc.data()['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          banks[name] = 0.0;
        }
      }

      void addBankIfMissing(String name) {
        final clean = name.trim();
        if (clean.isEmpty || clean.toLowerCase().contains('cash')) return;
        if (!banks.containsKey(clean)) {
          banks[clean] = 0.0;
        }
      }

      double parseDbl(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final cashSnap = await FirebaseFirestore.instance.collection('cash_entries').get();
      final bankSnap = await FirebaseFirestore.instance.collection('bank_entries').get();
      final receiptSnap = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').get();

      final start = DateTime(widget.from.year, widget.from.month, widget.from.day);
      final end = DateTime(widget.to.year, widget.to.month, widget.to.day, 23, 59, 59, 999);

      DateTime? parseDate(Map<String, dynamic> data) {
        if (data['voucherDate'] is Timestamp) return (data['voucherDate'] as Timestamp).toDate();
        if (data['createdAt'] is Timestamp) return (data['createdAt'] as Timestamp).toDate();
        if (data['voucherDate'] != null) {
          final str = data['voucherDate'].toString();
          try { return DateFormat('dd/MM/yyyy EEE').parse(str); } catch (_) {
            try { return DateFormat('dd/MM/yyyy').parse(str); } catch (_) {}
          }
        }
        return null;
      }

      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final isPurch = d['billType'] == 'Purchase' || d['billType'] == 'PurchaseReturn';
        final cashPaid = parseDbl(d['cashAmt'] ?? d['cashAmount']);
        final bankPaid = parseDbl(d['bankAmt'] ?? d['bankAmount']);
        final bankName = (d['bankName'] ?? '').toString().trim();

        if (isPurch) {
          cash -= cashPaid;
          if (bankName.isNotEmpty && bankPaid > 0) {
            addBankIfMissing(bankName);
            banks[bankName] = (banks[bankName] ?? 0.0) - bankPaid;
          }
        } else {
          cash += cashPaid;
          if (bankName.isNotEmpty && bankPaid > 0) {
            addBankIfMissing(bankName);
            banks[bankName] = (banks[bankName] ?? 0.0) + bankPaid;
          }
        }
      }

      for (final doc in cashSnap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final amt = parseDbl(d['amount'] ?? d['totalAmount']);
        final type = d['voucherType']?.toString().toLowerCase() ?? '';
        final isPayment = type.contains('payment');
        final acName = (d['accountName'] ?? d['acName'] ?? '').toString().trim();

        if (isPayment) {
          cash -= amt;
          if (acName.toLowerCase().contains('sbi') || acName.toLowerCase().contains('hdfc') || acName.toLowerCase().contains('bank') || banks.containsKey(acName)) {
            addBankIfMissing(acName);
            banks[acName] = (banks[acName] ?? 0.0) + amt;
          }
        } else {
          cash += amt;
          if (acName.toLowerCase().contains('sbi') || acName.toLowerCase().contains('hdfc') || acName.toLowerCase().contains('bank') || banks.containsKey(acName)) {
            addBankIfMissing(acName);
            banks[acName] = (banks[acName] ?? 0.0) - amt;
          }
        }
      }

      for (final doc in bankSnap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final amt = parseDbl(d['amount'] ?? d['totalAmount']);
        final bankName = (d['bookName'] ?? '').toString().trim();
        if (bankName.isEmpty) continue;
        addBankIfMissing(bankName);

        final type = d['voucherType']?.toString().toLowerCase() ?? '';
        final isPayment = type.contains('payment');
        final acName = (d['accountName'] ?? d['acName'] ?? '').toString().trim();

        if (isPayment) {
          banks[bankName] = (banks[bankName] ?? 0.0) - amt;
          if (acName.toLowerCase().contains('cash')) {
            cash += amt;
          }
        } else {
          banks[bankName] = (banks[bankName] ?? 0.0) + amt;
          if (acName.toLowerCase().contains('cash')) {
            cash -= amt;
          }
        }
      }

      for (final doc in receiptSnap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        if (d['rows'] is List && (d['rows'] as List).isNotEmpty) {
          for (final row in (d['rows'] as List)) {
            final double rowAmt = parseDbl(row['amount']);
            final String crDr = (row['crDr'] ?? 'CR').toString().toUpperCase();
            final String bookName = (row['book'] ?? '').toString().trim();

            if (bookName.isNotEmpty) {
              final isCash = bookName.toLowerCase().contains('cash');
              if (isCash) {
                if (crDr == 'CR') {
                  cash += rowAmt;
                } else {
                  cash -= rowAmt;
                }
              } else {
                addBankIfMissing(bookName);
                if (crDr == 'CR') {
                  banks[bookName] = (banks[bookName] ?? 0.0) + rowAmt;
                } else {
                  banks[bookName] = (banks[bookName] ?? 0.0) - rowAmt;
                }
              }
            }
          }
        } else {
          final cashAmt = parseDbl(d['cashAmt'] ?? d['cashAmount']);
          final bankAmt = parseDbl(d['bankAmt'] ?? d['bankAmount'] ?? d['bankAmt'] ?? d['cardAmt'] ?? d['cardAmount']);
          final bankName = (d['bankName'] ?? d['partyBank'] ?? '').toString().trim();

          cash += cashAmt;
          if (bankName.isNotEmpty && bankAmt > 0) {
            addBankIfMissing(bankName);
            banks[bankName] = (banks[bankName] ?? 0.0) + bankAmt;
          }
        }
      }

      if (mounted) {
        setState(() {
          _cashBalance = cash;
          _bankBalances = banks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _aLoader;
    }

    double totalBankSum = 0.0;
    _bankBalances.forEach((_, val) => totalBankSum += val);
    final totalSum = _cashBalance + totalBankSum;

    final List<Map<String, dynamic>> rows = [
      {
        'type': 'Cash',
        'name': 'Cash In Hand',
        'balance': _cashBalance,
      }
    ];

    _bankBalances.forEach((name, bal) {
      rows.add({
        'type': 'Bank',
        'name': name,
        'balance': bal,
      });
    });

    const accentColor = Color(0xFF0288D1);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL CASH & BANK BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        '${totalSum >= 0 ? "+" : "-"} ${_ffmt(totalSum.abs())}',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: totalSum >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Container(
                    color: accentColor.withAlpha(18),
                    child: Row(
                      children: [
                        _aTh('#', w: 50),
                        _aTh('Account Type', w: 150),
                        _aTh('Account / Bank Name', flex: true),
                        _aTh('Balance Amount', w: 200, r: true),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _bdr),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: rows.asMap().entries.map((e) {
                          final r = e.value;
                          final i = e.key;
                          final double bal = r['balance'] as double;
                          final balStr = '${bal >= 0 ? "+" : "-"} ${_ffmt(bal.abs())}';

                          return Container(
                            decoration: BoxDecoration(
                              color: i.isEven ? Colors.white : const Color(0xFFFAF7F3),
                              border: const Border(bottom: BorderSide(color: _bdr, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                _aTd('${i + 1}', w: 50),
                                _aTd(r['type'].toString(), w: 150, bold: true),
                                _aTd(r['name'].toString(), flex: true),
                                _aTd(
                                  balStr,
                                  w: 200,
                                  r: true,
                                  bold: true,
                                  c: bal >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(
                    color: accentColor.withAlpha(14),
                    child: Row(
                      children: [
                        _aTt('TOTAL', w: 50),
                        _aTt('', w: 150),
                        _aTt('', flex: true),
                        _aTt('${totalSum >= 0 ? "+" : "-"} ${_ffmt(totalSum.abs())}', w: 200, r: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

