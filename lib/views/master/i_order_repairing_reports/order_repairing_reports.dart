// order_repairing_reports.dart
// I Order / Repairing Reports — A (Order Status Report), B (Repairing Job Register)

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

Widget _gEmpty(String msg, {VoidCallback? onGenDemo}) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        if (onGenDemo != null) ...[
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: onGenDemo,
            icon: const Icon(Icons.add_to_photos_rounded, size: 14),
            label: const Text('Generate Demo Data', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _br,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          )
        ]
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

Widget _buildStatusBadge(String status) {
  Color bg = Colors.grey.shade100;
  Color fg = Colors.grey.shade700;
  
  final norm = status.trim().toLowerCase();
  if (norm == 'pending' || norm == 'received') {
    bg = const Color(0xFFFEEBEE);
    fg = const Color(0xFFC62828);
  } else if (norm == 'in progress' || norm == 'in repair') {
    bg = const Color(0xFFFFF3E0);
    fg = const Color(0xFFE65100);
  } else if (norm == 'completed' || norm == 'ready for delivery' || norm == 'ready') {
    bg = const Color(0xFFE8F5E9);
    fg = const Color(0xFF2E7D32);
  } else if (norm == 'delivered') {
    bg = const Color(0xFFE3F2FD);
    fg = const Color(0xFF1565C0);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
    ),
  );
}

// =============================================================================
//  A: ORDER STATUS REPORT
// =============================================================================
class OrderStatusReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const OrderStatusReportView({super.key, this.onReportSelected});
  @override State<OrderStatusReportView> createState() => _OrderStatusReportState();
}

class _OrderStatusReportState extends State<OrderStatusReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 90));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _statusFilter = 'All';
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
          r['customerName'].toString().toLowerCase().contains(_q) ||
          r['voucherNo'].toString().toLowerCase().contains(_q) ||
          r['itemName'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('order_entries').get();
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d) ?? DateTime.now();
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        list.add({
          'docId': doc.id,
          'voucherNo': d['voucherNo'] ?? 'ORD-${doc.id.substring(0, 4).toUpperCase()}',
          'date': dt,
          'customerName': d['customerName'] ?? d['acName'] ?? 'Walk-in Customer',
          'itemName': d['itemName'] ?? 'Gold Ornament',
          'pcs': (d['pcs'] as num?)?.toInt() ?? 1,
          'grossWeight': _fdbl(d['grossWeight']),
          'netWeight': _fdbl(d['netWeight'] ?? d['netWt']),
          'amount': _fdbl(d['amount'] ?? d['totalAmt']),
          'status': d['status'] ?? 'Pending',
          'deliveryDate': d['deliveryDate']?.toString() ?? '—',
        });
      }

      list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateDemoData() async {
    setState(() => _loading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('order_entries');

      final List<Map<String, dynamic>> demos = [
        {
          'voucherNo': 'ORD-8930',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 5))),
          'customerName': 'Adithya Vignesh',
          'itemName': 'Gold Chain 22K',
          'pcs': 1,
          'grossWeight': 24.500,
          'netWeight': 24.100,
          'amount': 165000.0,
          'status': 'Pending',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 10))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'ORD-8931',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 12))),
          'customerName': 'Deepak Kumar',
          'itemName': 'Wedding Ring Set Platinum',
          'pcs': 2,
          'grossWeight': 12.800,
          'netWeight': 12.200,
          'amount': 98000.0,
          'status': 'In Progress',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 4))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'ORD-8932',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 20))),
          'customerName': 'Priya Dharshini',
          'itemName': 'Antique Haram Gold',
          'pcs': 1,
          'grossWeight': 64.200,
          'netWeight': 63.500,
          'amount': 435000.0,
          'status': 'Completed',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 2))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'ORD-8933',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 30))),
          'customerName': 'Shanthi Dev',
          'itemName': 'Diamond Studs 18K',
          'pcs': 2,
          'grossWeight': 6.400,
          'netWeight': 5.800,
          'amount': 112000.0,
          'status': 'Delivered',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 10))),
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      for (final data in demos) {
        batch.set(col.doc(), data);
      }
      await batch.commit();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo orders generated successfully!'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      debugPrint('Failed to generate orders: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Order No', 'Date', 'Customer Name', 'Item Name', 'Pcs', 'Gross Wt', 'Net Wt', 'Amount', 'Delivery Date', 'Status'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['date'] as DateTime),
      r['customerName']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      r['pcs']?.toString() ?? '1',
      _fdbl(r['grossWeight']).toStringAsFixed(3),
      _fdbl(r['netWeight']).toStringAsFixed(3),
      _ffmt(_fdbl(r['amount'])),
      r['deliveryDate']?.toString() ?? '',
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Order Status Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Order Status Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Order Status Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Order Status Report', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'A Order Status Report', pageIcon: Icons.shopping_bag_rounded,
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
          const Icon(Icons.filter_alt_rounded, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Filter Status:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Pending', 'In Progress', 'Completed', 'Delivered'].map((st) {
            final sel = _statusFilter == st;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = st),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _br : _br.withAlpha(12), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(st, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : _br)),
              ),
            );
          }),
        ]),
      ),
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No order status records found', onGenDemo: _generateDemoData);
    double tWt = 0, tAmt = 0; int tPcs = 0;
    for (final r in list) {
      tWt += r['netWeight'] as double;
      tPcs += r['pcs'] as int;
      tAmt += r['amount'] as double;
    }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: _br.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40),
          _gTh('Order Date', w: 90),
          _gTh('Order No', w: 100),
          _gTh('Customer Name', flex: true),
          _gTh('Ordered Item', w: 160),
          _gTh('Pcs', w: 50, r: true),
          _gTh('Net Wt (g)', w: 90, r: true),
          _gTh('Est. Amt (₹)', w: 110, r: true),
          _gTh('Status', w: 100),
          _gTh('Est. Delivery', w: 100),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime), w: 90),
              _gTd(r['voucherNo'].toString(), w: 100, bold: true),
              _gTd(r['customerName'].toString(), flex: true),
              _gTd(r['itemName'].toString(), w: 160),
              _gTd(r['pcs'].toString(), w: 50, r: true),
              _gTd(_ffmt(r['netWeight'] as double), w: 90, r: true),
              _gTd(_ffmt(r['amount'] as double), w: 110, r: true, bold: true),
              Container(width: 100, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.centerLeft, child: _buildStatusBadge(r['status'].toString())),
              _gTd(r['deliveryDate'].toString(), w: 100),
            ]),
          );
        }).toList()))),
        Container(color: _br.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 90), _gTt('', w: 100), _gTt('', flex: true), _gTt('', w: 160),
          _gTt(tPcs.toString(), w: 50, r: true),
          _gTt(_ffmt(tWt), w: 90, r: true),
          _gTt(_ffmt(tAmt), w: 110, r: true),
          _gTt('', w: 100), _gTt('', w: 100),
        ])),
      ]),
    ));
  }
}

// =============================================================================
//  B: REPAIRING JOB REGISTER
// =============================================================================
class RepairingJobRegisterView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const RepairingJobRegisterView({super.key, this.onReportSelected});
  @override State<RepairingJobRegisterView> createState() => _RepairingJobRegisterState();
}

class _RepairingJobRegisterState extends State<RepairingJobRegisterView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 90));
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
  bool _loading  = true;
  List<Map<String, dynamic>> _records = [];
  String _statusFilter = 'All';
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
          r['customerName'].toString().toLowerCase().contains(_q) ||
          r['voucherNo'].toString().toLowerCase().contains(_q) ||
          r['itemName'].toString().toLowerCase().contains(_q) ||
          r['repairType'].toString().toLowerCase().contains(_q)).toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('repairing_entries').get();
      final List<Map<String, dynamic>> list = [];
      final start = DateTime(_from.year, _from.month, _from.day);
      final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      for (final doc in snap.docs) {
        final d = doc.data();
        final dt = _parseDate(d) ?? DateTime.now();
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        list.add({
          'docId': doc.id,
          'voucherNo': d['voucherNo'] ?? 'RP-${doc.id.substring(0, 4).toUpperCase()}',
          'date': dt,
          'customerName': d['customerName'] ?? d['acName'] ?? 'Walk-in Customer',
          'itemName': d['itemName'] ?? 'Gold Bangle',
          'repairType': d['repairType'] ?? 'Polishing & Soldering',
          'pcs': (d['pcs'] as num?)?.toInt() ?? 1,
          'grossWeight': _fdbl(d['grossWeight']),
          'netWeight': _fdbl(d['netWeight'] ?? d['netWt']),
          'amount': _fdbl(d['amount'] ?? d['totalAmt']),
          'status': d['status'] ?? 'Received',
          'deliveryDate': d['deliveryDate']?.toString() ?? '—',
        });
      }

      list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (e) {
      debugPrint('Error loading repairing jobs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateDemoData() async {
    setState(() => _loading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('repairing_entries');

      final List<Map<String, dynamic>> demos = [
        {
          'voucherNo': 'RP-4021',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 2))),
          'customerName': 'Meenakshi Sundaram',
          'itemName': 'Gold Necklace 22K',
          'repairType': 'Hook Replacement & Polishing',
          'pcs': 1,
          'grossWeight': 42.150,
          'netWeight': 41.800,
          'amount': 2500.0,
          'status': 'Received',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 3))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'RP-4022',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 7))),
          'customerName': 'Vijay Raghavan',
          'itemName': 'Gold Kada Bracelet',
          'repairType': 'Sizing & Screw Re-threading',
          'pcs': 1,
          'grossWeight': 28.900,
          'netWeight': 28.750,
          'amount': 1800.0,
          'status': 'In Repair',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 1))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'RP-4023',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 10))),
          'customerName': 'Anjali Menon',
          'itemName': 'Diamond Stud Earrings',
          'repairType': 'Prong Tightening & Clean',
          'pcs': 2,
          'grossWeight': 4.200,
          'netWeight': 3.900,
          'amount': 3500.0,
          'status': 'Ready',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'voucherNo': 'RP-4024',
          'voucherDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 25))),
          'customerName': 'Rajesh Sharma',
          'itemName': 'Silver Pooja Set',
          'repairType': 'Silver Anti-Tarnish Polishing',
          'pcs': 5,
          'grossWeight': 340.000,
          'netWeight': 338.000,
          'amount': 4500.0,
          'status': 'Delivered',
          'deliveryDate': DateFormat('dd/MM/yyyy').format(DateTime.now().subtract(const Duration(days: 15))),
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      for (final data in demos) {
        batch.set(col.doc(), data);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo repair jobs generated successfully!'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      debugPrint('Failed to generate repairing jobs: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() => _loading = false);
    }
  }

  void _export(String format) async {
    final headers = ['Job No', 'Date', 'Customer Name', 'Item Name', 'Repair Type', 'Pcs', 'Gross Wt', 'Net Wt', 'Charges', 'Delivery Date', 'Status'];
    final dataRows = _filtered.map((r) => [
      r['voucherNo']?.toString() ?? '',
      DateFormat('dd/MM/yyyy').format(r['date'] as DateTime),
      r['customerName']?.toString() ?? '',
      r['itemName']?.toString() ?? '',
      r['repairType']?.toString() ?? '',
      r['pcs']?.toString() ?? '1',
      _fdbl(r['grossWeight']).toStringAsFixed(3),
      _fdbl(r['netWeight']).toStringAsFixed(3),
      _ffmt(_fdbl(r['amount'])),
      r['deliveryDate']?.toString() ?? '',
      r['status']?.toString() ?? '',
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Repairing Job Register', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Repairing Job Register', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Repairing Job Register', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Repairing Job Register', '$format format', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return _gShell(
      context: context,
      pageTitle: 'B Repairing Job Register', pageIcon: Icons.build_circle_rounded,
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
          const Icon(Icons.filter_alt_rounded, size: 14, color: _brL),
          const SizedBox(width: 8),
          const Text('Filter Status:', style: TextStyle(fontSize: 12, color: _brL, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          ...['All', 'Received', 'In Repair', 'Ready', 'Delivered'].map((st) {
            final sel = _statusFilter == st;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = st),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _br : _br.withAlpha(12), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(st, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sel ? Colors.white : _br)),
              ),
            );
          }),
        ]),
      ),
      body: _loading ? _gLoader : _buildTable(list),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _gEmpty('No repairing job records found', onGenDemo: _generateDemoData);
    double tWt = 0, tAmt = 0; int tPcs = 0;
    for (final r in list) {
      tWt += r['netWeight'] as double;
      tPcs += r['pcs'] as int;
      tAmt += r['amount'] as double;
    }

    return Padding(padding: const EdgeInsets.all(16), child: Container(
      decoration: BoxDecoration(color: _bg0, border: Border.all(color: _bdr), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(color: _br.withAlpha(18), child: Row(children: [
          _gTh('#', w: 40),
          _gTh('Received Date', w: 95),
          _gTh('Job Card No', w: 100),
          _gTh('Customer Name', flex: true),
          _gTh('Item Description', w: 160),
          _gTh('Repair Requirement', w: 180),
          _gTh('Pcs', w: 50, r: true),
          _gTh('Net Wt (g)', w: 90, r: true),
          _gTh('Est. Cost (₹)', w: 110, r: true),
          _gTh('Status', w: 100),
          _gTh('Est. Delivery', w: 100),
        ])),
        const Divider(height: 1, color: _bdr),
        Expanded(child: SingleChildScrollView(child: Column(children: list.asMap().entries.map((e) {
          final r = e.value; final i = e.key;
          return Container(
            decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAF7F3), border: const Border(bottom: BorderSide(color: _bdr, width: 0.5))),
            child: Row(children: [
              _gTd('${i+1}', w: 40),
              _gTd(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime), w: 95),
              _gTd(r['voucherNo'].toString(), w: 100, bold: true),
              _gTd(r['customerName'].toString(), flex: true),
              _gTd(r['itemName'].toString(), w: 160),
              _gTd(r['repairType'].toString(), w: 180),
              _gTd(r['pcs'].toString(), w: 50, r: true),
              _gTd(_ffmt(r['netWeight'] as double), w: 90, r: true),
              _gTd(_ffmt(r['amount'] as double), w: 110, r: true, bold: true),
              Container(width: 100, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.centerLeft, child: _buildStatusBadge(r['status'].toString())),
              _gTd(r['deliveryDate'].toString(), w: 100),
            ]),
          );
        }).toList()))),
        Container(color: _br.withAlpha(14), child: Row(children: [
          _gTt('TOTAL', w: 40), _gTt('', w: 95), _gTt('', w: 100), _gTt('', flex: true), _gTt('', w: 160), _gTt('', w: 180),
          _gTt(tPcs.toString(), w: 50, r: true),
          _gTt(_ffmt(tWt), w: 90, r: true),
          _gTt(_ffmt(tAmt), w: 110, r: true),
          _gTt('', w: 100), _gTt('', w: 100),
        ])),
      ]),
    ));
  }
}
