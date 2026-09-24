import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/pdf_report_generator.dart';
import '../../utils/excel_generator.dart';

class CustomerReturnTab extends StatefulWidget {
  const CustomerReturnTab({super.key});

  @override
  State<CustomerReturnTab> createState() => _CustomerReturnTabState();
}

class _CustomerReturnTabState extends State<CustomerReturnTab> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  bool _loading = false;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];

  final _statusOptions = ['All', 'Processed', 'Pending'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    _dateFrom = fyStart;
    _dateTo = now;
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billType', isEqualTo: 'Return')
          .get();

      final fromDt =
          DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt = DateTime(
          _dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;
        final ts = data['billDate'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (dt.isAfter(fromDt.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(toDt.add(const Duration(seconds: 1)))) {
            // Expand items into individual rows
            final items = (data['items'] as List?) ?? [{}];
            for (final item in items) {
              rows.add({
                'billNo': data['billNo'] ?? '—',
                'originalBillNo': data['originalBillNo'] ?? '—',
                'date': _fmt.format(dt),
                'customerName': data['customerName'] ?? 'Walk-in',
                'customerMobile': data['customerMobile'] ?? '',
                'tagId': item['tagId'] ?? '',
                'productName':
                    '${item['tagId'] ?? ''} ${item['name'] ?? ''}'.trim(),
                'category': item['category'] ?? '—',
                'qty': item['qty'] ?? 1,
                'refundAmount': (item['lineAmount'] as num?)?.toDouble() ??
                    (data['totalPayable'] as num?)?.toDouble() ??
                    0.0,
                'reason': data['returnReason'] ?? '—',
                'refundMode': data['paymentMode'] ?? '—',
                'totalRefund':
                    (data['totalPayable'] as num?)?.toDouble() ?? 0.0,
                'status': data['returnStatus'] ?? 'Processed',
                '_ts': ts,
              });
            }
          }
        }
      }

      rows.sort((a, b) {
        final ta = a['_ts'] as Timestamp?;
        final tb = b['_ts'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _allRows = rows;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) BoutiqueToast.showError(context, 'Error loading returns: $e');
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allRows.where((r) {
        if (q.isNotEmpty) {
          final bill = r['billNo'].toString().toLowerCase();
          final cust = r['customerName'].toString().toLowerCase();
          final mob = r['customerMobile'].toString();
          if (!bill.contains(q) && !cust.contains(q) && !mob.contains(q)) {
            return false;
          }
        }
        if (_statusFilter != 'All' && r['status'] != _statusFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _load();
    }
  }

  double get _totalRefund =>
      _filtered.fold(0.0, (s, r) => s + ((r['refundAmount'] as num?)?.toDouble() ?? 0));

  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateIssueReportPdf(
      rows: _filtered,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleDownload() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to download.');
      return;
    }
    final bytes = await generateIssueReportPdf(
      rows: _filtered,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'issue_report_${_fmt.format(_dateFrom)}_${_fmt.format(_dateTo)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // ── Filter & Action Bar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
            ),
            child: Row(
              children: [
                // Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search bill no, customer, mobile…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Date From
                _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→',
                      style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
                const SizedBox(width: 12),
                // Status filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration:
                        BoutiqueInputDecoration.field(hintText: 'Status'),
                    items: _statusOptions
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _statusFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Refresh
                _iconBtn(Icons.refresh_rounded, BoutiqueColors.accent, _load,
                    'Refresh'),
                // Print
                _iconBtn(Icons.print_outlined, BoutiqueColors.accent,
                    _handlePrint, 'Print Report'),
                // Download PDF
                _iconBtn(Icons.download_outlined, BoutiqueColors.accent,
                    _handleDownload, 'Download PDF'),
                // Download Excel
                _iconBtn(Icons.table_view_rounded, const Color(0xFF1E7E34), () async {
                  if (_filtered.isEmpty) {
                    BoutiqueToast.showError(context, 'No data to download.');
                    return;
                  }
                  await ExcelGenerator.downloadIssueReportExcel(
                    rows: _filtered,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    filterType: 'Customer Returns',
                  );
                  if (mounted) {
                    BoutiqueToast.showSuccess(context, 'Customer Return Report (.xlsx) downloaded!');
                  }
                }, 'Download Excel (.xlsx)'),
              ],
            ),
          ),

          // ── Summary Banner ───────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            color: BoutiqueColors.accentSoft,
            child: Row(
              children: [
                _summaryChip(Icons.assignment_return_rounded,
                    'Total Returns', '${_filtered.length}'),
                const SizedBox(width: 24),
                _summaryChip(Icons.currency_rupee_rounded, 'Total Refund',
                    '₹${_numFmt.format(_totalRefund)}'),
              ],
            ),
          ),

          // ── Table ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: BoutiqueColors.accent))
                : _filtered.isEmpty
                    ? _emptyState('No return/issue records found',
                        Icons.assignment_return_outlined)
                    : Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoutiqueDecoration.card(),
                        child: Column(
                          children: [
                            _tableHeader([
                              'S.No', 'Return Bill No', 'Orig. Bill',
                              'Date', 'Customer', 'Mobile',
                              'Product', 'Qty', 'Refund (₹)',
                              'Reason', 'Mode', 'Status'
                            ]),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: BoutiqueColors.borderLight),
                                itemBuilder: (ctx, i) =>
                                    _tableRow(_filtered[i], i),
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

  Widget _tableHeader(List<String> cols) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          final flex = _columnFlex(e.key);
          return Expanded(
            flex: flex,
            child: Text(
              e.value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _columnFlex(int idx) {
    // S.No, RetBill, OrigBill, Date, Customer, Mobile, Product, Qty, Refund, Reason, Mode, Status
    const flex = [1, 2, 2, 2, 3, 2, 3, 1, 2, 2, 2, 2];
    return flex[idx];
  }

  Widget _tableRow(Map<String, dynamic> r, int i) {
    final isAlt = i.isOdd;
    final status = r['status']?.toString() ?? 'Processed';
    final statusColor = status == 'Processed'
        ? BoutiqueColors.success
        : BoutiqueColors.warning;
    final statusBg = status == 'Processed'
        ? BoutiqueColors.successBg
        : BoutiqueColors.warningBg;

    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 1, child: _cell('${i + 1}')),
          Expanded(
              flex: 2,
              child: _cell(r['billNo']?.toString() ?? '—',
                  color: BoutiqueColors.accent, bold: true)),
          Expanded(
              flex: 2, child: _cell(r['originalBillNo']?.toString() ?? '—')),
          Expanded(flex: 2, child: _cell(r['date']?.toString() ?? '—')),
          Expanded(
              flex: 3,
              child: _cell(r['customerName']?.toString() ?? '—', bold: true)),
          Expanded(
              flex: 2, child: _cell(r['customerMobile']?.toString() ?? '—')),
          Expanded(
              flex: 3,
              child: _cell(r['productName']?.toString() ?? '—')),
          Expanded(
              flex: 1, child: _cell(r['qty']?.toString() ?? '0')),
          Expanded(
              flex: 2,
              child: _cell(
                  '₹${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}',
                  bold: true)),
          Expanded(
              flex: 2, child: _cell(r['reason']?.toString() ?? '—')),
          Expanded(
              flex: 2, child: _cell(r['refundMode']?.toString() ?? '—')),
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {Color color = BoutiqueColors.textPrimary, bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _datePill(String label, DateTime dt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: BoutiqueColors.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BoutiqueColors.border),
        ),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: BoutiqueColors.textSecondary)),
            Text(_fmt.format(dt),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: BoutiqueColors.accent),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: BoutiqueColors.accent)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent)),
      ],
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: BoutiqueColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
