import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stock_reports_dummy_data.dart';
import 'widgets/erp_data_table.dart';

class ClosingStockReportView extends StatefulWidget {
  final List<StockSummaryItem> items;
  final VoidCallback? onRefresh;

  const ClosingStockReportView({super.key, required this.items, this.onRefresh});

  @override
  State<ClosingStockReportView> createState() => _ClosingStockReportViewState();
}

class _ClosingStockReportViewState extends State<ClosingStockReportView> {
  String _sortColumnKey = 'metalId';
  bool _isAscending = true;

  final numberFormat = NumberFormat('#,##0.000', 'en_US');

  List<StockSummaryItem> get filteredItems {
    const metalIdOrder = {
      '18D': 0,
      '18G': 1,
      '22G': 2,
      '24 KT': 3,
      'DI': 4,
      'S925': 5,
      'AL': 6,
    };

    return widget.items.toList()..sort((a, b) {
      int cmp = 0;
      switch (_sortColumnKey) {
        case 'metalId':
          final orderA = metalIdOrder[a.category] ?? 99;
          final orderB = metalIdOrder[b.category] ?? 99;
          cmp = orderA.compareTo(orderB);
          break;
        case 'shopStock':
          cmp = a.weight.compareTo(b.weight);
          break;
        case 'ownCust':
          cmp = 0;
          break;
        case 'ownSup':
          cmp = 0;
          break;
        case 'custWithUs':
          cmp = 0;
          break;
        case 'supWithUs':
          cmp = 0;
          break;
        case 'ownStock':
          cmp = a.weight.compareTo(b.weight);
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

  void _showManageMetalIdsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManageMetalIdsDialog(),
    ).then((_) {
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = filteredItems;

    double totalShopStock = 0.0;
    double totalOwnCust = 0.0;
    double totalOwnSup = 0.0;
    double totalCustWithUs = 0.0;
    double totalSupWithUs = 0.0;
    double totalOwnStock = 0.0;

    for (final item in displayItems) {
      totalShopStock += item.weight;
      totalOwnCust += item.ownCust;
      totalOwnSup += item.ownSup;
      totalCustWithUs += item.custWithUs;
      totalSupWithUs += item.supWithUs;
      totalOwnStock += (item.weight - item.ownCust - item.ownSup - item.custWithUs - item.supWithUs);
    }

    // Table Columns matching screenshot exactly
    final columns = const [
      ErpTableColumn(title: 'MetalID', key: 'metalId', width: 120),
      ErpTableColumn(
        title: 'Shop Stock\n(A)',
        key: 'shopStock',
        isNumeric: true,
        width: 140,
      ),
      ErpTableColumn(
        title: 'Own Stock With\nCustomer (B)',
        key: 'ownCust',
        isNumeric: true,
        width: 160,
      ),
      ErpTableColumn(
        title: 'Own Stock With\nSupplier (C)',
        key: 'ownSup',
        isNumeric: true,
        width: 160,
      ),
      ErpTableColumn(
        title: 'Customer Stock\nWith Us (D)',
        key: 'custWithUs',
        isNumeric: true,
        width: 160,
      ),
      ErpTableColumn(
        title: 'Supplier Stock\nWith Us (E)',
        key: 'supWithUs',
        isNumeric: true,
        width: 160,
      ),
      ErpTableColumn(
        title: 'Own Stock\n(A-B-C-D-E)',
        key: 'ownStock',
        isNumeric: true,
        width: 160,
      ),
    ];

    final rows = displayItems.map((item) {
      final double shopStock = item.weight;
      final double ownCust = item.ownCust;
      final double ownSup = item.ownSup;
      final double custWithUs = item.custWithUs;
      final double supWithUs = item.supWithUs;
      final double ownStock = shopStock - ownCust - ownSup - custWithUs - supWithUs;

      return {
        'metalId': item.category,
        'shopStock': numberFormat.format(shopStock),
        'ownCust': ownCust == 0.0 ? '' : numberFormat.format(ownCust),
        'ownSup': ownSup == 0.0 ? '' : numberFormat.format(ownSup),
        'custWithUs': custWithUs == 0.0 ? '' : numberFormat.format(custWithUs),
        'supWithUs': supWithUs == 0.0 ? '' : numberFormat.format(supWithUs),
        'ownStock': numberFormat.format(ownStock),
      };
    }).toList();

    final footerTotals = {
      'metalId': 'TOTAL',
      'shopStock': numberFormat.format(totalShopStock),
      'ownCust': totalOwnCust == 0.0 ? '' : numberFormat.format(totalOwnCust),
      'ownSup': totalOwnSup == 0.0 ? '' : numberFormat.format(totalOwnSup),
      'custWithUs': totalCustWithUs == 0.0 ? '' : numberFormat.format(totalCustWithUs),
      'supWithUs': totalSupWithUs == 0.0 ? '' : numberFormat.format(totalSupWithUs),
      'ownStock': numberFormat.format(totalOwnStock),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Closing Stock As On ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showManageMetalIdsDialog(context),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Manage Metal IDs', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Table ─────────────────────────────────────────────────────────
          SizedBox(
            height: 520,
            child: ErpDataTable(
              columns: columns,
              rows: rows,
              sortColumnKey: _sortColumnKey,
              isAscending: _isAscending,
              onSort: _handleSort,
              footerTotals: footerTotals,
              showPagination: false,
            ),
          ),
        ],
      ),
    );
  }
}

class ManageMetalIdsDialog extends StatefulWidget {
  const ManageMetalIdsDialog({super.key});

  @override
  State<ManageMetalIdsDialog> createState() => _ManageMetalIdsDialogState();
}

class _ManageMetalIdsDialogState extends State<ManageMetalIdsDialog> {
  final _codeController = TextEditingController();
  final _puritiesController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addMapping() async {
    final code = _codeController.text.toUpperCase().trim();
    final puritiesStr = _puritiesController.text.trim();
    if (code.isEmpty || puritiesStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final purities = puritiesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await FirebaseFirestore.instance.collection('closing_stock_configs').doc(code).set({
        'code': code,
        'purities': purities,
      });
      _codeController.clear();
      _puritiesController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving mapping: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteMapping(String id) async {
    try {
      await FirebaseFirestore.instance.collection('closing_stock_configs').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting mapping: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFCFAF5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manage Metal ID Mappings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE5DDD0)),
            const SizedBox(height: 8),

            // Mappings Stream
            Flexible(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('closing_stock_configs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No mappings configured yet. Defaults will be loaded.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final code = doc.data()['code']?.toString() ?? doc.id;
                      final purities = List<String>.from(doc.data()['purities'] ?? []);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5DDD0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF3E2723),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Maps to: ${purities.join(", ")}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () => _deleteMapping(doc.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Add New Metal ID Mapping',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 10),

            // Form Fields
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Metal ID Code',
                      hintText: 'e.g. 14K',
                      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _puritiesController,
                    decoration: InputDecoration(
                      labelText: 'Purity Keywords',
                      hintText: 'e.g. 14K, 585, 14KT',
                      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addMapping,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Mapping'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
