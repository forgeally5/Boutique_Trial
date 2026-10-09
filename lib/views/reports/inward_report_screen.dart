import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/excel_generator.dart';
import 'package:intl/intl.dart';

class InwardReportScreen extends StatefulWidget {
  const InwardReportScreen({super.key});

  @override
  State<InwardReportScreen> createState() => _InwardReportScreenState();
}

class _InwardReportScreenState extends State<InwardReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inwardTransactions = [];
  List<Map<String, dynamic>> _filtered = [];
  String _error = '';

  DateTime? _startDate;
  DateTime? _endDate;

  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _fetchInwardTransactions();
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
      return true;
    }).toList();
    setState(() => _isLoading = false);
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
    // Generate Excel logic
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
        content: const Text('Are you sure you want to delete all inward transaction records? This cannot be undone.'),
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
      _fetchInwardTransactions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All inward records cleared.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear records: $e')));
      setState(() => _isLoading = false);
    }
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: BoutiqueColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: BoutiqueColors.textSecondary, fontSize: 16)),
        ],
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
          Expanded(flex: 3, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary))),
          Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary))),
          Expanded(flex: 2, child: Text('Added Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> itemData, DateTime date) {
    final addedQty = (itemData['qty'] as num?)?.toInt() ?? 0;
    final addedWeight = (itemData['weight'] as num?)?.toDouble() ?? 0.0;

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
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(date),
              style: const TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemData['name']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: BoutiqueColors.textPrimary),
                ),
                Text(
                  itemData['tagId']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              itemData['category']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  displayAdded,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Date Filter
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: BoutiqueColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: BoutiqueColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                            : 'Filter by Date',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
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
              // Download Actions
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onPressed: _handleClearAll,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: BoutiqueColors.accent),
                onPressed: _fetchInwardTransactions,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.table_view_rounded, color: Color(0xFF1E7E34)),
                onPressed: _handleDownloadExcel,
                tooltip: 'Download Excel',
              ),
            ],
          ),
        ),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filtered.isEmpty
                  ? _emptyState('No inward transactions found for the selected date range.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Flatten transactions into a list of items for the table
                          final flatItems = <Map<String, dynamic>>[];
                          for (final bill in _filtered) {
                            final date = DateTime.tryParse(bill['billDate'] ?? '') ?? DateTime.now();
                            final items = bill['items'] as List<dynamic>? ?? [];
                            for (final item in items) {
                              flatItems.add({
                                'date': date,
                                'itemData': item,
                              });
                            }
                          }

                          if (flatItems.isEmpty) {
                            return _emptyState('No items found in these transactions.');
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
                              child: Column(
                                children: [
                                  _tableHeader(),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: flatItems.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                      itemBuilder: (ctx, i) {
                                        final entry = flatItems[i];
                                        return _tableRow(entry['itemData'], entry['date'] as DateTime);
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
