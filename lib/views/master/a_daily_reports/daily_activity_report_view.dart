import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../report_shared.dart';
import '../b_account_reports/account_reports.dart';

const _brown      = Color(0xFF3E2723);
const _brownLight = Color(0xFF6D4C41);
const _border     = Color(0xFFE5DDD0);

// ─── Data model ───────────────────────────────────────────────────────────────
class _DailyRow {
  final String   voucherNo;
  final DateTime date;
  final String   acName;
  final String   billType;   // 'Sale' | 'Purchase'
  final double   voucherAmt;
  final double   cashAmt;
  final double   cardAmt;
  final double   bankAmt;
  final double   dueAmt;
  final String   paymentMode;
  final String   itemName;
  final double   grossWt;
  final double   netWt;
  final double   metalAmt;
  final double   labourAmt;
  final double   gstAmt;

  const _DailyRow({
    required this.voucherNo,
    required this.date,
    required this.acName,
    required this.billType,
    required this.voucherAmt,
    required this.cashAmt,
    required this.cardAmt,
    required this.bankAmt,
    required this.dueAmt,
    required this.paymentMode,
    required this.itemName,
    required this.grossWt,
    required this.netWt,
    required this.metalAmt,
    required this.labourAmt,
    required this.gstAmt,
  });
}

// ─── Main view ────────────────────────────────────────────────────────────────
class DailyActivityReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const DailyActivityReportView({super.key, this.onReportSelected});

  @override
  State<DailyActivityReportView> createState() => _DailyActivityReportViewState();
}

class _DailyActivityReportViewState extends State<DailyActivityReportView> {
  // Default: show ALL records (last 1 year) so something always appears
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _toDate   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);

  bool   _loading = true;
  String _errorMsg = '';
  List<_DailyRow> _rows = [];
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ── Aggregates ─────────────────────────────────────────────────────────────
  List<_DailyRow> get _filtered {
    if (_searchQuery.isEmpty) return _rows;
    final q = _searchQuery.toLowerCase();
    return _rows.where((r) =>
        r.voucherNo.toLowerCase().contains(q) ||
        r.acName.toLowerCase().contains(q) ||
        r.itemName.toLowerCase().contains(q)).toList();
  }

  List<_DailyRow> _section(String type) => _filtered.where((r) => r.billType == type).toList();

  double _sum(List<_DailyRow> rows, double Function(_DailyRow) fn) =>
      rows.fold(0.0, (s, r) => s + fn(r));

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load data ───────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _errorMsg = ''; });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .orderBy('voucherDate', descending: true)
          .get();

      final List<_DailyRow> rows = [];

      for (final doc in snap.docs) {
        final d = doc.data();

        // ── Date ─────────────────────────────────────────────────────────────
        DateTime? date;
        if (d['voucherDate'] is Timestamp) {
          date = (d['voucherDate'] as Timestamp).toDate();
        } else if (d['createdAt'] is Timestamp) {
          date = (d['createdAt'] as Timestamp).toDate();
        }
        if (date == null) continue;

        // ── Date filter ───────────────────────────────────────────────────────
        final fromMidnight = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
        final toEnd        = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999);
        if (date.isBefore(fromMidnight) || date.isAfter(toEnd)) continue;

        // ── Bill type ─────────────────────────────────────────────────────────
        final billType = d['billType']?.toString() ?? 'Sale';
        // Only show Sale and Purchase in daily report
        if (billType != 'Sale' && billType != 'Purchase') continue;

        // ── Amounts ───────────────────────────────────────────────────────────
        final voucherAmt = (d['voucherAmt'] as num?)?.toDouble() ?? 0.0;
        final cashAmt    = (d['cashAmt']    as num?)?.toDouble() ?? 0.0;
        final cardAmt    = (d['cardAmt']    as num?)?.toDouble() ?? 0.0;
        final bankAmt    = (d['bankAmt']    as num?)?.toDouble() ?? 0.0;
        final dueAmt     = (d['dueAmt']     as num?)?.toDouble() ?? 0.0;
        final metalAmt   = (d['metalAmt']   as num?)?.toDouble() ?? 0.0;
        final labourAmt  = (d['labourAmt']  as num?)?.toDouble() ?? 0.0;
        final gstAmt     = (d['gstAmt']     as num?)?.toDouble() ?? 0.0;

        // ── Payment mode ──────────────────────────────────────────────────────
        String paymentMode;
        if (dueAmt >= voucherAmt * 0.99 && voucherAmt > 0) {
          paymentMode = 'Credit';
        } else if (cardAmt > 0 && cardAmt >= bankAmt && cardAmt >= cashAmt) {
          paymentMode = 'Card';
        } else if (bankAmt > 0 && bankAmt >= cashAmt) {
          paymentMode = 'Bank/UPI';
        } else if (cashAmt > 0) {
          paymentMode = 'Cash';
        } else {
          paymentMode = 'Mixed';
        }

        // ── Item name ─────────────────────────────────────────────────────────
        String itemName = d['itemName']?.toString() ?? '';
        if (itemName.isEmpty && d['items'] is List) {
          final items = d['items'] as List;
          if (items.isNotEmpty && items.first is Map) {
            itemName = items.first['name']?.toString() ?? '';
          }
        }
        if (itemName.isEmpty) itemName = d['carat']?.toString() ?? '';

        rows.add(_DailyRow(
          voucherNo:   d['voucherNo']?.toString() ?? doc.id,
          date:        date,
          acName:      d['acName']?.toString() ?? '',
          billType:    billType,
          voucherAmt:  voucherAmt,
          cashAmt:     cashAmt,
          cardAmt:     cardAmt,
          bankAmt:     bankAmt,
          dueAmt:      dueAmt,
          paymentMode: paymentMode,
          itemName:    itemName,
          grossWt:     (d['grossWeight'] as num?)?.toDouble() ?? 0.0,
          netWt:       (d['netWeight']   as num?)?.toDouble() ?? 0.0,
          metalAmt:    metalAmt,
          labourAmt:   labourAmt,
          gstAmt:      gstAmt,
        ));
      }

      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      debugPrint('DailyActivityReport error: $e');
      if (mounted) setState(() { _errorMsg = e.toString(); _loading = false; });
    }
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _brown, onPrimary: Colors.white, onSurface: _brown),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate   = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      _load();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, color: _border),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _brown)))
        else if (_errorMsg.isNotEmpty)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Failed to load data:\n$_errorMsg',
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
                ),
              ],
            ),
          )))
        else
          Expanded(child: _buildBody()),
      ],
    );
  }

  void _export(String format) async {
    final headers = [
      'Voucher No', 'Date', 'Type', 'Party Name', 'Items',
      'Gross Wt', 'Net Wt', 'Bill Amt', 'Cash Amt', 'Card Amt', 'Bank Amt', 'Due Amt'
    ];
    final dataRows = _filtered.map((r) => [
      r.voucherNo,
      DateFormat('dd/MM/yyyy').format(r.date),
      r.billType,
      r.acName,
      r.itemName,
      r.grossWt.toStringAsFixed(3),
      r.netWt.toStringAsFixed(3),
      NumberFormat('#,##,##0.00', 'en_IN').format(r.voucherAmt),
      NumberFormat('#,##,##0.00', 'en_IN').format(r.cashAmt),
      NumberFormat('#,##,##0.00', 'en_IN').format(r.cardAmt),
      NumberFormat('#,##,##0.00', 'en_IN').format(r.bankAmt),
      NumberFormat('#,##,##0.00', 'en_IN').format(r.dueAmt),
    ]).toList();

    String? path;
    if (format == 'csv') {
      path = await exportReportAsCsv(reportTitle: 'Daily Activity Report', headers: headers, rows: dataRows);
    } else if (format == 'excel') {
      path = await exportReportAsExcel(reportTitle: 'Daily Activity Report', headers: headers, rows: dataRows);
    } else if (format == 'pdf') {
      path = await exportReportAsPdf(reportTitle: 'Daily Activity Report', headers: headers, rows: dataRows);
    }
    if (mounted && path != null) {
      showReportDownloadDialog(context, 'Daily Activity Report', '$format format', path);
    }
  }

  // ── Header bar ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.today_rounded, size: 18, color: _brown),
          const SizedBox(width: 8),
          buildTitleDropdown(
            context: context,
            currentTitle: 'Daily Activity Report',
            onSelected: (newTitle) {
              widget.onReportSelected?.call(newTitle);
            },
            textColor: _brown,
            fontSize: 15,
            bold: true,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(12)),
            child: Text('${_filtered.length} records',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))),
          ),
          const Spacer(),
          // Search
          SizedBox(
            width: 200, height: 34,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search party / voucher…',
                hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 14, color: _brownLight),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _border),
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _brown, width: 1.5),
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date range
          OutlinedButton.icon(
            onPressed: _pickRange,
            style: OutlinedButton.styleFrom(
              foregroundColor: _brownLight,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.date_range_rounded, size: 14),
            label: Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)}  –  ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Download Report',
            onSelected: (val) {
              if (val == 'csv') _export('csv');
              if (val == 'excel') _export('excel');
              if (val == 'pdf') _export('pdf');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 14, color: _brownLight),
                  SizedBox(width: 6),
                  Text(
                    'Download',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 14, color: _brownLight),
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: _brownLight),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final fmt    = NumberFormat('#,##,##0.00', 'en_IN');
    final sales  = _section('Sale');
    final purch  = _section('Purchase');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ─────────────────────────────────────────────────
          _buildSummaryRow(sales, purch, fmt),
          const SizedBox(height: 16),

          // ── A: Sales ──────────────────────────────────────────────────────
          _buildSection(
            title: 'A   Sales Register',
            icon: Icons.sell_rounded,
            color: const Color(0xFF2E7D32),
            rows: sales,
            fmt: fmt,
          ),
          const SizedBox(height: 16),

          // ── B: Purchase ───────────────────────────────────────────────────
          _buildSection(
            title: 'B   Purchase Register',
            icon: Icons.shopping_cart_rounded,
            color: const Color(0xFF6A1B9A),
            rows: purch,
            fmt: fmt,
          ),
          const SizedBox(height: 16),

          // ── C: Payment Mode Breakdown ─────────────────────────────────────
          _buildPaymentSummary(fmt),
        ],
      ),
    );
  }

  // ── Summary cards row ────────────────────────────────────────────────────────
  Widget _buildSummaryRow(List<_DailyRow> sales, List<_DailyRow> purch, NumberFormat fmt) {
    final totalSales    = _sum(sales, (r) => r.voucherAmt);
    final totalPurchase = _sum(purch, (r) => r.voucherAmt);
    final totalCash     = _sum(_filtered, (r) => r.cashAmt);
    final totalCard     = _sum(_filtered, (r) => r.cardAmt);
    final totalBank     = _sum(_filtered, (r) => r.bankAmt);
    final totalDue      = _sum(_filtered, (r) => r.dueAmt);

    return Row(
      children: [
        _card('Total Sales',    totalSales,    Icons.sell_rounded,             const Color(0xFF1B5E20), const Color(0xFFE8F5E9), fmt),
        const SizedBox(width: 10),
        _card('Total Purchase', totalPurchase, Icons.shopping_cart_rounded,    const Color(0xFF6A1B9A), const Color(0xFFF3E5F5), fmt),
        const SizedBox(width: 10),
        _card('Cash Received',  totalCash,     Icons.payments_rounded,         const Color(0xFF1565C0), const Color(0xFFE3F2FD), fmt),
        const SizedBox(width: 10),
        _card('Card + Bank/UPI', totalCard + totalBank, Icons.credit_card_rounded, const Color(0xFFF57F17), const Color(0xFFFFFDE7), fmt),
        const SizedBox(width: 10),
        _card('Pending Due',    totalDue,      Icons.hourglass_bottom_rounded,  const Color(0xFFC62828), const Color(0xFFFFEBEE), fmt),
      ],
    );
  }

  Widget _card(String title, double amount, IconData icon, Color fg, Color bg, NumberFormat fmt) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Rs. ${fmt.format(amount)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section ──────────────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_DailyRow> rows,
    required NumberFormat fmt,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              border: Border(bottom: BorderSide(color: color.withAlpha(55))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 7),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                  child: Text('${rows.length} entries',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),

          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No entries for the selected period.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else ...[
            _tableHeader(),
            ...rows.asMap().entries.map((e) => _tableRow(e.key, e.value, fmt)),
            _totalsRow(rows, fmt, color),
          ],
        ],
      ),
    );
  }

  // ── Table header ─────────────────────────────────────────────────────────────
  Widget _tableHeader() {
    return Container(
      color: const Color(0xFFF9F6F0),
      child: Row(children: [
        _th('Voucher No', 105),
        _th('Date', 85),
        _th('Party Name', 0, flex: true),
        _th('Item', 130),
        _th('Gross Wt', 72, right: true),
        _th('Net Wt', 72, right: true),
        _th('Metal Amt', 90, right: true),
        _th('Labour Amt', 90, right: true),
        _th('GST', 72, right: true),
        _th('Bill Amt', 100, right: true),
        _th('Cash', 85, right: true),
        _th('Card', 75, right: true),
        _th('Bank/UPI', 82, right: true),
        _th('Due Amt', 85, right: true),
        _th('Mode', 80),
      ]),
    );
  }

  Widget _th(String text, double w, {bool flex = false, bool right = false}) {
    final inner = Container(
      width: flex ? null : w,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brownLight)),
    );
    return flex ? Expanded(child: inner) : inner;
  }

  // ── Table row ─────────────────────────────────────────────────────────────────
  Widget _tableRow(int idx, _DailyRow r, NumberFormat fmt) {
    final bg = idx.isEven ? Colors.white : const Color(0xFFFAF8F5);
    return Container(
      color: bg,
      child: Row(children: [
        _tc(r.voucherNo, 105),
        _tc(DateFormat('dd/MM/yyyy').format(r.date), 85),
        _tc(r.acName, 0, flex: true),
        _tc(r.itemName.isEmpty ? '—' : r.itemName, 130),
        _tc(r.grossWt > 0 ? r.grossWt.toStringAsFixed(3) : '—', 72, right: true),
        _tc(r.netWt   > 0 ? r.netWt.toStringAsFixed(3)   : '—', 72, right: true),
        _tc(r.metalAmt  > 0 ? fmt.format(r.metalAmt)  : '—', 90, right: true),
        _tc(r.labourAmt > 0 ? fmt.format(r.labourAmt) : '—', 90, right: true),
        _tc(r.gstAmt    > 0 ? fmt.format(r.gstAmt)    : '—', 72, right: true),
        _tc(fmt.format(r.voucherAmt), 100, right: true, bold: true),
        _tc(r.cashAmt > 0 ? fmt.format(r.cashAmt) : '—', 85, right: true),
        _tc(r.cardAmt > 0 ? fmt.format(r.cardAmt) : '—', 75, right: true),
        _tc(r.bankAmt > 0 ? fmt.format(r.bankAmt) : '—', 82, right: true),
        _tc(r.dueAmt  != 0 ? fmt.format(r.dueAmt)  : '—', 85, right: true,
            color: r.dueAmt > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
        _chip(r.paymentMode, 80),
      ]),
    );
  }

  Widget _tc(String text, double w, {bool flex = false, bool right = false, bool bold = false, Color? color}) {
    final inner = Container(
      width: flex ? null : w,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          )),
    );
    return flex ? Expanded(child: inner) : inner;
  }

  // ── Mode chip ─────────────────────────────────────────────────────────────────
  Widget _chip(String mode, double w) {
    const chips = <String, (Color, Color)>{
      'Cash':     (Color(0xFFE8F5E9), Color(0xFF2E7D32)),
      'Card':     (Color(0xFFE3F2FD), Color(0xFF1565C0)),
      'Bank/UPI': (Color(0xFFF3E5F5), Color(0xFF6A1B9A)),
      'Credit':   (Color(0xFFFFEBEE), Color(0xFFC62828)),
      'Mixed':    (Color(0xFFFFF8E1), Color(0xFFF57F17)),
    };
    final bg = chips[mode]?.$1 ?? const Color(0xFFF5F5F5);
    final fg = chips[mode]?.$2 ?? Colors.black54;
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(mode,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
        ),
      ),
    );
  }

  // ── Totals row ───────────────────────────────────────────────────────────────
  Widget _totalsRow(List<_DailyRow> rows, NumberFormat fmt, Color color) {
    final bill  = _sum(rows, (r) => r.voucherAmt);
    final cash  = _sum(rows, (r) => r.cashAmt);
    final card  = _sum(rows, (r) => r.cardAmt);
    final bank  = _sum(rows, (r) => r.bankAmt);
    final due   = _sum(rows, (r) => r.dueAmt);
    final metal = _sum(rows, (r) => r.metalAmt);
    final lab   = _sum(rows, (r) => r.labourAmt);
    final gst   = _sum(rows, (r) => r.gstAmt);

    return Container(
      color: color.withAlpha(14),
      child: Row(children: [
        _tt('TOTAL', 105, bold: true),
        _tt('', 85),
        Expanded(child: _tt('', 0)),
        _tt('', 130),
        _tt('', 72),
        _tt('', 72),
        _tt(fmt.format(metal), 90, right: true, bold: true),
        _tt(fmt.format(lab),   90, right: true, bold: true),
        _tt(fmt.format(gst),   72, right: true, bold: true),
        _tt(fmt.format(bill),  100, right: true, bold: true),
        _tt(fmt.format(cash),  85, right: true, bold: true),
        _tt(fmt.format(card),  75, right: true, bold: true),
        _tt(fmt.format(bank),  82, right: true, bold: true),
        _tt(fmt.format(due),   85, right: true, bold: true,
            color: due > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
        _tt('', 80),
      ]),
    );
  }

  Widget _tt(String text, double w, {bool right = false, bool bold = false, Color? color}) {
    final inner = Container(
      width: w == 0 ? null : w,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF3E2723),
          )),
    );
    return inner;
  }

  // ── Payment mode summary (Section C) ─────────────────────────────────────────
  Widget _buildPaymentSummary(NumberFormat fmt) {
    double totCash = 0, totCard = 0, totBank = 0, totCredit = 0;
    for (final r in _filtered) {
      totCash   += r.cashAmt;
      totCard   += r.cardAmt;
      totBank   += r.bankAmt;
      if (r.dueAmt > 0) totCredit += r.dueAmt;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF57F17).withAlpha(18),
              border: Border(bottom: BorderSide(color: const Color(0xFFF57F17).withAlpha(55))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 15, color: Color(0xFFF57F17)),
                SizedBox(width: 7),
                Text('C   Payment Mode Summary',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF57F17))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _modeBox('Cash', totCash, Icons.payments_rounded,       const Color(0xFFE8F5E9), const Color(0xFF2E7D32), fmt),
                const SizedBox(width: 10),
                _modeBox('Card', totCard, Icons.credit_card_rounded,    const Color(0xFFE3F2FD), const Color(0xFF1565C0), fmt),
                const SizedBox(width: 10),
                _modeBox('Bank / UPI', totBank, Icons.account_balance_rounded, const Color(0xFFF3E5F5), const Color(0xFF6A1B9A), fmt),
                const SizedBox(width: 10),
                _modeBox('Credit / Due', totCredit, Icons.hourglass_top_rounded, const Color(0xFFFFEBEE), const Color(0xFFC62828), fmt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBox(String label, double amount, IconData icon, Color bg, Color fg, NumberFormat fmt) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withAlpha(70)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                  const SizedBox(height: 4),
                  Text('Rs. ${fmt.format(amount)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: fg),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
