import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/pdf_report_generator.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  final _searchCtrl = TextEditingController();
  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  String _pricingFilter = 'All';
  bool _loading = false;

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _categories = ['All'];

  final _statusOptions = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];
  final _pricingOptions = ['All', 'Quantity-Based', 'Weight-Based'];

  @override
  void initState() {
    super.initState();
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
      final snap =
          await FirebaseFirestore.instance.collection('products').get();

      final rows = <Map<String, dynamic>>[];
      final catSet = <String>{};

      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;

        final qty = (data['quantity'] as num?)?.toInt() ?? 0;
        final sp = (data['sellingPrice'] as num?)?.toDouble() ?? 0;

        // Derive status
        String status = data['status']?.toString() ?? 'In Stock';
        if (qty == 0) status = 'Out of Stock';
        if (qty > 0 && qty < 5) status = 'Low Stock';
        data['status'] = status;
        data['stockValue'] = qty * sp;

        final cat = data['category']?.toString() ?? 'Uncategorized';
        catSet.add(cat);
        rows.add(data);
      }

      final cats = ['All', ...catSet.toList()..sort()];

      setState(() {
        _allProducts = rows;
        _categories = cats;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        BoutiqueToast.showError(context, 'Error loading stock: $e');
      }
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allProducts.where((r) {
        if (q.isNotEmpty) {
          final tag = r['tagId']?.toString().toLowerCase() ?? '';
          final name = r['name']?.toString().toLowerCase() ?? '';
          if (!tag.contains(q) && !name.contains(q)) return false;
        }
        if (_categoryFilter != 'All' &&
            r['category']?.toString() != _categoryFilter) { return false; }
        if (_statusFilter != 'All' &&
            r['status']?.toString() != _statusFilter) { return false; }
        if (_pricingFilter != 'All' &&
            r['pricingType']?.toString() != _pricingFilter) { return false; }
        return true;
      }).toList();
    });
  }

  // Summary values
  double get _totalStockValue => _filtered.fold(
      0.0,
      (s, r) =>
          s +
          ((r['quantity'] as num?)?.toDouble() ?? 0) *
              ((r['sellingPrice'] as num?)?.toDouble() ?? 0));

  int get _totalQty => _filtered.fold(
      0, (s, r) => s + ((r['quantity'] as num?)?.toInt() ?? 0));

  int get _lowStockCount =>
      _filtered.where((r) => r['status'] == 'Low Stock').length;

  int get _outOfStockCount =>
      _filtered.where((r) => r['status'] == 'Out of Stock').length;

  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateStockReportPdf(
      rows: _filtered,
      categoryFilter: _categoryFilter,
      statusFilter: _statusFilter,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleDownload() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to download.');
      return;
    }
    final bytes = await generateStockReportPdf(
      rows: _filtered,
      categoryFilter: _categoryFilter,
      statusFilter: _statusFilter,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // ── Filter Bar ───────────────────────────────────────────────
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
                      hintText: 'Search tag ID or product name…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Category
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
                // Status
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
                // Pricing Type
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _pricingFilter,
                    style: const TextStyle(
                        fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration:
                        BoutiqueInputDecoration.field(hintText: 'Pricing Type'),
                    items: _pricingOptions
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _pricingFilter = v);
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

          // ── Summary Cards ────────────────────────────────────────────
          Container(
            color: BoutiqueColors.bgCard,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Row(
              children: [
                _summaryCard(Icons.inventory_2_outlined, 'Total Products',
                    '${_filtered.length}', BoutiqueColors.accent),
                const SizedBox(width: 16),
                _summaryCard(Icons.numbers_rounded, 'Total Qty',
                    '$_totalQty', BoutiqueColors.gold),
                const SizedBox(width: 16),
                _summaryCard(
                    Icons.currency_rupee_rounded,
                    'Stock Value',
                    '₹${_numFmt.format(_totalStockValue)}',
                    BoutiqueColors.success),
                const SizedBox(width: 16),
                _summaryCard(Icons.warning_amber_rounded, 'Low Stock',
                    '$_lowStockCount', BoutiqueColors.warning),
                const SizedBox(width: 16),
                _summaryCard(Icons.remove_shopping_cart_rounded,
                    'Out of Stock', '$_outOfStockCount', BoutiqueColors.destructive),
              ],
            ),
          ),

          const Divider(height: 1, color: BoutiqueColors.border),

          // ── Table ────────────────────────────────────────────────────
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
                                separatorBuilder: (_, __) => const Divider(
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
      'S.No', 'Tag ID', 'Product Name', 'Category',
      'Type', 'Qty', 'Unit', 'MRP (₹)', 'Sell Price (₹)',
      'Stock Value (₹)', 'Festival', 'Status'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: _flex(e.key),
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

  int _flex(int idx) {
    const flexes = [1, 2, 4, 2, 2, 1, 1, 2, 2, 2, 1, 2];
    return flexes[idx];
  }

  Widget _tableRow(Map<String, dynamic> r, int i) {
    final qty = (r['quantity'] as num?)?.toInt() ?? 0;
    final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0;
    final stockVal = qty * sp;
    final status = r['status']?.toString() ?? 'In Stock';
    final isFestival = r['isFestivalStock'] == true;
    final isAlt = i.isOdd;

    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'Low Stock':
        statusColor = BoutiqueColors.warning;
        statusBg = BoutiqueColors.warningBg;
        break;
      case 'Out of Stock':
        statusColor = BoutiqueColors.destructive;
        statusBg = BoutiqueColors.destructiveBg;
        break;
      default:
        statusColor = BoutiqueColors.success;
        statusBg = BoutiqueColors.successBg;
    }

    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 1, child: _cell('${i + 1}')),
          Expanded(
              flex: 2,
              child: _cell(r['tagId']?.toString() ?? '—',
                  color: BoutiqueColors.accent, bold: true)),
          Expanded(
              flex: 4,
              child: _cell(r['name']?.toString() ?? '—', bold: true)),
          Expanded(flex: 2, child: _cell(r['category']?.toString() ?? '—')),
          Expanded(
              flex: 2,
              child: _cell(r['pricingType']?.toString() ?? '—')),
          Expanded(
              flex: 1,
              child: _cell('$qty',
                  color: qty == 0
                      ? BoutiqueColors.destructive
                      : qty < 5
                          ? BoutiqueColors.warning
                          : BoutiqueColors.textPrimary,
                  bold: true)),
          Expanded(flex: 1, child: _cell(r['unit']?.toString() ?? '—')),
          Expanded(
              flex: 2,
              child: _cell(
                  '₹${_numFmt.format((r['mrp'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
              flex: 2,
              child: _cell('₹${_numFmt.format(sp)}')),
          Expanded(
              flex: 2,
              child: _cell('₹${_numFmt.format(stockVal)}',
                  color: BoutiqueColors.textPrimary, bold: true)),
          Expanded(
            flex: 1,
            child: Icon(
              isFestival ? Icons.celebration_rounded : Icons.remove,
              size: 16,
              color: isFestival
                  ? BoutiqueColors.gold
                  : BoutiqueColors.textMuted,
            ),
          ),
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
                overflow: TextOverflow.ellipsis,
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

  Widget _summaryCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
              Text(label,
                  style: TextStyle(fontSize: 10, color: color)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
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
          Icon(Icons.inventory_2_outlined, size: 52, color: BoutiqueColors.textMuted),
          SizedBox(height: 12),
          Text('No products found matching the current filters.',
              style: TextStyle(
                  color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
