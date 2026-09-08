// counter_reports.dart
// D Counter Reports — Counter Sales Summary & Counter Stock Movement

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

Future<DateTimeRange?> _cPickRange(BuildContext ctx, DateTimeRange cur) =>
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

Widget _cLoader = const Center(child: CircularProgressIndicator(color: _br));

Widget _cEmpty(String msg) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );

Widget _cTh(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _cTd(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c}) {
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

Widget _cTt(String t, {double? w, bool r = false, bool flex = false, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(t, textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c ?? _br)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _cShell({
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
          child: Text('$totalRecords counters',
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
                hintText: 'Search counter...', hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
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
    Expanded(child: body),
  ]);
}

// =============================================================================
//  A: COUNTER SALES SUMMARY
// =============================================================================
class CounterSalesSummaryView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CounterSalesSummaryView({super.key, this.onReportSelected});
  @override State<CounterSalesSummaryView> createState() => _CounterSalesSummaryState();
}

class _CounterSalesSummaryState extends State<CounterSalesSummaryView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _rows
      : _rows.where((r) => r['counterName'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, Map<String, dynamic>> byC = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final bt = d['billType']?.toString() ?? '';
        if (bt != 'Sale') continue;
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;

        final items = d['items'] as List? ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final cName = item['counterName']?.toString() ??
                        item['counter']?.toString() ??
                        item['counterNo']?.toString() ?? 'Main Display Safe';
          
          final pcs = (item['pcs'] as num?)?.toInt() ?? (item['pieces'] as num?)?.toInt() ?? 1;
          final gw  = _fdbl(item['grossWeight'] ?? item['grossWt'] ?? 0.0);
          final nw  = _fdbl(item['netWeight'] ?? item['netWt'] ?? 0.0);
          final val = _fdbl(item['amount'] ?? item['rate'] ?? 0.0);

          final e = byC.putIfAbsent(cName.toLowerCase(), () => {
            'counterName': cName, 'pcs': 0, 'grossWt': 0.0, 'netWt': 0.0, 'value': 0.0,
          });

          e['pcs'] = (e['pcs'] as int) + pcs;
          e['grossWt'] = (e['grossWt'] as double) + gw;
          e['netWt'] = (e['netWt'] as double) + nw;
          e['value'] = (e['value'] as double) + val;
        }
      }

      final list = byC.values.toList()
        ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('CounterSalesSummary error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Counter Name', 'Qty (Pcs)', 'Gross Wt (g)', 'Net Wt (g)', 'Sales Value (Rs.)', 'Avg Rate/g'];
    final dataRows = _filtered.map((r) {
      final avg = (r['netWt'] as double) > 0 ? (r['value'] as double) / (r['netWt'] as double) : 0.0;
      return [
        r['counterName']?.toString() ?? '',
        r['pcs']?.toString() ?? '0',
        (r['grossWt'] as double).toStringAsFixed(3),
        (r['netWt'] as double).toStringAsFixed(3),
        _ffmt(r['value'] as double),
        _ffmt(avg),
      ];
    }).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Counter Sales Summary', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Counter Sales Summary', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Counter Sales Summary', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Counter Sales Summary', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) => _cShell(
    context: context,
    pageTitle: 'Counter Sales Summary', pageIcon: Icons.point_of_sale_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _cPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    onExportCsv: () => _export('csv'),
    onExportExcel: () => _export('excel'),
    onExportPdf: () => _export('pdf'),
    body: _loading ? _cLoader : _buildTable(),
  );

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _cEmpty('No counter sales records found for this period');
    
    int tPcs = 0;
    double tG = 0, tN = 0, tV = 0;
    for (final r in rows) {
      tPcs += r['pcs'] as int;
      tG += r['grossWt'] as double;
      tN += r['netWt'] as double;
      tV += r['value'] as double;
    }

    const color = Color(0xFF2E7D32);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _cTh('#', w: 40), _cTh('Counter Name', flex: true),
          _cTh('Qty (Pcs)', w: 100, r: true), _cTh('Gross Wt (g)', w: 130, r: true),
          _cTh('Net Wt (g)', w: 130, r: true), _cTh('Sales Value (Rs.)', w: 150, r: true),
          _cTh('Avg Rate/g', w: 130, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          final avg = (r['netWt'] as double) > 0 ? (r['value'] as double) / (r['netWt'] as double) : 0.0;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _cTd('${i+1}', w: 40),
              _cTd(r['counterName'].toString(), flex: true, bold: true),
              _cTd('${r['pcs']}', w: 100, r: true),
              _cTd((r['grossWt'] as double).toStringAsFixed(3), w: 130, r: true),
              _cTd((r['netWt'] as double).toStringAsFixed(3), w: 130, r: true),
              _cTd(_ffmt(r['value'] as double), w: 150, r: true, bold: true),
              _cTd(_ffmt(avg), w: 130, r: true, c: Colors.brown.shade800),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _cTt('TOTAL', w: 40), _cTt('', flex: true),
          _cTt('$tPcs', w: 100, r: true), _cTt(tG.toStringAsFixed(3), w: 130, r: true),
          _cTt(tN.toStringAsFixed(3), w: 130, r: true), _cTt(_ffmt(tV), w: 150, r: true),
          _cTt(_ffmt(tN > 0 ? tV / tN : 0.0), w: 130, r: true),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  B: COUNTER STOCK MOVEMENT
// =============================================================================
class CounterStockMovementView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CounterStockMovementView({super.key, this.onReportSelected});
  @override State<CounterStockMovementView> createState() => _CounterStockMovementState();
}

class _CounterStockMovementState extends State<CounterStockMovementView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 30));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _rows = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sc.dispose(); super.dispose(); }

  List<Map<String, dynamic>> get _filtered => _q.isEmpty ? _rows
      : _rows.where((r) => r['counterName'].toString().toLowerCase().contains(_q)).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final inventorySnap = await FirebaseFirestore.instance.collection('jewelry_inventory').get();

      final Map<String, Map<String, dynamic>> movement = {};

      // 1. Group current closing stock from jewelry_inventory (active items)
      for (final doc in inventorySnap.docs) {
        final d = doc.data();
        final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
        final pcs = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? 1;
        final isSold = pcs <= 0 || rawStatus.toLowerCase() == 'sold' || rawStatus.toLowerCase() == 'out of stock';
        if (isSold) continue;

        final cName = d['counterNo']?.toString() ?? d['counter']?.toString() ?? 'Main Display Safe';
        final nw = _fdbl(d['netWeight'] ?? d['netWt'] ?? 0.0);

        final e = movement.putIfAbsent(cName.toLowerCase(), () => {
          'counterName': cName, 'closingPcs': 0, 'closingWt': 0.0,
          'inPcs': 0, 'inWt': 0.0, 'outPcs': 0, 'outWt': 0.0,
        });

        e['closingPcs'] = (e['closingPcs'] as int) + pcs;
        e['closingWt'] = (e['closingWt'] as double) + nw;
      }

      // 2. Sum Stock In and Stock Out from bills within date range
      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final dt = _fts(d['voucherDate']); if (dt == null) continue;
        if (dt.isBefore(_from) || dt.isAfter(_to)) continue;

        final bt = d['billType']?.toString() ?? '';
        final isSale = bt == 'Sale';
        final isPurch = bt == 'Purchase';
        if (!isSale && !isPurch) continue;

        final items = d['items'] as List? ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final cName = item['counterName']?.toString() ??
                        item['counter']?.toString() ??
                        item['counterNo']?.toString() ?? 'Main Display Safe';
          
          final pcs = (item['pcs'] as num?)?.toInt() ?? (item['pieces'] as num?)?.toInt() ?? 1;
          final nw  = _fdbl(item['netWeight'] ?? item['netWt'] ?? 0.0);

          final e = movement.putIfAbsent(cName.toLowerCase(), () => {
            'counterName': cName, 'closingPcs': 0, 'closingWt': 0.0,
            'inPcs': 0, 'inWt': 0.0, 'outPcs': 0, 'outWt': 0.0,
          });

          if (isPurch) {
            e['inPcs'] = (e['inPcs'] as int) + pcs;
            e['inWt'] = (e['inWt'] as double) + nw;
          } else if (isSale) {
            e['outPcs'] = (e['outPcs'] as int) + pcs;
            e['outWt'] = (e['outWt'] as double) + nw;
          }
        }
      }

      // 3. Compute opening stock (Opening = Closing - In + Out)
      final list = movement.values.toList();
      for (final e in list) {
        e['openingPcs'] = (e['closingPcs'] as int) - (e['inPcs'] as int) + (e['outPcs'] as int);
        e['openingWt'] = (e['closingWt'] as double) - (e['inWt'] as double) + (e['outWt'] as double);
      }

      list.sort((a, b) => (b['closingWt'] as double).compareTo(a['closingWt'] as double));

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('CounterStockMovement error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = [
      'Counter Name', 'Opening Pcs', 'Opening Wt',
      'In Pcs', 'In Wt', 'Out Pcs', 'Out Wt',
      'Closing Pcs', 'Closing Wt'
    ];
    final dataRows = _filtered.map((r) => [
      r['counterName']?.toString() ?? '',
      r['openingPcs']?.toString() ?? '0',
      (r['openingWt'] as double).toStringAsFixed(3),
      r['inPcs']?.toString() ?? '0',
      (r['inWt'] as double).toStringAsFixed(3),
      r['outPcs']?.toString() ?? '0',
      (r['outWt'] as double).toStringAsFixed(3),
      r['closingPcs']?.toString() ?? '0',
      (r['closingWt'] as double).toStringAsFixed(3),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Counter Stock Movement', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Counter Stock Movement', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Counter Stock Movement', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Counter Stock Movement', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) => _cShell(
    context: context,
    pageTitle: 'Counter Stock Movement', pageIcon: Icons.swap_vert_rounded,
    from: _from, to: _to,
    onPickDate: () async {
      final r = await _cPickRange(context, DateTimeRange(start: _from, end: _to));
      if (r != null) { setState(() { _from = r.start; _to = r.end; }); _load(); }
    },
    onRefresh: _load, totalRecords: _filtered.length, searchCtrl: _sc, onSearch: (v) => setState(() => _q = v.toLowerCase()),
    onReportSelected: widget.onReportSelected,
    onExportCsv: () => _export('csv'),
    onExportExcel: () => _export('excel'),
    onExportPdf: () => _export('pdf'),
    body: _loading ? _cLoader : _buildTable(),
  );

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) return _cEmpty('No counter stock movement records found');

    int tOpPcs = 0, tInPcs = 0, tOutPcs = 0, tClPcs = 0;
    double tOpWt = 0.0, tInWt = 0.0, tOutWt = 0.0, tClWt = 0.0;

    for (final r in rows) {
      tOpPcs  += r['openingPcs'] as int;
      tOpWt   += r['openingWt'] as double;
      tInPcs  += r['inPcs'] as int;
      tInWt   += r['inWt'] as double;
      tOutPcs += r['outPcs'] as int;
      tOutWt  += r['outWt'] as double;
      tClPcs  += r['closingPcs'] as int;
      tClWt   += r['closingWt'] as double;
    }

    const color = Color(0xFF673AB7);
    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: color.withAlpha(18), child: Row(children: [
          _cTh('#', w: 40), _cTh('Counter Name', flex: true),
          _cTh('Open (Pcs/Wt)', w: 140, r: true),
          _cTh('Inward (Pcs/Wt)', w: 140, r: true),
          _cTh('Outward (Pcs/Wt)', w: 140, r: true),
          _cTh('Closing (Pcs/Wt)', w: 150, r: true),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: rows.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _cTd('${i+1}', w: 40),
              _cTd(r['counterName'].toString(), flex: true, bold: true),
              _cTd('${r['openingPcs']} pcs / ${(r['openingWt'] as double).toStringAsFixed(2)}g', w: 140, r: true),
              _cTd('${r['inPcs']} pcs / ${(r['inWt'] as double).toStringAsFixed(2)}g', w: 140, r: true, c: const Color(0xFF2E7D32)),
              _cTd('${r['outPcs']} pcs / ${(r['outWt'] as double).toStringAsFixed(2)}g', w: 140, r: true, c: const Color(0xFFC62828)),
              _cTd('${r['closingPcs']} pcs / ${(r['closingWt'] as double).toStringAsFixed(2)}g', w: 150, r: true, bold: true),
            ]),
          );
        }).toList()))),
        Container(color: color.withAlpha(14), child: Row(children: [
          _cTt('TOTAL', w: 40), _cTt('', flex: true),
          _cTt('$tOpPcs pcs / ${tOpWt.toStringAsFixed(2)}g', w: 140, r: true),
          _cTt('$tInPcs pcs / ${tInWt.toStringAsFixed(2)}g', w: 140, r: true, c: const Color(0xFF2E7D32)),
          _cTt('$tOutPcs pcs / ${tOutWt.toStringAsFixed(2)}g', w: 140, r: true, c: const Color(0xFFC62828)),
          _cTt('$tClPcs pcs / ${tClWt.toStringAsFixed(2)}g', w: 150, r: true),
        ])),
      ]),
    ));
  }
}
