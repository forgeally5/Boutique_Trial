// daily_reports_sections.dart
// Sections B through I of "A Daily Reports" — all data from Firestore only.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../report_shared.dart';
import '../b_account_reports/account_reports.dart';

// ── Shared constants ──────────────────────────────────────────────────────────
const _br      = Color(0xFF3E2723);
const _brL     = Color(0xFF6D4C41);
const _bdr     = Color(0xFFE5DDD0);
const _bg0     = Color(0xFFFDFBF7);
const _bg1     = Color(0xFFF9F6F0);

// ── Shared helpers ─────────────────────────────────────────────────────────────
DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
double    _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

String _fmt(double v) => NumberFormat('#,##,##0.00', 'en_IN').format(v);

// Shared date-range picker (reusable)
Future<DateTimeRange?> _pickRange(BuildContext ctx, DateTimeRange current) =>
    showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: current,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _br, onPrimary: Colors.white, onSurface: _br),
        ),
        child: child!,
      ),
    );

// Shared header row for every section
Widget _sectionHeader({
  required String title,
  required IconData icon,
  required Color color,
  required int count,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      border: Border(bottom: BorderSide(color: color.withAlpha(50))),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 7),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      const Spacer(),
      if (count >= 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
          child: Text('$count entries',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ),
    ]),
  );
}

// Shared page shell (header bar + body)
Widget _reportShell({
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
  required Widget body,
  ValueChanged<String>? onReportSelected,
  VoidCallback? onExportCsv,
  VoidCallback? onExportExcel,
  VoidCallback? onExportPdf,
}) {
  return Column(
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
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
              decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(10)),
              child: Text('$totalRecords records',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))),
            ),
            const Spacer(),
            if (searchCtrl != null) ...[
              SizedBox(
                width: 190, height: 32,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 13, color: _brL),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _bdr),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _br, width: 1.4),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            OutlinedButton.icon(
              onPressed: onPickDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: _brL,
                side: const BorderSide(color: _bdr),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              ),
              icon: const Icon(Icons.date_range_rounded, size: 13),
              label: Text(
                '${DateFormat('dd/MM/yy').format(from)}  –  ${DateFormat('dd/MM/yy').format(to)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
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
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: _bdr),
      Expanded(child: body),
    ],
  );
}

// Empty state
Widget _emptyState(String msg) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 44, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );

// Loading state
const Widget _loader = Center(child: CircularProgressIndicator(color: _br));

// ─── Table helpers ─────────────────────────────────────────────────────────────
Widget _th(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _td(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t,
        overflow: TextOverflow.ellipsis,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: c ?? Colors.black87)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _tt(String t, {double? w, bool r = false, bool flex = false, bool bold = true, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(t,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: c ?? _br)),
  );
  return flex ? Expanded(child: inner) : inner;
}

// ─────────────────────────────────────────────────────────────────────────────
//  B ─ DAILY STATEMENT
//  Groups all bills by date → shows daily totals
// ─────────────────────────────────────────────────────────────────────────────
class DailyStatementView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const DailyStatementView({super.key, this.onReportSelected});
  @override State<DailyStatementView> createState() => _DailyStatementState();
}

class _DailyStatementState extends State<DailyStatementView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);

  bool _loading = true;
  // Each entry: {date, salesCt, salesAmt, purchCt, purchAmt, cash, card, bank, due}
  List<Map<String, dynamic>> _rows = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .orderBy('voucherDate', descending: false)
          .get();

      final Map<String, Map<String, dynamic>> byDate = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;

        final key = DateFormat('yyyy-MM-dd').format(dt);
        final entry = byDate.putIfAbsent(key, () => {
          'dt': dt, 'salesCt': 0, 'salesAmt': 0.0,
          'purchCt': 0, 'purchAmt': 0.0,
          'cash': 0.0, 'card': 0.0, 'bank': 0.0, 'due': 0.0,
        });

        final isSale = d['billType']?.toString() == 'Sale';
        final isPurch = d['billType']?.toString() == 'Purchase';
        final amt = _dbl(d['voucherAmt']);

        if (isSale) { entry['salesCt'] += 1; entry['salesAmt'] += amt; }
        if (isPurch) { entry['purchCt'] += 1; entry['purchAmt'] += amt; }
        entry['cash'] += _dbl(d['cashAmt']);
        entry['card'] += _dbl(d['cardAmt']);
        entry['bank'] += _dbl(d['bankAmt']);
        entry['due']  += _dbl(d['dueAmt']);
      }

      final sorted = byDate.values.toList()
        ..sort((a, b) => (b['dt'] as DateTime).compareTo(a['dt'] as DateTime));

      if (mounted) setState(() { _rows = sorted; _loading = false; });
    } catch (e) {
      debugPrint('DailyStatement error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Date', 'Sales Ct', 'Sales Amt', 'Purchase Ct', 'Purchase Amt', 'Cash', 'Card', 'Bank', 'Due'];
    final dataRows = _rows.map((r) => [
      DateFormat('dd/MM/yyyy').format(r['dt'] as DateTime),
      r['salesCt'].toString(),
      _fmt(r['salesAmt']),
      r['purchCt'].toString(),
      _fmt(r['purchAmt']),
      _fmt(r['cash']),
      _fmt(r['card']),
      _fmt(r['bank']),
      _fmt(r['due']),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Daily Statement', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Daily Statement', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Daily Statement', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Daily Statement', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: 'B   Daily Statement',
      pageIcon: Icons.calendar_view_day_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _rows.length,
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : _buildTable(),
    );
  }

  Widget _buildTable() {
    double tSales = 0, tPurch = 0, tCash = 0, tCard = 0, tBank = 0, tDue = 0;
    for (final r in _rows) {
      tSales += r['salesAmt']; tPurch += r['purchAmt'];
      tCash += r['cash']; tCard += r['card']; tBank += r['bank']; tDue += r['due'];
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, border: Border.all(color: _bdr),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Column(children: [
          _sectionHeader(title: 'B   Daily Statement', icon: Icons.calendar_view_day_rounded,
              color: const Color(0xFF1565C0), count: _rows.length),
          // Header
          Container(color: _bg1, child: Row(children: [
            _th('Date', w: 100),
            _th('Sales#', w: 60, r: true),
            _th('Sales Amt', w: 120, r: true),
            _th('Purch#', w: 60, r: true),
            _th('Purchase Amt', w: 130, r: true),
            _th('Cash', w: 110, r: true),
            _th('Card', w: 100, r: true),
            _th('Bank / UPI', w: 110, r: true),
            _th('Due', w: 110, r: true),
            _th('Net (Sale-Purch)', flex: true, r: true),
          ])),
          // Middle Scrollable Area
          Expanded(
            child: _rows.isEmpty
                ? _emptyState('No transactions for the selected period.')
                : SingleChildScrollView(
                    child: Column(
                      children: _rows.asMap().entries.map((e) {
                        final r = e.value;
                        final net = (r['salesAmt'] as double) - (r['purchAmt'] as double);
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td(DateFormat('dd/MM/yyyy').format(r['dt'] as DateTime), w: 100),
                            _td('${r['salesCt']}', w: 60, r: true),
                            _td(_fmt(r['salesAmt']), w: 120, r: true, bold: true, c: const Color(0xFF1B5E20)),
                            _td('${r['purchCt']}', w: 60, r: true),
                            _td(_fmt(r['purchAmt']), w: 130, r: true, bold: true, c: const Color(0xFF6A1B9A)),
                            _td(_fmt(r['cash']), w: 110, r: true),
                            _td(_fmt(r['card']), w: 100, r: true),
                            _td(_fmt(r['bank']), w: 110, r: true),
                            _td(_fmt(r['due']), w: 110, r: true,
                                c: (r['due'] as double) > 0 ? const Color(0xFFC62828) : null),
                            _td(_fmt(net), flex: true, r: true, bold: true,
                                c: net >= 0 ? const Color(0xFF1B5E20) : const Color(0xFFC62828)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          // Totals (docked at the bottom)
          Container(
            color: const Color(0xFF1565C0).withAlpha(14),
            child: Row(children: [
              _tt('TOTAL', w: 100),
              _tt('', w: 60),
              _tt(_fmt(tSales), w: 120, r: true, c: const Color(0xFF1B5E20)),
              _tt('', w: 60),
              _tt(_fmt(tPurch), w: 130, r: true, c: const Color(0xFF6A1B9A)),
              _tt(_fmt(tCash), w: 110, r: true),
              _tt(_fmt(tCard), w: 100, r: true),
              _tt(_fmt(tBank), w: 110, r: true),
              _tt(_fmt(tDue), w: 110, r: true,
                  c: tDue > 0 ? const Color(0xFFC62828) : null),
              _tt(_fmt(tSales - tPurch), flex: true, r: true,
                  c: (tSales - tPurch) >= 0 ? const Color(0xFF1B5E20) : const Color(0xFFC62828)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  C ─ ITEM GROUP WISE ALLOY REPORT
//  Groups bill items by metal/purity group
// ─────────────────────────────────────────────────────────────────────────────
class ItemGroupAlloysView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const ItemGroupAlloysView({super.key, this.onReportSelected});
  @override State<ItemGroupAlloysView> createState() => _ItemGroupAlloysState();
}

class _ItemGroupAlloysState extends State<ItemGroupAlloysView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);

  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];

  @override void initState() { super.initState(); _load(); }

  String _metalGroup(String purity) {
    final p = purity.toUpperCase();
    if (p.contains('22') || p.contains('916')) return '22KT Gold (916)';
    if (p.contains('18') || p.contains('750')) return '18KT Gold (750)';
    if (p.contains('14') || p.contains('585')) return '14KT Gold (585)';
    if (p.contains('SILVER') || p.contains('925') || p.contains('S925')) return 'Silver 925';
    if (p.contains('PLATINUM') || p.contains('950')) return 'Platinum 950';
    if (p.contains('DIAMOND') || p.contains('18D') || p.contains('22D')) return 'Diamond';
    if (p.isEmpty) return 'Unspecified';
    return purity;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills')
          .orderBy('voucherDate', descending: true).get();

      final Map<String, Map<String, dynamic>> grpMap = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null || dt.isBefore(_from) || dt.isAfter(_to)) continue;

        // Top-level bill purity
        final purity = d['purity']?.toString() ?? d['carat']?.toString() ?? '';
        final grpKey = _metalGroup(purity.isNotEmpty ? purity : 'Unspecified');

        final g = grpMap.putIfAbsent(grpKey, () => {
          'group': grpKey, 'salesPcs': 0, 'purchPcs': 0,
          'salesGross': 0.0, 'purchGross': 0.0,
          'salesNet': 0.0, 'purchNet': 0.0,
          'salesAmt': 0.0, 'purchAmt': 0.0,
        });

        final isSale = d['billType']?.toString() == 'Sale';
        final gw = _dbl(d['grossWeight']);
        final nw = _dbl(d['netWeight']);
        final amt = _dbl(d['voucherAmt']);

        // Also sum from items array for better granularity
        final items = d['items'] as List?;
        if (items != null && items.isNotEmpty) {
          for (final item in items) {
            if (item is! Map) continue;
            final ip = item['purity']?.toString() ?? item['group']?.toString() ?? purity;
            final iGrp = _metalGroup(ip.isNotEmpty ? ip : purity);
            final ig = grpMap.putIfAbsent(iGrp, () => {
              'group': iGrp, 'salesPcs': 0, 'purchPcs': 0,
              'salesGross': 0.0, 'purchGross': 0.0,
              'salesNet': 0.0, 'purchNet': 0.0,
              'salesAmt': 0.0, 'purchAmt': 0.0,
            });
            final pcs = (item['pcs'] as num?)?.toInt() ?? 1;
            final igw = _dbl(item['grossWeight'] ?? item['weight']);
            final inw = _dbl(item['netWeight']);
            final iamt = _dbl(item['amount']);
            if (isSale) {
              ig['salesPcs'] += pcs; ig['salesGross'] += igw;
              ig['salesNet'] += inw; ig['salesAmt'] += iamt;
            } else {
              ig['purchPcs'] += pcs; ig['purchGross'] += igw;
              ig['purchNet'] += inw; ig['purchAmt'] += iamt;
            }
          }
        } else {
          // Fall back to top-level
          if (isSale) {
            g['salesGross'] += gw; g['salesNet'] += nw; g['salesAmt'] += amt;
          } else {
            g['purchGross'] += gw; g['purchNet'] += nw; g['purchAmt'] += amt;
          }
        }
      }

      final sorted = grpMap.values.toList()
        ..sort((a, b) => (a['group'] as String).compareTo(b['group'] as String));

      if (mounted) setState(() { _groups = sorted; _loading = false; });
    } catch (e) {
      debugPrint('ItemGroupAlloys error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Metal / Alloy Group', 'Sale Pcs', 'Sale Gross Wt', 'Sale Net Wt', 'Sale Amount', 'Purch Pcs', 'Purch Gross Wt', 'Purch Net Wt', 'Purch Amount'];
    final dataRows = _groups.map((r) => [
      r['group'] as String,
      r['salesPcs'].toString(),
      (r['salesGross'] as double).toStringAsFixed(3),
      (r['salesNet'] as double).toStringAsFixed(3),
      _fmt(r['salesAmt']),
      r['purchPcs'].toString(),
      (r['purchGross'] as double).toStringAsFixed(3),
      (r['purchNet'] as double).toStringAsFixed(3),
      _fmt(r['purchAmt']),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Item Group Wise Alloy Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Item Group Wise Alloy Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Item Group Wise Alloy Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Item Group Wise Alloy Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: 'C   Item Group Wise Alloy Report',
      pageIcon: Icons.layers_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _groups.length,
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : _buildTable(),
    );
  }

  Widget _buildTable() {
    final color = const Color(0xFF4E342E);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, border: Border.all(color: _bdr),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Column(children: [
          _sectionHeader(title: 'C   Item Group Wise Alloy Report',
              icon: Icons.layers_rounded, color: color, count: _groups.length),
          Container(color: _bg1, child: Row(children: [
            _th('Metal / Alloy Group', flex: true),
            _th('Sale Pcs', w: 72, r: true),
            _th('Sale Gross Wt', w: 110, r: true),
            _th('Sale Net Wt', w: 100, r: true),
            _th('Sale Amount', w: 120, r: true),
            _th('Purch Pcs', w: 72, r: true),
            _th('Purch Gross Wt', w: 110, r: true),
            _th('Purch Net Wt', w: 100, r: true),
            _th('Purch Amount', w: 120, r: true),
          ])),
          Expanded(
            child: _groups.isEmpty
                ? _emptyState('No alloy data for the selected period.')
                : SingleChildScrollView(
                    child: Column(
                      children: _groups.asMap().entries.map((e) {
                        final r = e.value;
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td(r['group'] as String, flex: true, bold: true),
                            _td('${r['salesPcs']}', w: 72, r: true),
                            _td((r['salesGross'] as double).toStringAsFixed(3), w: 110, r: true),
                            _td((r['salesNet'] as double).toStringAsFixed(3), w: 100, r: true),
                            _td(_fmt(r['salesAmt']), w: 120, r: true, c: const Color(0xFF1B5E20)),
                            _td('${r['purchPcs']}', w: 72, r: true),
                            _td((r['purchGross'] as double).toStringAsFixed(3), w: 110, r: true),
                            _td((r['purchNet'] as double).toStringAsFixed(3), w: 100, r: true),
                            _td(_fmt(r['purchAmt']), w: 120, r: true, c: const Color(0xFF6A1B9A)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Container(
            color: color.withAlpha(14),
            child: Row(children: [
              _tt('TOTAL', flex: true),
              _tt('${_groups.fold<int>(0, (s, r) => s + (r['salesPcs'] as int))}', w: 72, r: true),
              _tt(_groups.fold<double>(0, (s, r) => s + (r['salesGross'] as double)).toStringAsFixed(3), w: 110, r: true),
              _tt(_groups.fold<double>(0, (s, r) => s + (r['salesNet'] as double)).toStringAsFixed(3), w: 100, r: true),
              _tt(_fmt(_groups.fold<double>(0, (s, r) => s + (r['salesAmt'] as double))), w: 120, r: true, c: const Color(0xFF1B5E20)),
              _tt('${_groups.fold<int>(0, (s, r) => s + (r['purchPcs'] as int))}', w: 72, r: true),
              _tt(_groups.fold<double>(0, (s, r) => s + (r['purchGross'] as double)).toStringAsFixed(3), w: 110, r: true),
              _tt(_groups.fold<double>(0, (s, r) => s + (r['purchNet'] as double)).toStringAsFixed(3), w: 100, r: true),
              _tt(_fmt(_groups.fold<double>(0, (s, r) => s + (r['purchAmt'] as double))), w: 120, r: true, c: const Color(0xFF6A1B9A)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  D ─ MONTHLY SUMMARY REPORT
// ─────────────────────────────────────────────────────────────────────────────
class MonthlySummaryView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const MonthlySummaryView({super.key, this.onReportSelected});
  @override State<MonthlySummaryView> createState() => _MonthlySummaryState();
}

class _MonthlySummaryState extends State<MonthlySummaryView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills').orderBy('voucherDate').get();
      final Map<String, Map<String, dynamic>> byMonth = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null || dt.isBefore(_from) || dt.isAfter(_to)) continue;

        final key = DateFormat('yyyy-MM').format(dt);
        final entry = byMonth.putIfAbsent(key, () => {
          'monthLabel': DateFormat('MMM yyyy').format(dt),
          'salesCt': 0, 'salesAmt': 0.0,
          'purchCt': 0, 'purchAmt': 0.0,
          'cash': 0.0, 'card': 0.0, 'bank': 0.0, 'due': 0.0,
          'grossWt': 0.0, 'netWt': 0.0,
        });

        final isSale = d['billType']?.toString() == 'Sale';
        final amt = _dbl(d['voucherAmt']);
        if (isSale) { entry['salesCt'] += 1; entry['salesAmt'] += amt; }
        else { entry['purchCt'] += 1; entry['purchAmt'] += amt; }
        entry['cash']    += _dbl(d['cashAmt']);
        entry['card']    += _dbl(d['cardAmt']);
        entry['bank']    += _dbl(d['bankAmt']);
        entry['due']     += _dbl(d['dueAmt']);
        entry['grossWt'] += _dbl(d['grossWeight']);
        entry['netWt']   += _dbl(d['netWeight']);
      }

      final sorted = byMonth.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      if (mounted) setState(() { _rows = sorted.map((e) => e.value).toList(); _loading = false; });
    } catch (e) {
      debugPrint('MonthlySummary error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Month', 'Sale Count', 'Sale Amt', 'Purch Count', 'Purch Amt', 'Gross Wt', 'Net Wt', 'Cash', 'Card', 'Bank/UPI', 'Due'];
    final dataRows = _rows.map((r) => [
      r['monthLabel'] as String,
      r['salesCt'].toString(),
      _fmt(r['salesAmt']),
      r['purchCt'].toString(),
      _fmt(r['purchAmt']),
      (r['grossWt'] as double).toStringAsFixed(3),
      (r['netWt'] as double).toStringAsFixed(3),
      _fmt(r['cash']),
      _fmt(r['card']),
      _fmt(r['bank']),
      _fmt(r['due']),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Monthly Summary Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Monthly Summary Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Monthly Summary Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Monthly Summary Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: 'D   Monthly Summary Report',
      pageIcon: Icons.bar_chart_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _rows.length,
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : _buildTable(),
    );
  }

  Widget _buildTable() {
    const color = Color(0xFF00695C);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(children: [
          _sectionHeader(title: 'D   Monthly Summary Report',
              icon: Icons.bar_chart_rounded, color: color, count: _rows.length),
          Container(color: _bg1, child: Row(children: [
            _th('Month', w: 110),
            _th('Sale#', w: 55, r: true),
            _th('Sale Amt', w: 120, r: true),
            _th('Purch#', w: 55, r: true),
            _th('Purch Amt', w: 120, r: true),
            _th('Gross Wt', w: 90, r: true),
            _th('Net Wt', w: 90, r: true),
            _th('Cash', w: 110, r: true),
            _th('Card', w: 100, r: true),
            _th('Bank/UPI', w: 110, r: true),
            _th('Due', flex: true, r: true),
          ])),
          Expanded(
            child: _rows.isEmpty
                ? _emptyState('No data for the selected year.')
                : SingleChildScrollView(
                    child: Column(
                      children: _rows.asMap().entries.map((e) {
                        final r = e.value;
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td(r['monthLabel'] as String, w: 110, bold: true),
                            _td('${r['salesCt']}', w: 55, r: true),
                            _td(_fmt(r['salesAmt']), w: 120, r: true, c: const Color(0xFF1B5E20)),
                            _td('${r['purchCt']}', w: 55, r: true),
                            _td(_fmt(r['purchAmt']), w: 120, r: true, c: const Color(0xFF6A1B9A)),
                            _td((r['grossWt'] as double).toStringAsFixed(3), w: 90, r: true),
                            _td((r['netWt'] as double).toStringAsFixed(3), w: 90, r: true),
                            _td(_fmt(r['cash']), w: 110, r: true),
                            _td(_fmt(r['card']), w: 100, r: true),
                            _td(_fmt(r['bank']), w: 110, r: true),
                            _td(_fmt(r['due']), flex: true, r: true,
                                c: (r['due'] as double) > 0 ? const Color(0xFFC62828) : null),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Container(
            color: color.withAlpha(14),
            child: Row(children: [
              _tt('TOTAL', w: 110),
              _tt('${_rows.fold<int>(0, (s, r) => s + (r['salesCt'] as int))}', w: 55, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['salesAmt'] as double))), w: 120, r: true, c: const Color(0xFF1B5E20)),
              _tt('${_rows.fold<int>(0, (s, r) => s + (r['purchCt'] as int))}', w: 55, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['purchAmt'] as double))), w: 120, r: true, c: const Color(0xFF6A1B9A)),
              _tt(_rows.fold(0.0, (s, r) => s + (r['grossWt'] as double)).toStringAsFixed(3), w: 90, r: true),
              _tt(_rows.fold(0.0, (s, r) => s + (r['netWt'] as double)).toStringAsFixed(3), w: 90, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['cash'] as double))), w: 110, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['card'] as double))), w: 100, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['bank'] as double))), w: 110, r: true),
              _tt(_fmt(_rows.fold(0.0, (s, r) => s + (r['due'] as double))), flex: true, r: true,
                  c: _rows.fold(0.0, (s, r) => s + (r['due'] as double)) > 0
                      ? const Color(0xFFC62828) : null),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  E ─ VOUCHER PRINT  (list all bills, show details)
// ─────────────────────────────────────────────────────────────────────────────
class VoucherPrintView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const VoucherPrintView({super.key, this.onReportSelected});
  @override State<VoucherPrintView> createState() => _VoucherPrintState();
}

class _VoucherPrintState extends State<VoucherPrintView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _bills = [];
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _bills;
    return _bills.where((b) =>
        b['voucherNo'].toString().toLowerCase().contains(_q) ||
        b['acName'].toString().toLowerCase().contains(_q)).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills').orderBy('voucherDate', descending: true).get();
      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null || dt.isBefore(_from) || dt.isAfter(_to)) continue;
        list.add({...d, '_id': doc.id, '_dt': dt});
      }
      if (mounted) setState(() { _bills = list; _loading = false; });
    } catch (e) {
      debugPrint('VoucherPrint error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party', 'Item', 'Gross Wt', 'Net Wt', 'Bill Amt', 'Cash', 'Due Amt'];
    final dataRows = _filtered.map((b) => [
      b['voucherNo'].toString(),
      DateFormat('dd/MM/yyyy').format(b['_dt'] as DateTime),
      b['billType']?.toString() ?? '',
      b['acName']?.toString() ?? '',
      b['itemName']?.toString() ?? '',
      _dbl(b['grossWeight']).toStringAsFixed(3),
      _dbl(b['netWeight']).toStringAsFixed(3),
      _fmt(_dbl(b['voucherAmt'])),
      _fmt(_dbl(b['cashAmt'])),
      _fmt(_dbl(b['dueAmt'])),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Voucher Print Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Voucher Print Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Voucher Print Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Voucher Print Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: 'E   Voucher Print',
      pageIcon: Icons.print_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _filtered.length,
      searchCtrl: _searchCtrl,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : _buildTable(),
    );
  }

  Widget _buildTable() {
    const color = Color(0xFF37474F);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(children: [
          _sectionHeader(title: 'E   Voucher Print', icon: Icons.print_rounded,
              color: color, count: _filtered.length),
          Container(color: _bg1, child: Row(children: [
            _th('Voucher No', w: 120),
            _th('Date', w: 90),
            _th('Type', w: 90),
            _th('Party', flex: true),
            _th('Item', w: 150),
            _th('Gross Wt', w: 80, r: true),
            _th('Net Wt', w: 80, r: true),
            _th('Bill Amt', w: 110, r: true),
            _th('Cash', w: 90, r: true),
            _th('Due Amt', w: 90, r: true),
            _th('Action', w: 80),
          ])),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState('No vouchers for the selected date.')
                : SingleChildScrollView(
                    child: Column(
                      children: _filtered.asMap().entries.map((e) {
                        final b = e.value;
                        final isSale = b['billType']?.toString() == 'Sale';
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td(b['voucherNo']?.toString() ?? '—', w: 120),
                            _td(DateFormat('dd/MM/yyyy').format(b['_dt'] as DateTime), w: 90),
                            _td(b['billType']?.toString() ?? '—', w: 90,
                                c: isSale ? const Color(0xFF1B5E20) : const Color(0xFF6A1B9A)),
                            _td(b['acName']?.toString() ?? '—', flex: true),
                            _td(b['itemName']?.toString() ?? '—', w: 150),
                            _td(_dbl(b['grossWeight']).toStringAsFixed(3), w: 80, r: true),
                            _td(_dbl(b['netWeight']).toStringAsFixed(3), w: 80, r: true),
                            _td(_fmt(_dbl(b['voucherAmt'])), w: 110, r: true, bold: true),
                            _td(_dbl(b['cashAmt']) > 0 ? _fmt(_dbl(b['cashAmt'])) : '—', w: 90, r: true),
                            _td(_dbl(b['dueAmt']) > 0 ? _fmt(_dbl(b['dueAmt'])) : '—', w: 90, r: true,
                                c: _dbl(b['dueAmt']) > 0 ? const Color(0xFFC62828) : null),
                            SizedBox(
                              width: 80,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: TextButton.icon(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Open ${b['voucherNo']} from the bills list to print.'),
                                        backgroundColor: _br, duration: const Duration(seconds: 2)),
                                  ),
                                  icon: const Icon(Icons.print_rounded, size: 12),
                                  label: const Text('Print', style: TextStyle(fontSize: 10)),
                                  style: TextButton.styleFrom(
                                      foregroundColor: _br,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                                ),
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  F ─ FIX FORMAT REGISTER  (parameterised — covers all F.A to F.P)
// ─────────────────────────────────────────────────────────────────────────────
class FixFormatRegisterView extends StatefulWidget {
  final String registerTitle; // e.g. 'Sales Register', 'Purchase Register'
  final ValueChanged<String>? onReportSelected;
  const FixFormatRegisterView({super.key, required this.registerTitle, this.onReportSelected});
  @override State<FixFormatRegisterView> createState() => _FixFormatRegisterState();
}

class _FixFormatRegisterState extends State<FixFormatRegisterView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _searchCtrl = TextEditingController();
  String _q = '';

  final List<String> _selectedExtraColumns = [];
  final Map<String, String> _availableExtraColumns = {
    'GST Number': 'gstNo',
    'PAN Number': 'panNo',
    'Mobile No': 'phone',
    'Email': 'email',
    'City': 'city',
    'State': 'state',
    'Salesman': 'salesman',
    'Narration': 'narration',
    'Bank Name': 'bankName',
    'Cheque No': 'bankChequeNo',
    'Card Machine': 'cardMachine',
    'Approval No': 'cardApprovalNo',
    'Remarks': 'remarks',
    'Reference No': 'refNo',
  };

  String _getDynamicValue(Map r, String colName) {
    final key = _availableExtraColumns[colName] ?? '';
    if (key.isEmpty) return '—';
    if (r.containsKey(key) && r[key] != null && r[key].toString().isNotEmpty) return r[key].toString();
    final cDet = r['customerDetails'];
    if (cDet is Map && cDet.containsKey(key) && cDet[key] != null && cDet[key].toString().isNotEmpty) return cDet[key].toString();
    final sDet = r['supplierDetails'];
    if (sDet is Map && sDet.containsKey(key) && sDet[key] != null && sDet[key].toString().isNotEmpty) return sDet[key].toString();
    return '—';
  }

  String get _collection {
    final t = widget.registerTitle;
    if (t.contains('Inward Service') || t.contains('Outward Service')) return 'service_entries';
    if (t.contains('Customer Issue') || t.contains('Customer Receipt')) return 'consignment_entries';
    if (t.contains('Refinery')) return 'refinery_entries';
    if (t.contains('Sales') || t.contains('Purchase')) return 'bills';
    return 'generic_entries';
  }

  String? get _typeFilter {
    final t = widget.registerTitle;
    if (t.contains('Sales Return')) return 'SalesReturn';
    if (t.contains('Purchase Return')) return 'PurchaseReturn';
    if (t.contains('Sales Register')) return 'Sale';
    if (t.contains('Purchase Register')) return 'Purchase';
    if (t.contains('Customer Issue')) return 'Consignment Issue';
    if (t.contains('Customer Receipt')) return 'Consignment Receipt';
    if (t.contains('Supplier Issue')) return 'Supplier Issue';
    if (t.contains('Supplier Receipt')) return 'Supplier Receipt';
    return null;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _rows;
    return _rows.where((r) =>
        r['voucherNo'].toString().toLowerCase().contains(_q) ||
        r['acName'].toString().toLowerCase().contains(_q)).toList();
  }

  @override void initState() { super.initState(); _load(); }
  
  @override
  void didUpdateWidget(covariant FixFormatRegisterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registerTitle != widget.registerTitle) {
      _load();
    }
  }

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      QuerySnapshot snap;
      if (_collection == 'service_entries') {
        snap = await FirebaseFirestore.instance.collection('service_entries').get();
      } else if (_collection == 'bills') {
        snap = await FirebaseFirestore.instance.collection('bills').orderBy('voucherDate', descending: true).get();
      } else {
        snap = await FirebaseFirestore.instance.collection(_collection).get();
      }

      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;

        // Date
        DateTime? dt;
        if (_collection == 'service_entries') {
          if (d['createdAt'] is Timestamp) dt = (d['createdAt'] as Timestamp).toDate();
          if (dt == null) {
            try {
              if (d['date'] != null) {
                final parts = d['date'].toString().split('/');
                if (parts.length >= 3) dt = DateTime(int.parse(parts[2].substring(0, 4)), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {}
          }
        } else if (_collection == 'bills') {
          dt = _ts(d['voucherDate']);
        } else {
          // For generic, consignment, refinery
          if (d['voucherDate'] != null) {
            try {
              final parts = d['voucherDate'].toString().split(' ')[0].split('/'); // handles "17/08/2026 EEE"
              if (parts.length >= 3) dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            } catch (_) {}
          }
          if (dt == null && d['createdAt'] is Timestamp) dt = (d['createdAt'] as Timestamp).toDate();
        }
        if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;

        // Apply type filter
        if (_typeFilter != null) {
          if (_collection == 'bills') {
            final bt = d['billType']?.toString() ?? '';
            if (bt != _typeFilter) continue;
          } else if (_collection == 'consignment_entries' || _collection == 'generic_entries') {
            final vt = d['voucherType']?.toString().toLowerCase() ?? '';
            if (!vt.contains(_typeFilter!.toLowerCase())) continue;
          }
        } else if (_collection == 'refinery_entries') {
          final vt = d['voucherType']?.toString().toLowerCase() ?? '';
          if (widget.registerTitle.toLowerCase().contains('issue') && !vt.contains('issue')) continue;
          if (widget.registerTitle.toLowerCase().contains('receipt') && !vt.contains('receipt')) continue;
        }

        list.add({...d, '_id': doc.id, '_dt': dt});
      }

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('FixFormatRegister error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final List<String> headers = [];
    final List<List<dynamic>> dataRows = [];
    
    final isSalesOrPurch = widget.registerTitle.contains('Sales Register') || widget.registerTitle.contains('Purchase Register');
    
    if (isSalesOrPurch) {
      final isSales = widget.registerTitle.contains('Sales');
      headers.addAll([
        'Vou. No', 'Vou date', 'Name', 'item name', 'carat', 'gr. wt', 'Nt. wt',
        'GST Taxable amnt', 'GST Total %', 'total GST Amnt', 'IGST Amnt', 'CGST Amnt', 'SGST Amt',
        'Rnd. Discount', 'Bill amnt', 'Card Amt', 'Bank Amnt', 'Cash Amnt',
        isSales ? 'Pan. No.' : 'GST Number'
      ]);
      headers.addAll(_selectedExtraColumns);
      
      for (final r in _filtered) {
        final List<dynamic> row = [
          r['voucherNo']?.toString() ?? '',
          DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime),
          r['acName']?.toString() ?? '',
          r['itemName']?.toString() ?? '',
          r['carat']?.toString() ?? r['purity']?.toString() ?? '',
          _dbl(r['grossWeight']).toStringAsFixed(3),
          _dbl(r['netWeight']).toStringAsFixed(3),
          _fmt(_dbl(r['afterDiscount'])),
          _dbl(r['gstPercentage']).toStringAsFixed(2),
          _fmt(_dbl(r['gstAmt'])),
          _fmt(_dbl(r['igstAmt'])),
          _fmt(_dbl(r['cgstAmt'])),
          _fmt(_dbl(r['sgstAmt'])),
          _fmt(_dbl(r['discountAmt']) + _dbl(r['rndDiscount'])),
          _fmt(_dbl(r['voucherAmt'])),
          _fmt(_dbl(r['cardAmt'])),
          _fmt(_dbl(r['bankAmt'])),
          _fmt(_dbl(r['cashAmt'])),
          isSales ? (r['panNo']?.toString() ?? '—') : (r['gstNo']?.toString() ?? '—')
        ];
        for (final extra in _selectedExtraColumns) {
          row.add(_getDynamicValue(r, extra));
        }
        dataRows.add(row);
      }
    } else {
      final isService = _collection == 'service_entries';
      headers.addAll(['Voucher No', 'Date', 'Party Name', 'Item / Type']);
      if (!isService) {
        headers.addAll(['Gross Wt', 'Net Wt', 'Cash', 'Card', 'Bank/UPI', 'Due']);
      }
      headers.add('Amount');
      headers.addAll(_selectedExtraColumns);
      
      for (final r in _filtered) {
        final List<dynamic> row = [
          r['voucherNo']?.toString() ?? '',
          DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime),
          r['acName']?.toString() ?? '',
          r['itemName']?.toString() ?? r['transactionType']?.toString() ?? '',
        ];
        if (!isService) {
          row.addAll([
            _dbl(r['grossWeight']).toStringAsFixed(3),
            _dbl(r['netWeight']).toStringAsFixed(3),
            _fmt(_dbl(r['cashAmt'])),
            _fmt(_dbl(r['cardAmt'])),
            _fmt(_dbl(r['bankAmt'])),
            _fmt(_dbl(r['dueAmt'])),
          ]);
        }
        row.add(_fmt(isService ? _dbl(r['amount']) : _dbl(r['voucherAmt'])));
        for (final extra in _selectedExtraColumns) {
          row.add(_getDynamicValue(r, extra));
        }
        dataRows.add(row);
      }
    }

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: widget.registerTitle, headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: widget.registerTitle, headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: widget.registerTitle, headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, widget.registerTitle, '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: widget.registerTitle,
      pageIcon: Icons.table_rows_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _filtered.length,
      searchCtrl: _searchCtrl,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : (widget.registerTitle.contains('Sales Register') || widget.registerTitle.contains('Purchase Register') ? _buildExtendedRegisterTable() : _buildTable()),
    );
  }

  Widget _buildAddColumnButton() {
    final isSales = widget.registerTitle.contains('Sales');
    
    // Show all available columns except the ones that are hardcoded by default
    final validOptions = _availableExtraColumns.keys.where((col) {
      if (widget.registerTitle.contains('Sales Register') || widget.registerTitle.contains('Purchase Register')) {
        if (isSales && col == 'PAN Number') return false; 
        if (!isSales && col == 'GST Number') return false; 
      }
      return true;
    }).toList();

    if (validOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 40,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.add_circle, color: Colors.blueGrey, size: 20),
        tooltip: 'Columns',
        onSelected: (col) {
          setState(() {
            if (_selectedExtraColumns.contains(col)) {
              _selectedExtraColumns.remove(col);
            } else {
              _selectedExtraColumns.add(col);
            }
          });
        },
        itemBuilder: (ctx) => validOptions.map((c) {
          final isSelected = _selectedExtraColumns.contains(c);
          return PopupMenuItem<String>(
            value: c,
            height: 35,
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFFCA6F1E),
                    onChanged: (val) {
                      // We can pop the menu manually if we want, but let the PopupMenuItem handle the main tap.
                      Navigator.pop(ctx, c);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(c, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExtendedRegisterTable() {
    final isSales = widget.registerTitle.contains('Sales');
    const color = Color(0xFF5D4037);
    double tGross = 0, tNet = 0, tTaxable = 0, tGst = 0, tIgst = 0, tCgst = 0, tSgst = 0;
    double tDiscount = 0, tBillAmt = 0, tCard = 0, tBank = 0, tCash = 0;

    for (final r in _filtered) {
      tGross += _dbl(r['grossWeight']);
      tNet += _dbl(r['netWeight']);
      tTaxable += _dbl(r['afterDiscount']);
      tGst += _dbl(r['gstAmt']);
      tIgst += _dbl(r['igstAmt']);
      tCgst += _dbl(r['cgstAmt']);
      tSgst += _dbl(r['sgstAmt']);
      tDiscount += _dbl(r['discountAmt']) + _dbl(r['rndDiscount']);
      tBillAmt += _dbl(r['voucherAmt']);
      tCard += _dbl(r['cardAmt']);
      tBank += _dbl(r['bankAmt']);
      tCash += _dbl(r['cashAmt']);
    }

    final tableWidth = 2100.0 + (_selectedExtraColumns.length * 120.0) + 40.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(
          children: [
            _sectionHeader(title: 'F › ${widget.registerTitle}', icon: Icons.table_rows_rounded, color: color, count: _filtered.length),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      Container(
                        color: _bg1,
                        child: Row(
                          children: [
                            _th('Vou. No', w: 100),
                            _th('Vou date', w: 90),
                            _th('Name', w: 200), // Party Name
                            _th('item name', w: 150),
                            _th('carat', w: 80),
                            _th('gr. wt', w: 80, r: true),
                            _th('Nt. wt', w: 80, r: true),
                            _th('GST Taxable amnt', w: 120, r: true),
                            _th('GST Total %', w: 90, r: true),
                            _th('total GST Amnt', w: 110, r: true),
                            _th('IGST Amnt', w: 90, r: true),
                            _th('CGST Amnt', w: 90, r: true),
                            _th('SGST Amt', w: 90, r: true),
                            _th('Rnd. Discount', w: 100, r: true),
                            _th('Bill amnt', w: 110, r: true),
                            _th('Card Amt', w: 90, r: true),
                            _th('Bank Amnt', w: 90, r: true),
                            _th('Cash Amnt', w: 90, r: true),
                            if (isSales) _th('Pan. No.', w: 120),
                            if (!isSales) _th('GST Number', w: 130),
                            ..._selectedExtraColumns.map((c) => _th(c, w: 120)),
                            _buildAddColumnButton(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _filtered.isEmpty
                            ? _emptyState('No entries in Sales Register for the selected period.')
                            : SingleChildScrollView(
                                child: Column(
                                  children: _filtered.asMap().entries.map((e) {
                                    final r = e.value;
                                    final dt = r['_dt'] as DateTime;
                                    
                                    // Extract data
                                    final vNo = r['voucherNo']?.toString() ?? '—';
                                    final party = r['acName']?.toString() ?? '—';
                                    final item = r['itemName']?.toString() ?? '—';
                                    final carat = r['carat']?.toString() ?? r['purity']?.toString() ?? '—';
                                    
                                    final gross = _dbl(r['grossWeight']);
                                    final net = _dbl(r['netWeight']);
                                    final taxable = _dbl(r['afterDiscount']);
                                    final gstAmt = _dbl(r['gstAmt']);
                                    
                                    String gstPct = '0%';
                                    if (taxable > 0 && gstAmt > 0) {
                                      gstPct = '${((gstAmt / taxable) * 100).round()}%';
                                    }

                                    final igst = _dbl(r['igstAmt']);
                                    final cgst = _dbl(r['cgstAmt']);
                                    final sgst = _dbl(r['sgstAmt']);
                                    final discount = _dbl(r['discountAmt']) + _dbl(r['rndDiscount']);
                                    final bill = _dbl(r['voucherAmt']);
                                    final card = _dbl(r['cardAmt']);
                                    final bank = _dbl(r['bankAmt']);
                                    final cash = _dbl(r['cashAmt']);
                                    
                                    // Customer Details map
                                    final cDet = r['customerDetails'] as Map?;
                                    final panNo = cDet?['panNo']?.toString() ?? '—';
                                    final gstNo = cDet?['gstNo']?.toString() ?? '—';

                                    return Container(
                                      color: e.key.isEven ? Colors.white : _bg0,
                                      child: Row(
                                        children: [
                                          _td(vNo, w: 100),
                                          _td(DateFormat('dd/MM/yyyy').format(dt), w: 90),
                                          _td(party, w: 200),
                                          _td(item, w: 150),
                                          _td(carat, w: 80),
                                          _td(gross.toStringAsFixed(3), w: 80, r: true),
                                          _td(net.toStringAsFixed(3), w: 80, r: true),
                                          _td(_fmt(taxable), w: 120, r: true),
                                          _td(gstPct, w: 90, r: true),
                                          _td(_fmt(gstAmt), w: 110, r: true),
                                          _td(_fmt(igst), w: 90, r: true),
                                          _td(_fmt(cgst), w: 90, r: true),
                                          _td(_fmt(sgst), w: 90, r: true),
                                          _td(_fmt(discount), w: 100, r: true),
                                          _td(_fmt(bill), w: 110, r: true, bold: true),
                                          _td(card > 0 ? _fmt(card) : '—', w: 90, r: true),
                                          _td(bank > 0 ? _fmt(bank) : '—', w: 90, r: true),
                                          _td(cash > 0 ? _fmt(cash) : '—', w: 90, r: true),
                                          if (isSales) _td(panNo, w: 120),
                                          if (!isSales) _td(gstNo, w: 130),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      Container(
                        color: color.withAlpha(14),
                        child: Row(
                          children: [
                            _tt('TOTAL', w: 100),
                            _tt('', w: 90),
                            _tt('', w: 200),
                            _tt('', w: 150),
                            _tt('', w: 80),
                            _tt(tGross.toStringAsFixed(3), w: 80, r: true),
                            _tt(tNet.toStringAsFixed(3), w: 80, r: true),
                            _tt(_fmt(tTaxable), w: 120, r: true),
                            _tt('', w: 90, r: true),
                            _tt(_fmt(tGst), w: 110, r: true),
                            _tt(_fmt(tIgst), w: 90, r: true),
                            _tt(_fmt(tCgst), w: 90, r: true),
                            _tt(_fmt(tSgst), w: 90, r: true),
                            _tt(_fmt(tDiscount), w: 100, r: true),
                            _tt(_fmt(tBillAmt), w: 110, r: true),
                            _tt(_fmt(tCard), w: 90, r: true),
                            _tt(_fmt(tBank), w: 90, r: true),
                            _tt(_fmt(tCash), w: 90, r: true),
                            if (isSales) _tt('', w: 120),
                            if (!isSales) _tt('', w: 130),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final isService = _collection == 'service_entries';
    const color = Color(0xFF5D4037);
    double tAmt = 0, tGross = 0, tNet = 0, tCash = 0, tCard = 0, tBank = 0, tDue = 0;
    for (final r in _filtered) {
      final amt = isService ? _dbl(r['amount']) : _dbl(r['voucherAmt']);
      tAmt += amt; tGross += _dbl(r['grossWeight']); tNet += _dbl(r['netWeight']);
      if (!isService) { tCash += _dbl(r['cashAmt']); tCard += _dbl(r['cardAmt']); tBank += _dbl(r['bankAmt']); tDue += _dbl(r['dueAmt']); }
    }

    // Calculate dynamic width for generic table if extra columns are selected
    double dynamicTableWidth = 1000.0;
    if (!isService) dynamicTableWidth += 510.0; // sum of gross, net, cash, card, bank, due
    dynamicTableWidth += _selectedExtraColumns.length * 120.0 + 40.0;
    final bool needsScroll = _selectedExtraColumns.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(children: [
          _sectionHeader(title: 'F › ${widget.registerTitle}',
              icon: Icons.table_rows_rounded, color: color, count: _filtered.length),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: needsScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: needsScroll ? dynamicTableWidth : MediaQuery.of(context).size.width - 32,
                child: Column(
                  children: [
                    Container(color: _bg1, child: Row(children: [
                      _th('Voucher No', w: 120),
                      _th('Date', w: 90),
                      _th('Party Name', flex: !needsScroll, w: needsScroll ? 200 : null),
                      _th('Item / Type', w: 150),
                      if (!isService) ...[
                        _th('Gross Wt', w: 80, r: true),
                        _th('Net Wt', w: 80, r: true),
                        _th('Cash', w: 90, r: true),
                        _th('Card', w: 80, r: true),
                        _th('Bank/UPI', w: 90, r: true),
                        _th('Due', w: 90, r: true),
                      ],
                      _th('Amount', w: 110, r: true),
                      ..._selectedExtraColumns.map((c) => _th(c, w: 120)),
                      _buildAddColumnButton(),
                    ])),
                    Expanded(
                      child: _filtered.isEmpty
                          ? _emptyState('No entries in ${widget.registerTitle} for the selected period.')
                          : SingleChildScrollView(
                              child: Column(
                                children: _filtered.asMap().entries.map((e) {
                                  final r = e.value;
                                  final dt = r['_dt'] as DateTime;
                                  final vNo = r['voucherNo']?.toString() ?? r['docId']?.toString() ?? '—';
                                  final party = r['acName']?.toString() ?? r['accountName']?.toString() ?? '—';
                                  final item  = r['itemName']?.toString() ?? r['voucherType']?.toString() ?? '—';
                                  final amt = isService ? _dbl(r['amount']) : _dbl(r['voucherAmt']);
                                  return Container(
                                    color: e.key.isEven ? Colors.white : _bg0,
                                    child: Row(children: [
                                      _td(vNo, w: 120),
                                      _td(DateFormat('dd/MM/yyyy').format(dt), w: 90),
                                      _td(party, flex: !needsScroll, w: needsScroll ? 200 : null),
                                      _td(item, w: 150),
                                      if (!isService) ...[
                                        _td(_dbl(r['grossWeight']).toStringAsFixed(3), w: 80, r: true),
                                        _td(_dbl(r['netWeight']).toStringAsFixed(3), w: 80, r: true),
                                        _td(_dbl(r['cashAmt']) > 0 ? _fmt(_dbl(r['cashAmt'])) : '—', w: 90, r: true),
                                        _td(_dbl(r['cardAmt']) > 0 ? _fmt(_dbl(r['cardAmt'])) : '—', w: 80, r: true),
                                        _td(_dbl(r['bankAmt']) > 0 ? _fmt(_dbl(r['bankAmt'])) : '—', w: 90, r: true),
                                        _td(_dbl(r['dueAmt']) > 0 ? _fmt(_dbl(r['dueAmt'])) : '—', w: 90, r: true,
                                            c: _dbl(r['dueAmt']) > 0 ? const Color(0xFFC62828) : null),
                                      ],
                                      _td(_fmt(amt), w: 110, r: true, bold: true),
                                      ..._selectedExtraColumns.map((c) => _td(_getDynamicValue(r, c), w: 120)),
                                      const SizedBox(width: 40),
                                    ]),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    Container(
                      color: color.withAlpha(14),
                      child: Row(children: [
                        _tt('TOTAL', w: 120),
                        _tt('', w: 90),
                        needsScroll ? _tt('', w: 200) : Expanded(child: _tt('')),
                        _tt('', w: 150),
                        if (!isService) ...[
                          _tt(tGross.toStringAsFixed(3), w: 80, r: true),
                          _tt(tNet.toStringAsFixed(3), w: 80, r: true),
                          _tt(_fmt(tCash), w: 90, r: true),
                          _tt(_fmt(tCard), w: 80, r: true),
                          _tt(_fmt(tBank), w: 90, r: true),
                          _tt(_fmt(tDue), w: 90, r: true, c: tDue > 0 ? const Color(0xFFC62828) : null),
                        ],
                        _tt(_fmt(tAmt), w: 110, r: true),
                        ..._selectedExtraColumns.map((c) => _tt('', w: 120)),
                        const SizedBox(width: 40),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  G ─ ADD/LESS SPLIT TRANSFER LABEL REPORT
//  Shows jewelry_inventory items by their status / movement
// ─────────────────────────────────────────────────────────────────────────────
class AddLessSplitTransferView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const AddLessSplitTransferView({super.key, this.onReportSelected});
  @override State<AddLessSplitTransferView> createState() => _AddLessSplitTransferState();
}

class _AddLessSplitTransferState extends State<AddLessSplitTransferView> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  String _statusFilter = 'All';
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    var rows = _rows;
    if (_statusFilter != 'All') rows = rows.where((r) => r['status'] == _statusFilter).toList();
    if (_q.isNotEmpty) {
      rows = rows.where((r) =>
          r['tagId'].toString().toLowerCase().contains(_q) ||
          r['name'].toString().toLowerCase().contains(_q) ||
          r['category'].toString().toLowerCase().contains(_q)).toList();
    }
    return rows;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('jewelry_inventory').get();
      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final d = doc.data();
        final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
        final pcs = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? 1;
        final isSold = pcs <= 0 || rawStatus.toLowerCase() == 'sold' || rawStatus.toLowerCase() == 'out of stock';
        final isYetToAdd = d['yetToAdd'] == true || rawStatus == 'Yet to add';
        final status = isSold ? 'Sold' : isYetToAdd ? 'Yet to Add' : 'Available';

        list.add({
          'tagId':    d['id']?.toString() ?? doc.id,
          'name':     d['name']?.toString() ?? d['productName']?.toString() ?? '—',
          'category': d['category']?.toString() ?? d['groupName']?.toString() ?? '—',
          'purity':   d['purity']?.toString() ?? d['metalId']?.toString() ?? '—',
          'grossWt':  _dbl(d['grossWeight'] ?? d['grossWt']),
          'netWt':    _dbl(d['netWeight'] ?? d['netWt']),
          'pcs':      pcs,
          'counter':  d['counterNo']?.toString() ?? d['counter']?.toString() ?? '—',
          'status':   status,
          'createdAt': _ts(d['createdAt']),
        });
      }

      list.sort((a, b) {
        const ord = {'Available': 0, 'Yet to Add': 1, 'Sold': 2};
        return (ord[a['status']] ?? 3).compareTo(ord[b['status']] ?? 3);
      });

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('AddLessSplit error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Master Tag', 'Product Name', 'Category', 'Purity', 'Gross Wt', 'Net Wt', 'Pcs', 'Counter', 'Status'];
    final dataRows = _filtered.map((r) => [
      (r['tagId']?.toString() ?? '').replaceAll(RegExp(r'\[\d+\]$'), ''),
      r['name']?.toString() ?? '',
      r['category']?.toString() ?? '',
      r['purity']?.toString() ?? '',
      _dbl(r['grossWt']).toStringAsFixed(3),
      _dbl(r['netWt']).toStringAsFixed(3),
      r['pcs']?.toString() ?? '1',
      r['counter']?.toString() ?? '',
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Add Less Split Transfer Label Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Add Less Split Transfer Label Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Add Less Split Transfer Label Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Add Less Split Transfer Label Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4527A0);
    final avail = _filtered.where((r) => r['status'] == 'Available').length;
    final sold  = _filtered.where((r) => r['status'] == 'Sold').length;
    final ytadd = _filtered.where((r) => r['status'] == 'Yet to Add').length;

    return Column(children: [
      _reportShell(
        context: context,
        pageTitle: 'G   Add / Less / Split / Transfer Label Report',
        pageIcon: Icons.swap_horiz_rounded,
        from: DateTime.now(), to: DateTime.now(),
        onPickDate: () {}, // Inventory is not date-filtered
        onRefresh: _load,
        totalRecords: _filtered.length,
        searchCtrl: _searchCtrl,
        onSearch: (v) => setState(() => _q = v.toLowerCase()),
        onReportSelected: widget.onReportSelected,
        onExportCsv: () => _export('csv'),
        onExportExcel: () => _export('excel'),
        onExportPdf: () => _export('pdf'),
        body: _loading ? _loader : Column(children: [
          // Status filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _filterChip('All', _statusFilter, (v) => setState(() => _statusFilter = v), Colors.grey),
              const SizedBox(width: 8),
              _filterChip('Available', _statusFilter, (v) => setState(() => _statusFilter = v), const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _filterChip('Yet to Add', _statusFilter, (v) => setState(() => _statusFilter = v), const Color(0xFFF57F17)),
              const SizedBox(width: 8),
              _filterChip('Sold', _statusFilter, (v) => setState(() => _statusFilter = v), const Color(0xFFC62828)),
              const SizedBox(width: 16),
              _statBadge('Available', avail, const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _statBadge('Yet to Add', ytadd, const Color(0xFFF57F17)),
              const SizedBox(width: 8),
              _statBadge('Sold', sold, const Color(0xFFC62828)),
            ]),
          ),
          const Divider(height: 1, color: _bdr),
          Expanded(child: _buildInventoryTable(color)),
        ]),
      ).expand(),
    ]);
  }

  Widget _buildInventoryTable(Color color) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(children: [
          _sectionHeader(title: 'G   Label / Stock Movement Report',
              icon: Icons.swap_horiz_rounded, color: color, count: _filtered.length),
          Container(color: _bg1, child: Row(children: [
            _th('Master Tag', w: 120),
            _th('Item Name', flex: true),
            _th('Category', w: 130),
            _th('Purity', w: 90),
            _th('Pcs', w: 50, r: true),
            _th('Gross Wt', w: 90, r: true),
            _th('Net Wt', w: 90, r: true),
            _th('Counter', w: 150),
            _th('Status', w: 100),
          ])),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState('No inventory items found.')
                : SingleChildScrollView(
                    child: Column(
                      children: _filtered.asMap().entries.map((e) {
                        final r = e.value;
                        final statusColor = r['status'] == 'Available'
                            ? const Color(0xFF2E7D32)
                            : r['status'] == 'Yet to Add'
                                ? const Color(0xFFF57F17)
                                : const Color(0xFFC62828);
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td((r['tagId'] as String).replaceAll(RegExp(r'\[\d+\]$'), ''), w: 120, bold: true),
                            _td(r['name'] as String, flex: true),
                            _td(r['category'] as String, w: 130),
                            _td(r['purity'] as String, w: 90),
                            _td('${r['pcs']}', w: 50, r: true),
                            _td((r['grossWt'] as double).toStringAsFixed(3), w: 90, r: true),
                            _td((r['netWt'] as double).toStringAsFixed(3), w: 90, r: true),
                            _td(r['counter'] as String, w: 150),
                            SizedBox(
                              width: 100,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: statusColor.withAlpha(28),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withAlpha(80))),
                                  child: Text(r['status'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                ),
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String current, ValueChanged<String> onTap, Color color) {
    final sel = current == label;
    return InkWell(
      onTap: () => onTap(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _bdr),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: sel ? color : _brL)),
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(12)),
    child: Text('$label: $count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );
}

extension on Widget {
  Widget expand() => Expanded(child: this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  H ─ CASH RECEIPT EXCEPTION REPORT
//  Bills where cash amount > Rs.2,00,000 (PAN mandatory per Income Tax rules)
// ─────────────────────────────────────────────────────────────────────────────
class CashReceiptExceptionView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CashReceiptExceptionView({super.key, this.onReportSelected});
  @override State<CashReceiptExceptionView> createState() => _CashReceiptExceptionState();
}

class _CashReceiptExceptionState extends State<CashReceiptExceptionView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _searchCtrl = TextEditingController();
  String _q = '';
  static const _threshold = 200000.0;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _rows;
    return _rows.where((r) =>
        r['voucherNo'].toString().toLowerCase().contains(_q) ||
        r['acName'].toString().toLowerCase().contains(_q) ||
        (r['panNo']?.toString() ?? '').toLowerCase().contains(_q)).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills').orderBy('voucherDate', descending: true).get();
      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null || dt.isBefore(_from) || dt.isAfter(_to)) continue;
        final cash = _dbl(d['cashAmt']);
        if (cash < _threshold) continue; // only high-value cash
        list.add({...d, '_id': doc.id, '_dt': dt});
      }

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('CashException error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party Name', 'Bill Amt', 'Cash Amt', 'PAN No', 'PAN Status'];
    final dataRows = _filtered.map((r) {
      final pan = r['panNo']?.toString() ?? r['panNumber']?.toString() ?? r['pan']?.toString() ?? '';
      final hasPan = pan.isNotEmpty;
      return [
        r['voucherNo']?.toString() ?? '',
        DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime),
        r['billType']?.toString() ?? '',
        r['acName']?.toString() ?? '',
        _fmt(_dbl(r['voucherAmt'])),
        _fmt(_dbl(r['cashAmt'])),
        pan,
        hasPan ? 'Verified' : 'Missing',
      ];
    }).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Cash Receipt Exception Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Cash Receipt Exception Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Cash Receipt Exception Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Cash Receipt Exception Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reportShell(
      context: context,
      pageTitle: 'H   Cash Receipt Exception Report  (Cash > Rs.2,00,000)',
      pageIcon: Icons.warning_amber_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _filtered.length,
      searchCtrl: _searchCtrl,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : _buildTable(),
    );
  }

  Widget _buildTable() {
    const color = Color(0xFFBF360C);
    double tCash = 0, tAmt = 0;
    for (final r in _filtered) { tCash += _dbl(r['cashAmt']); tAmt += _dbl(r['voucherAmt']); }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Warning banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border.all(color: const Color(0xFFC62828).withAlpha(80)),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFC62828)),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'As per Income Tax rules, PAN details are mandatory for cash transactions above Rs. 2,00,000. '
              'Transactions listed below require PAN verification.',
              style: TextStyle(fontSize: 11, color: Color(0xFFC62828)),
            )),
          ]),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white, border: Border.all(color: _bdr),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sectionHeader(title: 'H   Cash Receipt Exception Report',
                  icon: Icons.warning_amber_rounded, color: color, count: _filtered.length),
              Container(color: _bg1, child: Row(children: [
                _th('Voucher No', w: 120),
                _th('Date', w: 90),
                _th('Type', w: 80),
                _th('Party Name', flex: true),
                _th('Bill Amt', w: 120, r: true),
                _th('Cash Amt', w: 120, r: true),
                _th('PAN No', w: 140),
                _th('PAN Status', w: 100),
              ])),
              Expanded(
                child: _filtered.isEmpty
                    ? _emptyState('No cash receipts exceeding Rs.2,00,000 in this period.')
                    : SingleChildScrollView(
                        child: Column(
                          children: _filtered.asMap().entries.map((e) {
                            final r = e.value;
                            final pan = r['panNo']?.toString() ?? r['panNumber']?.toString() ?? r['pan']?.toString() ?? '';
                            final hasPan = pan.isNotEmpty;
                            return Container(
                              color: e.key.isEven ? Colors.white : _bg0,
                              child: Row(children: [
                                _td(r['voucherNo']?.toString() ?? '—', w: 120),
                                _td(DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime), w: 90),
                                _td(r['billType']?.toString() ?? '—', w: 80),
                                _td(r['acName']?.toString() ?? '—', flex: true),
                                _td(_fmt(_dbl(r['voucherAmt'])), w: 120, r: true, bold: true),
                                _td(_fmt(_dbl(r['cashAmt'])), w: 120, r: true, bold: true,
                                    c: const Color(0xFFC62828)),
                                _td(hasPan ? pan : '— Not Entered —', w: 140,
                                    c: hasPan ? null : const Color(0xFFC62828)),
                                SizedBox(
                                  width: 100,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: hasPan ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(20)),
                                      child: Text(hasPan ? 'PAN Verified' : 'PAN Missing',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 9, fontWeight: FontWeight.bold,
                                              color: hasPan ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
                                    ),
                                  ),
                                ),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              Container(
                color: color.withAlpha(14),
                child: Row(children: [
                  _tt('TOTAL', w: 120),
                  _tt('', w: 90), _tt('', w: 80),
                  Expanded(child: _tt('')),
                  _tt(_fmt(tAmt), w: 120, r: true),
                  _tt(_fmt(tCash), w: 120, r: true, c: const Color(0xFFC62828)),
                  _tt('', w: 140), _tt('', w: 100),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  I ─ PAN CARD EXCEPTION REPORT
//  Transactions > Rs.50,000 without PAN
// ─────────────────────────────────────────────────────────────────────────────
class PanCardExceptionView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const PanCardExceptionView({super.key, this.onReportSelected});
  @override State<PanCardExceptionView> createState() => _PanCardExceptionState();
}

class _PanCardExceptionState extends State<PanCardExceptionView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  bool _showOnlyMissing = true;
  final _searchCtrl = TextEditingController();
  String _q = '';
  static const _threshold = 50000.0;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills').orderBy('voucherDate', descending: true).get();
      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _ts(d['voucherDate']);
        if (dt == null || dt.isBefore(_from) || dt.isAfter(_to)) continue;
        final amt = _dbl(d['voucherAmt']);
        if (amt < _threshold) continue; // only high-value

        final pan = d['panNo']?.toString() ??
            d['panNumber']?.toString() ??
            d['pan']?.toString() ??
            (d['customerDetails'] as Map?)?['pan']?.toString() ??
            (d['supplierDetails'] as Map?)?['pan']?.toString() ??
            '';

        list.add({...d, '_id': doc.id, '_dt': dt, '_pan': pan, '_hasPan': pan.isNotEmpty});
      }

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('PanException error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var rows = _showOnlyMissing ? _rows.where((r) => !(r['_hasPan'] as bool)).toList() : _rows;
    if (_q.isNotEmpty) {
      rows = rows.where((r) =>
          r['voucherNo'].toString().toLowerCase().contains(_q) ||
          r['acName'].toString().toLowerCase().contains(_q) ||
          (r['_pan'] as String).toLowerCase().contains(_q)).toList();
    }
    return rows;
  }

  void _export(String format) async {
    final headers = ['Voucher No', 'Date', 'Type', 'Party Name', 'Bill Amt', 'Cash Amt', 'PAN No', 'PAN Status', 'Salesman'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime),
      r['billType']?.toString() ?? '',
      r['acName']?.toString() ?? '',
      _fmt(_dbl(r['voucherAmt'])),
      _fmt(_dbl(r['cashAmt'])),
      r['_pan']?.toString() ?? '',
      (r['_hasPan'] as bool) ? 'Verified' : 'Missing',
      r['salesman']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'PAN Card Exception Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'PAN Card Exception Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'PAN Card Exception Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'PAN Card Exception Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _rows.where((r) => !(r['_hasPan'] as bool)).length;
    return _reportShell(
      context: context,
      pageTitle: 'I   PAN Card Exception Report  (Bills > Rs.2,00,000)',
      pageIcon: Icons.credit_card_off_rounded,
      from: _from, to: _to,
      onPickDate: () async {
        final r = await _pickRange(context, DateTimeRange(start: _from, end: _to));
        if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
      },
      onRefresh: _load,
      totalRecords: _filtered.length,
      searchCtrl: _searchCtrl,
      onSearch: (v) => setState(() => _q = v.toLowerCase()),
      onReportSelected: widget.onReportSelected,
      onExportCsv: () => _export('csv'),
      onExportExcel: () => _export('excel'),
      onExportPdf: () => _export('pdf'),
      body: _loading ? _loader : Column(children: [
        // Toggle bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.filter_list_rounded, size: 15, color: _brL),
            const SizedBox(width: 6),
            _toggleBtn('Missing PAN Only', _showOnlyMissing, () => setState(() => _showOnlyMissing = true),
                const Color(0xFFC62828)),
            const SizedBox(width: 8),
            _toggleBtn('Show All (> 50,000)', !_showOnlyMissing, () => setState(() => _showOnlyMissing = false),
                const Color(0xFF1B5E20)),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
              child: Text('PAN Missing: $missing of ${_rows.length} bills',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
            ),
          ]),
        ),
        const Divider(height: 1, color: _bdr),
        Expanded(child: _buildTable()),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap, Color color) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(22) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color : _bdr),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: active ? color : _brL)),
        ),
      );

  Widget _buildTable() {
    const color = Color(0xFF880E4F);
    double tAmt = 0;
    for (final r in _filtered) { tAmt += _dbl(r['voucherAmt']); }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: _bdr),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHeader(title: 'I   PAN Card Exception Report',
              icon: Icons.credit_card_off_rounded, color: color, count: _filtered.length),
          Container(color: _bg1, child: Row(children: [
            _th('Voucher No', w: 120),
            _th('Date', w: 90),
            _th('Type', w: 80),
            _th('Party Name', flex: true),
            _th('Bill Amt', w: 120, r: true),
            _th('Cash Amt', w: 110, r: true),
            _th('PAN No', w: 150),
            _th('PAN Status', w: 110),
            _th('Salesman', w: 110),
          ])),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState('No PAN card exceptions matching filter.')
                : SingleChildScrollView(
                    child: Column(
                      children: _filtered.asMap().entries.map((e) {
                        final r = e.value;
                        final pan = r['_pan'] as String;
                        final hasPan = r['_hasPan'] as bool;
                        return Container(
                          color: e.key.isEven ? Colors.white : _bg0,
                          child: Row(children: [
                            _td(r['voucherNo']?.toString() ?? '—', w: 120),
                            _td(DateFormat('dd/MM/yyyy').format(r['_dt'] as DateTime), w: 90),
                            _td(r['billType']?.toString() ?? '—', w: 80),
                            _td(r['acName']?.toString() ?? '—', flex: true),
                            _td(_fmt(_dbl(r['voucherAmt'])), w: 120, r: true, bold: true),
                            _td(_dbl(r['cashAmt']) > 0 ? _fmt(_dbl(r['cashAmt'])) : '—', w: 110, r: true),
                            _td(hasPan ? pan : '— Not Available —', w: 150,
                                c: hasPan ? Colors.black87 : const Color(0xFFC62828)),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: hasPan ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(hasPan ? '✓ PAN Available' : '✗ PAN Missing',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 9, fontWeight: FontWeight.bold,
                                          color: hasPan ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
                                ),
                              ),
                            ),
                            _td(r['salesman']?.toString() ?? '—', w: 110),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Container(
            color: color.withAlpha(14),
            child: Row(children: [
              _tt('TOTAL', w: 120), _tt('', w: 90), _tt('', w: 80),
              Expanded(child: _tt('')),
              _tt(_fmt(tAmt), w: 120, r: true),
              _tt('', w: 110), _tt('', w: 150), _tt('', w: 110), _tt('', w: 110),
            ]),
          ),
        ]),
      ),
    );
  }
}
