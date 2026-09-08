// utility_reports.dart
// H Utility Reports — A: Audit Trail Report, B: System Activity Log

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
//  A: AUDIT TRAIL REPORT
// =============================================================================
class AuditTrailReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const AuditTrailReportView({super.key, this.onReportSelected});
  @override State<AuditTrailReportView> createState() => _AuditTrailReportState();
}

class _AuditTrailReportState extends State<AuditTrailReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  final _sc = TextEditingController();
  String _q = '';
  String _typeFilter = 'All'; // 'All', 'Sales', 'Purchase', 'Cash', 'Bank', 'Journal'

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_typeFilter != 'All') {
      list = list.where((r) => r['action'].toString().toLowerCase().contains(_typeFilter.toLowerCase())).toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) =>
          r['partyName'].toString().toLowerCase().contains(_q) ||
          r['docNo'].toString().toLowerCase().contains(_q) ||
          r['action'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      // 1. Fetch bills (Sales & Purchase)
      try {
        final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
        for (final doc in billsSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          final billType = d['billType']?.toString() ?? '';
          final isSale = billType == 'Sale' || billType == 'SalesReturn' || billType == 'Estimate';
          final action = isSale ? 'Save Sales Invoice' : 'Save Purchase Bill';

          list.add({
            'timestamp': dt,
            'docNo': (d['voucherNo'] ?? d['billNo'] ?? doc.id).toString().replaceAll('/', '-'),
            'action': action,
            'partyName': d['acName']?.toString() ?? 'Walk-in',
            'amount': _fdbl(d['voucherAmt']),
            'user': d['salesman']?.toString() ?? 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      // 2. Fetch cash entries
      try {
        final cashSnap = await FirebaseFirestore.instance.collection('cash_entries').get();
        for (final doc in cashSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          list.add({
            'timestamp': dt,
            'docNo': (d['voucherNo'] ?? doc.id).toString().replaceAll('/', '-'),
            'action': 'Save Cash Entry',
            'partyName': d['particulars']?.toString() ?? d['acName']?.toString() ?? 'N/A',
            'amount': _fdbl(d['amount'] ?? d['voucherAmt']),
            'user': d['user']?.toString() ?? 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      // 3. Fetch bank entries
      try {
        final bankSnap = await FirebaseFirestore.instance.collection('bank_entries').get();
        for (final doc in bankSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          list.add({
            'timestamp': dt,
            'docNo': (d['voucherNo'] ?? doc.id).toString().replaceAll('/', '-'),
            'action': 'Save Bank Entry',
            'partyName': d['particulars']?.toString() ?? d['acName']?.toString() ?? 'N/A',
            'amount': _fdbl(d['amount'] ?? d['voucherAmt']),
            'user': d['user']?.toString() ?? 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      // 4. Fetch journal entries
      try {
        final journalSnap = await FirebaseFirestore.instance.collection('journal_entries').get();
        for (final doc in journalSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          list.add({
            'timestamp': dt,
            'docNo': (d['voucherNo'] ?? doc.id).toString().replaceAll('/', '-'),
            'action': 'Save Journal Entry',
            'partyName': d['particulars']?.toString() ?? d['acName']?.toString() ?? 'N/A',
            'amount': _fdbl(d['amount'] ?? d['voucherAmt']),
            'user': d['user']?.toString() ?? 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      list.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildHeaderCell(String text, {bool alignRight = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _br),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {bool bold = false, bool alignRight = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _export(String format) async {
    final headers = ['Timestamp', 'Voucher/Doc No', 'Action/Type', 'Party/Account', 'Amount', 'Performed By', 'Status'];
    final dataRows = _filtered.map((r) => [
      DateFormat('dd/MM/yyyy HH:mm').format(r['timestamp'] as DateTime),
      r['docNo']?.toString() ?? '',
      r['action']?.toString() ?? '',
      r['partyName']?.toString() ?? '',
      r['amount'] > 0 ? _ffmt(r['amount'] as double) : '—',
      r['user']?.toString() ?? '',
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Audit Trail Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Audit Trail Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Audit Trail Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Audit Trail Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    Widget body;
    if (_loading) {
      body = _gLoader;
    } else if (list.isEmpty) {
      body = _gEmpty('No audit trail records found for this period.');
    } else {
      body = Container(
        color: _bg0,
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(60),
                1: FixedColumnWidth(150),
                2: FixedColumnWidth(150),
                3: FlexColumnWidth(2.5),
                4: FlexColumnWidth(3),
                5: FixedColumnWidth(150),
                6: FixedColumnWidth(150),
                7: FixedColumnWidth(100),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _bdr, width: 1.2)),
                  ),
                  children: [
                    _buildHeaderCell('S.No'),
                    _buildHeaderCell('Timestamp'),
                    _buildHeaderCell('Voucher/Doc No'),
                    _buildHeaderCell('Action/Type'),
                    _buildHeaderCell('Party/Account'),
                    _buildHeaderCell('Amount (₹)', alignRight: true),
                    _buildHeaderCell('Performed By'),
                    _buildHeaderCell('Status'),
                  ],
                ),
                ...List.generate(list.length, (idx) {
                  final r = list[idx];
                  final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(r['timestamp'] as DateTime);
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _bdr, width: 0.8)),
                    ),
                    children: [
                      _buildDataCell('${idx + 1}'),
                      _buildDataCell(dateStr),
                      _buildDataCell(r['docNo'].toString(), bold: true),
                      _buildDataCell(r['action'].toString()),
                      _buildDataCell(r['partyName'].toString()),
                      _buildDataCell(r['amount'] > 0 ? _ffmt(r['amount'] as double) : '—', alignRight: true),
                      _buildDataCell(r['user'].toString()),
                      TableCell(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(r['status'].toString(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }

    final typeFilterWidget = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          const Text('Filter Action: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brL)),
          const SizedBox(width: 8),
          ...['All', 'Sales', 'Purchase', 'Cash', 'Bank', 'Journal'].map((t) {
            final isSel = _typeFilter == t;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(t, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : _brL, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: _br,
                backgroundColor: _bg0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: _bdr)),
                onSelected: (val) {
                  if (val) setState(() => _typeFilter = t);
                },
              ),
            );
          }),
        ],
      ),
    );

    return _gShell(
      context: context,
      pageTitle: 'A Audit Trail Report',
      pageIcon: Icons.history,
      from: _from,
      to: _to,
      onPickDate: () async {
        final rng = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
        if (rng != null) {
          setState(() { _from = rng.start; _to = rng.end; });
          _load();
        }
      },
      onRefresh: _load,
      totalRecords: list.length,
      searchCtrl: _sc,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      filterWidget: typeFilterWidget,
      body: body,
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
    );
  }
}

// =============================================================================
//  B: SYSTEM ACTIVITY LOG
// =============================================================================
class SystemActivityLogView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const SystemActivityLogView({super.key, this.onReportSelected});
  @override State<SystemActivityLogView> createState() => _SystemActivityLogState();
}

class _SystemActivityLogState extends State<SystemActivityLogView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  final _sc = TextEditingController();
  String _q = '';
  String _activityFilter = 'All'; // 'All', 'Transactions', 'Directory Masters'

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var list = _records;
    if (_activityFilter == 'Transactions') {
      list = list.where((r) => r['category'] == 'Transaction').toList();
    } else if (_activityFilter == 'Directory Masters') {
      list = list.where((r) => r['category'] == 'Master').toList();
    }
    if (_q.isNotEmpty) {
      list = list.where((r) =>
          r['description'].toString().toLowerCase().contains(_q) ||
          r['user'].toString().toLowerCase().contains(_q) ||
          r['ref'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      // 1. Fetch bills (Sales & Purchase)
      try {
        final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
        for (final doc in billsSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          final billType = d['billType']?.toString() ?? '';
          final isSale = billType == 'Sale' || billType == 'SalesReturn' || billType == 'Estimate';
          final typeLabel = isSale ? 'Sales Bill' : 'Purchase Bill';
          final voucherNo = (d['voucherNo'] ?? d['billNo'] ?? doc.id).toString().replaceAll('/', '-');

          list.add({
            'timestamp': dt,
            'activityType': '$typeLabel Saved',
            'category': 'Transaction',
            'ref': voucherNo,
            'description': 'Saved bill $voucherNo for account "${d['acName'] ?? 'Walk-in'}" with amount ₹ ${_ffmt(_fdbl(d['voucherAmt']))}.',
            'user': d['salesman']?.toString() ?? 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      // 2. Fetch customers additions
      try {
        final custSnap = await FirebaseFirestore.instance.collection('customers').get();
        for (final doc in custSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          final cCode = d['customerCode']?.toString() ?? '—';
          final cName = d['name']?.toString() ?? 'Unknown Customer';

          list.add({
            'timestamp': dt,
            'activityType': 'Customer Directory Added',
            'category': 'Master',
            'ref': cCode,
            'description': 'Added new customer directory record "$cName" (Customer Code: $cCode).',
            'user': 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      // 3. Fetch suppliers additions
      try {
        final suppSnap = await FirebaseFirestore.instance.collection('suppliers').get();
        for (final doc in suppSnap.docs) {
          final d = doc.data();
          final dt = _parseDate(d);
          if (dt == null) continue;
          if (dt.isBefore(start) || dt.isAfter(end)) continue;

          final sCode = d['supplierCode']?.toString() ?? '—';
          final sName = d['name']?.toString() ?? 'Unknown Supplier';

          list.add({
            'timestamp': dt,
            'activityType': 'Supplier Directory Added',
            'category': 'Master',
            'ref': sCode,
            'description': 'Added new supplier directory record "$sName" (Supplier Code: $sCode).',
            'user': 'System Admin',
            'status': 'Success',
          });
        }
      } catch (_) {}

      list.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Timestamp', 'Activity Type', 'Category', 'Reference', 'Description', 'User', 'Status'];
    final dataRows = _filtered.map((r) => [
      DateFormat('dd/MM/yyyy HH:mm:ss').format(r['timestamp'] as DateTime),
      r['activityType']?.toString() ?? '',
      r['category']?.toString() ?? '',
      r['ref']?.toString() ?? '',
      r['description']?.toString() ?? '',
      r['user']?.toString() ?? '',
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'System Activity Log', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'System Activity Log', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'System Activity Log', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'System Activity Log', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    Widget body;
    if (_loading) {
      body = _gLoader;
    } else if (list.isEmpty) {
      body = _gEmpty('No system activity log records found for this period.');
    } else {
      body = Container(
        color: _bg0,
        child: ListView.separated(
          itemCount: list.length,
          separatorBuilder: (c, i) => const Divider(height: 1, color: _bdr),
          itemBuilder: (c, idx) {
            final r = list[idx];
            final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(r['timestamp'] as DateTime);
            final isMaster = r['category'] == 'Master';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMaster ? Colors.blue.shade50 : Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMaster ? Icons.folder_shared_rounded : Icons.receipt_long_rounded,
                  size: 16,
                  color: isMaster ? Colors.blue.shade800 : Colors.amber.shade900,
                ),
              ),
              title: Row(
                children: [
                  Text(r['activityType'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _br)),
                  const SizedBox(width: 8),
                  Text('[$dateStr]', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text(r['status'].toString(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Expanded(child: Text(r['description'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade800))),
                    const SizedBox(width: 10),
                    Text('User: ${r['user']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final filterWidget = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          const Text('Filter Type: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brL)),
          const SizedBox(width: 8),
          ...['All', 'Transactions', 'Directory Masters'].map((t) {
            final isSel = _activityFilter == t;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(t, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : _brL, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: _br,
                backgroundColor: _bg0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: _bdr)),
                onSelected: (val) {
                  if (val) setState(() => _activityFilter = t);
                },
              ),
            );
          }),
        ],
      ),
    );

    return _gShell(
      context: context,
      pageTitle: 'B System Activity Log',
      pageIcon: Icons.assessment_rounded,
      from: _from,
      to: _to,
      onPickDate: () async {
        final rng = await _gPickRange(context, DateTimeRange(start: _from, end: _to));
        if (rng != null) {
          setState(() { _from = rng.start; _to = rng.end; });
          _load();
        }
      },
      onRefresh: _load,
      totalRecords: list.length,
      searchCtrl: _sc,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      filterWidget: filterWidget,
      body: body,
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
    );
  }
}
