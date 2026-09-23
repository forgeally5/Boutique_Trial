import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../utils/boutique_theme.dart';
import 'dart:math' as math;
import '../../utils/pdf_report_generator.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Sub-Tab bar ──────────────────────────────────────────────
        Container(
          color: BoutiqueColors.bgCard,
          child: TabBar(
            controller: _tabController,
            labelColor: BoutiqueColors.accent,
            unselectedLabelColor: BoutiqueColors.textSecondary,
            indicatorColor: BoutiqueColors.accent,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.category_rounded, size: 16),
                text: 'Product-wise Sales Summary',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Icons.bar_chart_rounded, size: 16),
                text: 'Total Sales Summary',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
            ],
          ),
        ),
        // ── Tab Content ──────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ProductWiseSalesTab(),
              _TotalSalesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB A: Individual Product Sales
// ═══════════════════════════════════════════════════════════════════════════════

class _IndividualSalesTab extends StatefulWidget {
  const _IndividualSalesTab();

  @override
  State<_IndividualSalesTab> createState() => _IndividualSalesTabState();
}

class _IndividualSalesTabState extends State<_IndividualSalesTab> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();
  String _paymentFilter = 'All';
  String _categoryFilter = 'All';
  bool _loading = false;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _categories = ['All'];

  final _paymentModes = [
    'All', 'Cash', 'Card', 'UPI', 'Bank Transfer', 'Cheque'
  ];

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
          .where('billType', isEqualTo: 'Sale')
          .get();

      final fromDt =
          DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt =
          DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];
      final catSet = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['billDate'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isBefore(fromDt.subtract(const Duration(seconds: 1))) ||
            dt.isAfter(toDt.add(const Duration(seconds: 1)))) {
          continue;
        }

        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          final cat = item['category']?.toString() ?? '—';
          catSet.add(cat);
          final paymentsList = (data['payments'] as List?)?.cast<Map<String, dynamic>>();
          String paymentStr = data['paymentMode'] ?? '—';
          final Map<String, double> paymentMap = {};
          
          if (paymentsList != null && paymentsList.isNotEmpty) {
            paymentMap.addEntries(paymentsList.map((p) => MapEntry(p['mode']?.toString() ?? 'Other', (p['amount'] as num?)?.toDouble() ?? 0.0)));
            paymentStr = paymentMap.entries.map((e) => '${e.key} ₹${_numFmt.format(e.value)}').join(' + ');
          } else if (paymentStr != '—' && paymentStr != 'Split Payment') {
            paymentMap[paymentStr] = (data['totalPayable'] as num?)?.toDouble() ?? 0.0;
          }

          rows.add({
            'billNo': data['billNo'] ?? '—',
            'date': _fmt.format(dt),
            'customerName': data['customerName'] ?? 'Walk-in',
            'tagId': item['tagId'] ?? '—',
            'productName':
                '${item['tagId'] ?? ''} ${item['name'] ?? ''}'.trim(),
            'category': cat,
            'qty': item['qty'] ?? 1,
            'price': (item['price'] as num?)?.toDouble() ?? 0.0,
            'discountAmt': (item['discountAmt'] as num?)?.toDouble() ?? 0.0,
            'lineAmount': (item['lineAmount'] as num?)?.toDouble() ?? 0.0,
            'paymentMode': paymentStr,
            'paymentMap': paymentMap,
            '_ts': ts,
          });
        }
      }

      rows.sort((a, b) {
        final ta = a['_ts'] as Timestamp?;
        final tb = b['_ts'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      final cats = ['All', ...catSet.toList()..sort()];
      setState(() {
        _allRows = rows;
        _categories = cats;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) BoutiqueToast.showError(context, 'Error: $e');
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allRows.where((r) {
        if (q.isNotEmpty) {
          final bill = r['billNo'].toString().toLowerCase();
          final cust = r['customerName'].toString().toLowerCase();
          final tag = r['tagId'].toString().toLowerCase();
          if (!bill.contains(q) && !cust.contains(q) && !tag.contains(q)) {
            return false;
          }
        }
        if (_paymentFilter != 'All') {
          final pMap = r['paymentMap'] as Map<String, double>?;
          if (pMap == null || !pMap.containsKey(_paymentFilter)) {
            return false;
          }
        }
        if (_categoryFilter != 'All' &&
            r['category'] != _categoryFilter) {
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

  double get _totalRevenue => _filtered.fold(
      0.0,
      (s, r) => s + ((r['lineAmount'] as num?)?.toDouble() ?? 0));
  double get _totalDiscount => _filtered.fold(
      0.0,
      (s, r) => s + ((r['discountAmt'] as num?)?.toDouble() ?? 0));
  int get _totalQty => _filtered.fold(
      0, (s, r) => s + ((r['qty'] as num?)?.toInt() ?? 0));

  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateSalesIndividualPdf(
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
    final bytes = await generateSalesIndividualPdf(
      rows: _filtered,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'individual_sales_${_fmt.format(_dateFrom)}_${_fmt.format(_dateTo)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search bill no, customer, tag ID…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→',
                      style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration:
                        BoutiqueInputDecoration.field(hintText: 'Category'),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _categoryFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration: BoutiqueInputDecoration.field(
                        hintText: 'Payment Mode'),
                    items: _paymentModes
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _paymentFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: BoutiqueColors.accent),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handlePrint,
                  tooltip: 'Print Report',
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleDownload,
                  tooltip: 'Download PDF',
                ),
              ],
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            color: BoutiqueColors.accentSoft,
            child: Row(
              children: [
                _chip(Icons.receipt_long_rounded, 'Line Items',
                    '${_filtered.length}'),
                const SizedBox(width: 20),
                _chip(Icons.shopping_bag_rounded, 'Total Qty',
                    '$_totalQty'),
                const SizedBox(width: 20),
                _chip(Icons.currency_rupee_rounded, 'Total Revenue',
                    '₹${_numFmt.format(_totalRevenue)}'),
                const SizedBox(width: 20),
                _chip(Icons.discount_outlined, 'Total Discount',
                    '₹${_numFmt.format(_totalDiscount)}'),
              ],
            ),
          ),

          // Table
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: BoutiqueColors.accent))
                : _filtered.isEmpty
                    ? _emptyState()
                    : Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoutiqueDecoration.card(),
                        child: Column(
                          children: [
                            _tableHeader(),
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

  Widget _tableHeader() {
    const cols = [
      'S.No', 'Bill No', 'Date', 'Customer', 'Tag ID',
      'Product', 'Category', 'Qty', 'Unit Price (₹)',
      'Discount (₹)', 'Total (₹)', 'Payment'
    ];
    const flexes = [1, 2, 2, 3, 2, 3, 2, 1, 2, 2, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: flexes[e.key],
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

  Widget _tableRow(Map<String, dynamic> r, int i) {
    const flexes = [1, 2, 2, 3, 2, 3, 2, 1, 2, 2, 2, 2];
    final isAlt = i.isOdd;
    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: flexes[0], child: _cell('${i + 1}')),
          Expanded(
              flex: flexes[1],
              child: _cell(r['billNo']?.toString() ?? '—',
                  color: BoutiqueColors.accent, bold: true)),
          Expanded(
              flex: flexes[2], child: _cell(r['date']?.toString() ?? '—')),
          Expanded(
              flex: flexes[3],
              child: _cell(r['customerName']?.toString() ?? '—', bold: true)),
          Expanded(
              flex: flexes[4],
              child: _cell(r['tagId']?.toString() ?? '—')),
          Expanded(
              flex: flexes[5],
              child: _cell(r['productName']?.toString() ?? '—')),
          Expanded(
              flex: flexes[6],
              child: _cell(r['category']?.toString() ?? '—')),
          Expanded(
              flex: flexes[7],
              child: _cell('${(r['qty'] as num?)?.toInt() ?? 0}')),
          Expanded(
              flex: flexes[8],
              child: _cell(
                  '₹${_numFmt.format((r['price'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: flexes[9],
              child: _cell(
                  '₹${_numFmt.format((r['discountAmt'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: flexes[10],
              child: _cell(
                  '₹${_numFmt.format((r['lineAmount'] as num?)?.toDouble() ?? 0)}',
                  bold: true)),
          Expanded(
              flex: flexes[11],
              child: Tooltip(
                message: r['paymentMode']?.toString() ?? '—',
                child: _cell(r['paymentMode']?.toString() ?? '—'),
              )),
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
            Text(DateFormat('dd/MM/yyyy').format(dt),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: BoutiqueColors.accent),
        const SizedBox(width: 5),
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: BoutiqueColors.accent)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent)),
      ],
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt_rounded, size: 52, color: BoutiqueColors.textMuted),
          SizedBox(height: 12),
          Text('No individual sales records found.',
              style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB B: Total Sales Summary
// ═══════════════════════════════════════════════════════════════════════════════

class _TotalSalesTab extends StatefulWidget {
  const _TotalSalesTab();

  @override
  State<_TotalSalesTab> createState() => _TotalSalesTabState();
}

class _TotalSalesTabState extends State<_TotalSalesTab> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();
  String _paymentFilter = 'All';
  bool _loading = false;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];

  final _paymentModes = [
    'All', 'Cash', 'Card', 'UPI', 'Bank Transfer', 'Cheque'
  ];

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
          .where('billType', isEqualTo: 'Sale')
          .get();

      final fromDt =
          DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt =
          DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['billDate'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isBefore(fromDt.subtract(const Duration(seconds: 1))) ||
            dt.isAfter(toDt.add(const Duration(seconds: 1)))) {
          continue;
        }

        final paymentsList = (data['payments'] as List?)?.cast<Map<String, dynamic>>();
        String paymentStr = data['paymentMode'] ?? '—';
        final Map<String, double> paymentMap = {};
        
        if (paymentsList != null && paymentsList.isNotEmpty) {
          paymentMap.addEntries(paymentsList.map((p) => MapEntry(p['mode']?.toString() ?? 'Other', (p['amount'] as num?)?.toDouble() ?? 0.0)));
          paymentStr = paymentMap.entries.map((e) => '${e.key} ₹${_numFmt.format(e.value)}').join(' + ');
        } else if (paymentStr != '—' && paymentStr != 'Split Payment') {
          paymentMap[paymentStr] = (data['totalPayable'] as num?)?.toDouble() ?? 0.0;
        }

        rows.add({
          'billNo': data['billNo'] ?? '—',
          'date': _fmt.format(dt),
          'customerName': data['customerName'] ?? 'Walk-in',
          'customerMobile': data['customerMobile'] ?? '',
          'subtotal': (data['subtotal'] as num?)?.toDouble() ?? 0.0,
          'discount': (data['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0,
          'tax': (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
          'totalPayable': (data['totalPayable'] as num?)?.toDouble() ?? 0.0,
          'amountReceived': (data['amountReceived'] as num?)?.toDouble() ?? 0.0,
          'paymentMode': paymentStr,
          'paymentMap': paymentMap,
          'itemCount': (data['items'] as List?)?.length ?? 0,
          '_ts': ts,
        });
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
      if (mounted) BoutiqueToast.showError(context, 'Error: $e');
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
        if (_paymentFilter != 'All') {
          final pMap = r['paymentMap'] as Map<String, double>?;
          if (pMap == null || !pMap.containsKey(_paymentFilter)) {
            return false;
          }
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

  double get _totalPayable => _filtered.fold(
      0.0, (s, r) => s + ((r['totalPayable'] as num?)?.toDouble() ?? 0));
  double get _totalDiscount => _filtered.fold(
      0.0, (s, r) => s + ((r['discount'] as num?)?.toDouble() ?? 0));
  double get _totalTax => _filtered.fold(
      0.0, (s, r) => s + ((r['tax'] as num?)?.toDouble() ?? 0));
  double get _totalReceived => _filtered.fold(
      0.0,
      (s, r) => s + ((r['amountReceived'] as num?)?.toDouble() ?? 0));

  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateSalesTotalPdf(
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
    final bytes = await generateSalesTotalPdf(
      rows: _filtered,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'total_sales_${_fmt.format(_dateFrom)}_${_fmt.format(_dateTo)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
            ),
            child: Row(
              children: [
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
                _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→',
                      style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration: BoutiqueInputDecoration.field(
                        hintText: 'Payment Mode'),
                    items: _paymentModes
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _paymentFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: BoutiqueColors.accent),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handlePrint,
                  tooltip: 'Print Report',
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleDownload,
                  tooltip: 'Download PDF',
                ),
              ],
            ),
          ),

          // Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            color: BoutiqueColors.bgCard,
            child: Row(
              children: [
                _statCard('Total Bills', '${_filtered.length}',
                    Icons.receipt_long_rounded, BoutiqueColors.accent),
                const SizedBox(width: 16),
                _statCard('Total Revenue',
                    '₹${_numFmt.format(_totalPayable)}',
                    Icons.trending_up_rounded, BoutiqueColors.success),
                const SizedBox(width: 16),
                _statCard('Total Discount',
                    '₹${_numFmt.format(_totalDiscount)}',
                    Icons.discount_outlined, BoutiqueColors.gold),
                const SizedBox(width: 16),
                _statCard('Total Tax', '₹${_numFmt.format(_totalTax)}',
                    Icons.account_balance_outlined, BoutiqueColors.textSecondary),
                const SizedBox(width: 16),
                _statCard('Amount Received',
                    '₹${_numFmt.format(_totalReceived)}',
                    Icons.payments_outlined, BoutiqueColors.warning),
              ],
            ),
          ),

          // Payment Mode Breakdown
          if (_filtered.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              color: BoutiqueColors.bgSubtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Mode Breakdown', style: TextStyle(fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ...() {
                        final sums = <String, double>{};
                        for (final r in _filtered) {
                          final pMap = r['paymentMap'] as Map<String, double>? ?? {};
                          for (final e in pMap.entries) {
                            sums[e.key] = (sums[e.key] ?? 0) + e.value;
                          }
                        }
                        final total = sums.values.fold(0.0, (s, v) => s + v);
                        if (total == 0) return [const SizedBox()];
                        
                        return sums.entries.where((e) => e.value > 0).map((e) {
                          final percent = (e.value / total * 100).toStringAsFixed(1);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: BoutiqueColors.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: BoutiqueColors.border),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.key, style: const TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
                                const SizedBox(width: 8),
                                Text('₹${_numFmt.format(e.value)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: BoutiqueColors.accentSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: BoutiqueColors.border),

          // Table
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: BoutiqueColors.accent))
                : _filtered.isEmpty
                    ? _emptyState()
                    : Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoutiqueDecoration.card(),
                        child: Column(
                          children: [
                            _tableHeader(),
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

  Widget _tableHeader() {
    const cols = [
      'S.No', 'Bill No', 'Date', 'Customer', 'Mobile',
      'Items', 'Subtotal (₹)', 'Discount (₹)', 'Tax (₹)',
      'Total Payable (₹)', 'Payment', 'Received (₹)'
    ];
    const flexes = [1, 2, 2, 3, 2, 1, 2, 2, 2, 2, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: flexes[e.key],
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

  Widget _tableRow(Map<String, dynamic> r, int i) {
    const flexes = [1, 2, 2, 3, 2, 1, 2, 2, 2, 2, 2, 2];
    final isAlt = i.isOdd;
    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: flexes[0], child: _cell('${i + 1}')),
          Expanded(
              flex: flexes[1],
              child: _cell(r['billNo']?.toString() ?? '—',
                  color: BoutiqueColors.accent, bold: true)),
          Expanded(
              flex: flexes[2], child: _cell(r['date']?.toString() ?? '—')),
          Expanded(
              flex: flexes[3],
              child: _cell(r['customerName']?.toString() ?? '—', bold: true)),
          Expanded(
              flex: flexes[4],
              child: _cell(r['customerMobile']?.toString() ?? '—')),
          Expanded(
              flex: flexes[5],
              child: _cell('${r['itemCount'] ?? 0}')),
          Expanded(
              flex: flexes[6],
              child: _cell(
                  '₹${_numFmt.format((r['subtotal'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: flexes[7],
              child: _cell(
                  '₹${_numFmt.format((r['discount'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: flexes[8],
              child: _cell(
                  '₹${_numFmt.format((r['tax'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: flexes[9],
              child: _cell(
                  '₹${_numFmt.format((r['totalPayable'] as num?)?.toDouble() ?? 0)}',
                  bold: true,
                  color: BoutiqueColors.accent)),
          Expanded(
              flex: flexes[10],
              child: Tooltip(
                message: r['paymentMode']?.toString() ?? '—',
                child: _cell(r['paymentMode']?.toString() ?? '—'),
              )),
          Expanded(
              flex: flexes[11],
              child: _cell(
                  '₹${_numFmt.format((r['amountReceived'] as num?)?.toDouble() ?? 0)}')),
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
            Text(DateFormat('dd/MM/yyyy').format(dt),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 52, color: BoutiqueColors.textMuted),
          SizedBox(height: 12),
          Text('No sales records found for the selected period.',
              style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TAB C: Product-wise Sales Summary
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ProductWiseSalesTab extends StatefulWidget {
  const _ProductWiseSalesTab();

  @override
  State<_ProductWiseSalesTab> createState() => _ProductWiseSalesTabState();
}

class _ProductWiseSalesTabState extends State<_ProductWiseSalesTab> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();
  String _paymentFilter = 'All';
  String _categoryFilter = 'All';
  bool _loading = false;

  int _sortColumnIndex = 5; // Revenue
  bool _sortAscending = false;

  List<Map<String, dynamic>> _allRawRows = [];
  List<Map<String, dynamic>> _aggregatedRows = [];
  List<String> _categories = ['All'];

  final _paymentModes = [
    'All', 'Cash', 'Card', 'UPI', 'Bank Transfer', 'Cheque'
  ];

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
          .where('billType', isEqualTo: 'Sale')
          .get();

      final fromDt =
          DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt =
          DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];
      final catSet = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['billDate'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        if (dt.isBefore(fromDt.subtract(const Duration(seconds: 1))) ||
            dt.isAfter(toDt.add(const Duration(seconds: 1)))) {
          continue;
        }

        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          final cat = item['category']?.toString() ?? 'â€”';
          catSet.add(cat);
          rows.add({
            'billNo': data['billNo'] ?? 'â€”',
            'tagId': item['tagId'] ?? 'â€”',
            'productName': item['name'] ?? '',
            'category': cat,
            'qty': (item['qty'] as num?)?.toInt() ?? 1,
            'discountAmt': (item['discountAmt'] as num?)?.toDouble() ?? 0.0,
            'lineAmount': (item['lineAmount'] as num?)?.toDouble() ?? 0.0,
            'paymentMode': data['paymentMode'] ?? 'â€”',
          });
        }
      }

      final cats = ['All', ...catSet.toList()..sort()];
      setState(() {
        _allRawRows = rows;
        _categories = cats;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) BoutiqueToast.showError(context, 'Error: $e');
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    
    // 1. Filter Raw Rows
    final filteredRaw = _allRawRows.where((r) {
      if (q.isNotEmpty) {
        final tag = r['tagId'].toString().toLowerCase();
        final name = r['productName'].toString().toLowerCase();
        if (!tag.contains(q) && !name.contains(q)) {
          return false;
        }
      }
      if (_paymentFilter != 'All' && r['paymentMode'] != _paymentFilter) return false;
      if (_categoryFilter != 'All' && r['category'] != _categoryFilter) return false;
      return true;
    }).toList();

    // 2. Aggregate
    final aggMap = <String, Map<String, dynamic>>{};
    for (final r in filteredRaw) {
      final tagId = r['tagId'].toString();
      final name = r['productName'].toString();
      final key = '$tagId|$name';
      
      if (!aggMap.containsKey(key)) {
        aggMap[key] = {
          'tagId': tagId,
          'productName': name,
          'category': r['category'],
          'qty': 0,
          'revenue': 0.0,
          'discount': 0.0,
          'orderIds': <String>{},
        };
      }
      
      aggMap[key]!['qty'] = (aggMap[key]!['qty'] as int) + (r['qty'] as int);
      aggMap[key]!['revenue'] = (aggMap[key]!['revenue'] as double) + (r['lineAmount'] as double);
      aggMap[key]!['discount'] = (aggMap[key]!['discount'] as double) + (r['discountAmt'] as double);
      (aggMap[key]!['orderIds'] as Set<String>).add(r['billNo'].toString());
    }

    final aggList = aggMap.values.map((v) {
      final qty = v['qty'] as int;
      final rev = v['revenue'] as double;
      return {
        'tagId': v['tagId'],
        'productName': v['productName'],
        'category': v['category'],
        'qty': qty,
        'revenue': rev,
        'discount': v['discount'],
        'orders': (v['orderIds'] as Set).length,
        'avgPrice': qty > 0 ? rev / qty : 0.0,
      };
    }).toList();

    // 3. Sort
    _sortRows(aggList, _sortColumnIndex, _sortAscending);

    setState(() {
      _aggregatedRows = aggList;
    });
  }

  void _sortRows(List<Map<String, dynamic>> rows, int columnIndex, bool ascending) {
    rows.sort((a, b) {
      dynamic valA;
      dynamic valB;
      switch (columnIndex) {
        case 0: valA = a['tagId']; valB = b['tagId']; break;
        case 1: valA = a['productName']; valB = b['productName']; break;
        case 2: valA = a['category']; valB = b['category']; break;
        case 3: valA = a['qty']; valB = b['qty']; break;
        case 4: valA = a['revenue']; valB = b['revenue']; break;
        case 5: valA = a['discount']; valB = b['discount']; break;
        case 6: valA = a['avgPrice']; valB = b['avgPrice']; break;
        case 7: valA = a['orders']; valB = b['orders']; break;
        default: valA = a['revenue']; valB = b['revenue']; break;
      }

      int cmp = 0;
      if (valA is num && valB is num) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }
      return ascending ? cmp : -cmp;
    });
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = false; 
      }
      _sortRows(_aggregatedRows, _sortColumnIndex, _sortAscending);
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

  double get _totalRevenue => _aggregatedRows.fold(0.0, (s, r) => s + (r['revenue'] as double));
  double get _totalDiscount => _aggregatedRows.fold(0.0, (s, r) => s + (r['discount'] as double));
  int get _totalQty => _aggregatedRows.fold(0, (s, r) => s + (r['qty'] as int));

  Future<void> _handlePrint() async {
    if (_aggregatedRows.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateProductWisePdf(
      rows: _aggregatedRows,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleDownload() async {
    if (_aggregatedRows.isEmpty) {
      BoutiqueToast.showError(context, 'No data to download.');
      return;
    }
    final bytes = await generateProductWisePdf(
      rows: _aggregatedRows,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'product_wise_sales_${_fmt.format(_dateFrom)}_${_fmt.format(_dateTo)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search product name or tag ID…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→',
                      style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration:
                        BoutiqueInputDecoration.field(hintText: 'Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _categoryFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration: BoutiqueInputDecoration.field(
                        hintText: 'Payment Mode'),
                    items: _paymentModes
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _paymentFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: BoutiqueColors.accent),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handlePrint,
                  tooltip: 'Print Report',
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleDownload,
                  tooltip: 'Download PDF',
                ),
              ],
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            color: BoutiqueColors.accentSoft,
            child: Row(
              children: [
                _chip(Icons.category_rounded, 'Unique Products', '${_aggregatedRows.length}'),
                const SizedBox(width: 20),
                _chip(Icons.shopping_bag_rounded, 'Total Qty Sold', '$_totalQty'),
                const SizedBox(width: 20),
                _chip(Icons.currency_rupee_rounded, 'Total Revenue', '₹${_numFmt.format(_totalRevenue)}'),
                const SizedBox(width: 20),
                _chip(Icons.discount_outlined, 'Total Discount', '₹${_numFmt.format(_totalDiscount)}'),
              ],
            ),
          ),

          // Table
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: BoutiqueColors.accent))
                : _aggregatedRows.isEmpty
                    ? _emptyState()
                    : Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoutiqueDecoration.card(),
                        child: Column(
                          children: [
                            _tableHeader(),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _aggregatedRows.length,
                                separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: BoutiqueColors.borderLight),
                                itemBuilder: (ctx, i) => _tableRow(_aggregatedRows[i], i),
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

  Widget _tableHeader() {
    const cols = [
      'S.No', 'Tag ID', 'Product Name', 'Category', 'Qty Sold',
      'Revenue (₹)', 'Discount (₹)', 'Avg Price (₹)', 'Orders'
    ];
    const flexes = [1, 2, 4, 2, 2, 2, 2, 2, 2];
    // We map column labels to column indices for sorting
    final colIndices = [-1, 0, 1, 2, 3, 4, 5, 6, 7];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          final colIndex = colIndices[e.key];
          final isSortable = colIndex >= 0;
          return Expanded(
            flex: flexes[e.key],
            child: isSortable 
              ? InkWell(
                  onTap: () => _onSort(colIndex),
                  child: Row(
                    children: [
                      Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textSecondary,
                        ),
                      ),
                      if (_sortColumnIndex == colIndex)
                        Icon(
                          _sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 14,
                          color: BoutiqueColors.textSecondary,
                        ),
                    ],
                  ),
                )
              : Text(
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

  Widget _tableRow(Map<String, dynamic> r, int i) {
    const flexes = [1, 2, 4, 2, 2, 2, 2, 2, 2];
    final isAlt = i.isOdd;
    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: flexes[0], child: _cell('${i + 1}')),
          Expanded(flex: flexes[1], child: _cell(r['tagId'].toString())),
          Expanded(flex: flexes[2], child: _cell(r['productName'].toString(), bold: true, color: BoutiqueColors.accent)),
          Expanded(flex: flexes[3], child: _cell(r['category'].toString())),
          Expanded(flex: flexes[4], child: _cell(r['qty'].toString())),
          Expanded(flex: flexes[5], child: _cell('₹${_numFmt.format(r['revenue'])}', bold: true)),
          Expanded(flex: flexes[6], child: _cell('₹${_numFmt.format(r['discount'])}')),
          Expanded(flex: flexes[7], child: _cell('₹${_numFmt.format(r['avgPrice'])}')),
          Expanded(flex: flexes[8], child: _cell(r['orders'].toString())),
        ],
      ),
    );
  }

  Widget _cell(String text, {Color color = BoutiqueColors.textPrimary, bool bold = false}) {
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
            Text('$label: ', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
            Text(DateFormat('dd/MM/yyyy').format(dt),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: BoutiqueColors.accent),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: BoutiqueColors.accent)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
      ],
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_rounded, size: 52, color: BoutiqueColors.textMuted),
          SizedBox(height: 12),
          Text('No product sales records found.',
              style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

