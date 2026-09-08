import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_reports_dummy_data.dart';
import 'widgets/stock_summary_card.dart';
import 'widgets/erp_data_table.dart';

class TagWiseStockReportView extends StatefulWidget {
  final List<TagWiseStockItem> items;

  const TagWiseStockReportView({super.key, required this.items});

  @override
  State<TagWiseStockReportView> createState() => _TagWiseStockReportViewState();
}

class _TagWiseStockReportViewState extends State<TagWiseStockReportView> {
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedCounter = 'All Counters';
  String _selectedStatus = 'All Statuses';

  String _sortColumnKey = 'tagNumber';
  bool _isAscending = true;

  final numberFormat = NumberFormat('#,##0.00', 'en_US');

  List<TagWiseStockItem> get filteredItems {
    return widget.items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.tagNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.itemName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All Categories' || item.category == _selectedCategory;
      final matchesCounter =
          _selectedCounter == 'All Counters' || item.counter == _selectedCounter;
      final matchesStatus =
          _selectedStatus == 'All Statuses' || item.status == _selectedStatus;

      return matchesSearch && matchesCategory && matchesCounter && matchesStatus;
    }).toList()
      ..sort((a, b) {
        int cmp = 0;
        switch (_sortColumnKey) {
          case 'tagNumber':
            cmp = a.tagNumber.compareTo(b.tagNumber);
            break;
          case 'barcode':
            cmp = a.barcode.compareTo(b.barcode);
            break;
          case 'itemName':
            cmp = a.itemName.compareTo(b.itemName);
            break;
          case 'grossWeight':
            cmp = a.grossWeight.compareTo(b.grossWeight);
            break;
          case 'netWeight':
            cmp = a.netWeight.compareTo(b.netWeight);
            break;
          case 'purity':
            cmp = a.purity.compareTo(b.purity);
            break;
          case 'status':
            cmp = a.status.compareTo(b.status);
            break;
          case 'counter':
            cmp = a.counter.compareTo(b.counter);
            break;
        }
        return _isAscending ? cmp : -cmp;
      });
  }

  void _handleSort(String columnKey) {
    setState(() {
      if (_sortColumnKey == columnKey) {
        _isAscending = !_isAscending;
      } else {
        _sortColumnKey = columnKey;
        _isAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = filteredItems;

    final int totalTags = displayItems.length;
    final int availableCount = displayItems.where((e) => e.status == 'Available').length;
    final int soldCount = displayItems.where((e) => e.status == 'Sold').length;
    final int reservedCount = displayItems.where((e) => e.status == 'Reserved').length;
    final int activeTags = availableCount + reservedCount;

    double totalGross = 0.0;
    double totalNet = 0.0;
    for (final item in displayItems) {
      totalGross += item.grossWeight;
      totalNet += item.netWeight;
    }


    final columns = const [
      ErpTableColumn(title: 'Tag Number', key: 'tagNumber', width: 130),
      ErpTableColumn(title: 'Barcode', key: 'barcode', width: 130),
      ErpTableColumn(title: 'Item Name', key: 'itemName', width: 190),
      ErpTableColumn(title: 'Purity', key: 'purity', width: 120),
      ErpTableColumn(title: 'Gross Wt (g)', key: 'grossWeight', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Net Wt (g)', key: 'netWeight', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Status', key: 'status', width: 110),
      ErpTableColumn(title: 'Counter', key: 'counter', width: 160),
    ];

    final rows = displayItems.map((item) {
      return {
        'tagNumber': item.tagNumber,
        'barcode': item.barcode,
        'itemName': item.itemName,
        'purity': item.purity,
        'grossWeight': '${numberFormat.format(item.grossWeight)} g',
        'netWeight': '${numberFormat.format(item.netWeight)} g',
        'status': item.status,
        'counter': item.counter,
      };
    }).toList();

    final footerTotals = {
      'tagNumber': 'TOTAL ($totalTags Tags)',
      'barcode': '',
      'itemName': '',
      'purity': '',
      'grossWeight': '${numberFormat.format(totalGross)} g',
      'netWeight': '${numberFormat.format(totalNet)} g',
      'status': '',
      'counter': '',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Summary Cards ───────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 4 ? 2.6 : 2.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StockSummaryCard(
                    title: 'Total Tags',
                    value: '$totalTags',
                    subtitle: 'Unique RFID / Barcode Tags',
                    icon: Icons.sell_rounded,
                    accentColor: const Color(0xFF3E2723),
                  ),
                  StockSummaryCard(
                    title: 'Active Tags',
                    value: '$activeTags',
                    subtitle: 'Available + Reserved items',
                    icon: Icons.verified_rounded,
                    accentColor: const Color(0xFFB45309),
                  ),
                  StockSummaryCard(
                    title: 'Available Tags',
                    value: '$availableCount',
                    subtitle: 'Ready for customer billing',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: const Color(0xFF15803D),
                  ),
                  StockSummaryCard(
                    title: 'Sold Tags',
                    value: '$soldCount',
                    subtitle: 'Billed and delivered',
                    icon: Icons.shopping_bag_rounded,
                    accentColor: const Color(0xFFB91C1C),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),


          // ── 3. Filters Panel ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DDD0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3E2723).withValues(alpha: 0.03),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 42,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search Tag / Barcode / Item...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8D6E63)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: const Color(0xFFFCFAF5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                      ),
                    ),
                  ),
                ),

                _buildFilterDropdown(
                  value: _selectedCategory,
                  items: StockReportsDummyData.categories,
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),

                _buildFilterDropdown(
                  value: _selectedCounter,
                  items: StockReportsDummyData.counters,
                  onChanged: (val) => setState(() => _selectedCounter = val!),
                ),

                _buildFilterDropdown(
                  value: _selectedStatus,
                  items: StockReportsDummyData.statuses,
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. Data Table ──────────────────────────────────────────────────
          SizedBox(
            height: 480,
            child: ErpDataTable(
              columns: columns,
              rows: rows,
              sortColumnKey: _sortColumnKey,
              isAscending: _isAscending,
              onSort: _handleSort,
              footerTotals: footerTotals,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueItems = items.toSet().toList();
    final validValue = uniqueItems.contains(value) ? value : uniqueItems.first;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DDD0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF3E2723)),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF3E2723)),
          onChanged: onChanged,
          items: uniqueItems.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}
