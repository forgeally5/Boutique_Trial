import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/excel_generator.dart';
import 'package:intl/intl.dart';
import '../../widgets/report_filter_widgets.dart';

class InwardReportScreen extends StatefulWidget {
  final FocusNode? searchFocusNode;
  const InwardReportScreen({super.key, this.searchFocusNode});

  @override
  State<InwardReportScreen> createState() => InwardReportScreenState();
}

class InwardReportScreenState extends State<InwardReportScreen> {
  final _currencyFmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _searchCtrl = TextEditingController();
  late FocusNode _searchFocusNode;
  bool _ownSearchFocusNode = false;

  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _inwardTransactions = [];
  List<Map<String, dynamic>> _filtered = [];
  String _error = '';

  late DateTime _startDate;
  late DateTime _endDate;
  String _searchQuery = '';

  Future<void> refresh() async => _fetchInwardTransactions();

  @override
  void initState() {
    super.initState();
    if (widget.searchFocusNode != null) {
      _searchFocusNode = widget.searchFocusNode!;
    } else {
      _searchFocusNode = FocusNode(debugLabel: 'inward_report_search');
      _ownSearchFocusNode = true;
    }
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    _startDate = fyStart;
    _endDate = now;
    _fetchInwardTransactions();
    if (widget.searchFocusNode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _startDate : _endDate;
    final picked = await showBoutiqueDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _startDate = picked : _endDate = picked);
      _applyFilters();
    }
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
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      if (bDate.isBefore(start)) return false;
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      if (bDate.isAfter(end)) return false;

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

  void _showProductInwardHistoryDialog(Map<String, dynamic> itemData) {
    final targetTag = itemData['tagId']?.toString().trim() ?? '';
    final targetName = itemData['name']?.toString().trim() ?? '';
    final category = itemData['category']?.toString().trim() ?? '-';

    final List<Map<String, dynamic>> productHistory = [];

    for (final bill in _inwardTransactions) {
      final bDate = DateTime.tryParse(bill['billDate'] ?? '') ?? DateTime.now();
      final narration = bill['narration']?.toString() ?? 'Stock Inward';
      final items = bill['items'] as List<dynamic>? ?? [];

      for (final it in items) {
        if (it is! Map) continue;
        final itTag = it['tagId']?.toString().trim() ?? '';
        final itName = it['name']?.toString().trim() ?? '';

        final matches = (targetTag.isNotEmpty && itTag.toLowerCase() == targetTag.toLowerCase()) ||
            (targetTag.isEmpty && itName.toLowerCase() == targetName.toLowerCase());

        if (matches) {
          final billDateParsed = DateTime.tryParse(bill['billDate']?.toString() ?? '');
          final itemDate = billDateParsed ??
              (it['addedDate'] != null
                  ? (DateTime.tryParse(it['addedDate'].toString()) ?? bDate)
                  : bDate);

          productHistory.add({
            'date': itemDate,
            'narration': narration,
            'itemData': it,
          });
        }
      }
    }

    productHistory.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _ProductInwardHistoryDialog(
        productName: targetName,
        tagId: targetTag,
        category: category,
        historyRows: productHistory,
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
    var amount = (itemData['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0 && rate > 0) {
      amount = addedWeight > 0 ? (rate * addedWeight) : (rate * addedQty);
    }

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
            child: InkWell(
              onTap: () => _showProductInwardHistoryDialog(itemData),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            itemData['name']?.toString() ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: BoutiqueColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'View complete inward history & download Excel',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: BoutiqueColors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: BoutiqueColors.accentLightBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 11, color: BoutiqueColors.accent),
                                SizedBox(width: 3),
                                Text(
                                  'History',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
        var amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt <= 0 && rate > 0) {
          amt = weight > 0 ? (rate * weight) : (rate * qty);
        }

        totalInwardUnits += qty;
        totalInwardWeight += weight;
        totalInwardValue += amt;

        final billDateParsed = DateTime.tryParse(bill['billDate']?.toString() ?? '');
        final itemDate = billDateParsed ??
            (item['addedDate'] != null
                ? (DateTime.tryParse(item['addedDate'].toString()) ?? date)
                : date);

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

              // Date From
              ReportDatePill(
                label: 'From',
                dt: _startDate,
                order: 6.0,
                fmt: DateFormat('dd/MM/yyyy'),
                onTap: () => _pickDate(isFrom: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→',
                    style: TextStyle(color: BoutiqueColors.textSecondary)),
              ),
              // Date To
              ReportDatePill(
                label: 'To',
                dt: _endDate,
                order: 7.0,
                fmt: DateFormat('dd/MM/yyyy'),
                onTap: () => _pickDate(isFrom: false),
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
              Tooltip(
                message: 'Refresh Inward Data (Alt+4)',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, color: BoutiqueColors.accent, size: 16),
                  label: const Text('Refresh', style: TextStyle(color: BoutiqueColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: BoutiqueColors.bgCard,
                    side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _fetchInwardTransactions,
                ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// PRODUCT INWARD HISTORY DIALOG WITH EXCEL EXPORT & ESC KEY SUPPORT
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductInwardHistoryDialog extends StatelessWidget {
  final String productName;
  final String tagId;
  final String category;
  final List<Map<String, dynamic>> historyRows;

  const _ProductInwardHistoryDialog({
    required this.productName,
    required this.tagId,
    required this.category,
    required this.historyRows,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##,##0.00', 'en_IN');
    final dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

    int totalQty = 0;
    double totalWeight = 0.0;
    double totalValue = 0.0;

    for (final r in historyRows) {
      final item = r['itemData'] as Map<String, dynamic>? ?? r;
      final q = (item['qty'] as num?)?.toInt() ?? 0;
      final w = (item['weight'] as num?)?.toDouble() ?? 0.0;
      final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
      var amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0 && rate > 0) {
        amt = w > 0 ? (rate * w) : (rate * q);
      }
      totalQty += q;
      totalWeight += w;
      totalValue += amt;
    }

    return FocusScope(
      autofocus: true,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            width: 880,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: BoutiqueColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BoutiqueColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    color: BoutiqueColors.bgSecondary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BoutiqueColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded, color: BoutiqueColors.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    productName.isEmpty ? 'Product Inward History' : productName,
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: BoutiqueColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (tagId.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BoutiqueColors.accentSoft,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: BoutiqueColors.accentLightBorder),
                                    ),
                                    child: Text(
                                      tagId,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: BoutiqueColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Category: $category • Complete date & time breakdown of every inward addition',
                              style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Download Excel Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.file_download_rounded, size: 16),
                        label: const Text('Export Excel (.xlsx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await ExcelGenerator.downloadProductInwardHistoryExcel(
                            productName: productName,
                            tagId: tagId,
                            category: category,
                            historyRows: historyRows,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                        tooltip: 'Close (Esc)',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ── Stat Summary Cards ────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: BoutiqueColors.bgMain,
                    border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      _dialogStatCard(
                        icon: Icons.layers_rounded,
                        label: 'Total Batches',
                        value: '${historyRows.length} entries',
                        color: BoutiqueColors.accent,
                      ),
                      const SizedBox(width: 12),
                      _dialogStatCard(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Total Qty Inwarded',
                        value: '$totalQty pcs',
                        color: Colors.green,
                      ),
                      if (totalWeight > 0) ...[
                        const SizedBox(width: 12),
                        _dialogStatCard(
                          icon: Icons.scale_rounded,
                          label: 'Total Weight',
                          value: '${totalWeight.toStringAsFixed(1)}g',
                          color: Colors.teal,
                        ),
                      ],
                      const SizedBox(width: 12),
                      _dialogStatCard(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Total Inward Value',
                        value: '₹ ${currencyFmt.format(totalValue)}',
                        color: BoutiqueColors.textPrimary,
                      ),
                    ],
                  ),
                ),

                // ── Table Header ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  color: BoutiqueColors.bgSecondary,
                  child: const Row(
                    children: [
                      SizedBox(width: 40, child: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary))),
                      Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary))),
                      Expanded(flex: 3, child: Text('Inward Source / Narration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary))),
                      Expanded(flex: 2, child: Text('Added Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Unit Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Total Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
                    ],
                  ),
                ),

                // ── History List ──────────────────────────────────────
                Expanded(
                  child: historyRows.isEmpty
                      ? const Center(
                          child: Text('No inward batches found for this product.', style: TextStyle(color: BoutiqueColors.textSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: historyRows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                          itemBuilder: (ctx, i) {
                            final row = historyRows[i];
                            final dt = row['date'] as DateTime;
                            final narration = row['narration']?.toString() ?? 'Stock Inward';
                            final item = row['itemData'] as Map<String, dynamic>? ?? row;
                            final q = (item['qty'] as num?)?.toInt() ?? 0;
                            final w = (item['weight'] as num?)?.toDouble() ?? 0.0;
                            final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                            var amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                            if (amt <= 0 && rate > 0) {
                              amt = w > 0 ? (rate * w) : (rate * q);
                            }

                            final addedStr = w > 0 && q > 0
                                ? '+$q pcs | +${w}g'
                                : w > 0
                                    ? '+${w}g'
                                    : '+$q pcs';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              color: i % 2 == 1 ? BoutiqueColors.bgMain.withValues(alpha: 0.5) : Colors.transparent,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      dateTimeFmt.format(dt),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BoutiqueColors.textPrimary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: BoutiqueColors.bgSecondary,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: BoutiqueColors.border),
                                      ),
                                      child: Text(
                                        narration,
                                        style: const TextStyle(fontSize: 11, color: BoutiqueColors.textPrimary, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      addedStr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      rate > 0 ? '₹${rate == rate.toInt() ? rate.toInt() : rate.toStringAsFixed(1)}' : '-',
                                      style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      amt > 0 ? '₹ ${currencyFmt.format(amt)}' : '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BoutiqueColors.textPrimary),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // ── Dialog Footer ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: BoutiqueColors.bgSecondary,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: BoutiqueColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Press Esc or click Close to exit',
                        style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BoutiqueColors.textPrimary,
                          side: const BorderSide(color: BoutiqueColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _dialogStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: BoutiqueColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BoutiqueColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: BoutiqueColors.textSecondary)),
                  Text(
                    value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
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
}
