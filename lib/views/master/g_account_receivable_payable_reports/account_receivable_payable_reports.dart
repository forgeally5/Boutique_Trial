// account_receivable_payable_reports.dart
// G Account Receivable / Payable Reports — A, B, C, D

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

Future<DateTimeRange?> _gPickRange(BuildContext ctx, DateTimeRange cur) =>
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

Widget _gLoader = const Center(child: CircularProgressIndicator(color: _br));

Widget _gEmpty(String msg) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );

Widget _gTh(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _gTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
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

Widget _gTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: r ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c ?? _br)),
    ),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _gShell({
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
          decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(10)),
          child: Text('$totalRecords items',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
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

DateTime? _parseDate(Map<String, dynamic> data) {
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


// =============================================================================
//  A: ACCOUNT & BILLS REPORT
// =============================================================================
class AccountAndBillsReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const AccountAndBillsReportView({super.key, this.onReportSelected});
  @override State<AccountAndBillsReportView> createState() => _AccountAndBillsReportState();
}

class _AccountAndBillsReportState extends State<AccountAndBillsReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _partyTypeFilter = 'All'; // 'All', 'Customer', 'Supplier'
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_partyTypeFilter != 'All') {
      list = list.where((r) => r['partyType']?.toString().toLowerCase() == _partyTypeFilter.toLowerCase()).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) =>
          r['partyName'].toString().toLowerCase().contains(_q) ||
          r['billNo'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final billType = d['billType']?.toString() ?? '';
        final isSale = billType == 'Sale' || billType == 'SalesReturn' || billType == 'Estimate';
        final isPurchase = billType == 'Purchase' || billType == 'PurchaseReturn';
        if (!isSale && !isPurchase) continue;

        final cd = d['customerDetails'] as Map<String, dynamic>? ?? {};
        final sd = d['supplierDetails'] as Map<String, dynamic>? ?? {};

        final name = d['acName']?.toString() ?? (isSale ? (cd['name'] ?? 'Walk-in') : (sd['name'] ?? 'Walk-in'));
        final amt = _fdbl(d['voucherAmt']);
        final paid = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);
        final due = amt - paid;

        list.add({
          'docId': doc.id,
          'billNo': (d['voucherNo'] ?? d['billNo'] ?? 'V-${doc.id.substring(0, 4)}').toString().replaceAll('/', '-'),
          'date': dt,
          'partyType': isSale ? 'Customer' : 'Supplier',
          'partyName': name,
          'amount': amt,
          'paid': paid,
          'due': due,
          'ageDays': DateTime.now().difference(dt).inDays,
        });
      }

      list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Bill No', 'Date', 'Type', 'Party Name', 'Amount', 'Paid', 'Outstanding Due', 'Age (Days)'];
    final dataRows = _filtered.map((r) => [
      r['billNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['date'] as DateTime),
      r['partyType']?.toString() ?? '',
      r['partyName']?.toString() ?? '',
      _ffmt(_fdbl(r['amount'])),
      _ffmt(_fdbl(r['paid'])),
      _ffmt(_fdbl(r['due'])),
      r['ageDays']?.toString() ?? '0',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Account and Bills Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Account and Bills Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Account and Bills Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Account and Bills Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'Account & Bills Report', pageIcon: Icons.account_balance_wallet_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
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
          const Text('Filter Party Type:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Customer', 'Supplier'].map((type) {
            final sel = _partyTypeFilter == type;
            return GestureDetector(
              onTap: () => setState(() => _partyTypeFilter = type),
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
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No accounts & bills records found');
    double tAmt = 0, tPd = 0, tDue = 0;
    for (final r in list) {
      tAmt += r['amount'] as double;
      tPd += r['paid'] as double;
      tDue += r['due'] as double;
    }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: _br.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40), _gTh('Date', w: 100), _gTh('Bill/Voucher No', w: 120),
          _gTh('Party Type', w: 100), _gTh('Party Name', flex: true),
          _gTh('Bill Amt (₹)', w: 120, r: true), _gTh('Paid (₹)', w: 110, r: true),
          _gTh('Due (₹)', w: 120, r: true), _gTh('Age (Days)', w: 80, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final due = r['due'] as double;
          final Color dueColor = due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime), w: 100),
              _gTd(r['billNo'].toString(), w: 120, bold: true),
              _gTd(r['partyType'].toString(), w: 100, bold: true, c: r['partyType'] == 'Customer' ? Colors.blue.shade800 : Colors.orange.shade800),
              _gTd(r['partyName'].toString(), flex: true),
              _gTd(_ffmt(r['amount'] as double), w: 120, r: true),
              _gTd(_ffmt(r['paid'] as double), w: 110, r: true),
              _gTd(_ffmt(due), w: 120, r: true, bold: true, c: dueColor),
              _gTd('${r['ageDays']} days', w: 80, r: true),
            ]),
          );
        }).toList()))),
        Container(color: _br.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 100), _gTt('', w: 120), _gTt('', w: 100), _gTt('', flex: true),
          _gTt(_ffmt(tAmt), w: 120, r: true), _gTt(_ffmt(tPd), w: 110, r: true),
          _gTt(_ffmt(tDue), w: 120, r: true), _gTt('', w: 80),
        ])),
      ]),
    ));
  }
}


// =============================================================================
//  B: ACCOUNTS RECEIVABLE SUMMARY (Customers)
// =============================================================================
class AccountsReceivableSummaryView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const AccountsReceivableSummaryView({super.key, this.onReportSelected});
  @override State<AccountsReceivableSummaryView> createState() => _AccountsReceivableSummaryState();
}

class _AccountsReceivableSummaryState extends State<AccountsReceivableSummaryView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _records
      : _records.where((r) => r['customerName'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> map = {};
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final billType = d['billType']?.toString() ?? '';
        final isSale = billType == 'Sale' || billType == 'SalesReturn' || billType == 'Estimate';
        if (!isSale) continue;

        final cd = d['customerDetails'] as Map<String, dynamic>? ?? {};
        final name = d['acName']?.toString() ?? cd['name']?.toString() ?? 'Walk-in';
        final code = cd['customerCode']?.toString() ?? '—';
        final amt = _fdbl(d['voucherAmt']);
        final paid = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);

        final key = name.toLowerCase();
        final e = map.putIfAbsent(key, () => {
          'customerName': name,
          'customerCode': code,
          'totalBilling': 0.0,
          'totalReceived': 0.0,
          'lastBillDate': dt,
        });

        e['totalBilling'] = (e['totalBilling'] as double) + amt;
        e['totalReceived'] = (e['totalReceived'] as double) + paid;
        if (dt.isAfter(e['lastBillDate'] as DateTime)) {
          e['lastBillDate'] = dt;
        }
      }

      final list = map.values.toList()
        ..sort((a, b) => ((b['totalBilling'] as double) - (b['totalReceived'] as double))
            .compareTo((a['totalBilling'] as double) - (a['totalReceived'] as double)));

      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Code', 'Customer Name', 'Last Bill', 'Total Billing', 'Total Received', 'Outstanding Due'];
    final dataRows = _filtered.map((r) => [
      r['customerCode']?.toString() ?? '',
      r['customerName']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime),
      _ffmt(_fdbl(r['totalBilling'])),
      _ffmt(_fdbl(r['totalReceived'])),
      _ffmt(_fdbl(r['totalBilling']) - _fdbl(r['totalReceived'])),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Accounts Receivable Summary', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Accounts Receivable Summary', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Accounts Receivable Summary', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Accounts Receivable Summary', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'Accounts Receivable Summary', pageIcon: Icons.trending_up_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No accounts receivable found');
    double tBill = 0, tRec = 0, tDue = 0;
    for (final r in list) {
      tBill += r['totalBilling'] as double;
      tRec += r['totalReceived'] as double;
      tDue += (r['totalBilling'] as double) - (r['totalReceived'] as double);
    }

    const Color color = Color(0xFF0288D1);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40), _gTh('Customer Code', w: 120), _gTh('Customer Name', flex: true),
          _gTh('Total Billing (₹)', w: 150, r: true), _gTh('Total Received (₹)', w: 150, r: true),
          _gTh('Receivable Due (₹)', w: 160, r: true), _gTh('Last Date', w: 100),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final due = (r['totalBilling'] as double) - (r['totalReceived'] as double);
          final Color dueColor = due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(r['customerCode'].toString(), w: 120),
              _gTd(r['customerName'].toString(), flex: true, bold: true),
              _gTd(_ffmt(r['totalBilling'] as double), w: 150, r: true),
              _gTd(_ffmt(r['totalReceived'] as double), w: 150, r: true),
              _gTd(_ffmt(due), w: 160, r: true, bold: true, c: dueColor),
              _gTd(DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime), w: 100),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 120), _gTt('', flex: true),
          _gTt(_ffmt(tBill), w: 150, r: true), _gTt(_ffmt(tRec), w: 150, r: true),
          _gTt(_ffmt(tDue), w: 160, r: true), _gTt('', w: 100),
        ])),
      ]),
    ));
  }
}


// =============================================================================
//  C: ACCOUNTS PAYABLE SUMMARY (Suppliers)
// =============================================================================
class AccountsPayableSummaryView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const AccountsPayableSummaryView({super.key, this.onReportSelected});
  @override State<AccountsPayableSummaryView> createState() => _AccountsPayableSummaryState();
}

class _AccountsPayableSummaryState extends State<AccountsPayableSummaryView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _records
      : _records.where((r) => r['supplierName'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> map = {};
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final billType = d['billType']?.toString() ?? '';
        final isPurchase = billType == 'Purchase' || billType == 'PurchaseReturn';
        if (!isPurchase) continue;

        final sd = d['supplierDetails'] as Map<String, dynamic>? ?? {};
        final name = d['acName']?.toString() ?? sd['name']?.toString() ?? 'Walk-in';
        final code = sd['supplierCode']?.toString() ?? '—';
        final amt = _fdbl(d['voucherAmt']);
        final paid = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);

        final key = name.toLowerCase();
        final e = map.putIfAbsent(key, () => {
          'supplierName': name,
          'supplierCode': code,
          'totalPurchase': 0.0,
          'totalPaid': 0.0,
          'lastPurchaseDate': dt,
        });

        e['totalPurchase'] = (e['totalPurchase'] as double) + amt;
        e['totalPaid'] = (e['totalPaid'] as double) + paid;
        if (dt.isAfter(e['lastPurchaseDate'] as DateTime)) {
          e['lastPurchaseDate'] = dt;
        }
      }

      final list = map.values.toList()
        ..sort((a, b) => ((b['totalPurchase'] as double) - (b['totalPaid'] as double))
            .compareTo((a['totalPurchase'] as double) - (a['totalPaid'] as double)));

      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Code', 'Supplier Name', 'Last Purchase', 'Total Purchase', 'Total Paid', 'Outstanding Due'];
    final dataRows = _filtered.map((r) => [
      r['supplierCode']?.toString() ?? '',
      r['supplierName']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['lastPurchaseDate'] as DateTime),
      _ffmt(_fdbl(r['totalPurchase'])),
      _ffmt(_fdbl(r['totalPaid'])),
      _ffmt(_fdbl(r['totalPurchase']) - _fdbl(r['totalPaid'])),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Accounts Payable Summary', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Accounts Payable Summary', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Accounts Payable Summary', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Accounts Payable Summary', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'Accounts Payable Summary', pageIcon: Icons.trending_down_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load, totalRecords: list.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No accounts payable found');
    double tPur = 0, tPd = 0, tDue = 0;
    for (final r in list) {
      tPur += r['totalPurchase'] as double;
      tPd += r['totalPaid'] as double;
      tDue += (r['totalPurchase'] as double) - (r['totalPaid'] as double);
    }

    const Color color = Color(0xFFE65100);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40), _gTh('Supplier Code', w: 120), _gTh('Supplier Name', flex: true),
          _gTh('Total Purchase (₹)', w: 150, r: true), _gTh('Total Paid (₹)', w: 150, r: true),
          _gTh('Payable Due (₹)', w: 160, r: true), _gTh('Last Date', w: 100),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final due = (r['totalPurchase'] as double) - (r['totalPaid'] as double);
          final Color dueColor = due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(r['supplierCode'].toString(), w: 120),
              _gTd(r['supplierName'].toString(), flex: true, bold: true),
              _gTd(_ffmt(r['totalPurchase'] as double), w: 150, r: true),
              _gTd(_ffmt(r['totalPaid'] as double), w: 150, r: true),
              _gTd(_ffmt(due), w: 160, r: true, bold: true, c: dueColor),
              _gTd(DateFormat('dd/MM/yyyy').format(r['lastPurchaseDate'] as DateTime), w: 100),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 120), _gTt('', flex: true),
          _gTt(_ffmt(tPur), w: 150, r: true), _gTt(_ffmt(tPd), w: 150, r: true),
          _gTt(_ffmt(tDue), w: 160, r: true), _gTt('', w: 100),
        ])),
      ]),
    ));
  }
}


// =============================================================================
//  D: OUTSTANDING AGING REPORT
// =============================================================================
class OutstandingAgingReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const OutstandingAgingReportView({super.key, this.onReportSelected});
  @override State<OutstandingAgingReportView> createState() => _OutstandingAgingReportState();
}

class _OutstandingAgingReportState extends State<OutstandingAgingReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _partyTypeFilter = 'All'; // 'All', 'Customer', 'Supplier'
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_partyTypeFilter != 'All') {
      list = list.where((r) => r['partyType']?.toString().toLowerCase() == _partyTypeFilter.toLowerCase()).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) => r['partyName'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> map = {};
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d);
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        final billType = d['billType']?.toString() ?? '';
        final isSale = billType == 'Sale' || billType == 'SalesReturn' || billType == 'Estimate';
        final isPurchase = billType == 'Purchase' || billType == 'PurchaseReturn';
        if (!isSale && !isPurchase) continue;

        final cd = d['customerDetails'] as Map<String, dynamic>? ?? {};
        final sd = d['supplierDetails'] as Map<String, dynamic>? ?? {};

        final name = d['acName']?.toString() ?? (isSale ? (cd['name'] ?? 'Walk-in') : (sd['name'] ?? 'Walk-in'));
        final amt = _fdbl(d['voucherAmt']);
        final paid = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);
        final due = amt - paid;
        if (due <= 0) continue; // Only age positive outstanding dues

        final key = '${isSale ? 'C' : 'S'}_${name.toLowerCase()}';
        final e = map.putIfAbsent(key, () => {
          'partyName': name,
          'partyType': isSale ? 'Customer' : 'Supplier',
          'totalOutstanding': 0.0,
          'slab0to30': 0.0,
          'slab31to60': 0.0,
          'slab61to90': 0.0,
          'slabAbove90': 0.0,
        });

        final age = DateTime.now().difference(dt).inDays;
        e['totalOutstanding'] = (e['totalOutstanding'] as double) + due;

        if (age <= 30) {
          e['slab0to30'] = (e['slab0to30'] as double) + due;
        } else if (age <= 60) {
          e['slab31to60'] = (e['slab31to60'] as double) + due;
        } else if (age <= 90) {
          e['slab61to90'] = (e['slab61to90'] as double) + due;
        } else {
          e['slabAbove90'] = (e['slabAbove90'] as double) + due;
        }
      }

      final list = map.values.toList()
        ..sort((a, b) => (b['totalOutstanding'] as double).compareTo(a['totalOutstanding'] as double));

      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Party Name', 'Party Type', '0 - 30 Days', '31 - 60 Days', '61 - 90 Days', '> 90 Days', 'Total Outstanding'];
    final dataRows = _filtered.map((r) => [
      r['partyName']?.toString() ?? '',
      r['partyType']?.toString() ?? '',
      _ffmt(_fdbl(r['slab0to30'])),
      _ffmt(_fdbl(r['slab31to60'])),
      _ffmt(_fdbl(r['slab61to90'])),
      _ffmt(_fdbl(r['slabAbove90'])),
      _ffmt(_fdbl(r['totalOutstanding'])),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Outstanding Aging Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Outstanding Aging Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Outstanding Aging Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Outstanding Aging Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'Outstanding Aging Report', pageIcon: Icons.hourglass_bottom_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
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
          const Text('Filter Party Type:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Customer', 'Supplier'].map((type) {
            final sel = _partyTypeFilter == type;
            return GestureDetector(
              onTap: () => setState(() => _partyTypeFilter = type),
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
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No outstanding aging records found');
    double tOut = 0, t0_30 = 0, t31_60 = 0, t61_90 = 0, tAbove = 0;
    for (final r in list) {
      tOut += r['totalOutstanding'] as double;
      t0_30 += r['slab0to30'] as double;
      t31_60 += r['slab31to60'] as double;
      t61_90 += r['slab61to90'] as double;
      tAbove += r['slabAbove90'] as double;
    }

    const Color color = Color(0xFF673AB7);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40), _gTh('Party Type', w: 100), _gTh('Party Name', flex: true),
          _gTh('Total Dues (₹)', w: 130, r: true), _gTh('0-30 Days', w: 110, r: true),
          _gTh('31-60 Days', w: 110, r: true), _gTh('61-90 Days', w: 110, r: true),
          _gTh('>90 Days', w: 110, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final total = r['totalOutstanding'] as double;
          final slab0 = r['slab0to30'] as double;
          final slab31 = r['slab31to60'] as double;
          final slab61 = r['slab61to90'] as double;
          final slabA = r['slabAbove90'] as double;

          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(r['partyType'].toString(), w: 100, bold: true, c: r['partyType'] == 'Customer' ? Colors.blue.shade800 : Colors.orange.shade800),
              _gTd(r['partyName'].toString(), flex: true, bold: true),
              _gTd(_ffmt(total), w: 130, r: true, bold: true, c: const Color(0xFFC62828)),
              _gTd(slab0 > 0 ? _ffmt(slab0) : '—', w: 110, r: true),
              _gTd(slab31 > 0 ? _ffmt(slab31) : '—', w: 110, r: true),
              _gTd(slab61 > 0 ? _ffmt(slab61) : '—', w: 110, r: true),
              _gTd(slabA > 0 ? _ffmt(slabA) : '—', w: 110, r: true, bold: slabA > 0, c: slabA > 0 ? const Color(0xFFC62828) : null),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 100), _gTt('', flex: true),
          _gTt(_ffmt(tOut), w: 130, r: true), _gTt(_ffmt(t0_30), w: 110, r: true),
          _gTt(_ffmt(t31_60), w: 110, r: true), _gTt(_ffmt(t61_90), w: 110, r: true),
          _gTt(_ffmt(tAbove), w: 110, r: true),
        ])),
      ]),
    ));
  }
}
