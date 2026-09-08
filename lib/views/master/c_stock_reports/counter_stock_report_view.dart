import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_reports_dummy_data.dart';
import 'widgets/stock_summary_card.dart';
import 'widgets/custom_charts.dart';
import 'widgets/erp_data_table.dart';

class CounterStockReportView extends StatefulWidget {
  final List<CounterStockItem> items;

  const CounterStockReportView({super.key, required this.items});

  @override
  State<CounterStockReportView> createState() => _CounterStockReportViewState();
}

class _CounterStockReportViewState extends State<CounterStockReportView> {
  String _selectedCounter = 'All Counters';
  String _selectedStaff = 'All Staff';
  String _selectedCategory = 'All Categories';

  String _sortColumnKey = 'counterName';
  bool _isAscending = true;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final numberFormat = NumberFormat('#,##0.00', 'en_US');

  List<CounterStockItem> get filteredItems {
    return widget.items.where((item) {
      final matchesCounter =
          _selectedCounter == 'All Counters' || item.counterName == _selectedCounter;
      final matchesStaff =
          _selectedStaff == 'All Staff' || item.staff == _selectedStaff;
      final matchesCategory =
          _selectedCategory == 'All Categories' || item.category == _selectedCategory;

      return matchesCounter && matchesStaff && matchesCategory;
    }).toList()
      ..sort((a, b) {
        int cmp = 0;
        switch (_sortColumnKey) {
          case 'counterName':
            cmp = a.counterName.compareTo(b.counterName);
            break;
          case 'staff':
            cmp = a.staff.compareTo(b.staff);
            break;
          case 'category':
            cmp = a.category.compareTo(b.category);
            break;
          case 'itemCount':
            cmp = a.itemCount.compareTo(b.itemCount);
            break;
          case 'quantity':
            cmp = a.quantity.compareTo(b.quantity);
            break;
          case 'weight':
            cmp = a.weight.compareTo(b.weight);
            break;
          case 'value':
            cmp = a.value.compareTo(b.value);
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

    final int totalCounters = displayItems.length;
    int totalQty = 0;
    double totalWeight = 0.0;
    double totalValue = 0.0;

    for (final item in displayItems) {
      totalQty += item.quantity;
      totalWeight += item.weight;
      totalValue += item.value;
    }

    final verticalBarData = displayItems.map((item) {
      return VerticalBarChartData(
        label: item.counterName.replaceAll('Counter ', 'C'),
        value: item.value,
        displayValue: '₹${(item.value / 100000).toStringAsFixed(1)}L',
      );
    }).toList();

    final columns = const [
      ErpTableColumn(title: 'Counter Name', key: 'counterName', width: 180),
      ErpTableColumn(title: 'In-Charge Staff', key: 'staff', width: 140),
      ErpTableColumn(title: 'Category', key: 'category', width: 140),
      ErpTableColumn(title: 'Item Count', key: 'itemCount', isNumeric: true, width: 100),
      ErpTableColumn(title: 'Quantity', key: 'quantity', isNumeric: true, width: 100),
      ErpTableColumn(title: 'Weight (g)', key: 'weight', isNumeric: true, width: 120),
      ErpTableColumn(title: 'Value (₹)', key: 'value', isNumeric: true, width: 150),
    ];

    final rows = displayItems.map((item) {
      return {
        'counterName': item.counterName,
        'staff': item.staff,
        'category': item.category,
        'itemCount': '${item.itemCount} Items',
        'quantity': '${item.quantity} Pcs',
        'weight': '${numberFormat.format(item.weight)} g',
        'value': currencyFormat.format(item.value),
      };
    }).toList();

    final footerTotals = {
      'counterName': 'TOTAL ($totalCounters Counters)',
      'staff': '',
      'category': '',
      'itemCount': '',
      'quantity': '$totalQty Pcs',
      'weight': '${numberFormat.format(totalWeight)} g',
      'value': currencyFormat.format(totalValue),
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
                    title: 'Total Counters',
                    value: '$totalCounters',
                    subtitle: 'Active floor & safe counters',
                    icon: Icons.storefront_rounded,
                    accentColor: const Color(0xFF3E2723),
                  ),
                  StockSummaryCard(
                    title: 'Total Stock Quantity',
                    value: '$totalQty Pcs',
                    subtitle: 'Pieces allocated across counters',
                    icon: Icons.inventory_rounded,
                    accentColor: const Color(0xFFB45309),
                  ),
                  StockSummaryCard(
                    title: 'Total Weight',
                    value: '${numberFormat.format(totalWeight)} g',
                    subtitle: 'Total net counter weight',
                    icon: Icons.scale_rounded,
                    accentColor: const Color(0xFFD97706),
                  ),
                  StockSummaryCard(
                    title: 'Total Stock Value',
                    value: currencyFormat.format(totalValue),
                    subtitle: 'Showroom counter stock worth',
                    icon: Icons.account_balance_rounded,
                    accentColor: const Color(0xFF15803D),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 2. Vertical Bar Chart ──────────────────────────────────────────
          SizedBox(
            height: 340,
            child: CustomVerticalBarChart(
              title: 'Counter-wise Stock Value Distribution',
              items: verticalBarData,
            ),
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
                _buildFilterDropdown(
                  value: _selectedCounter,
                  items: StockReportsDummyData.counters,
                  onChanged: (val) => setState(() => _selectedCounter = val!),
                ),

                _buildFilterDropdown(
                  value: _selectedStaff,
                  items: StockReportsDummyData.staffList,
                  onChanged: (val) => setState(() => _selectedStaff = val!),
                ),

                _buildFilterDropdown(
                  value: _selectedCategory,
                  items: StockReportsDummyData.categories,
                  onChanged: (val) => setState(() => _selectedCategory = val!),
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
