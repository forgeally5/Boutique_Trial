import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_reports_dummy_data.dart';
import 'widgets/erp_data_table.dart';

class ItemWiseStockBalanceView extends StatefulWidget {
  final List<ItemWiseStockItem> items;

  const ItemWiseStockBalanceView({super.key, required this.items});

  @override
  State<ItemWiseStockBalanceView> createState() => _ItemWiseStockBalanceViewState();
}

class _ItemWiseStockBalanceViewState extends State<ItemWiseStockBalanceView> {
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedPurity = 'All Purities';

  bool _filterShop = true;
  bool _filterWebsite = true;
  bool _filterShopWeb = true;
  bool _filterYetToAdd = false;

  String _sortColumnKey = 'soldQuantity';
  bool _isAscending = false;

  final numberFormat = NumberFormat('#,##0.00', 'en_US');

  List<ItemWiseStockItem> get filteredItems {
    return widget.items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.itemCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All Categories' || item.category == _selectedCategory;
      final matchesPurity =
          _selectedPurity == 'All Purities' || item.purity == _selectedPurity;

      bool matchesStatus = false;
      final statusLower = item.productStatus.toLowerCase();
      if (_filterShop && statusLower == 'shop product') {
        matchesStatus = true;
      }
      if (_filterWebsite && statusLower == 'web product') {
        matchesStatus = true;
      }
      if (_filterShopWeb && statusLower == 'website product') {
        matchesStatus = true;
      }
      if (_filterYetToAdd && statusLower == 'yet to add') {
        matchesStatus = true;
      }

      return matchesSearch && matchesCategory && matchesPurity && matchesStatus;
    }).toList()
      ..sort((a, b) {
        int cmp = 0;
        switch (_sortColumnKey) {
          case 'rank':
            cmp = a.soldQuantity.compareTo(b.soldQuantity);
            break;
          case 'itemCode':
            cmp = a.itemCode.compareTo(b.itemCode);
            break;
          case 'itemName':
            cmp = a.itemName.compareTo(b.itemName);
            break;
          case 'category':
            cmp = a.category.compareTo(b.category);
            break;
          case 'grossWeight':
            cmp = a.grossWeight.compareTo(b.grossWeight);
            break;
          case 'netWeight':
            cmp = a.netWeight.compareTo(b.netWeight);
            break;
          case 'availableQuantity':
            cmp = a.availableQuantity.compareTo(b.availableQuantity);
            break;
          case 'soldQuantity':
            cmp = a.soldQuantity.compareTo(b.soldQuantity);
            break;
          case 'totalQuantity':
            cmp = a.totalQuantity.compareTo(b.totalQuantity);
            break;
          case 'soldPercentage':
            cmp = a.soldPercentage.compareTo(b.soldPercentage);
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

    // First calculate ranks based on overall sold quantity descending
    final sortedBySold = widget.items.toList()
      ..sort((a, b) => b.soldQuantity.compareTo(a.soldQuantity));
    final Map<String, int> ranks = {};
    for (int i = 0; i < sortedBySold.length; i++) {
      ranks[sortedBySold[i].itemCode] = i + 1;
    }

    int totalAvailable = 0;
    int totalSold = 0;
    double totalGross = 0.0;
    double totalNet = 0.0;

    for (final item in displayItems) {
      totalAvailable += item.availableQuantity;
      totalSold += item.soldQuantity;
      totalGross += item.grossWeight;
      totalNet += item.netWeight;
    }

    final int totalTotal = totalAvailable + totalSold;
    final double overallSoldPct = totalTotal > 0 ? (totalSold / totalTotal * 100) : 0.0;

    // Table Columns
    final columns = const [
      ErpTableColumn(title: 'Rank', key: 'rank', width: 80, isNumeric: true),
      ErpTableColumn(title: 'Master Tag', key: 'itemCode', width: 130),
      ErpTableColumn(title: 'Item Name', key: 'itemName', width: 190),
      ErpTableColumn(title: 'Category', key: 'category', width: 140),
      ErpTableColumn(title: 'Gross Wt (g)', key: 'grossWeight', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Net Wt (g)', key: 'netWeight', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Available Qty', key: 'availableQuantity', isNumeric: true, width: 125),
      ErpTableColumn(title: 'Sold Qty', key: 'soldQuantity', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Total Qty', key: 'totalQuantity', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Sold %', key: 'soldPercentage', isNumeric: true, width: 100),
    ];

    final rows = displayItems.map((item) {
      final rank = ranks[item.itemCode] ?? 0;
      return {
        'rank': '#$rank',
        'itemCode': item.itemCode.replaceAll(RegExp(r'\[\d+\]$'), ''),
        'itemName': item.itemName,
        'category': item.category,
        'grossWeight': '${numberFormat.format(item.grossWeight)} g',
        'netWeight': '${numberFormat.format(item.netWeight)} g',
        'availableQuantity': '${item.availableQuantity} Pcs',
        'soldQuantity': '${item.soldQuantity} Pcs',
        'totalQuantity': '${item.totalQuantity} Pcs',
        'soldPercentage': '${item.soldPercentage.toStringAsFixed(1)}%',
      };
    }).toList();

    final footerTotals = {
      'rank': '',
      'itemCode': 'TOTAL (${displayItems.length} Items)',
      'itemName': '',
      'category': '',
      'grossWeight': '${numberFormat.format(totalGross)} g',
      'netWeight': '${numberFormat.format(totalNet)} g',
      'availableQuantity': '$totalAvailable Pcs',
      'soldQuantity': '$totalSold Pcs',
      'totalQuantity': '$totalTotal Pcs',
      'soldPercentage': '${overallSoldPct.toStringAsFixed(1)}%',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Filters Panel ───────────────────────────────────────────────
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
              spacing: 20,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 42,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search Item Name / Code...',
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
                  value: _selectedPurity,
                  items: StockReportsDummyData.purities,
                  onChanged: (val) => setState(() => _selectedPurity = val!),
                ),

                // Checkbox Filters
                _buildCheckboxFilter(
                  label: 'SHOP',
                  value: _filterShop,
                  onChanged: (val) => setState(() => _filterShop = val!),
                ),

                _buildCheckboxFilter(
                  label: 'WEBSITE',
                  value: _filterWebsite,
                  onChanged: (val) => setState(() => _filterWebsite = val!),
                ),

                _buildCheckboxFilter(
                  label: 'WEB+SHOP',
                  value: _filterShopWeb,
                  onChanged: (val) => setState(() => _filterShopWeb = val!),
                ),

                _buildCheckboxFilter(
                  label: 'YET TO ADD',
                  value: _filterYetToAdd,
                  onChanged: (val) => setState(() => _filterYetToAdd = val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 2. Data Table ──────────────────────────────────────────────────
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

  Widget _buildCheckboxFilter({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xFF3E2723),
            checkColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE5DDD0), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
      ],
    );
  }
}
