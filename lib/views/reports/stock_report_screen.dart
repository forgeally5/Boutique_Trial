import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/pdf_report_generator.dart';
import '../../utils/excel_generator.dart';
import '../../widgets/report_export_dialog.dart';
import '../../widgets/searchable_dropdown.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  // Product-wise filters
  final _searchCtrl = TextEditingController();
  String _categoryFilter = 'All';
  String _statusFilter = 'All';

  // Category-wise Closing Stock filters
  final _catSearchCtrl = TextEditingController();
  String _catStatusFilter = 'All';
  final Set<String> _expandedCategories = {};

  bool _loading = false;

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _categoryClosingRows = [];
  List<Map<String, dynamic>> _filteredCategoryRows = [];
  List<String> _categories = ['All'];

  final _statusOptions = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
    'Damaged/Defective'
  ];

  final _catStatusOptions = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
    _catSearchCtrl.addListener(_applyCategoryFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _catSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('products').get();

      // Fetch sales from bills collection to compute total sold per product
      final billSnap =
          await FirebaseFirestore.instance.collection('bills').get();
      final Map<String, int> soldMap = {};
      for (final doc in billSnap.docs) {
        final data = doc.data();
        final billType = data['billType']?.toString() ?? 'Sale';
        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          final tagId = item['tagId']?.toString().trim() ?? '';
          final q = (item['qty'] as num?)?.toInt() ?? 0;
          if (tagId.isNotEmpty) {
            if (billType == 'Return') {
              soldMap[tagId] = (soldMap[tagId] ?? 0) - q;
            } else {
              soldMap[tagId] = (soldMap[tagId] ?? 0) + q;
            }
          }
        }
      }

      final rows = <Map<String, dynamic>>[];
      final catSet = <String>{};
      final Map<String, Map<String, dynamic>> catAgg = {};

      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;

        final tagId = data['tagId']?.toString().trim() ?? '';
        final balance = (data['quantity'] as num?)?.toInt() ?? 0;
        final issueQty = (data['issueQuantity'] as num?)?.toInt() ?? 0;
        final soldQty = (soldMap[tagId] ??
                (data['soldQuantity'] as num?)?.toInt() ??
                0)
            .clamp(0, 999999);
        final totalReceived = (data['totalQuantity'] as num?)?.toInt() ??
            (balance + issueQty + soldQty);

        final sp = (data['sellingPrice'] as num?)?.toDouble() ?? 0;
        final cat = (data['category']?.toString().trim().isNotEmpty ?? false)
            ? data['category'].toString().trim()
            : 'Uncategorized';
        catSet.add(cat);

        // 1. Good / Sellable Stock Row
        String status;
        if (balance == 0) {
          status = 'Out of Stock';
        } else if (balance > 0 && balance < 5) {
          status = 'Low Stock';
        } else {
          status = 'In Stock';
        }

        final goodStock = Map<String, dynamic>.from(data);
        goodStock['category'] = cat;
        goodStock['status'] = status;
        goodStock['totalReceived'] = totalReceived;
        goodStock['issueQty'] = issueQty;
        goodStock['soldQty'] = soldQty;
        goodStock['balance'] = balance;
        goodStock['stockValue'] = balance * sp;
        rows.add(goodStock);

        // Aggregate into Category-wise Closing Stock
        final entry = catAgg.putIfAbsent(cat, () {
          return {
            'category': cat,
            'skuCount': 0,
            'totalPurchased': 0,
            'totalIssued': 0,
            'totalSold': 0,
            'closingQty': 0,
            'closingValue': 0.0,
            'products': <Map<String, dynamic>>[],
          };
        });

        entry['skuCount'] = (entry['skuCount'] as int) + 1;
        entry['totalPurchased'] =
            (entry['totalPurchased'] as int) + totalReceived;
        entry['totalIssued'] = (entry['totalIssued'] as int) + issueQty;
        entry['totalSold'] = (entry['totalSold'] as int) + soldQty;
        entry['closingQty'] = (entry['closingQty'] as int) + balance;
        entry['closingValue'] =
            (entry['closingValue'] as double) + (balance * sp);
        (entry['products'] as List<Map<String, dynamic>>).add(goodStock);

        // 2. Defective Stock Row (displayed separately in product-wise if any pcs are defective/damaged)
        if (issueQty > 0) {
          final defectiveStock = Map<String, dynamic>.from(data);
          defectiveStock['category'] = cat;
          defectiveStock['name'] = '${data['name']} (Defective)';
          defectiveStock['quantity'] = issueQty;
          defectiveStock['totalReceived'] = issueQty;
          defectiveStock['issueQty'] = issueQty;
          defectiveStock['soldQty'] = 0;
          defectiveStock['balance'] = 0;
          defectiveStock['status'] = 'Damaged/Defective';
          defectiveStock['stockValue'] = issueQty * sp;
          rows.add(defectiveStock);
        }
      }

      // Finalize category rows with status & sort alphabetically
      final catRows = catAgg.values.map((e) {
        final closingQty = e['closingQty'] as int;
        String cStatus;
        if (closingQty <= 0) {
          cStatus = 'Out of Stock';
        } else if (closingQty < 10) {
          cStatus = 'Low Stock';
        } else {
          cStatus = 'In Stock';
        }
        e['status'] = cStatus;
        return e;
      }).toList()
        ..sort((a, b) =>
            (a['category'] as String).compareTo(b['category'] as String));

      final cats = ['All', ...catSet.toList()..sort()];

      setState(() {
        _allProducts = rows;
        _categoryClosingRows = catRows;
        _categories = cats;
        _loading = false;
      });
      _applyFilters();
      _applyCategoryFilters();
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
            r['category']?.toString() != _categoryFilter) {
          return false;
        }
        if (_statusFilter != 'All' &&
            r['status']?.toString() != _statusFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _applyCategoryFilters() {
    final q = _catSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredCategoryRows = _categoryClosingRows.where((r) {
        if (q.isNotEmpty) {
          final cat = r['category']?.toString().toLowerCase() ?? '';
          if (!cat.contains(q)) return false;
        }
        if (_catStatusFilter != 'All' &&
            r['status']?.toString() != _catStatusFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  // ── Product-wise Summary values ───────────────────────────────────────────
  double get _totalStockValue => _filtered.fold(
      0.0,
      (s, r) =>
          s +
          ((r['balance'] as num?)?.toDouble() ??
                  (r['quantity'] as num?)?.toDouble() ??
                  0) *
              ((r['sellingPrice'] as num?)?.toDouble() ?? 0));

  int get _totalPurchasedQty => _filtered.fold(
      0, (s, r) => s + ((r['totalReceived'] as num?)?.toInt() ?? 0));

  int get _totalIssuedQty =>
      _filtered.fold(0, (s, r) => s + ((r['issueQty'] as num?)?.toInt() ?? 0));

  int get _totalSoldQty =>
      _filtered.fold(0, (s, r) => s + ((r['soldQty'] as num?)?.toInt() ?? 0));

  int get _totalBalanceQty => _filtered.fold(
      0,
      (s, r) =>
          s +
          ((r['balance'] as num?)?.toInt() ??
              (r['quantity'] as num?)?.toInt() ??
              0));

  int get _lowStockCount =>
      _filtered.where((r) => r['status'] == 'Low Stock').length;

  int get _outOfStockCount =>
      _filtered.where((r) => r['status'] == 'Out of Stock').length;

  // ── Category-wise Closing Stock Summary values ────────────────────────────
  int get _catTotalSkus => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['skuCount'] as num?)?.toInt() ?? 0));

  int get _catTotalPurchased => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalPurchased'] as num?)?.toInt() ?? 0));

  int get _catTotalIssued => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalIssued'] as num?)?.toInt() ?? 0));

  int get _catTotalSold => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalSold'] as num?)?.toInt() ?? 0));

  int get _catTotalClosingQty => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['closingQty'] as num?)?.toInt() ?? 0));

  double get _catTotalClosingValue => _filteredCategoryRows.fold(
      0.0, (s, r) => s + ((r['closingValue'] as num?)?.toDouble() ?? 0.0));

  int get _catZeroStockCount =>
      _filteredCategoryRows.where((r) => (r['closingQty'] as int) <= 0).length;

  // ── Print / Download handlers (Product-wise) ──────────────────────────────
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
    await ReportExportDialog.show(
      context: context,
      title: 'Product-Wise Stock Report',
      onDownloadPdf: () async {
        final bytes = await generateStockReportPdf(
          rows: _filtered,
          categoryFilter: _categoryFilter,
          statusFilter: _statusFilter,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadProductStockReportExcel(
          rows: _filtered,
          categoryFilter: _categoryFilter,
          statusFilter: _statusFilter,
        );
      },
    );
  }

  // ── Print / Download handlers (Category-wise Closing Stock) ───────────────
  Future<void> _handleCatPrint() async {
    if (_filteredCategoryRows.isEmpty) {
      BoutiqueToast.showError(context, 'No closing stock data to print.');
      return;
    }
    final bytes = await generateCategoryClosingStockPdf(
      rows: _filteredCategoryRows,
      statusFilter: _catStatusFilter,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleCatDownload() async {
    if (_filteredCategoryRows.isEmpty) {
      BoutiqueToast.showError(context, 'No closing stock data to download.');
      return;
    }
    await ReportExportDialog.show(
      context: context,
      title: 'Closing Stock Report (Category-Wise)',
      onDownloadPdf: () async {
        final bytes = await generateCategoryClosingStockPdf(
          rows: _filteredCategoryRows,
          statusFilter: _catStatusFilter,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'closing_stock_category_wise_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadCategoryClosingStockExcel(
          rows: _filteredCategoryRows,
          statusFilter: _catStatusFilter,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allProducts.isNotEmpty && _categoryClosingRows.isEmpty && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryClosingRows.isEmpty && !_loading) {
          _load();
        }
      });
    }
    return DefaultTabController(
      length: 2,
      child: Container(
        color: BoutiqueColors.bgMain,
        child: Column(
          children: [
            // ── Sub-Tab Bar (Product-Wise vs Category-Wise Closing Stock) ──
            Container(
              decoration: const BoxDecoration(
                color: BoutiqueColors.bgCard,
                border: Border(
                  bottom: BorderSide(color: BoutiqueColors.border, width: 1),
                ),
              ),
              child: const TabBar(
                labelColor: BoutiqueColors.accent,
                unselectedLabelColor: BoutiqueColors.textSecondary,
                indicatorColor: BoutiqueColors.accent,
                indicatorWeight: 2.5,
                labelStyle:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list_alt_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Product-Wise Stock Report'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Closing Stock Report (Category-Wise)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Sub-Tab Views ──────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _buildProductWiseView(),
                  _buildCategoryWiseClosingView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: PRODUCT-WISE STOCK VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProductWiseView() {
    return Column(
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
                child: SearchableDropdownField(
                  label: 'Category',
                  value: _categoryFilter,
                  items: _categories,
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
                child: SearchableDropdownField(
                  label: 'Status',
                  value: _statusFilter,
                  items: _statusOptions,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _statusFilter = v);
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(Icons.inventory_2_outlined, 'Total Products',
                    '${_filtered.length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.shopping_bag_outlined, 'Total Purchased',
                    '$_totalPurchasedQty', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.assignment_return_outlined, 'Total Issued',
                    '$_totalIssuedQty', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.point_of_sale_rounded, 'Total Sold',
                    '$_totalSoldQty', BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.numbers_rounded, 'Balance Stock',
                    '$_totalBalanceQty', BoutiqueColors.gold),
                const SizedBox(width: 14),
                _summaryCard(
                    Icons.currency_rupee_rounded,
                    'Stock Value',
                    '₹${_numFmt.format(_totalStockValue)}',
                    BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.warning_amber_rounded, 'Low Stock',
                    '$_lowStockCount', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.remove_shopping_cart_rounded, 'Out of Stock',
                    '$_outOfStockCount', BoutiqueColors.destructive),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: BoutiqueColors.border),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filtered.isEmpty
                  ? _emptyState('No products found matching the current filters.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < 1450
                                  ? 1450
                                  : constraints.maxWidth,
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
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: CATEGORY-WISE CLOSING STOCK REPORT VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryWiseClosingView() {
    return Column(
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
              // Search Category
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _catSearchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(
                    hintText: 'Search category name…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: BoutiqueColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status Filter
              Expanded(
                flex: 2,
                child: SearchableDropdownField(
                  label: 'Closing Status',
                  value: _catStatusFilter,
                  items: _catStatusOptions,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _catStatusFilter = v);
                      _applyCategoryFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Expand/Collapse All button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    if (_expandedCategories.length ==
                        _filteredCategoryRows.length) {
                      _expandedCategories.clear();
                    } else {
                      _expandedCategories.addAll(_filteredCategoryRows
                          .map((e) => e['category'].toString()));
                    }
                  });
                },
                icon: Icon(
                  _expandedCategories.length == _filteredCategoryRows.length &&
                          _filteredCategoryRows.isNotEmpty
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 16,
                  color: BoutiqueColors.accent,
                ),
                label: Text(
                  _expandedCategories.length == _filteredCategoryRows.length &&
                          _filteredCategoryRows.isNotEmpty
                      ? 'Collapse All'
                      : 'Expand Products',
                  style: const TextStyle(
                      fontSize: 12,
                      color: BoutiqueColors.accent,
                      fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: BoutiqueColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
                onPressed: _handleCatPrint,
                tooltip: 'Print Closing Stock Report',
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined,
                    color: BoutiqueColors.accent),
                onPressed: _handleCatDownload,
                tooltip: 'Download Closing Stock PDF',
              ),
            ],
          ),
        ),

        // ── Category Summary KPI Cards ───────────────────────────────
        Container(
          color: BoutiqueColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(Icons.category_outlined, 'Total Categories',
                    '${_filteredCategoryRows.length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.qr_code_2_rounded, 'Total SKUs',
                    '$_catTotalSkus', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.shopping_bag_outlined, 'Opening / Purchased',
                    '$_catTotalPurchased', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.assignment_return_outlined, 'Issued / Defect',
                    '$_catTotalIssued', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.point_of_sale_rounded, 'Sold Qty',
                    '$_catTotalSold', BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.inventory_rounded, 'Closing Stock Qty',
                    '$_catTotalClosingQty', BoutiqueColors.gold),
                const SizedBox(width: 14),
                _summaryCard(
                    Icons.currency_rupee_rounded,
                    'Closing Stock Value',
                    '₹${_numFmt.format(_catTotalClosingValue)}',
                    BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.remove_shopping_cart_rounded,
                    'Zero-Stock Categories', '$_catZeroStockCount', BoutiqueColors.destructive),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: BoutiqueColors.border),

        // ── Category-Wise Table + Grand Total Footer ─────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filteredCategoryRows.isEmpty
                  ? _emptyState(
                      'No categories found matching the current filters.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < 1250
                                  ? 1250
                                  : constraints.maxWidth,
                              child: Column(
                                children: [
                                  _catTableHeader(),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _filteredCategoryRows.length,
                                      separatorBuilder: (_, _) => const Divider(
                                          height: 1,
                                          color: BoutiqueColors.borderLight),
                                      itemBuilder: (ctx, i) =>
                                          _catTableRow(_filteredCategoryRows[i], i),
                                    ),
                                  ),
                                  _catGrandTotalFooter(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _catTableHeader() {
    const cols = [
      'S.No',
      'Category Name',
      'Total Items (SKUs)',
      'Purchased Qty',
      'Issued Qty',
      'Sold Qty',
      'Closing Stock Qty',
      'Closing Value (₹)',
      'Stock Share (%)',
      'Status'
    ];
    const flexes = [1, 4, 2, 2, 2, 2, 2, 3, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: flexes[e.key],
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _catTableRow(Map<String, dynamic> r, int i) {
    final category = r['category']?.toString() ?? 'Uncategorized';
    final skuCount = (r['skuCount'] as num?)?.toInt() ?? 0;
    final totalPurchased = (r['totalPurchased'] as num?)?.toInt() ?? 0;
    final totalIssued = (r['totalIssued'] as num?)?.toInt() ?? 0;
    final totalSold = (r['totalSold'] as num?)?.toInt() ?? 0;
    final closingQty = (r['closingQty'] as num?)?.toInt() ?? 0;
    final closingValue = (r['closingValue'] as num?)?.toDouble() ?? 0.0;
    final status = r['status']?.toString() ?? 'In Stock';
    final products =
        (r['products'] as List<Map<String, dynamic>>?) ?? const [];

    final totalVal = _catTotalClosingValue;
    final sharePct = totalVal > 0 ? (closingValue / totalVal) * 100 : 0.0;
    final isExpanded = _expandedCategories.contains(category);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category);
              } else {
                _expandedCategories.add(category);
              }
            });
          },
          child: Container(
            color: isExpanded
                ? BoutiqueColors.accentSoft.withValues(alpha: 0.35)
                : (isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('${i + 1}'),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: BoutiqueColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _cell(
                            category,
                            color: BoutiqueColors.accent,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('$skuCount Items', bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('$totalPurchased',
                        color: BoutiqueColors.accent, bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$totalIssued',
                      color: totalIssued > 0
                          ? BoutiqueColors.warning
                          : BoutiqueColors.textSecondary,
                      bold: totalIssued > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$totalSold',
                      color: totalSold > 0
                          ? BoutiqueColors.success
                          : BoutiqueColors.textSecondary,
                      bold: totalSold > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$closingQty',
                      color: closingQty == 0
                          ? BoutiqueColors.destructive
                          : closingQty < 10
                              ? BoutiqueColors.warning
                              : BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '₹${_numFmt.format(closingValue)}',
                      color: BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (sharePct / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: BoutiqueColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  BoutiqueColors.accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${sharePct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BoutiqueColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Expanded Drill-Down Product Rows inside this Category ─────────
        if (isExpanded && products.isNotEmpty)
          Container(
            color: BoutiqueColors.bgMain.withValues(alpha: 0.6),
            padding:
                const EdgeInsets.only(left: 44, right: 20, top: 8, bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: BoutiqueColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BoutiqueColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: BoutiqueColors.bgSecondary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Tag ID',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 4,
                            child: Text('Product Name',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Purchased',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Issued',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sold',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Closing Qty',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 1,
                            child: Text('Unit',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sell Price (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Closing Value (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                      ],
                    ),
                  ),
                  ...products.asMap().entries.map((pe) {
                    final p = pe.value;
                    final bal = (p['balance'] as num?)?.toInt() ?? 0;
                    final sp = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: pe.key.isOdd
                            ? BoutiqueColors.bgSubtle
                            : BoutiqueColors.bgCard,
                        border: const Border(
                          top: BorderSide(color: BoutiqueColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: _cell(p['tagId']?.toString() ?? '—',
                                  color: BoutiqueColors.accent, bold: true)),
                          Expanded(
                              flex: 4,
                              child: _cell(p['name']?.toString() ?? '—')),
                          Expanded(
                              flex: 2,
                              child: _cell('${p['totalReceived'] ?? 0}')),
                          Expanded(
                              flex: 2, child: _cell('${p['issueQty'] ?? 0}')),
                          Expanded(
                              flex: 2, child: _cell('${p['soldQty'] ?? 0}')),
                          Expanded(
                              flex: 2,
                              child: _cell('$bal',
                                  color: bal == 0
                                      ? BoutiqueColors.destructive
                                      : BoutiqueColors.textPrimary,
                                  bold: true)),
                          Expanded(
                              flex: 1,
                              child: _cell(p['unit']?.toString() ?? '—')),
                          Expanded(
                              flex: 2, child: _cell('₹${_numFmt.format(sp)}')),
                          Expanded(
                              flex: 2,
                              child: _cell('₹${_numFmt.format(bal * sp)}',
                                  bold: true)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _catGrandTotalFooter() {
    const flexes = [1, 4, 2, 2, 2, 2, 2, 3, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        border: Border(
          top: BorderSide(color: BoutiqueColors.border, width: 1.5),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(flex: flexes[0], child: const SizedBox()),
          Expanded(
            flex: flexes[1],
            child: const Text(
              'GRAND TOTAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            flex: flexes[2],
            child: _cell('$_catTotalSkus Items', bold: true),
          ),
          Expanded(
            flex: flexes[3],
            child: _cell('$_catTotalPurchased',
                color: BoutiqueColors.accent, bold: true),
          ),
          Expanded(
            flex: flexes[4],
            child: _cell('$_catTotalIssued',
                color: BoutiqueColors.warning, bold: true),
          ),
          Expanded(
            flex: flexes[5],
            child: _cell('$_catTotalSold',
                color: BoutiqueColors.success, bold: true),
          ),
          Expanded(
            flex: flexes[6],
            child: _cell('$_catTotalClosingQty',
                color: BoutiqueColors.accent, bold: true),
          ),
          Expanded(
            flex: flexes[7],
            child: Text(
              '₹${_numFmt.format(_catTotalClosingValue)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.success,
              ),
            ),
          ),
          Expanded(
            flex: flexes[8],
            child: _cell('100.0%', bold: true),
          ),
          Expanded(flex: flexes[9], child: const SizedBox()),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCT-WISE TABLE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _tableHeader() {
    const cols = [
      'S.No',
      'Tag ID',
      'Product Name',
      'Category',
      'Total Purchased',
      'Issued Qty',
      'Sold Qty',
      'Balance Qty',
      'Unit',
      'MRP (₹)',
      'Sell Price (₹)',
      'Stock Value (₹)',
      'Status'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: _flex(e.key),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _flex(int idx) {
    const flexes = [1, 2, 4, 3, 2, 2, 2, 2, 1, 2, 2, 2, 2];
    return flexes[idx];
  }

  Widget _tableRow(Map<String, dynamic> r, int i) {
    final totalReceived = (r['totalReceived'] as num?)?.toInt() ?? 0;
    final issueQty = (r['issueQty'] as num?)?.toInt() ?? 0;
    final soldQty = (r['soldQty'] as num?)?.toInt() ?? 0;
    final balance = (r['balance'] as num?)?.toInt() ??
        (r['quantity'] as num?)?.toInt() ??
        0;
    final sp = (r['sellingPrice'] as num?)?.toDouble() ?? 0;
    final stockVal = balance * sp;
    final status = r['status']?.toString() ?? 'In Stock';
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
      case 'Damaged/Defective':
      case 'Damaged':
      case 'Defective':
        statusColor = const Color(0xFFC0392B);
        statusBg = const Color(0xFFFFEBEE);
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
          Expanded(
              flex: 1,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('${i + 1}'))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell(r['tagId']?.toString() ?? '—',
                      color: BoutiqueColors.accent, bold: true))),
          Expanded(
              flex: 4,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell(r['name']?.toString() ?? '—', bold: true))),
          Expanded(
              flex: 3,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell(r['category']?.toString() ?? '—'))),
          // 4 breakdown columns
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('$totalReceived',
                      color: BoutiqueColors.accent, bold: true))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('$issueQty',
                      color: issueQty > 0
                          ? BoutiqueColors.warning
                          : BoutiqueColors.textSecondary,
                      bold: issueQty > 0))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('$soldQty',
                      color: soldQty > 0
                          ? BoutiqueColors.success
                          : BoutiqueColors.textSecondary,
                      bold: soldQty > 0))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('$balance',
                      color: balance == 0
                          ? BoutiqueColors.destructive
                          : balance < 5
                              ? BoutiqueColors.warning
                              : BoutiqueColors.textPrimary,
                      bold: true))),
          Expanded(
              flex: 1,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell(r['unit']?.toString() ?? '—'))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell(
                      '₹${_numFmt.format((r['mrp'] as num?)?.toDouble() ?? 0)}'))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('₹${_numFmt.format(sp)}'))),
          Expanded(
              flex: 2,
              child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _cell('₹${_numFmt.format(stockVal)}',
                      color: BoutiqueColors.textPrimary, bold: true))),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              Text(label, style: TextStyle(fontSize: 10, color: color)),
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

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 52, color: BoutiqueColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
