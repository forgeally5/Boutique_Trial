import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../../state/admin_state.dart';
import '../../../products/repositories/product_repository.dart';
import 'daily_counter_stock_entry_model.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

class DailyCounterStockEntryView extends StatefulWidget {
  final AdminState state;

  const DailyCounterStockEntryView({super.key, required this.state});

  @override
  State<DailyCounterStockEntryView> createState() => _DailyCounterStockEntryViewState();
}

class _DailyCounterStockEntryViewState extends State<DailyCounterStockEntryView> {
  final List<DailyCounterStockEntry> _allRows = [];
  final List<DailyCounterStockEntry> _transferLogs = [];
  List<String> _counterOptions = [];
  final Map<String, String> _editedToCounters = {};
  bool _isLoading = false;

  // Filters
  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  List<String> get _dropdownCounters {
    if (_counterOptions.isEmpty) {
      return ['Cash Counter', 'C1', 'V1'];
    }
    return _counterOptions;
  }

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch unique counters
      final counters = await ProductRepository().getUniqueCounters();

      // 2. Fetch jewelry_inventory items
      final inventorySnap = await FirebaseFirestore.instance
          .collection('jewelry_inventory')
          .get();

      // 3. Fetch daily_counter_stock_entries
      final entriesSnap = await FirebaseFirestore.instance
          .collection('daily_counter_stock_entries')
          .orderBy('createdAt', descending: true)
          .get();

      final entries = entriesSnap.docs
          .map((doc) => DailyCounterStockEntry.fromMap(doc.data(), doc.id))
          .toList();

      final List<DailyCounterStockEntry> rows = [];

      for (final doc in inventorySnap.docs) {
        final d = doc.data();
        final tagId = d['tagId']?.toString() ?? d['productId']?.toString() ?? doc.id;
        if (tagId.trim().isEmpty) continue;

        // Skip sold items
        final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
        final pcs = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? 1;
        final isSold = pcs <= 0 || rawStatus.toLowerCase() == 'sold' || rawStatus.toLowerCase() == 'out of stock';
        if (isSold) continue;

        final itemName = d['name']?.toString() ?? d['itemName']?.toString() ?? 'Unnamed';
        final grossWeight = (d['grossWeight'] as num?)?.toDouble() ?? (d['grossWt'] as num?)?.toDouble() ?? 0.0;
        final netWeight = (d['netWeight'] as num?)?.toDouble() ?? (d['netWt'] as num?)?.toDouble() ?? 0.0;

        // Find latest transfer entry for this tagId (labelNo)
        final latestTransfer = entries.firstWhere(
          (e) => e.labelNo.trim().toLowerCase() == tagId.trim().toLowerCase(),
          orElse: () => DailyCounterStockEntry(
            docId: 'new_$tagId',
            transactionNo: '',
            date: DateTime.now(),
            fromCounter: d['counterNo']?.toString() ?? d['counter']?.toString() ?? 'Main Display Safe',
            toCounter: d['counterNo']?.toString() ?? d['counter']?.toString() ?? 'Main Display Safe',
            labelNo: tagId,
            itemName: itemName,
            pcs: pcs,
            grossWeight: grossWeight,
            netWeight: netWeight,
            remarks: '',
            status: 'COMPLETED',
            createdAt: DateTime.now(),
          ),
        );

        rows.add(latestTransfer);
      }

      if (mounted) {
        setState(() {
          _counterOptions = counters;
          _transferLogs.clear();
          _transferLogs.addAll(entries);
          _allRows.clear();
          _allRows.addAll(rows);
        });
      }
    } catch (e) {
      debugPrint('Firestore load error (using local state): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DailyCounterStockEntry> get _filteredRecords {
    return _allRows.where((r) {
      final isEdited = _editedToCounters.containsKey(r.labelNo);
      final displayToCounter = _editedToCounters[r.labelNo] ?? r.toCounter;
      final displayStatus = isEdited ? 'DRAFT' : r.status;
      final displayDate = r.updatedAt ?? r.date;

      final matchSearch = _searchQuery.isEmpty ||
          r.labelNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.fromCounter.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          displayToCounter.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchStatus = _statusFilter == 'All' ||
          displayStatus.toLowerCase() == _statusFilter.toLowerCase();

      bool matchDate = true;
      if (_fromDate != null) {
        matchDate = matchDate && displayDate.isAfter(_fromDate!.subtract(const Duration(days: 1)));
      }
      if (_toDate != null) {
        matchDate = matchDate && displayDate.isBefore(_toDate!.add(const Duration(days: 1)));
      }

      return matchSearch && matchStatus && matchDate;
    }).toList();
  }

  String _generateNextTxNumber() {
    final prefix = 'CST-';
    final count = _transferLogs.where((r) => r.transactionNo.startsWith(prefix)).length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  Future<void> _saveRowAsCompleted(DailyCounterStockEntry r) async {
    final newToCounter = _editedToCounters[r.labelNo] ?? r.toCounter;
    final currentDatetime = DateTime.now();

    setState(() => _isLoading = true);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
      
      String docId = r.docId;
      String transactionNo = r.transactionNo;

      if (isOnline) {
        if (docId.startsWith('new_')) {
          transactionNo = _generateNextTxNumber();
          final docRef = await FirebaseFirestore.instance
              .collection('daily_counter_stock_entries')
              .add({
                'transactionNo': transactionNo,
                'date': Timestamp.fromDate(currentDatetime),
                'fromCounter': r.fromCounter,
                'toCounter': newToCounter,
                'labelNo': r.labelNo,
                'itemName': r.itemName,
                'pcs': r.pcs,
                'grossWeight': r.grossWeight,
                'netWeight': r.netWeight,
                'remarks': r.remarks,
                'status': 'COMPLETED',
                'createdAt': Timestamp.fromDate(currentDatetime),
                'updatedAt': Timestamp.fromDate(currentDatetime),
              });
          docId = docRef.id;
        } else {
          await FirebaseFirestore.instance
              .collection('daily_counter_stock_entries')
              .doc(docId)
              .update({
                'toCounter': newToCounter,
                'status': 'COMPLETED',
                'date': Timestamp.fromDate(currentDatetime),
                'updatedAt': Timestamp.fromDate(currentDatetime),
              });
        }

        // Also update counter of the product in jewelry_inventory!
        await FirebaseFirestore.instance
            .collection('jewelry_inventory')
            .doc(r.labelNo)
            .update({
              'counter': newToCounter,
              'counterNo': newToCounter,
            });
      } else {
         if (docId.startsWith('new_')) {
            transactionNo = '${_generateNextTxNumber()}-OFF';
         } else if (!transactionNo.endsWith('-OFF')) {
            transactionNo = '$transactionNo-OFF';
         }
         
         await LocalDbService().insertEntry(
            'daily_counter_stock_entries', 
            {
               'transactionNo': transactionNo,
               'date': Timestamp.fromDate(currentDatetime),
               'fromCounter': r.fromCounter,
               'toCounter': newToCounter,
               'labelNo': r.labelNo,
               'itemName': r.itemName,
               'pcs': r.pcs,
               'grossWeight': r.grossWeight,
               'netWeight': r.netWeight,
               'remarks': r.remarks,
               'status': 'COMPLETED',
               'createdAt': Timestamp.fromDate(currentDatetime),
               'updatedAt': Timestamp.fromDate(currentDatetime),
            },
            operation: docId.startsWith('new_') ? 'ADD' : 'UPDATE',
            docId: docId.startsWith('new_') ? null : docId
         );
         
         final List<Map<String, dynamic>> docUpdates = [
            {
               'collection': 'jewelry_inventory',
               'docId': r.labelNo,
               'data': {
                  'counter': newToCounter,
                  'counterNo': newToCounter,
               }
            }
         ];
         
         await LocalDbService().insertEntry(
            'offline_metadata', 
            {'documentUpdates': docUpdates},
            operation: 'UPDATE'
         );
         SyncService().syncNow();
      }

      // Clear local edit state for this tag
      _editedToCounters.remove(r.labelNo);

      // Refresh records
      await _fetchRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock Transfer completed for ${r.labelNo}!'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing transfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving changes.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelRowEdit(DailyCounterStockEntry r) {
    setState(() {
      _editedToCounters.remove(r.labelNo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter & Toolbar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search by Tag ID, Item Name, Counter...',
                          prefixIcon: const Icon(Icons.search, color: _brownLight),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          items: ['All', 'COMPLETED', 'DRAFT', 'CANCELLED']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, color: _brown))))
                              .toList(),
                          onChanged: (v) => setState(() => _statusFilter = v!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Filters
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      icon: const Icon(Icons.date_range, size: 18, color: _brown),
                      label: Text(
                        _fromDate == null ? 'Date Filter' : '${dateFormat.format(_fromDate!)} - ${dateFormat.format(_toDate ?? DateTime.now())}',
                        style: const TextStyle(fontSize: 13, color: _brown),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                           setState(() {
                             _fromDate = picked.start;
                             _toDate = picked.end;
                           });
                        }
                      },
                    ),
                    if (_fromDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Table Card
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _brown))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final double minWidth = 1300;
                        final double tableWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
                        final double columnsTotalWidth = tableWidth - 168; // 9 * 16 (spacing) + 2 * 12 (margins)

                        final double tagIdWidth = columnsTotalWidth * 0.10;
                        final double itemNameWidth = columnsTotalWidth * 0.14;
                        final double grossWtWidth = columnsTotalWidth * 0.09;
                        final double netWtWidth = columnsTotalWidth * 0.09;
                        final double pcsWidth = columnsTotalWidth * 0.05;
                        final double currentCounterWidth = columnsTotalWidth * 0.11;
                        final double toCounterWidth = columnsTotalWidth * 0.11;
                        final double dateWidth = columnsTotalWidth * 0.10;
                        final double statusWidth = columnsTotalWidth * 0.10;
                        final double actionWidth = columnsTotalWidth * 0.11;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sticky Table Header
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: _border,
                                  ),
                                  child: DataTable(
                                    columnSpacing: 16,
                                    horizontalMargin: 12,
                                    headingRowColor: WidgetStateProperty.all(_headerBg),
                                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 13),
                                    columns: [
                                      DataColumn(label: SizedBox(width: tagIdWidth, child: const Text('Tag ID'))),
                                      DataColumn(label: SizedBox(width: itemNameWidth, child: const Text('Item Name'))),
                                      DataColumn(label: SizedBox(width: grossWtWidth, child: const Text('Gross Wt (g)'))),
                                      DataColumn(label: SizedBox(width: netWtWidth, child: const Text('Net Wt (g)'))),
                                      DataColumn(label: SizedBox(width: pcsWidth, child: const Text('Pcs'))),
                                      DataColumn(label: SizedBox(width: currentCounterWidth, child: const Text('Current Counter'))),
                                      DataColumn(label: SizedBox(width: toCounterWidth, child: const Text('To Counter'))),
                                      DataColumn(label: SizedBox(width: dateWidth, child: const Text('Date'))),
                                      DataColumn(label: SizedBox(width: statusWidth, child: const Text('Status'))),
                                      DataColumn(label: SizedBox(width: actionWidth, child: const Text('Action'))),
                                    ],
                                    rows: const [],
                                  ),
                                ),
                                // Scrollable Body Rows or Empty State
                                Expanded(
                                  child: filtered.isEmpty
                                      ? SizedBox(
                                          width: tableWidth,
                                          child: const Center(
                                            child: Text(
                                              'No Counter Stock Entries found.',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              dividerColor: _border,
                                            ),
                                            child: DataTable(
                                              headingRowHeight: 0,
                                              columnSpacing: 16,
                                              horizontalMargin: 12,
                                              columns: [
                                                DataColumn(label: SizedBox(width: tagIdWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: itemNameWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: grossWtWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: netWtWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: pcsWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: currentCounterWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: toCounterWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: dateWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: statusWidth, child: const SizedBox())),
                                                DataColumn(label: SizedBox(width: actionWidth, child: const SizedBox())),
                                              ],
                                              rows: filtered.map((r) {
                                                final isEdited = _editedToCounters.containsKey(r.labelNo);
                                                final displayToCounter = _editedToCounters[r.labelNo] ?? r.toCounter;
                                                final displayStatus = isEdited ? 'DRAFT' : r.status;
                                                final displayDate = r.updatedAt ?? r.date;

                                                return DataRow(
                                                  cells: [
                                                    // 1. Tag ID
                                                    DataCell(SizedBox(width: tagIdWidth, child: Text(r.labelNo.isEmpty ? '-' : r.labelNo, style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)))),
                                                    // 2. Item Name
                                                    DataCell(SizedBox(width: itemNameWidth, child: Text(r.itemName, overflow: TextOverflow.ellipsis))),
                                                    // 3. Gross Wt
                                                    DataCell(SizedBox(width: grossWtWidth, child: Text(r.grossWeight.toStringAsFixed(3)))),
                                                    // 4. Net Wt
                                                    DataCell(SizedBox(width: netWtWidth, child: Text(r.netWeight.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)))),
                                                    // 5. Pcs
                                                    DataCell(SizedBox(width: pcsWidth, child: Text(r.pcs.toString()))),
                                                    // 6. Current Counter
                                                    DataCell(SizedBox(width: currentCounterWidth, child: Text(r.fromCounter, overflow: TextOverflow.ellipsis))),
                                                    // 7. To Counter
                                                    DataCell(
                                                      SizedBox(
                                                        width: toCounterWidth,
                                                        child: DropdownButtonHideUnderline(
                                                          child: DropdownButton<String>(
                                                            value: _dropdownCounters.contains(displayToCounter) ? displayToCounter : (_dropdownCounters.isNotEmpty ? _dropdownCounters.first : null),
                                                            isExpanded: true,
                                                            items: _dropdownCounters.map((c) {
                                                              return DropdownMenuItem<String>(
                                                                value: c,
                                                                child: Text(c, style: const TextStyle(fontSize: 13, color: _brown)),
                                                              );
                                                            }).toList(),
                                                            onChanged: (newVal) {
                                                              if (newVal != null) {
                                                                setState(() {
                                                                  if (newVal == r.toCounter && !r.docId.startsWith('new_')) {
                                                                    _editedToCounters.remove(r.labelNo);
                                                                  } else {
                                                                    _editedToCounters[r.labelNo] = newVal;
                                                                  }
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // 8. Date
                                                    DataCell(SizedBox(width: dateWidth, child: Text(dateFormat.format(displayDate)))),
                                                    // 9. Status
                                                    DataCell(SizedBox(width: statusWidth, child: Align(alignment: Alignment.centerLeft, child: _buildStatusChip(displayStatus)))),
                                                    // 10. Action
                                                    DataCell(
                                                      SizedBox(
                                                        width: actionWidth,
                                                        child: DropdownButtonHideUnderline(
                                                          child: DropdownButton<String>(
                                                            value: 'Action',
                                                            items: const [
                                                              DropdownMenuItem(value: 'Action', child: Text('Action', style: TextStyle(fontSize: 13, color: Colors.grey))),
                                                              DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold))),
                                                              DropdownMenuItem(value: 'Cancel', child: Text('Cancel', style: TextStyle(fontSize: 13, color: Colors.red))),
                                                            ],
                                                            onChanged: (val) async {
                                                              if (val == 'Completed') {
                                                                await _saveRowAsCompleted(r);
                                                              } else if (val == 'Cancel') {
                                                                _cancelRowEdit(r);
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
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
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.grey[200]!;
    Color text = Colors.grey[800]!;

    if (status == 'COMPLETED') {
      bg = Colors.green[50]!;
      text = Colors.green[800]!;
    } else if (status == 'DRAFT') {
      bg = Colors.orange[50]!;
      text = Colors.orange[800]!;
    } else if (status == 'CANCELLED') {
      bg = Colors.red[50]!;
      text = Colors.red[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}