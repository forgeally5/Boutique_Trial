import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_reports_dummy_data.dart';
import 'widgets/stock_summary_card.dart';
import 'widgets/custom_charts.dart';
import 'widgets/erp_data_table.dart';

class SupplierStockReportView extends StatefulWidget {
  final List<SupplierStockItem> items;

  const SupplierStockReportView({super.key, required this.items});

  @override
  State<SupplierStockReportView> createState() => _SupplierStockReportViewState();
}

class _SupplierStockReportViewState extends State<SupplierStockReportView> {
  String _selectedSupplier = 'All Suppliers';
  String _sortColumnKey = 'supplierName';
  bool _isAscending = true;

  final numberFormat = NumberFormat('#,##0.000', 'en_US');

  List<SupplierStockItem> get filteredItems {
    return widget.items.where((item) {
      final matchesSupplier = _selectedSupplier == 'All Suppliers' ||
          '${item.supplierCode} - ${item.supplierName}' == _selectedSupplier;
      return matchesSupplier;
    }).toList()
      ..sort((a, b) {
        int cmp = 0;
        switch (_sortColumnKey) {
          case 'supplierCode':
            cmp = a.supplierCode.compareTo(b.supplierCode);
            break;
          case 'supplierName':
            cmp = a.supplierName.compareTo(b.supplierName);
            break;
          case 'tagPrefix':
            cmp = a.tagPrefix.compareTo(b.tagPrefix);
            break;
          case 'groupName':
            cmp = a.groupName.compareTo(b.groupName);
            break;
          case 'purchasedPcs':
            cmp = a.purchasedPcs.compareTo(b.purchasedPcs);
            break;
          case 'purchasedGrossWt':
            cmp = a.purchasedGrossWt.compareTo(b.purchasedGrossWt);
            break;
          case 'purchasedNetWt':
            cmp = a.purchasedNetWt.compareTo(b.purchasedNetWt);
            break;
          case 'taggedPcs':
            cmp = a.taggedPcs.compareTo(b.taggedPcs);
            break;
          case 'taggedGrossWt':
            cmp = a.taggedGrossWt.compareTo(b.taggedGrossWt);
            break;
          case 'taggedNetWt':
            cmp = a.taggedNetWt.compareTo(b.taggedNetWt);
            break;
          case 'activePcs':
            cmp = a.activePcs.compareTo(b.activePcs);
            break;
          case 'activeGrossWt':
            cmp = a.activeGrossWt.compareTo(b.activeGrossWt);
            break;
          case 'activeNetWt':
            cmp = a.activeNetWt.compareTo(b.activeNetWt);
            break;
          case 'remainingGrossWt':
            cmp = a.remainingGrossWt.compareTo(b.remainingGrossWt);
            break;
          case 'remainingNetWt':
            cmp = a.remainingNetWt.compareTo(b.remainingNetWt);
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

    // Aggregates
    int totalPurPcs = 0;
    double totalPurGross = 0.0;
    double totalPurNet = 0.0;
    double totalPurDia = 0.0;
    double totalPurStn = 0.0;

    int totalTagPcs = 0;
    double totalTagGross = 0.0;
    double totalTagNet = 0.0;

    int totalActPcs = 0;
    double totalActGross = 0.0;
    double totalActNet = 0.0;

    for (final item in displayItems) {
      totalPurPcs += item.purchasedPcs;
      totalPurGross += item.purchasedGrossWt;
      totalPurNet += item.purchasedNetWt;
      totalPurDia += item.purchasedDiamondWt;
      totalPurStn += item.purchasedStoneWt;

      totalTagPcs += item.taggedPcs;
      totalTagGross += item.taggedGrossWt;
      totalTagNet += item.taggedNetWt;

      totalActPcs += item.activePcs;
      totalActGross += item.activeGrossWt;
      totalActNet += item.activeNetWt;
    }

    final double totalRemGross = totalPurGross - totalTagGross;
    final double totalRemNet = totalPurNet - totalTagNet;

    // Charts data
    final verticalBarData = displayItems.take(5).map((item) {
      return VerticalBarChartData(
        label: item.supplierCode,
        value: item.remainingNetWt,
        displayValue: '${item.remainingNetWt.toStringAsFixed(1)}g',
      );
    }).toList();

    // Table definitions
    final columns = const [
      ErpTableColumn(title: 'Supplier Code', key: 'supplierCode', width: 110),
      ErpTableColumn(title: 'Supplier Name', key: 'supplierName', width: 180),
      ErpTableColumn(title: 'Tag Prefix', key: 'tagPrefix', width: 100),
      ErpTableColumn(title: 'Group Name', key: 'groupName', width: 150),
      // Purchased
      ErpTableColumn(title: 'Pur Pcs', key: 'purchasedPcs', isNumeric: true, width: 80),
      ErpTableColumn(title: 'Pur Gross (g)', key: 'purchasedGrossWt', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Pur Net (g)', key: 'purchasedNetWt', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Pur Dia (ct)', key: 'purchasedDiamondWt', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Pur Stn (g)', key: 'purchasedStoneWt', isNumeric: true, width: 110),
      // Tagged
      ErpTableColumn(title: 'Tag Pcs', key: 'taggedPcs', isNumeric: true, width: 80),
      ErpTableColumn(title: 'Tag Gross (g)', key: 'taggedGrossWt', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Tag Net (g)', key: 'taggedNetWt', isNumeric: true, width: 110),
      // Active Counter
      ErpTableColumn(title: 'Ctr Pcs', key: 'activePcs', isNumeric: true, width: 80),
      ErpTableColumn(title: 'Ctr Gross (g)', key: 'activeGrossWt', isNumeric: true, width: 110),
      ErpTableColumn(title: 'Ctr Net (g)', key: 'activeNetWt', isNumeric: true, width: 110),
      // Remaining
      ErpTableColumn(title: 'Rem Gross (g)', key: 'remainingGrossWt', isNumeric: true, width: 120),
      ErpTableColumn(title: 'Rem Net (g)', key: 'remainingNetWt', isNumeric: true, width: 120),
    ];

    final rows = displayItems.map((item) {
      return {
        'supplierCode': item.supplierCode,
        'supplierName': item.supplierName,
        'tagPrefix': item.tagPrefix,
        'groupName': item.groupName,
        'purchasedPcs': '${item.purchasedPcs} Pcs',
        'purchasedGrossWt': '${numberFormat.format(item.purchasedGrossWt)} g',
        'purchasedNetWt': '${numberFormat.format(item.purchasedNetWt)} g',
        'purchasedDiamondWt': '${numberFormat.format(item.purchasedDiamondWt)} ct',
        'purchasedStoneWt': '${numberFormat.format(item.purchasedStoneWt)} g',
        'taggedPcs': '${item.taggedPcs} Pcs',
        'taggedGrossWt': '${numberFormat.format(item.taggedGrossWt)} g',
        'taggedNetWt': '${numberFormat.format(item.taggedNetWt)} g',
        'activePcs': '${item.activePcs} Pcs',
        'activeGrossWt': '${numberFormat.format(item.activeGrossWt)} g',
        'activeNetWt': '${numberFormat.format(item.activeNetWt)} g',
        'remainingGrossWt': '${numberFormat.format(item.remainingGrossWt)} g',
        'remainingNetWt': '${numberFormat.format(item.remainingNetWt)} g',
      };
    }).toList();

    final footerTotals = {
      'supplierCode': 'TOTAL (${displayItems.length} Rows)',
      'supplierName': '',
      'tagPrefix': '',
      'groupName': '',
      'purchasedPcs': '$totalPurPcs Pcs',
      'purchasedGrossWt': '${numberFormat.format(totalPurGross)} g',
      'purchasedNetWt': '${numberFormat.format(totalPurNet)} g',
      'purchasedDiamondWt': '${numberFormat.format(totalPurDia)} ct',
      'purchasedStoneWt': '${numberFormat.format(totalPurStn)} g',
      'taggedPcs': '$totalTagPcs Pcs',
      'taggedGrossWt': '${numberFormat.format(totalTagGross)} g',
      'taggedNetWt': '${numberFormat.format(totalTagNet)} g',
      'activePcs': '$totalActPcs Pcs',
      'activeGrossWt': '${numberFormat.format(totalActGross)} g',
      'activeNetWt': '${numberFormat.format(totalActNet)} g',
      'remainingGrossWt': '${numberFormat.format(totalRemGross)} g',
      'remainingNetWt': '${numberFormat.format(totalRemNet)} g',
    };

    // Get all supplier options for dropdown
    final supplierOptions = ['All Suppliers'];
    for (final item in widget.items) {
      final label = '${item.supplierCode} - ${item.supplierName}';
      if (!supplierOptions.contains(label)) {
        supplierOptions.add(label);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Filter dropdown (Moved to Top) ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5DDD0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3E2723).withValues(alpha: 0.03),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Supplier Filter: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                const SizedBox(width: 12),
                _buildFilterDropdown(
                  value: _selectedSupplier,
                  items: supplierOptions,
                  onChanged: (val) => setState(() => _selectedSupplier = val ?? 'All Suppliers'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Summary Cards ───────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 3 : (width > 700 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 3 ? 3.6 : (crossAxisCount == 2 ? 3.4 : 4.5),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StockSummaryCard(
                    title: 'Total Purchased Net Wt',
                    value: '${numberFormat.format(totalPurNet)} g',
                    subtitle: 'Incoming stock from suppliers',
                    icon: Icons.local_shipping_rounded,
                    accentColor: const Color(0xFF3E2723),
                  ),
                  StockSummaryCard(
                    title: 'Active Counter Net Wt',
                    value: '${numberFormat.format(totalActNet)} g',
                    subtitle: 'Current closing stock in counter',
                    icon: Icons.storefront_rounded,
                    accentColor: const Color(0xFFB45309),
                  ),
                  StockSummaryCard(
                    title: 'Remaining Untagged Net Wt',
                    value: '${numberFormat.format(totalRemNet)} g',
                    subtitle: 'Purchased weight not yet tagged',
                    icon: Icons.pending_actions_rounded,
                    accentColor: const Color(0xFF15803D),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 3. Chart ───────────────────────────────────────────────────────
          if (verticalBarData.isNotEmpty) ...[
            SizedBox(
              height: 320,
              child: CustomVerticalBarChart(
                title: 'Top 5 Suppliers - Remaining Untagged Net Weight (g)',
                items: verticalBarData,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── 4. Table ───────────────────────────────────────────────────────
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
