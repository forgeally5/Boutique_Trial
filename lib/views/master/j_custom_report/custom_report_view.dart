// custom_report_view.dart
// J Custom Report — A (Custom User Report)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../report_shared.dart';

const _br  = Color(0xFF3E2723);
const _brL = Color(0xFF6D4C41);
const _bdr = Color(0xFFE5DDD0);
const _bg0 = Color(0xFFFDFBF7);

Widget _gLoader = const Center(child: CircularProgressIndicator(color: _br));
String _ffmt(double v)  => NumberFormat('#,##,##0.00', 'en_IN').format(v);

class CustomUserReportView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const CustomUserReportView({super.key, this.onReportSelected});
  @override State<CustomUserReportView> createState() => _CustomUserReportState();
}

class _CustomUserReportState extends State<CustomUserReportView> {
  final List<Map<String, String>> _collections = [
    {'id': 'bills', 'name': 'Bills / Invoices'},
    {'id': 'jewelry_inventory', 'name': 'Jewelry Inventory'},
    {'id': 'customers', 'name': 'Customers Master'},
    {'id': 'suppliers', 'name': 'Suppliers Master'},
    {'id': 'order_entries', 'name': 'Customer Orders'},
    {'id': 'repairing_entries', 'name': 'Repairing Jobs'},
    {'id': 'journal_entries', 'name': 'Journal Entries'},
    {'id': 'cash_entries', 'name': 'Cash Book Entries'},
    {'id': 'bank_entries', 'name': 'Bank Book Entries'},
  ];

  String _selectedCollection = 'bills';
  bool _loading = true;
  List<Map<String, dynamic>> _allDocs = [];
  List<String> _detectedKeys = [];
  List<String> _selectedColumns = [];
  final _sc = TextEditingController();
  String _q = '';

  @override void initState() {
    super.initState();
    _loadCollectionData();
  }

  @override void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionData() async {
    setState(() {
      _loading = true;
      _allDocs = [];
      _detectedKeys = [];
      _selectedColumns = [];
    });

    try {
      final snap = await FirebaseFirestore.instance.collection(_selectedCollection).get();
      final List<Map<String, dynamic>> docs = [];
      final Set<String> keys = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        d['_id'] = doc.id; // Store ID with underscore to avoid conflict
        docs.add(d);

        // Collect all keys
        for (final k in d.keys) {
          if (k != 'id' && k != '_id' && k != 'createdAt') {
            keys.add(k);
          }
        }
      }

      // Convert keys set to sorted list
      final sortedKeys = keys.toList()..sort();
      
      // Default columns to select (take first 5-6 columns to avoid clutter)
      final List<String> defaultCols = [];
      final preferred = ['voucherNo', 'billNo', 'date', 'voucherDate', 'name', 'customerName', 'partyName', 'itemName', 'netWeight', 'grossWeight', 'amount', 'totalAmt', 'phone', 'mobile'];
      
      for (final p in preferred) {
        if (sortedKeys.contains(p)) {
          defaultCols.add(p);
        }
      }
      
      for (final k in sortedKeys) {
        if (!defaultCols.contains(k) && defaultCols.length < 6) {
          defaultCols.add(k);
        }
      }

      if (defaultCols.isEmpty && sortedKeys.isNotEmpty) {
        defaultCols.addAll(sortedKeys.take(5));
      }

      if (mounted) {
        setState(() {
          _allDocs = docs;
          _detectedKeys = sortedKeys;
          _selectedColumns = defaultCols;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dynamic custom report: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load collection: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _allDocs;
    return _allDocs.where((doc) {
      for (final val in doc.values) {
        if (val != null && val.toString().toLowerCase().contains(_q)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  String _formatVal(dynamic val) {
    if (val == null) return '—';
    if (val is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(val.toDate());
    }
    if (val is num) {
      // Check if it's double and looks like weight or amount
      if (val is double) {
        return val.toStringAsFixed(3);
      }
      return val.toString();
    }
    if (val is List) {
      return '${val.length} items';
    }
    if (val is Map) {
      if (val.containsKey('name')) return val['name'].toString();
      return val.values.take(2).join(', ');
    }
    return val.toString();
  }

  bool _isNumeric(dynamic val) {
    if (val is num) return true;
    if (val == null) return false;
    final str = val.toString();
    return double.tryParse(str) != null;
  }

  double _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _showColumnSelector() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Choose Display Columns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _br)),
          content: SizedBox(
            width: 320,
            child: _detectedKeys.isEmpty
                ? const Text('No fields detected in this collection.', style: TextStyle(fontSize: 12, color: Colors.grey))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _detectedKeys.map((key) {
                        final isSel = _selectedColumns.contains(key);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: _br,
                          title: Text(key, style: const TextStyle(fontSize: 12)),
                          value: isSel,
                          onChanged: (bool? val) {
                            if (val == true) {
                              if (!_selectedColumns.contains(key)) {
                                _selectedColumns.add(key);
                              }
                            } else {
                              _selectedColumns.remove(key);
                            }
                            setDlgState(() {});
                            setState(() {}); // Update main screen table in real-time
                          },
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedColumns = List.from(_detectedKeys);
                });
                setDlgState(() {});
              },
              child: const Text('Select All', style: TextStyle(fontSize: 12, color: _brL)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedColumns.clear();
                });
                setDlgState(() {});
              },
              child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: _br, foregroundColor: Colors.white),
              child: const Text('Done', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.analytics_rounded, size: 17, color: _br),
              const SizedBox(width: 8),
              buildTitleDropdown(
                context: context,
                currentTitle: 'Custom User Report',
                onSelected: (newTitle) {
                  widget.onReportSelected?.call(newTitle);
                },
                textColor: _br,
                fontSize: 14,
                bold: true,
              ),
              const SizedBox(width: 15),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _bdr),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCollection,
                    icon: const Icon(Icons.arrow_drop_down, color: _brL, size: 18),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _br),
                    dropdownColor: Colors.white,
                    items: _collections.map((col) {
                      return DropdownMenuItem<String>(
                        value: col['id'],
                        child: Text(col['name']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCollection = val;
                        });
                        _loadCollectionData();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                child: Text('${list.length} rows',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              ),
              const Spacer(),
              SizedBox(
                width: 190, height: 32,
                child: TextField(
                  controller: _sc,
                  onChanged: (v) => setState(() => _q = v.toLowerCase()),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search collection...',
                    hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 13, color: _brL),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showColumnSelector,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brL,
                  side: const BorderSide(color: _bdr),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                ),
                icon: const Icon(Icons.view_column_rounded, size: 13),
                label: Text('Columns (${_selectedColumns.length}/${_detectedKeys.length})',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _loadCollectionData,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: _brL),
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _bdr),
        Expanded(
          child: _loading
              ? _gLoader
              : _buildReportBody(list),
        ),
      ],
    );
  }

  Widget _buildReportBody(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('No records found in "$_selectedCollection"', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    if (_selectedColumns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('Please select columns to display', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showColumnSelector,
              style: ElevatedButton.styleFrom(backgroundColor: _br, foregroundColor: Colors.white),
              child: const Text('Choose Columns', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    // Dynamic width calculation based on number of columns
    // We will assign flex layout or fixed widths.
    // Let's divide equally or assign width based on key name.

    // Let's calculate sums for visible columns that are numeric
    final Map<String, double> sums = {};
    for (final col in _selectedColumns) {
      bool isNum = true;
      double sum = 0.0;
      for (final doc in list) {
        final val = doc[col];
        if (!_isNumeric(val)) {
          isNum = false;
          break;
        }
        sum += _asDouble(val);
      }
      if (isNum && list.isNotEmpty) {
        sums[col] = sum;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: _bg0,
          border: Border.all(color: _bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // Table Header Row
            Container(
              color: _br.withAlpha(18),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: const Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
                  ),
                  ..._selectedColumns.map((col) {
                    final isR = sums.containsKey(col);
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Text(
                          _formatHeader(col),
                          textAlign: isR ? TextAlign.right : TextAlign.left,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: _bdr),
            
            // Table Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: list.asMap().entries.map((entry) {
                    final i = entry.key;
                    final doc = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.white : const Color(0xFFFAF7F3),
                        border: const Border(bottom: BorderSide(color: _bdr, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ),
                          ..._selectedColumns.map((col) {
                            final val = doc[col];
                            final formatted = _formatVal(val);
                            final isR = sums.containsKey(col);
                            final isVNo = col.toLowerCase().contains('no') || col.toLowerCase().contains('id');
                            return Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                alignment: isR ? Alignment.centerRight : Alignment.centerLeft,
                                child: Text(
                                  formatted,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isVNo ? FontWeight.bold : FontWeight.normal,
                                    color: isVNo ? _br : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Summary Totals Row (Only show if at least one column has a sum)
            if (sums.isNotEmpty) ...[
              const Divider(height: 1, color: _bdr),
              Container(
                color: _br.withAlpha(14),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: const Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _br)),
                    ),
                    ..._selectedColumns.map((col) {
                      final hasSum = sums.containsKey(col);
                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Text(
                            hasSum ? _ffmt(sums[col]!) : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _br),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatHeader(String key) {
    if (key.length <= 3) return key.toUpperCase();
    
    // Convert camelCase to title case
    final regex = RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])');
    final parts = key.split(regex);
    return parts.map((p) {
      if (p.isEmpty) return '';
      return p[0].toUpperCase() + p.substring(1);
    }).join(' ');
  }
}
