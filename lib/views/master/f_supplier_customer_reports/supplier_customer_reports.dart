// supplier_customer_reports.dart
// F Supplier / Customer Reports — A, B, C, D

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../report_shared.dart';
import '../b_account_reports/account_reports.dart';

const _br  = Color(0xFF3E2723);
const _brL = Color(0xFF6D4C41);
const _bdr = Color(0xFFE5DDD0);
const _bg0 = Color(0xFFFDFBF7);



DateTime? _fts(dynamic v)  => v is Timestamp ? v.toDate() : null;
double    _fdbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
String    _ffmt(double v)  => NumberFormat('#,##,##0.00', 'en_IN').format(v);

Future<DateTimeRange?> _fPickRange(BuildContext ctx, DateTimeRange cur) =>
    showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: cur,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: _br, onPrimary: Colors.white, onSurface: _br),
        ),
        child: child!,
      ),
    );

const Widget _fLoader = Center(child: CircularProgressIndicator(color: _br));

Widget _fEmpty(String msg) => Center(
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inbox_rounded, size: 44, color: Colors.grey.shade300),
    const SizedBox(height: 10),
    Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
  ]),
);

Widget _fTh(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _fTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
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

Widget _fTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c ?? _br)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _fShell({
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

// ===== A: SUPPLIER OUTSTANDING =====
class SupplierOutstandingView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const SupplierOutstandingView({super.key, this.onReportSelected});
  @override State<SupplierOutstandingView> createState() => _SupplierOutstandingState();
}

class _SupplierOutstandingState extends State<SupplierOutstandingView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _rows
      : _rows.where((r) => r['supplierName'].toString().toLowerCase().contains(_q) || r['supplierCode'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> byS = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final bt = d['billType']?.toString() ?? '';
        if (bt != 'Purchase' && bt != 'PurchaseReturn') continue;
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;
        final sd = d['supplierDetails'] as Map<String, dynamic>? ?? {};
        final name = d['acName']?.toString() ?? sd['name']?.toString() ?? 'Unknown';
        final code = sd['supplierCode']?.toString() ?? '—';
        final e = byS.putIfAbsent(name.toLowerCase(), () => {
          'supplierName': name, 'supplierCode': code, 'totalPurchase': 0.0, 'totalPaid': 0.0, 'billCount': 0, 'lastBillDate': dt,
        });
        final amt = _fdbl(d['voucherAmt']);
        final paid = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);
        if (bt == 'Purchase') {
          e['totalPurchase'] = (e['totalPurchase'] as double) + amt;
          e['totalPaid'] = (e['totalPaid'] as double) + paid;
          e['billCount'] = (e['billCount'] as int) + 1;
        } else { e['totalPurchase'] = (e['totalPurchase'] as double) - amt; }
        if (dt.isAfter(e['lastBillDate'] as DateTime)) e['lastBillDate'] = dt;
      }
      final list = byS.values.toList()
        ..sort((a, b) => ((b['totalPurchase'] as double) - (b['totalPaid'] as double)).compareTo((a['totalPurchase'] as double) - (a['totalPaid'] as double)));
      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) { debugPrint('SupplierOutstanding: $e'); if (mounted) setState(() => _loading = false); }
  }

  void _export(String format) async {
    final headers = ['Code', 'Supplier Name', 'Bills', 'Last Bill', 'Total Purchase', 'Total Paid', 'Outstanding Due'];
    final dataRows = _filtered.map((r) => [
      r['supplierCode']?.toString() ?? '',
      r['supplierName']?.toString() ?? '',
      r['billCount']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime),
      _ffmt(r['totalPurchase'] as double),
      _ffmt(r['totalPaid'] as double),
      _ffmt((r['totalPurchase'] as double) - (r['totalPaid'] as double)),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Supplier Outstanding Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Supplier Outstanding Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Supplier Outstanding Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Supplier Outstanding Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) => _fShell(
    context: context,
    pageTitle: 'A   Supplier Outstanding Report', pageIcon: Icons.account_balance_wallet_outlined,
    from: _from, to: _to,
    onPickDate: () async { final r = await _fPickRange(context, DateTimeRange(start: _from, end: _to)); if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); } },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    onExportCsv: () => _export('csv'),
    onExportExcel: () => _export('excel'),
    onExportPdf: () => _export('pdf'),
    body: _loading ? _fLoader : _buildTable(),
  );

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _fEmpty('No supplier outstanding records found');
    double tP = 0, tPd = 0, tD = 0;
    for (final r in rows) { tP += r['totalPurchase'] as double; tPd += r['totalPaid'] as double; tD += (r['totalPurchase'] as double) - (r['totalPaid'] as double); }
    const color = Color(0xFF5D4037);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _fTh('#', w: 40), _fTh('Code', w: 100), _fTh('Supplier Name', flex: true),
          _fTh('Bills', w: 60, r: true), _fTh('Last Bill', w: 100),
          _fTh('Total Purchase', w: 140, r: true), _fTh('Total Paid', w: 130, r: true), _fTh('Outstanding Due', w: 150, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final due = (r['totalPurchase'] as double) - (r['totalPaid'] as double);
          final dc = due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _fTd('${i+1}', w: 40), _fTd(r['supplierCode'].toString(), w: 100),
              _fTd(r['supplierName'].toString(), flex: true, bold: true),
              _fTd('${r['billCount']}', w: 60, r: true),
              _fTd(DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime), w: 100),
              _fTd(_ffmt(r['totalPurchase'] as double), w: 140, r: true),
              _fTd(_ffmt(r['totalPaid'] as double), w: 130, r: true),
              _fTd(_ffmt(due), w: 150, r: true, bold: true, c: dc),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _fTt('TOTAL', w: 40), _fTt('', w: 100), _fTt('', flex: true), _fTt('', w: 60), _fTt('', w: 100),
          _fTt(_ffmt(tP), w: 140, r: true), _fTt(_ffmt(tPd), w: 130, r: true),
          _fTt(_ffmt(tD), w: 150, r: true, c: tD > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
        ])),
      ]),
    ));
  }
}

// ===== B: CUSTOMER OUTSTANDING =====
class CustomerOutstandingView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CustomerOutstandingView({super.key, this.onReportSelected});
  @override State<CustomerOutstandingView> createState() => _CustomerOutstandingState();
}

class _CustomerOutstandingState extends State<CustomerOutstandingView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _rows
      : _rows.where((r) => r['customerName'].toString().toLowerCase().contains(_q) || r['customerCode'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> byC = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final bt = d['billType']?.toString() ?? '';
        if (bt != 'Sale' && bt != 'SalesReturn') continue;
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;
        final cd = d['customerDetails'] as Map<String, dynamic>? ?? {};
        final name = d['acName']?.toString() ?? cd['name']?.toString() ?? 'Unknown';
        final code = cd['customerCode']?.toString() ?? cd['id']?.toString() ?? '—';
        final e = byC.putIfAbsent(name.toLowerCase(), () => {
          'customerName': name, 'customerCode': code, 'totalSales': 0.0, 'totalReceived': 0.0, 'billCount': 0, 'lastBillDate': dt,
        });
        final amt = _fdbl(d['voucherAmt']);
        final recv = _fdbl(d['cashAmt']) + _fdbl(d['bankAmt']) + _fdbl(d['cardAmt']);
        if (bt == 'Sale') {
          e['totalSales'] = (e['totalSales'] as double) + amt;
          e['totalReceived'] = (e['totalReceived'] as double) + recv;
          e['billCount'] = (e['billCount'] as int) + 1;
        } else { e['totalSales'] = (e['totalSales'] as double) - amt; }
        if (dt.isAfter(e['lastBillDate'] as DateTime)) e['lastBillDate'] = dt;
      }
      final list = byC.values.toList()
        ..sort((a, b) => ((b['totalSales'] as double) - (b['totalReceived'] as double)).compareTo((a['totalSales'] as double) - (a['totalReceived'] as double)));
      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) { debugPrint('CustomerOutstanding: $e'); if (mounted) setState(() => _loading = false); }
  }

  void _export(String format) async {
    final headers = ['Code', 'Customer Name', 'Bills', 'Last Bill', 'Total Sales', 'Total Received', 'Outstanding Due'];
    final dataRows = _filtered.map((r) => [
      r['customerCode']?.toString() ?? '',
      r['customerName']?.toString() ?? '',
      r['billCount']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime),
      _ffmt(r['totalSales'] as double),
      _ffmt(r['totalReceived'] as double),
      _ffmt((r['totalSales'] as double) - (r['totalReceived'] as double)),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Customer Outstanding Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Customer Outstanding Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Customer Outstanding Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Customer Outstanding Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) => _fShell(
    context: context,
    pageTitle: 'B   Customer Outstanding Report', pageIcon: Icons.people_alt_outlined,
    from: _from, to: _to,
    onPickDate: () async { final r = await _fPickRange(context, DateTimeRange(start: _from, end: _to)); if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); } },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    onExportCsv: () => _export('csv'),
    onExportExcel: () => _export('excel'),
    onExportPdf: () => _export('pdf'),
    body: _loading ? _fLoader : _buildTable(),
  );

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _fEmpty('No customer outstanding records found');
    double tS = 0, tR = 0, tD = 0;
    for (final r in rows) { tS += r['totalSales'] as double; tR += r['totalReceived'] as double; tD += (r['totalSales'] as double) - (r['totalReceived'] as double); }
    const color = Color(0xFF1B5E20);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _fTh('#', w: 40), _fTh('Code', w: 100), _fTh('Customer Name', flex: true),
          _fTh('Bills', w: 60, r: true), _fTh('Last Bill', w: 100),
          _fTh('Total Sales', w: 140, r: true), _fTh('Received', w: 130, r: true), _fTh('Amount Due', w: 150, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final due = (r['totalSales'] as double) - (r['totalReceived'] as double);
          final dc = due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _fTd('${i+1}', w: 40), _fTd(r['customerCode'].toString(), w: 100),
              _fTd(r['customerName'].toString(), flex: true, bold: true),
              _fTd('${r['billCount']}', w: 60, r: true),
              _fTd(DateFormat('dd/MM/yyyy').format(r['lastBillDate'] as DateTime), w: 100),
              _fTd(_ffmt(r['totalSales'] as double), w: 140, r: true),
              _fTd(_ffmt(r['totalReceived'] as double), w: 130, r: true),
              _fTd(_ffmt(due), w: 150, r: true, bold: true, c: dc),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _fTt('TOTAL', w: 40), _fTt('', w: 100), _fTt('', flex: true), _fTt('', w: 60), _fTt('', w: 100),
          _fTt(_ffmt(tS), w: 140, r: true), _fTt(_ffmt(tR), w: 130, r: true),
          _fTt(_ffmt(tD), w: 150, r: true, c: tD > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
        ])),
      ]),
    ));
  }
}

// ===== C: SUPPLIER LEDGER =====
class SupplierLedgerView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const SupplierLedgerView({super.key, this.onReportSelected});
  @override State<SupplierLedgerView> createState() => _SupplierLedgerState();
}

class _SupplierLedgerState extends State<SupplierLedgerView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';
  String? _selectedName;  // null = All suppliers
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<String> get _nameOptions {
    final names = _rows.map((r) => r['acName'].toString()).toSet().toList()..sort();
    return names;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _rows;
    if (_selectedName != null) list = list.where((r) => r['acName'].toString() == _selectedName).toList();
    if (_q.isNotEmpty) list = list.where((r) => r['acName'].toString().toLowerCase().contains(_q) || r['voucherNo'].toString().toLowerCase().contains(_q)).toList();
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').orderBy('voucherDate', descending: true).get();
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final bt = d['billType']?.toString() ?? '';
        if (bt != 'Purchase' && bt != 'PurchaseReturn') continue;
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;
        list.add({ 'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'billType': bt,
          'acName': d['acName'] ?? '—', 'voucherAmt': _fdbl(d['voucherAmt']),
          'cashAmt': _fdbl(d['cashAmt']), 'bankAmt': _fdbl(d['bankAmt']),
          'cardAmt': _fdbl(d['cardAmt']), 'dueAmt': _fdbl(d['dueAmt']), 'itemName': d['itemName'] ?? '—' });
      }
      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) { debugPrint('SupplierLedger: $e'); if (mounted) setState(() => _loading = false); }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party Name', 'Items', 'Voucher Amt', 'Cash Amt', 'Bank Amt', 'Card Amt', 'Outstanding'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime),
      r['billType']?.toString() ?? '',
      r['acName']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      _ffmt(r['voucherAmt'] as double),
      _ffmt(r['cashAmt'] as double),
      _ffmt(r['bankAmt'] as double),
      _ffmt(r['cardAmt'] as double),
      _ffmt(r['dueAmt'] as double),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Supplier Ledger Summary', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Supplier Ledger Summary', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Supplier Ledger Summary', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Supplier Ledger Summary', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _nameOptions;
    return _fShell(
      context: context,
      pageTitle: 'C   Supplier Ledger Summary', pageIcon: Icons.book_outlined,
      from: _from, to: _to,
      onPickDate: () async { final r = await _fPickRange(context, DateTimeRange(start: _from, end: _to)); if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); } },
      onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.person_search_outlined, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Supplier:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 280, height: 32,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedName,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(8)),
              ),
              hint: const Text('All Suppliers (A - Z)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _brL),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Suppliers', style: TextStyle(fontSize: 11))),
                ...names.map((n) => DropdownMenuItem<String>(value: n, child: Text(n, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _selectedName = v),
            ),
          ),
          if (_selectedName != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() => _selectedName = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFEFEBE9), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, size: 12, color: _br),
              ),
            ),
          ],
        ]),
      ),
      body: _loading ? _fLoader : _buildTable(),
    );
  }

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _fEmpty('No supplier ledger entries found');
    double tA = 0, tC = 0, tB = 0, tCd = 0, tD = 0;
    for (final r in rows) { tA += r['voucherAmt'] as double; tC += r['cashAmt'] as double; tB += r['bankAmt'] as double; tCd += r['cardAmt'] as double; tD += r['dueAmt'] as double; }
    const color = Color(0xFF4A148C);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _fTh('#', w: 40), _fTh('Voucher No', w: 110), _fTh('Date', w: 90), _fTh('Type', w: 70),
          _fTh('Supplier Name', flex: true), _fTh('Item', w: 120),
          _fTh('Total Amt', w: 120, r: true), _fTh('Cash', w: 90, r: true),
          _fTh('Bank', w: 90, r: true), _fTh('Card', w: 90, r: true), _fTh('Due', w: 100, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final isPR = r['billType'] == 'PurchaseReturn';
          final tc = isPR ? const Color(0xFFE65100) : const Color(0xFF1A237E);
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _fTd('${i+1}', w: 40), _fTd(r['voucherNo'].toString(), w: 110, bold: true),
              _fTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 90),
              Container(width: 70, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: tc.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: Text(isPR ? 'PR' : 'PL', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc)))),
              _fTd(r['acName'].toString(), flex: true), _fTd(r['itemName'].toString(), w: 120),
              _fTd(_ffmt(r['voucherAmt'] as double), w: 120, r: true, bold: true),
              _fTd((r['cashAmt'] as double) > 0 ? _ffmt(r['cashAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['bankAmt'] as double) > 0 ? _ffmt(r['bankAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['cardAmt'] as double) > 0 ? _ffmt(r['cardAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['dueAmt'] as double) > 0 ? _ffmt(r['dueAmt'] as double) : '—', w: 100, r: true,
                  c: (r['dueAmt'] as double) > 0 ? const Color(0xFFC62828) : null),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _fTt('TOTAL', w: 40), _fTt('', w: 110), _fTt('', w: 90), _fTt('', w: 70),
          _fTt('', flex: true), _fTt('', w: 120),
          _fTt(_ffmt(tA), w: 120, r: true), _fTt(_ffmt(tC), w: 90, r: true),
          _fTt(_ffmt(tB), w: 90, r: true), _fTt(_ffmt(tCd), w: 90, r: true),
          _fTt(_ffmt(tD), w: 100, r: true, c: tD > 0 ? const Color(0xFFC62828) : null),
        ])),
      ]),
    ));
  }
}

// ===== D: CUSTOMER LEDGER =====
class CustomerLedgerView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CustomerLedgerView({super.key, this.onReportSelected});
  @override State<CustomerLedgerView> createState() => _CustomerLedgerState();
}

class _CustomerLedgerState extends State<CustomerLedgerView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';
  String? _selectedName;  // null = All customers
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<String> get _nameOptions {
    final names = _rows.map((r) => r['acName'].toString()).toSet().toList()..sort();
    return names;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _rows;
    if (_selectedName != null) list = list.where((r) => r['acName'].toString() == _selectedName).toList();
    if (_q.isNotEmpty) list = list.where((r) => r['acName'].toString().toLowerCase().contains(_q) || r['voucherNo'].toString().toLowerCase().contains(_q)).toList();
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').orderBy('voucherDate', descending: true).get();
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final bt = d['billType']?.toString() ?? '';
        if (bt != 'Sale' && bt != 'SalesReturn') continue;
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;
        list.add({ 'voucherNo': d['voucherNo'] ?? '—', 'voucherDate': dt, 'billType': bt,
          'acName': d['acName'] ?? '—', 'salesman': d['salesman'] ?? '—',
          'voucherAmt': _fdbl(d['voucherAmt']), 'cashAmt': _fdbl(d['cashAmt']),
          'bankAmt': _fdbl(d['bankAmt']), 'cardAmt': _fdbl(d['cardAmt']),
          'dueAmt': _fdbl(d['dueAmt']), 'itemName': d['itemName'] ?? '—' });
      }
      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) { debugPrint('CustomerLedger: $e'); if (mounted) setState(() => _loading = false); }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party Name', 'Salesman', 'Items', 'Voucher Amt', 'Cash Amt', 'Bank Amt', 'Card Amt', 'Outstanding'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime),
      r['billType']?.toString() ?? '',
      r['acName']?.toString() ?? '',
      r['salesman']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      _ffmt(r['voucherAmt'] as double),
      _ffmt(r['cashAmt'] as double),
      _ffmt(r['bankAmt'] as double),
      _ffmt(r['cardAmt'] as double),
      _ffmt(r['dueAmt'] as double),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Customer Ledger Summary', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Customer Ledger Summary', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Customer Ledger Summary', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Customer Ledger Summary', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _nameOptions;
    return _fShell(
      context: context,
      pageTitle: 'D   Customer Ledger Summary', pageIcon: Icons.receipt_long_outlined,
      from: _from, to: _to,
      onPickDate: () async { final r = await _fPickRange(context, DateTimeRange(start: _from, end: _to)); if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); } },
      onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      filterWidget: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(children: [
          const Icon(Icons.person_search_outlined, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Customer:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 280, height: 32,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedName,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(8)),
              ),
              hint: const Text('All Customers (A - Z)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _brL),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Customers', style: TextStyle(fontSize: 11))),
                ...names.map((n) => DropdownMenuItem<String>(value: n, child: Text(n, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _selectedName = v),
            ),
          ),
          if (_selectedName != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() => _selectedName = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFEFEBE9), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, size: 12, color: _br),
              ),
            ),
          ],
        ]),
      ),
      body: _loading ? _fLoader : _buildTable(),
    );
  }

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _fEmpty('No customer ledger entries found');
    double tA = 0, tC = 0, tB = 0, tCd = 0, tD = 0;
    for (final r in rows) { tA += r['voucherAmt'] as double; tC += r['cashAmt'] as double; tB += r['bankAmt'] as double; tCd += r['cardAmt'] as double; tD += r['dueAmt'] as double; }
    const color = Color(0xFF0D47A1);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _fTh('#', w: 40), _fTh('Voucher No', w: 110), _fTh('Date', w: 90), _fTh('Type', w: 70),
          _fTh('Customer Name', flex: true), _fTh('Item', w: 120), _fTh('Salesman', w: 100),
          _fTh('Total Amt', w: 120, r: true), _fTh('Cash', w: 90, r: true),
          _fTh('Bank', w: 90, r: true), _fTh('Card', w: 90, r: true), _fTh('Due', w: 100, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final isSR = r['billType'] == 'SalesReturn';
          final tc = isSR ? const Color(0xFFE65100) : const Color(0xFF1A237E);
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _fTd('${i+1}', w: 40), _fTd(r['voucherNo'].toString(), w: 110, bold: true),
              _fTd(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 90),
              Container(width: 70, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: tc.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: Text(isSR ? 'SR' : 'SL', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc)))),
              _fTd(r['acName'].toString(), flex: true),
              _fTd(r['itemName'].toString(), w: 120), _fTd(r['salesman'].toString(), w: 100),
              _fTd(_ffmt(r['voucherAmt'] as double), w: 120, r: true, bold: true),
              _fTd((r['cashAmt'] as double) > 0 ? _ffmt(r['cashAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['bankAmt'] as double) > 0 ? _ffmt(r['bankAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['cardAmt'] as double) > 0 ? _ffmt(r['cardAmt'] as double) : '—', w: 90, r: true),
              _fTd((r['dueAmt'] as double) > 0 ? _ffmt(r['dueAmt'] as double) : '—', w: 100, r: true,
                  c: (r['dueAmt'] as double) > 0 ? const Color(0xFFC62828) : null),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _fTt('TOTAL', w: 40), _fTt('', w: 110), _fTt('', w: 90), _fTt('', w: 70),
          _fTt('', flex: true), _fTt('', w: 120), _fTt('', w: 100),
          _fTt(_ffmt(tA), w: 120, r: true), _fTt(_ffmt(tC), w: 90, r: true),
          _fTt(_ffmt(tB), w: 90, r: true), _fTt(_ffmt(tCd), w: 90, r: true),
          _fTt(_ffmt(tD), w: 100, r: true, c: tD > 0 ? const Color(0xFFC62828) : null),
        ])),
      ]),
    ));
  }
}
