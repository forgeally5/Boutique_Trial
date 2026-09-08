// approval_consignment_reports.dart
// E Approval / Consignment Reports — Approval Pending Register & Consignment Issue/Receipt Report

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../report_shared.dart';
import '../b_account_reports/account_reports.dart';

const _br  = Color(0xFF3E2723);
const _brL = Color(0xFF6D4C41);
const _bdr = Color(0xFFE5DDD0);
const _bg0 = Color(0xFFFDFBF7);

double _fdbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
String _ffmt(double v)  => NumberFormat('#,##,##0.00', 'en_IN').format(v);

Future<DateTimeRange?> _apPickRange(BuildContext ctx, DateTimeRange cur) =>
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

Widget _apLoader = const Center(child: CircularProgressIndicator(color: _br));

Widget _apEmpty(String msg) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.assignment_turned_in_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );

Widget _apTh(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _apTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, overflow: TextOverflow.ellipsis,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: c ?? Colors.black87)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _apTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c ?? _br)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _apShell({
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
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
          child: Text('$totalRecords items',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
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
        const SizedBox(width: 6),
        if (onExportCsv != null || onExportExcel != null || onExportPdf != null) ...[
          PopupMenuButton<String>(
            tooltip: 'Download Report',
            onSelected: (val) {
              if (val == 'csv' && onExportCsv != null) onExportCsv();
              if (val == 'excel' && onExportExcel != null) onExportExcel();
              if (val == 'pdf' && onExportPdf != null) onExportPdf();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: _bdr),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 13, color: _brL),
                  SizedBox(width: 6),
                  Text(
                    'Download',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 13, color: _brL),
                ],
              ),
            ),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_rows_rounded, size: 16, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Download as CSV (.csv)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.grid_on_rounded, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Download as Excel (.xls)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Download as PDF (.pdf)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
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


// =============================================================================
//  A: APPROVAL PENDING REGISTER
// =============================================================================
class ApprovalPendingRegisterView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const ApprovalPendingRegisterView({super.key, this.onReportSelected});
  @override State<ApprovalPendingRegisterView> createState() => _ApprovalPendingRegisterState();
}

class _ApprovalPendingRegisterState extends State<ApprovalPendingRegisterView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 90));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _statusFilter = 'Pending'; // 'All', 'Pending', 'Returned', 'Billed'
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_statusFilter != 'All') {
      list = list.where((r) => r['status']?.toString().toLowerCase() == _statusFilter.toLowerCase()).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) =>
          r['acName'].toString().toLowerCase().contains(_q) ||
          r['voucherNo'].toString().toLowerCase().contains(_q) ||
          r['itemName'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('approval_entries').get();
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

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

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        list.add({
          'docId': doc.id,
          'voucherNo': d['voucherNo'] ?? d['approvalNo'] ?? 'AP-${doc.id.substring(0, 4)}',
          'voucherDate': dt,
          'acName': d['acName'] ?? d['customerName'] ?? 'Walk-in Customer',
          'itemName': d['itemName'] ?? 'Gold Jewelry Item',
          'carat': d['carat']?.toString() ?? '22K',
          'grossWeight': _fdbl(d['grossWeight'] ?? d['grossWt']),
          'netWeight': _fdbl(d['netWeight'] ?? d['netWt']),
          'pcs': (d['pcs'] ?? d['pieces'] ?? d['qty'] ?? 1) as int,
          'amount': _fdbl(d['amount'] ?? d['totalAmt'] ?? d['voucherAmt']),
          'status': d['status']?.toString() ?? 'Pending', // Pending, Returned, Billed
          'rawDoc': d,
        });
      }

      list.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Party Name', 'Item Name', 'Carat', 'Gross Wt', 'Net Wt', 'Pcs', 'Amount', 'Status'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime),
      r['acName']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      r['carat']?.toString() ?? '',
      _fdbl(r['grossWeight']).toStringAsFixed(3),
      _fdbl(r['netWeight']).toStringAsFixed(3),
      r['pcs']?.toString() ?? '1',
      _ffmt(_fdbl(r['amount'])),
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Approval Pending Register', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Approval Pending Register', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Approval Pending Register', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Approval Pending Register', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _apShell(
      context: context,
      pageTitle: 'Approval Pending Register', pageIcon: Icons.assignment_late_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _apPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.filter_list_rounded, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Approval Status:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Pending', 'Returned', 'Billed'].map((status) {
            final sel = _statusFilter == status;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = status),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _br : _br.withAlpha(12), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : _br)),
              ),
            );
          }),
        ]),
      ),
      body: _loading ? _apLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _apEmpty('No approval pending register records found');
    double tPcs = 0, tGw = 0, tNw = 0, tAmt = 0;
    for (final r in list) {
      tPcs += r['pcs'] as int;
      tGw += r['grossWeight'] as double;
      tNw += r['netWeight'] as double;
      tAmt += r['amount'] as double;
    }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: _br.withAlpha(18), child: Row(children: [
          _apTh('#', w: 40), _apTh('Date', w: 100), _apTh('Voucher No', w: 110),
          _apTh('Customer Name', w: 160), _apTh('Particular Item Name', flex: true),
          _apTh('Carat', w: 70), _apTh('Pcs', w: 60, r: true),
          _apTh('Gross Weight', w: 100, r: true), _apTh('Net Weight', w: 100, r: true),
          _apTh('Amount (₹)', w: 130, r: true), _apTh('Status', w: 100),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final status = r['status'].toString();
          final Color statusColor = status.toLowerCase() == 'pending' ? const Color(0xFFD84315)
              : status.toLowerCase() == 'returned' ? const Color(0xFF757575) : const Color(0xFF2E7D32);

          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _apTd('${i+1}', w: 40),
              _apTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100),
              _apTd(r['voucherNo'].toString(), w: 110, bold: true),
              _apTd(r['acName'].toString(), w: 160),
              _apTd(r['itemName'].toString(), flex: true),
              _apTd(r['carat'].toString(), w: 70),
              _apTd(r['pcs'].toString(), w: 60, r: true),
              _apTd(r['grossWeight'] > 0 ? '${r['grossWeight'].toStringAsFixed(3)}g' : '—', w: 100, r: true),
              _apTd(r['netWeight'] > 0 ? '${r['netWeight'].toStringAsFixed(3)}g' : '—', w: 100, r: true),
              _apTd(r['amount'] > 0 ? _ffmt(r['amount']) : '—', w: 130, r: true, bold: true),
              _apTd(status, w: 100, bold: true, c: statusColor),
            ]),
          );
        }).toList()))),
        Container(color: _br.withAlpha(14), child: Row(children: [
          _apTt('TOTAL', w: 40), _apTt('', w: 100), _apTt('', w: 110), _apTt('', w: 160), _apTt('', flex: true),
          _apTt('', w: 70), _apTt(tPcs.toStringAsFixed(0), w: 60, r: true),
          _apTt('${tGw.toStringAsFixed(3)}g', w: 100, r: true),
          _apTt('${tNw.toStringAsFixed(3)}g', w: 100, r: true),
          _apTt(_ffmt(tAmt), w: 130, r: true),
          _apTt('', w: 100),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  B: CONSIGNMENT ISSUE / RECEIPT REPORT
// =============================================================================
class ConsignmentIssueReceiptReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const ConsignmentIssueReceiptReportView({super.key, this.onReportSelected});
  @override State<ConsignmentIssueReceiptReportView> createState() => _ConsignmentIssueReceiptReportState();
}

class _ConsignmentIssueReceiptReportState extends State<ConsignmentIssueReceiptReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 90));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _typeFilter = 'All'; // 'All', 'Consignment Issue', 'Consignment Receipt'
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_typeFilter != 'All') {
      list = list.where((r) => r['voucherType']?.toString().toLowerCase() == _typeFilter.toLowerCase()).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) =>
          r['acName'].toString().toLowerCase().contains(_q) ||
          r['voucherNo'].toString().toLowerCase().contains(_q) ||
          r['itemName'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('consignment_entries').get();
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

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

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        list.add({
          'docId': doc.id,
          'voucherNo': d['voucherNo'] ?? d['consignmentNo'] ?? 'CN-${doc.id.substring(0, 4)}',
          'voucherDate': dt,
          'acName': d['acName'] ?? d['customerName'] ?? 'Walk-in Customer',
          'itemName': d['itemName'] ?? 'Gold Ornament Consignment',
          'carat': d['carat']?.toString() ?? '22K',
          'grossWeight': _fdbl(d['grossWeight'] ?? d['grossWt']),
          'netWeight': _fdbl(d['netWeight'] ?? d['netWt']),
          'pcs': (d['pcs'] ?? d['pieces'] ?? d['qty'] ?? 1) as int,
          'amount': _fdbl(d['amount'] ?? d['totalAmt'] ?? d['voucherAmt']),
          'voucherType': d['voucherType'] ?? d['type'] ?? 'Consignment Issue', // Consignment Issue, Consignment Receipt
          'rawDoc': d,
        });
      }

      list.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party Name', 'Item Name', 'Carat', 'Gross Wt', 'Net Wt', 'Pcs', 'Amount'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime),
      r['voucherType']?.toString() ?? '',
      r['acName']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      r['carat']?.toString() ?? '',
      _fdbl(r['grossWeight']).toStringAsFixed(3),
      _fdbl(r['netWeight']).toStringAsFixed(3),
      r['pcs']?.toString() ?? '1',
      _ffmt(_fdbl(r['amount'])),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Consignment Issue Receipt Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Consignment Issue Receipt Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Consignment Issue Receipt Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Consignment Issue Receipt Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _apShell(
      context: context,
      pageTitle: 'Consignment Issue / Receipt Report', pageIcon: Icons.local_shipping_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _apPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.filter_list_rounded, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Voucher Type:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Consignment Issue', 'Consignment Receipt'].map((type) {
            final sel = _typeFilter == type;
            return GestureDetector(
              onTap: () => setState(() => _typeFilter = type),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _br : _br.withAlpha(12), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : _br)),
              ),
            );
          }),
        ]),
      ),
      body: _loading ? _apLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _apEmpty('No consignment issues or receipts found');
    double tPcs = 0, tGw = 0, tNw = 0, tAmt = 0;
    for (final r in list) {
      tPcs += r['pcs'] as int;
      tGw += r['grossWeight'] as double;
      tNw += r['netWeight'] as double;
      tAmt += r['amount'] as double;
    }

    const Color color = Color(0xFF0D47A1);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _apTh('#', w: 40), _apTh('Date', w: 100), _apTh('Voucher No', w: 110),
          _apTh('Voucher Type', w: 140), _apTh('Customer Name', w: 160), _apTh('Particular Item Name', flex: true),
          _apTh('Carat', w: 70), _apTh('Pcs', w: 60, r: true),
          _apTh('Gross Weight', w: 100, r: true), _apTh('Net Weight', w: 100, r: true),
          _apTh('Amount (₹)', w: 130, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final isIssue = r['voucherType'].toString().toLowerCase().contains('issue');
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _apTd('${i+1}', w: 40),
              _apTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100),
              _apTd(r['voucherNo'].toString(), w: 110, bold: true),
              _apTd(r['voucherType'].toString(), w: 140, bold: true, c: isIssue ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
              _apTd(r['acName'].toString(), w: 160),
              _apTd(r['itemName'].toString(), flex: true),
              _apTd(r['carat'].toString(), w: 70),
              _apTd(r['pcs'].toString(), w: 60, r: true),
              _apTd(r['grossWeight'] > 0 ? '${r['grossWeight'].toStringAsFixed(3)}g' : '—', w: 100, r: true),
              _apTd(r['netWeight'] > 0 ? '${r['netWeight'].toStringAsFixed(3)}g' : '—', w: 100, r: true),
              _apTd(r['amount'] > 0 ? _ffmt(r['amount']) : '—', w: 130, r: true, bold: true),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _apTt('TOTAL', w: 40), _apTt('', w: 100), _apTt('', w: 110), _apTt('', w: 140), _apTt('', w: 160), _apTt('', flex: true),
          _apTt('', w: 70), _apTt(tPcs.toStringAsFixed(0), w: 60, r: true),
          _apTt('${tGw.toStringAsFixed(3)}g', w: 100, r: true),
          _apTt('${tNw.toStringAsFixed(3)}g', w: 100, r: true),
          _apTt(_ffmt(tAmt), w: 130, r: true),
        ])),
      ]),
    ));
  }
}
