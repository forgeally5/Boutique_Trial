import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/excel_generator.dart';
import 'package:intl/intl.dart';

class InwardReportScreen extends StatefulWidget {
  final FocusNode? searchFocusNode;
  const InwardReportScreen({super.key, this.searchFocusNode});

  @override
  State<InwardReportScreen> createState() => _InwardReportScreenState();
}

class _InwardReportScreenState extends State<InwardReportScreen> {
  final _currencyFmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _searchCtrl = TextEditingController();
  late FocusNode _searchFocusNode;
  bool _ownSearchFocusNode = false;

  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _inwardTransactions = [];
  List<Map<String, dynamic>> _filtered = [];
  String _error = '';

  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.searchFocusNode != null) {
      _searchFocusNode = widget.searchFocusNode!;
    } else {
      _searchFocusNode = FocusNode(debugLabel: 'inward_report_search');
      _ownSearchFocusNode = true;
    }
    _fetchInwardTransactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_ownSearchFocusNode) {
      _searchFocusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInwardTransactions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final bills = await ApiService().getBills();
      final inwardBills = bills.where((b) => b['billType'] == 'Inward').toList();

      // Sort by date descending
      inwardBills.sort((a, b) {
        final dateA = DateTime.tryParse(a['billDate'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['billDate'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      _inwardTransactions = inwardBills;
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = 'Failed to load inward report: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filtered = _inwardTransactions.where((bill) {
      final bDate = DateTime.tryParse(bill['billDate'] ?? '') ?? DateTime.now();
      if (_startDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 0, 0, 0);
        if (bDate.isBefore(start)) return false;
      }
      if (_endDate != null) {
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (bDate.isAfter(end)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final narration = (bill['narration'] ?? '').toString().toLowerCase();
        final billNo = (bill['billNo'] ?? '').toString().toLowerCase();
        final items = bill['items'] as List<dynamic>? ?? [];

        final matchesItem = items.any((it) {
          if (it is! Map) return false;
          final name = (it['name'] ?? '').toString().toLowerCase();
          final tagId = (it['tagId'] ?? '').toString().toLowerCase();
          final category = (it['category'] ?? '').toString().toLowerCase();
          return name.contains(q) || tagId.contains(q) || category.contains(q);
        });

        if (!matchesItem && !narration.contains(q) && !billNo.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() => _isLoading = false);
  }

  Future<void> _syncExistingInventory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sync_rounded, color: BoutiqueColors.accent),
            SizedBox(width: 8),
            Text('Sync Inventory to Inward Report'),
          ],
        ),
        content: const Text(
          'This will scan all inventory products in the database and create Inward Report records for any products that do not have an inward entry yet.\n\nAll historical and client-added stock will be permanently linked and visible in the report across all devices. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BoutiqueColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);
    try {
      final products = await ApiService().getProducts();

      // Collect all tagIds that already appear in any inward bill
      final existingTagIds = <String>{};
      for (final bill in _inwardTransactions) {
        final items = bill['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is Map && item['tagId'] != null) {
            existingTagIds.add(item['tagId'].toString().trim().toUpperCase());
          }
        }
      }

      // Products with positive stock that haven't been logged in inward
      final missingProducts = products.where((p) {
        final tag = p.tagId.trim().toUpperCase();
        return !existingTagIds.contains(tag) && (p.quantity > 0 || p.grossWeight > 0);
      }).toList();

      if (missingProducts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All inventory products are already recorded in the Inward Report!')),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      // Group missing products by their original added_date
      final Map<String, List<Product>> byDate = {};
      for (final p in missingProducts) {
        final dateKey = p.addedDate != null ? p.addedDate!.toIso8601String() : DateTime.now().toIso8601String();
        byDate.putIfAbsent(dateKey, () => []).add(p);
      }

      for (final entry in byDate.entries) {
        final d = DateTime.tryParse(entry.key) ?? DateTime.now();
        final itemsList = entry.value;
        const int chunkSize = 50;
        for (int i = 0; i < itemsList.length; i += chunkSize) {
          final chunk = itemsList.sublist(
            i,
            i + chunkSize > itemsList.length ? itemsList.length : i + chunkSize,
          );
          final items = chunk.map((p) {
            final isWeight = p.pricingType == 'Weight-Based';
            final qty = isWeight ? (p.quantity > 0 ? p.quantity : 1) : p.quantity;
            return ApiService().createInwardItemMap(
              product: p,
              addedQty: qty,
              addedWeight: p.grossWeight,
              oldQty: 0,
              newQty: p.quantity,
              oldWeight: 0.0,
              newWeight: p.grossWeight,
              addedDate: p.addedDate,
            );
          }).toList();

          await ApiService().recordInwardBill(
            items: items,
            narration: 'Inventory Stock Sync (Catalog)',
            date: d,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully synced ${missingProducts.length} inventory products to Inward Report!')),
        );
      }
      await _fetchInwardTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync inventory: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: BoutiqueColors.accent),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  Future<void> _handleDownloadExcel() async {
    try {
      await ExcelGenerator.downloadInwardReportExcel(transactions: _filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  Future<void> _handleClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Inward Records'),
        content: const Text('Are you sure you want to delete all inward transaction records from the database? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      for (final bill in _inwardTransactions) {
        if (bill['docId'] != null) {
          await ApiService().deleteBill(bill['docId']);
        }
      }
      await _fetchInwardTransactions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All inward records cleared.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear records: $e')));
      setState(() => _isLoading = false);
    }
  }

  Widget _emptyState(String msg, {bool showSyncButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: BoutiqueColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              msg,
              style: const TextStyle(color: BoutiqueColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (showSyncButton) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _syncExistingInventory,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Sync Current Inventory to Inward Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BoutiqueColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BoutiqueColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary))),
          Expanded(flex: 3, child: Text('Item Name & Tag ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary))),
          Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary))),
          Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('Added Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('Total Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> itemData, DateTime date, String narration) {
    final addedQty = (itemData['qty'] as num?)?.toInt() ?? 0;
    final addedWeight = (itemData['weight'] as num?)?.toDouble() ?? 0.0;
    final rate = (itemData['rate'] as num?)?.toDouble() ?? 0.0;
    final amount = (itemData['amount'] as num?)?.toDouble() ?? 0.0;

    String formatAdded(num? q, num? w) {
      final parts = <String>[];
      if (q != null && q > 0) parts.add('+${q.toInt()} Qty');
      if (w != null && w > 0) parts.add('+${w.toDouble()}g');
      if (parts.isEmpty) return '-';
      return parts.join(' | ');
    }

    final displayAdded = formatAdded(addedQty, addedWeight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Date & Time
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(date),
              style: const TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary),
            ),
          ),
          // Name & Tag ID
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemData['name']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: BoutiqueColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BoutiqueColors.bgSecondary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: BoutiqueColors.border),
                      ),
                      child: Text(
                        itemData['tagId']?.toString() ?? '',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: BoutiqueColors.accent),
                      ),
                    ),
                    if (narration.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• $narration',
                        style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Category
          Expanded(
            flex: 2,
            child: Text(
              itemData['category']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
            ),
          ),
          // Rate
          Expanded(
            flex: 1,
            child: Text(
              rate > 0 ? '₹${rate == rate.toInt() ? rate.toInt() : rate.toStringAsFixed(1)}' : '-',
              style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          // Added Stock
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  displayAdded,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                ),
              ),
            ),
          ),
          // Total Value
          Expanded(
            flex: 2,
            child: Text(
              amount > 0 ? '₹ ${_currencyFmt.format(amount)}' : '-',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: BoutiqueColors.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Flatten transactions into a list of items for the table
    final flatItems = <Map<String, dynamic>>[];
    int totalInwardUnits = 0;
    double totalInwardWeight = 0.0;
    double totalInwardValue = 0.0;

    for (final bill in _filtered) {
      final date = DateTime.tryParse(bill['billDate'] ?? '') ?? DateTime.now();
      final narration = bill['narration']?.toString() ?? 'Stock Inward';
      final items = bill['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString();
        final tagId = (item['tagId'] ?? '').toString();
        final cat = (item['category'] ?? '').toString();

        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          if (!name.toLowerCase().contains(q) &&
              !tagId.toLowerCase().contains(q) &&
              !cat.toLowerCase().contains(q) &&
              !narration.toLowerCase().contains(q)) {
            continue;
          }
        }

        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
        final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;

        totalInwardUnits += qty;
        totalInwardWeight += weight;
        totalInwardValue += amt;

        final itemDate = item['addedDate'] != null
            ? (DateTime.tryParse(item['addedDate'].toString()) ?? date)
            : date;

        flatItems.add({
          'date': itemDate,
          'narration': narration,
          'itemData': item,
        });
      }
    }

    // Sort items by exact date & time descending
    flatItems.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    final totalStockString = totalInwardWeight > 0 && totalInwardUnits > 0
        ? '$totalInwardUnits pcs | ${totalInwardWeight.toStringAsFixed(1)}g'
        : totalInwardWeight > 0
            ? '${totalInwardWeight.toStringAsFixed(1)}g'
            : '$totalInwardUnits pcs';

    return Column(
      children: [
        // ── Filter Bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
          ),
          child: Row(
            children: [
              // Search Input
              SizedBox(
                width: 260,
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by item name, tag, category...',
                    hintStyle: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 18, color: BoutiqueColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: BoutiqueColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: BoutiqueColors.border),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Date Filter Button
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: BoutiqueColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: BoutiqueColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                            : 'Filter by Date',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BoutiqueColors.textPrimary),
                      ),
                      if (_startDate != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _clearDateFilter,
                          child: const Icon(Icons.close, size: 16, color: BoutiqueColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Sync Inventory (Subtle icon button)
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BoutiqueColors.accent))
                    : const Icon(Icons.sync_rounded, color: BoutiqueColors.accent),
                onPressed: _isSyncing ? null : _syncExistingInventory,
                tooltip: 'Sync Inventory Stock to Inward Report',
              ),
              const SizedBox(width: 4),

              // Clear All
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _handleClearAll,
              ),
              const SizedBox(width: 6),

              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: BoutiqueColors.accent),
                onPressed: _fetchInwardTransactions,
                tooltip: 'Refresh',
              ),

              // Download Excel
              IconButton(
                icon: const Icon(Icons.table_view_rounded, color: Color(0xFF1E7E34)),
                onPressed: _handleDownloadExcel,
                tooltip: 'Download Excel',
              ),
            ],
          ),
        ),

        // ── Summary Cards ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              _buildSummaryCard(
                'Total Inward Batches',
                '${_filtered.length}',
                Icons.receipt_long_rounded,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Total Stock Added',
                totalStockString,
                Icons.add_box_rounded,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildSummaryCard(
                'Total Inward Value',
                '₹ ${_currencyFmt.format(totalInwardValue)}',
                Icons.currency_rupee_rounded,
                BoutiqueColors.accent,
              ),
            ],
          ),
        ),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
              : _error.isNotEmpty
                  ? _emptyState(_error)
                  : _inwardTransactions.isEmpty
                      ? _emptyState(
                          'No inward transactions found.\nClick below to sync your current inventory catalog to the Inward Report.',
                          showSyncButton: true,
                        )
                  : flatItems.isEmpty
                      ? _emptyState('No inward transactions match your filter criteria.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < 950 ? 950 : constraints.maxWidth,
                              child: Column(
                                children: [
                                  _tableHeader(),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: flatItems.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                      itemBuilder: (ctx, i) {
                                        final entry = flatItems[i];
                                        return _tableRow(
                                          entry['itemData'] as Map<String, dynamic>,
                                          entry['date'] as DateTime,
                                          entry['narration'] as String,
                                        );
                                      },
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
}
