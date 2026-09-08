import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../state/admin_state.dart';
import '../../../utils/pdf_outsource_manufacturing.dart';
import 'outsource_manufacturing_model.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

Widget buildStatusChip(String status) {
  Color bg = Colors.grey[50]!;
  Color text = Colors.grey[800]!;
  Color border = Colors.grey[300]!;

  final normalized = status.toUpperCase();
  if (normalized == 'ON PROCESS' || normalized == 'DRAFT') {
    bg = Colors.orange[50]!;
    text = Colors.orange[800]!;
    border = Colors.orange[200]!;
  } else if (normalized == 'COMPLETED') {
    bg = Colors.green[50]!;
    text = Colors.green[800]!;
    border = Colors.green[200]!;
  } else if (normalized == 'CONVERTED TO SALE' ||
      normalized == 'CONVERTED_TO_SALE') {
    bg = Colors.purple[50]!;
    text = Colors.purple[800]!;
    border = Colors.purple[200]!;
  } else if (normalized == 'RETURNED') {
    bg = Colors.blue[50]!;
    text = Colors.blue[800]!;
    border = Colors.blue[200]!;
  } else if (normalized == 'CANCELLED') {
    bg = Colors.red[50]!;
    text = Colors.red[800]!;
    border = Colors.red[200]!;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: border),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
    ),
  );
}

class OutsourceManufacturingView extends StatefulWidget {
  final AdminState state;

  const OutsourceManufacturingView({super.key, required this.state});

  @override
  State<OutsourceManufacturingView> createState() =>
      _OutsourceManufacturingViewState();
}

class _OutsourceManufacturingViewState
    extends State<OutsourceManufacturingView> {
  final List<OutsourceManufacturing> _records = [];
  bool _isLoading = false;

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  OutsourceManufacturing? _selectedRecord;
  bool _processOnly = false;
  List<String> _artisans = [];
  String _selectedArtisan = 'All';

  @override
  void initState() {
    super.initState();
    _fetchRecords();
    _loadArtisans();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('outsource_manufacturing_entries')
          .orderBy('createdAt', descending: true)
          .get();

      final fetched = snap.docs
          .map((doc) => OutsourceManufacturing.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(fetched);
        });
      }
    } catch (e) {
      debugPrint('Firestore load error (using local state): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadArtisans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('suppliers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        _artisans = ['All', ...list.toSet()];
      });
    } catch (e) {
      debugPrint("Error loading suppliers for filter: $e");
    }
  }

  void _convertIssueToReceipt(OutsourceManufacturing issue) {
    final receiptRecord = OutsourceManufacturing(
      docId: '',
      transactionNo: _generateNextTxNumber('Outsource Receipt'),
      date: DateTime.now(),
      transactionType: 'Outsource Receipt',
      artisanName: issue.artisanName,
      referenceNo: issue.transactionNo,
      items: issue.items.map((item) {
        return OutsourceManufacturingItem(
          tagId: item.tagId,
          itemName: item.itemName,
          quantity: item.quantity,
          grossWeight: item.grossWeight,
          stoneWeight: item.stoneWeight,
          netWeight: item.netWeight,
          purity: item.purity,
          fineWeight: item.fineWeight,
          wastageWeight: item.wastageWeight,
          labourRate: item.labourRate,
          labourType: item.labourType,
          remarks: item.remarks,
          extraCharges: List.from(item.extraCharges),
        );
      }).toList(),
      totalGrossWeight: issue.totalGrossWeight,
      totalNetWeight: issue.totalNetWeight,
      totalFineWeight: issue.totalFineWeight,
      totalQuantity: issue.totalQuantity,
      remarks: 'Converted from Issue ${issue.transactionNo}',
      status: 'ON PROCESS',
      isReverseCharge: issue.isReverseCharge,
      isTdsApplicable: issue.isTdsApplicable,
      gstPercent: issue.gstPercent,
      tdsPercent: issue.tdsPercent,
      totalLabourAmt: issue.totalLabourAmt,
      cgstAmt: issue.cgstAmt,
      sgstAmt: issue.sgstAmt,
      tdsAmt: issue.tdsAmt,
      netPayableAmt: issue.netPayableAmt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _openEntryDialog(receiptRecord);
  }

  Widget _buildFilterRow(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    bool isPrimary = false,
  }) {
    final uniqueItems = items.toSet().toList();
    String displayValue = value;
    if (!uniqueItems.contains(displayValue)) {
      if (uniqueItems.contains('All')) {
        displayValue = 'All';
      } else if (uniqueItems.isNotEmpty) {
        displayValue = uniqueItems.first;
      } else {
        uniqueItems.add(displayValue);
      }
    }

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _brownLight,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: displayValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                  size: 16,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ),
                onChanged: onChanged,
                items: uniqueItems
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPrimary && displayValue == item
                                ? _brown
                                : Colors.black,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(
    String label,
    String value, {
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _brownLight,
              ),
            ),
          ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.grey,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    const btnBg = Color(0xFFF4F0E8);
    final isEnabled = onTap != null;
    return Material(
      color: isEnabled ? btnBg : btnBg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(
              color: _border.withValues(alpha: isEnabled ? 1.0 : 0.5),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isEnabled ? (iconColor ?? _brown) : Colors.grey,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: isEnabled ? _brown : Colors.grey,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<OutsourceManufacturing> get _filteredRecords {
    return _records.where((r) {
      final matchSearch =
          _searchQuery.isEmpty ||
          r.transactionNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.artisanName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.referenceNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.items.any(
            (item) => item.itemName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          );

      final matchType =
          _typeFilter == 'All' ||
          r.transactionType.toLowerCase() == _typeFilter.toLowerCase();

      final matchStatus =
          _statusFilter == 'All' ||
          r.status.toLowerCase() == _statusFilter.toLowerCase() ||
          (_statusFilter == 'ON PROCESS' && r.status.toLowerCase() == 'draft');

      final matchArtisan =
          _selectedArtisan == 'All' || r.artisanName == _selectedArtisan;

      final matchProcessOnly =
          !_processOnly ||
          r.status.toUpperCase() == 'ON PROCESS' ||
          r.status.toUpperCase() == 'DRAFT' ||
          r.status.toUpperCase() == 'PENDING';

      bool matchDate = true;
      if (_fromDate != null) {
        matchDate =
            matchDate &&
            r.date.isAfter(_fromDate!.subtract(const Duration(days: 1)));
      }
      if (_toDate != null) {
        matchDate =
            matchDate && r.date.isBefore(_toDate!.add(const Duration(days: 1)));
      }

      return matchSearch &&
          matchType &&
          matchStatus &&
          matchArtisan &&
          matchProcessOnly &&
          matchDate;
    }).toList();
  }

  String _generateNextTxNumber(String type) {
    final prefix = type.toLowerCase().contains('receipt') ? 'OR-' : 'OI-';
    final count =
        _records.where((r) => r.transactionNo.startsWith(prefix)).length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  void _openEntryDialog([OutsourceManufacturing? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OutsourceManufacturingFormDialog(
        existing: existing,
        generateTxNo: _generateNextTxNumber,
        state: widget.state,
        onSave: (record) async {
          try {
            if (existing == null) {
              final docRef = await FirebaseFirestore.instance
                  .collection('outsource_manufacturing_entries')
                  .add(record.toMap());
              final newRecord = OutsourceManufacturing.fromMap(
                record.toMap(),
                docRef.id,
              );
              setState(() => _records.insert(0, newRecord));
            } else {
              await FirebaseFirestore.instance
                  .collection('outsource_manufacturing_entries')
                  .doc(existing.docId)
                  .update(record.toMap());
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) {
                setState(() => _records[idx] = record);
              }
            }

            // Manage Inventory Piece Preservation
            try {
              if (record.isIssue) {
                for (var item in record.items) {
                  if (item.tagId.isNotEmpty) {
                    await ProductRepository().markPiecePreserved(
                      tagId: item.tagId,
                      transactionType: 'Outsource Issue',
                      transactionNo: record.transactionNo,
                    );
                  }
                }
              } else {
                for (var item in record.items) {
                  if (item.tagId.isNotEmpty) {
                    await ProductRepository().markPieceAvailable(tagId: item.tagId);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error updating outsource inventory preservation: $e');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Job Transaction ${record.transactionNo} saved successfully!',
                  ),
                  backgroundColor: Colors.green[800],
                ),
              );
            }
          } catch (e) {
            // Local fallback
            if (existing == null) {
              setState(() => _records.insert(0, record));
            } else {
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) setState(() => _records[idx] = record);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Saved locally: ${record.transactionNo}'),
                  backgroundColor: _brown,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _cancelRecord(OutsourceManufacturing r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Entry?'),
        content: Text(
          'Are you sure you want to cancel the job transaction ${r.transactionNo}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('outsource_manufacturing_entries')
            .doc(r.docId)
            .update({'status': 'CANCELLED', 'updatedAt': Timestamp.now()});
        if (r.isIssue) {
          for (var item in r.items) {
            if (item.tagId.isNotEmpty) {
              await ProductRepository().markPieceAvailable(tagId: item.tagId);
            }
          }
        }

        final idx = _records.indexWhere((rec) => rec.docId == r.docId);
        if (idx != -1) {
          setState(() {
            _records[idx] = OutsourceManufacturing(
              docId: r.docId,
              transactionNo: r.transactionNo,
              date: r.date,
              transactionType: r.transactionType,
              artisanName: r.artisanName,
              referenceNo: r.referenceNo,
              items: r.items,
              totalGrossWeight: r.totalGrossWeight,
              totalNetWeight: r.totalNetWeight,
              totalFineWeight: r.totalFineWeight,
              totalQuantity: r.totalQuantity,
              remarks: r.remarks,
              status: 'CANCELLED',
              createdAt: r.createdAt,
              updatedAt: DateTime.now(),
            );
          });
        }
      } catch (e) {
        // Fallback locally
        final idx = _records.indexWhere((rec) => rec.docId == r.docId);
        if (idx != -1) {
          setState(() {
            _records[idx] = OutsourceManufacturing(
              docId: r.docId,
              transactionNo: r.transactionNo,
              date: r.date,
              transactionType: r.transactionType,
              artisanName: r.artisanName,
              referenceNo: r.referenceNo,
              items: r.items,
              totalGrossWeight: r.totalGrossWeight,
              totalNetWeight: r.totalNetWeight,
              totalFineWeight: r.totalFineWeight,
              totalQuantity: r.totalQuantity,
              remarks: r.remarks,
              status: 'CANCELLED',
              createdAt: r.createdAt,
              updatedAt: DateTime.now(),
            );
          });
        }
      }
    }
  }

  void _showViewDetailsDialog(OutsourceManufacturing r) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Job Details - ${r.transactionNo}',
              style: const TextStyle(
                color: _brown,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            _buildStatusChip(r.status),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow('Date', dateFormat.format(r.date)),
                  ),
                  Expanded(
                    child: _buildDetailRow('Artisan Name', r.artisanName),
                  ),
                  Expanded(child: _buildDetailRow('Type', r.transactionType)),
                  Expanded(
                    child: _buildDetailRow(
                      'Reference No',
                      r.referenceNo.isEmpty ? '-' : r.referenceNo,
                    ),
                  ),
                ],
              ),
              const Divider(color: _border),
              const SizedBox(height: 8),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, color: _brown),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: _border),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: _headerBg),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Item Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Gross Wt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Stone Wt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Net Wt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Purity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Fine Wt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Remarks',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...r.items.map(
                        (item) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.itemName,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.quantity.toString(),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.grossWeight.toStringAsFixed(3),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.stoneWeight.toStringAsFixed(3),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.netWeight.toStringAsFixed(3),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.purity.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.fineWeight.toStringAsFixed(3),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.remarks,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: _border),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildDetailRow(
                    'Total Qty',
                    r.totalQuantity.toString(),
                    isBold: true,
                  ),
                  const SizedBox(width: 20),
                  _buildDetailRow(
                    'Total Gross Wt',
                    '${r.totalGrossWeight.toStringAsFixed(3)} g',
                    isBold: true,
                  ),
                  const SizedBox(width: 20),
                  _buildDetailRow(
                    'Total Net Wt',
                    '${r.totalNetWeight.toStringAsFixed(3)} g',
                    isBold: true,
                  ),
                  const SizedBox(width: 20),
                  _buildDetailRow(
                    'Total Fine Wt',
                    '${r.totalFineWeight.toStringAsFixed(3)} g',
                    isBold: true,
                  ),
                ],
              ),
              if (r.remarks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Remarks: ${r.remarks}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16, color: _brown),
            label: const Text('PDF / Print', style: TextStyle(color: _brown)),
            onPressed: () {
              Navigator.pop(ctx);
              PdfOutsourceManufacturing.printPdf(r);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brown,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C41)),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? _brown : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: _brown,
          ),
        ),
      ),
    );
  }

  Widget _buildRowCell(
    String text, {
    int flex = 2,
    bool isBold = false,
    Color? color,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
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
            padding: const EdgeInsets.all(12),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters (Left)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterRow(
                              'Artisan',
                              _selectedArtisan,
                              _artisans,
                              (val) => setState(() {
                                _selectedArtisan = val!;
                                _selectedRecord = null;
                              }),
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFilterRow(
                              'Type',
                              _typeFilter,
                              ['All', 'Outsource Issue', 'Outsource Receipt'],
                              (val) => setState(() {
                                _typeFilter = val!;
                                _selectedRecord = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterRow(
                              'Status',
                              _statusFilter,
                              [
                                'All',
                                'ON PROCESS',
                                'COMPLETED',
                                'CONVERTED TO SALE',
                                'RETURNED',
                                'CANCELLED',
                              ],
                              (val) => setState(() {
                                _statusFilter = val!;
                                _selectedRecord = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildDateTile(
                                    'Date From',
                                    _fromDate == null
                                        ? '-'
                                        : dateFormat.format(_fromDate!),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _fromDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _fromDate = picked;
                                          _selectedRecord = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'To',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _brown,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDateTile(
                                    '',
                                    _toDate == null
                                        ? '-'
                                        : dateFormat.format(_toDate!),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _toDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _toDate = picked;
                                          _selectedRecord = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 26,
                              child: TextField(
                                onChanged: (v) => setState(() {
                                  _searchQuery = v;
                                  _selectedRecord = null;
                                }),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search by Tx No, Artisan, Item...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: _brownLight,
                                    size: 14,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: _brown),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _processOnly
                                  ? _brown
                                  : Colors.white,
                              side: BorderSide(
                                color: _processOnly ? _brown : _border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: () => setState(() {
                              _processOnly = !_processOnly;
                              _selectedRecord = null;
                            }),
                            child: const Text(
                              'ON PROCESS Only',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown,
                              ),
                            ),
                          ),
                          if (_fromDate != null || _toDate != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.red,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _fromDate = null;
                                _toDate = null;
                                _selectedRecord = null;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Action Buttons (Right)
                Row(
                  children: [
                    _buildActionButton(
                      Icons.add,
                      'Add',
                      onTap: () {
                        setState(() => _selectedRecord = null);
                        _openEntryDialog();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.edit,
                      'Modify',
                      iconColor: Colors.blue,
                      onTap:
                          _selectedRecord == null ||
                              _selectedRecord!.status == 'CANCELLED'
                          ? null
                          : () => _openEntryDialog(_selectedRecord),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.cancel,
                      'Cancel',
                      iconColor: Colors.red,
                      onTap:
                          _selectedRecord == null ||
                              _selectedRecord!.status == 'CANCELLED'
                          ? null
                          : () => _cancelRecord(_selectedRecord!),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.swap_horiz,
                      'Convert\nReceipt',
                      iconColor: Colors.green,
                      onTap:
                          _selectedRecord == null ||
                              _selectedRecord!.transactionType !=
                                  'Outsource Issue' ||
                              _selectedRecord!.status == 'CANCELLED'
                          ? null
                          : () => _convertIssueToReceipt(_selectedRecord!),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.print,
                      'Print',
                      iconColor: Colors.teal,
                      onTap: _selectedRecord == null
                          ? null
                          : () => PdfOutsourceManufacturing.printPdf(
                              _selectedRecord!,
                            ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.visibility,
                      'View',
                      iconColor: Colors.deepPurple,
                      onTap: _selectedRecord == null
                          ? null
                          : () => _showViewDetailsDialog(_selectedRecord!),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.refresh,
                      'Refresh',
                      iconColor: Colors.green,
                      onTap: () {
                        setState(() => _selectedRecord = null);
                        _fetchRecords();
                      },
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
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Headers
                  Container(
                    color: _headerBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Transaction No', flex: 2),
                        _buildHeaderCell('Date', flex: 2),
                        _buildHeaderCell('Type', flex: 2),
                        _buildHeaderCell('Artisan', flex: 2),
                        _buildHeaderCell('Items', flex: 1),
                        _buildHeaderCell('Total Qty', flex: 1),
                        _buildHeaderCell('Total Gross (g)', flex: 2),
                        _buildHeaderCell('Total Net (g)', flex: 2),
                        _buildHeaderCell('Total Fine (g)', flex: 2),
                        _buildHeaderCell('Status', flex: 2),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  // Table Body
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _brown),
                          )
                        : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No Outsource Manufacturing entries found.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final isEven = index % 2 == 0;
                              final isSelected =
                                  _selectedRecord?.docId == entry.docId;

                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (isSelected) {
                                    _selectedRecord = null;
                                  } else {
                                    _selectedRecord = entry;
                                  }
                                }),
                                onDoubleTap: () =>
                                    _showViewDetailsDialog(entry),
                                child: Container(
                                  color: isSelected
                                      ? const Color(0xFFFDF6ED)
                                      : (isEven ? Colors.white : _headerBg),
                                  child: Row(
                                    children: [
                                      _buildRowCell(
                                        entry.transactionNo,
                                        flex: 2,
                                        isBold: true,
                                      ),
                                      _buildRowCell(
                                        dateFormat.format(entry.date),
                                        flex: 2,
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: entry.isIssue
                                                  ? Colors.blue[50]
                                                  : Colors.green[50],
                                              border: Border.all(
                                                color: entry.isIssue
                                                    ? Colors.blue[300]!
                                                    : Colors.green[400]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              entry.transactionType,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: entry.isIssue
                                                    ? Colors.blue[900]
                                                    : Colors.green[900],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildRowCell(entry.artisanName, flex: 2),
                                      _buildRowCell(
                                        '${entry.items.length}',
                                        flex: 1,
                                      ),
                                      _buildRowCell(
                                        '${entry.totalQuantity}',
                                        flex: 1,
                                      ),
                                      _buildRowCell(
                                        entry.totalGrossWeight.toStringAsFixed(
                                          3,
                                        ),
                                        flex: 2,
                                      ),
                                      _buildRowCell(
                                        entry.totalNetWeight.toStringAsFixed(3),
                                        flex: 2,
                                        isBold: true,
                                      ),
                                      _buildRowCell(
                                        entry.totalFineWeight.toStringAsFixed(
                                          3,
                                        ),
                                        flex: 2,
                                        isBold: true,
                                        color: Colors.brown,
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: () {
                                                String currentStatus = entry
                                                    .status
                                                    .toUpperCase();
                                                if (currentStatus == 'DRAFT' ||
                                                    currentStatus == 'ISSUED' ||
                                                    currentStatus ==
                                                        'PARTIALLY RECEIVED' ||
                                                    currentStatus ==
                                                        'PARTIALLY_RECEIVED' ||
                                                    currentStatus ==
                                                        'PENDING') {
                                                  currentStatus = 'ON PROCESS';
                                                }
                                                if (currentStatus ==
                                                    'CONVERTED_TO_SALE') {
                                                  currentStatus =
                                                      'CONVERTED TO SALE';
                                                }
                                                return currentStatus;
                                              }(),
                                              isDense: true,
                                              elevation: 2,
                                              icon: const Icon(
                                                Icons.arrow_drop_down,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              items:
                                                  <String>[
                                                    'ON PROCESS',
                                                    'COMPLETED',
                                                    'CONVERTED TO SALE',
                                                    'RETURNED',
                                                    'CANCELLED',
                                                  ].map<
                                                    DropdownMenuItem<String>
                                                  >((String value) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: value,
                                                      child: buildStatusChip(
                                                        value,
                                                      ),
                                                    );
                                                  }).toList(),
                                              onChanged: (String? newValue) async {
                                                if (newValue != null &&
                                                    newValue != entry.status) {
                                                  try {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection(
                                                          'outsource_manufacturing_entries',
                                                        )
                                                        .doc(entry.docId)
                                                        .update({
                                                          'status': newValue,
                                                          'updatedAt':
                                                              Timestamp.now(),
                                                        });

                                                    final updatedRecord =
                                                        OutsourceManufacturing(
                                                          docId: entry.docId,
                                                          transactionNo: entry
                                                              .transactionNo,
                                                          date: entry.date,
                                                          transactionType: entry
                                                              .transactionType,
                                                          artisanName:
                                                              entry.artisanName,
                                                          referenceNo:
                                                              entry.referenceNo,
                                                          items: entry.items,
                                                          totalGrossWeight: entry
                                                              .totalGrossWeight,
                                                          totalNetWeight: entry
                                                              .totalNetWeight,
                                                          totalFineWeight: entry
                                                              .totalFineWeight,
                                                          totalQuantity: entry
                                                              .totalQuantity,
                                                          remarks:
                                                              entry.remarks,
                                                          status: newValue,
                                                          isReverseCharge: entry
                                                              .isReverseCharge,
                                                          isTdsApplicable: entry
                                                              .isTdsApplicable,
                                                          gstPercent:
                                                              entry.gstPercent,
                                                          tdsPercent:
                                                              entry.tdsPercent,
                                                          totalLabourAmt: entry
                                                              .totalLabourAmt,
                                                          cgstAmt:
                                                              entry.cgstAmt,
                                                          sgstAmt:
                                                              entry.sgstAmt,
                                                          tdsAmt: entry.tdsAmt,
                                                          netPayableAmt: entry
                                                              .netPayableAmt,
                                                          createdAt:
                                                              entry.createdAt,
                                                          updatedAt:
                                                              DateTime.now(),
                                                        );

                                                    setState(() {
                                                      final idx = _records
                                                          .indexWhere(
                                                            (rec) =>
                                                                rec.docId ==
                                                                entry.docId,
                                                          );
                                                      if (idx != -1) {
                                                        _records[idx] =
                                                            updatedRecord;
                                                      }
                                                      if (_selectedRecord
                                                              ?.docId ==
                                                          entry.docId) {
                                                        _selectedRecord =
                                                            updatedRecord;
                                                      }
                                                    });
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Status updated to $newValue',
                                                        ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error updating status: $e',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
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

                  // Bottom Summary Row
                  const Divider(height: 1, color: _border, thickness: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: _headerBg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${filtered.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return buildStatusChip(status);
  }
}

class OutsourceSubBillingRow {
  String styleName;
  final TextEditingController weightController = TextEditingController();
  final TextEditingController pcsController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  OutsourceSubBillingRow({
    this.styleName = 'Less Wt',
    String weight = '0.000',
    String pcs = '1',
    String remarks = '',
  }) {
    weightController.text = weight;
    pcsController.text = pcs;
    remarksController.text = remarks;
  }

  void dispose() {
    weightController.dispose();
    pcsController.dispose();
    remarksController.dispose();
  }
}

// Controller for each item row in the outsource manufacturing list
class OutsourceItemRowController {
  final TextEditingController tagIdCtrl;
  final TextEditingController itemNameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController grossWtCtrl;
  bool otherWtChecked;
  final TextEditingController
  stoneWtCtrl; // mapped internally to otherWeight/stoneWeight
  final TextEditingController netWtCtrl;
  final TextEditingController purityCtrl;
  final TextEditingController fineWtCtrl;
  final TextEditingController wastageWtCtrl;
  final TextEditingController remarksCtrl;
  final List<OutsourceSubBillingRow> subRows = [];

  OutsourceItemRowController({
    String tagId = '',
    String itemName = '',
    String qty = '1',
    String grossWt = '0.000',
    required this.otherWtChecked,
    String stoneWt = '0.000',
    String netWt = '0.000',
    String purity = '916.0',
    String fineWt = '0.000',
    String wastageWt = '0.000',
    String remarks = '',
  }) : tagIdCtrl = TextEditingController(text: tagId),
       itemNameCtrl = TextEditingController(text: itemName),
       qtyCtrl = TextEditingController(text: qty),
       grossWtCtrl = TextEditingController(text: grossWt),
       stoneWtCtrl = TextEditingController(text: stoneWt),
       netWtCtrl = TextEditingController(text: netWt),
       purityCtrl = TextEditingController(text: purity),
       fineWtCtrl = TextEditingController(text: fineWt),
       wastageWtCtrl = TextEditingController(text: wastageWt),
       remarksCtrl = TextEditingController(text: remarks);

  void dispose() {
    tagIdCtrl.dispose();
    itemNameCtrl.dispose();
    qtyCtrl.dispose();
    grossWtCtrl.dispose();
    stoneWtCtrl.dispose();
    netWtCtrl.dispose();
    purityCtrl.dispose();
    fineWtCtrl.dispose();
    wastageWtCtrl.dispose();
    remarksCtrl.dispose();
    for (var sr in subRows) {
      sr.dispose();
    }
  }
}

// Form Dialog Modal Dialog
class _OutsourceManufacturingFormDialog extends StatefulWidget {
  final OutsourceManufacturing? existing;
  final String Function(String type) generateTxNo;
  final Function(OutsourceManufacturing record) onSave;
  final AdminState state;

  const _OutsourceManufacturingFormDialog({
    this.existing,
    required this.generateTxNo,
    required this.onSave,
    required this.state,
  });

  @override
  State<_OutsourceManufacturingFormDialog> createState() =>
      _OutsourceManufacturingFormDialogState();
}

class _OutsourceManufacturingFormDialogState
    extends State<_OutsourceManufacturingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _txNo;
  late DateTime _date;
  String _txType = 'Outsource Issue';
  final _artisanCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _status = 'ON PROCESS';

  final List<OutsourceItemRowController> _itemRows = [];
  bool _isSyncing = false;

  double _totalGross = 0.0;
  double _totalNet = 0.0;
  double _totalFine = 0.0;
  int _totalQty = 0;

  List<String> _suppliers = [];
  List<String> _filteredSuppliers = [];
  bool _isLoadingSuppliers = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _artisanFocusNode = FocusNode();

  final LayerLink _refNoLayerLink = LayerLink();
  OverlayEntry? _refNoOverlayEntry;
  final FocusNode _refNoFocusNode = FocusNode();
  List<String> _matchingIssues = [];
  List<String> _filteredIssues = [];
  bool _isLoadingIssues = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();

    _artisanFocusNode.addListener(() {
      if (_artisanFocusNode.hasFocus) {
        _showOverlay();
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _hideOverlay();
          }
        });
      }
    });

    _artisanCtrl.addListener(() {
      final text = _artisanCtrl.text.trim().toLowerCase();
      setState(() {
        _filteredSuppliers = _suppliers
            .where((s) => s.toLowerCase().contains(text))
            .toList();
      });
      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
      }
    });

    _refNoFocusNode.addListener(() {
      if (_refNoFocusNode.hasFocus) {
        _fetchMatchingIssues();
        _showRefNoOverlay();
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _hideRefNoOverlay();
            _loadReferencedIssueDetails(_refNoCtrl.text);
          }
        });
      }
    });

    _refNoCtrl.addListener(() {
      final text = _refNoCtrl.text.trim().toLowerCase();
      setState(() {
        _filteredIssues = _matchingIssues
            .where((s) => s.toLowerCase().contains(text))
            .toList();
      });
      if (_refNoOverlayEntry != null) {
        _refNoOverlayEntry!.markNeedsBuild();
      }
    });

    if (widget.existing != null) {
      final e = widget.existing!;
      _txNo = e.transactionNo;
      _date = e.date;
      _txType = e.transactionType;
      _artisanCtrl.text = e.artisanName;
      _refNoCtrl.text = e.referenceNo;
      _remarksCtrl.text = e.remarks;
      _status = e.status;

      for (var item in e.items) {
        _addNewItemRow(item: item);
      }
    } else {
      _date = DateTime.now();
      _txNo = widget.generateTxNo(_txType);
      _addNewItemRow();
    }
  }

  void _attachSubRowListeners(
    OutsourceItemRowController parentRow,
    OutsourceSubBillingRow subRow,
  ) {
    subRow.weightController.addListener(() => _syncRowWeights(parentRow));
    subRow.pcsController.addListener(_recalculateTotals);
    subRow.remarksController.addListener(_recalculateTotals);
  }

  void _addNewItemRow({OutsourceManufacturingItem? item}) {
    final hasStone = (item?.stoneWeight ?? 0.0) > 0.0;
    final row = OutsourceItemRowController(
      tagId: item?.tagId ?? '',
      itemName:
          item?.itemName ??
          (_txType == 'Outsource Issue' ? 'Raw Gold Bar' : 'Gold Jewellery'),
      qty: item?.quantity.toString() ?? '1',
      grossWt: item?.grossWeight.toStringAsFixed(3) ?? '0.000',
      otherWtChecked: hasStone || (item?.extraCharges.isNotEmpty ?? false),
      stoneWt: item?.stoneWeight.toStringAsFixed(3) ?? '0.000',
      netWt: item?.netWeight.toStringAsFixed(3) ?? '0.000',
      purity: item?.purity.toStringAsFixed(1) ?? '916.0',
      fineWt: item?.fineWeight.toStringAsFixed(3) ?? '0.000',
      wastageWt: item?.wastageWeight.toStringAsFixed(3) ?? '0.000',
      remarks: item?.remarks ?? '',
    );

    if (item != null && item.extraCharges.isNotEmpty) {
      for (var ec in item.extraCharges) {
        if (ec is Map) {
          final sub = OutsourceSubBillingRow(
            styleName: ec['styleName']?.toString() ?? 'Less Wt',
            weight: ((ec['weight'] ?? 0.0) as num).toDouble().toStringAsFixed(
              3,
            ),
            pcs: (ec['pcs'] ?? 1).toString(),
            remarks: ec['remarks']?.toString() ?? '',
          );
          row.subRows.add(sub);
          _attachSubRowListeners(row, sub);
        }
      }
    } else if (hasStone) {
      final sub = OutsourceSubBillingRow(
        styleName: 'Less Wt',
        weight: item!.stoneWeight.toStringAsFixed(3),
        pcs: '1',
      );
      row.subRows.add(sub);
      _attachSubRowListeners(row, sub);
    }

    setState(() {
      _itemRows.add(row);
    });
    _attachListeners(row);
    _recalculateTotals();
  }

  void _removeRow(int idx) {
    if (_itemRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item row is required.')),
      );
      return;
    }
    setState(() {
      final row = _itemRows.removeAt(idx);
      row.dispose();
    });
    _recalculateTotals();
  }

  void _syncRowWeights(
    OutsourceItemRowController row, {
    bool fromNet = false,
    bool fromOther = false,
  }) {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final gross = double.tryParse(row.grossWtCtrl.text.trim()) ?? 0.0;
      final purity = double.tryParse(row.purityCtrl.text.trim()) ?? 0.0;

      double net;
      double other = 0.0;

      if (row.otherWtChecked) {
        double sumSubWt = 0.0;
        for (var sr in row.subRows) {
          sumSubWt += double.tryParse(sr.weightController.text.trim()) ?? 0.0;
        }
        other = sumSubWt;

        if (fromNet) {
          net = double.tryParse(row.netWtCtrl.text.trim()) ?? gross;
          if (net > gross) net = gross;
          other = (gross - net).clamp(0.0, double.infinity);
          if (row.subRows.isNotEmpty) {
            final firstSubWtStr = other.toStringAsFixed(3);
            if (row.subRows.first.weightController.text != firstSubWtStr) {
              row.subRows.first.weightController.text = firstSubWtStr;
            }
          }
        } else {
          net = (gross - other).clamp(0.0, double.infinity);
        }
      } else {
        if (fromOther) {
          other = double.tryParse(row.stoneWtCtrl.text.trim()) ?? 0.0;
          if (other > gross) other = gross;
          net = (gross - other).clamp(0.0, double.infinity);
        } else {
          other = double.tryParse(row.stoneWtCtrl.text.trim()) ?? 0.0;
          net = (gross - other).clamp(0.0, double.infinity);
        }
      }

      final netStr = net.toStringAsFixed(3);
      if (row.netWtCtrl.text != netStr && !fromNet) {
        row.netWtCtrl.text = netStr;
      }

      final otherStr = other.toStringAsFixed(3);
      if (row.stoneWtCtrl.text != otherStr && !fromOther) {
        row.stoneWtCtrl.text = otherStr;
      }

      final fine = (net * purity / 1000.0).clamp(0.0, double.infinity);
      final fineStr = fine.toStringAsFixed(3);
      if (row.fineWtCtrl.text != fineStr) {
        row.fineWtCtrl.text = fineStr;
      }
    } finally {
      _isSyncing = false;
    }

    _recalculateTotals();
  }

  Future<void> _fetchTagDetails(
    String tagId,
    OutsourceItemRowController row,
  ) async {
    if (tagId.trim().isEmpty) return;
    try {
      String cleanTag = tagId.trim();
      if (cleanTag.startsWith('{') && cleanTag.contains('}')) {
        try {
          final map = jsonDecode(cleanTag.substring(cleanTag.indexOf('{'), cleanTag.lastIndexOf('}') + 1));
          if (map['tagId'] != null) {
            cleanTag = map['tagId'].toString();
          } else if (map['baseTag'] != null) {
            cleanTag = map['baseTag'].toString();
          }
        } catch (_) {}
      } else if (cleanTag.contains('Tag:')) {
        final match = RegExp(r'Tag:\s*([^\r\n]+)').firstMatch(cleanTag);
        if (match != null) cleanTag = match.group(1)!;
      } else if (cleanTag.contains('\n')) {
        final lines = cleanTag
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          String? found;
          for (final line in lines) {
            if (RegExp(r'^[A-Z0-9]+-[A-Z0-9]+').hasMatch(line.toUpperCase())) {
              found = line;
              break;
            }
          }
          cleanTag = found ?? lines.first;
        }
      }

      // Normalize spacing before brackets, e.g. "24B-1 [1]" -> "24B-1[1]"
      cleanTag = cleanTag.replaceAll(RegExp(r'\s+\['), '[');

      cleanTag = cleanTag
          .split('-P')[0]
          .split('-p')[0]
          .split('/P')[0]
          .trim()
          .toUpperCase();

      // Check for duplicate scan
      bool isDuplicate = false;
      for (int i = 0; i < _itemRows.length; i++) {
        if (_itemRows[i] != row &&
            _itemRows[i].tagIdCtrl.text.trim().toUpperCase() == cleanTag) {
          isDuplicate = true;
          break;
        }
      }

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Item "$cleanTag" is already added to this outsource order.',
              ),
              backgroundColor: const Color(0xFFC0392B),
            ),
          );
        }
        row.tagIdCtrl.clear();
        return;
      }

      Future<DocumentSnapshot<Map<String, dynamic>>> queryDb(String tag) async {
        DocumentSnapshot<Map<String, dynamic>> d = await FirebaseFirestore
            .instance
            .collection('jewelry_inventory')
            .doc(tag)
            .get();
        if (!d.exists || d.data() == null) {
          final snapTag = await FirebaseFirestore.instance
              .collection('jewelry_inventory')
              .where('tagId', isEqualTo: tag)
              .limit(1)
              .get();
          if (snapTag.docs.isNotEmpty) {
            d = snapTag.docs.first;
          } else {
            final snapBarcode = await FirebaseFirestore.instance
                .collection('jewelry_inventory')
                .where('barcode', isEqualTo: tag)
                .limit(1)
                .get();
            if (snapBarcode.docs.isNotEmpty) {
              d = snapBarcode.docs.first;
            }
          }
        }
        return d;
      }

      DocumentSnapshot<Map<String, dynamic>> doc = await queryDb(cleanTag);
      if (!doc.exists || doc.data() == null) {
        String baseTag = cleanTag;
        final match = RegExp(r'^(.+?)\[\d+\]$').firstMatch(cleanTag);
        if (match != null) {
          baseTag = match.group(1)!.trim();
        }
        if (baseTag != cleanTag) {
          doc = await queryDb(baseTag);
        }
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        List<Map<String, dynamic>> piecesList = [];
        if (data['pieces'] is List) {
          piecesList = List<Map<String, dynamic>>.from(
            (data['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
          );
        }

        if (piecesList.isNotEmpty && piecesList.any((p) => (p['tagId'] ?? '').toString().contains('['))) {
          final pieceMatch = piecesList.firstWhere(
            (p) => (p['tagId'] ?? '').toString().trim().toUpperCase() == cleanTag,
            orElse: () => {},
          );
          if (pieceMatch.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Please enter or scan the specific piece tag (e.g. $cleanTag[1], $cleanTag[2]). Base tag "$cleanTag" cannot be selected directly.'),
                  backgroundColor: const Color(0xFFC0392B),
                ),
              );
            }
            row.tagIdCtrl.clear();
            return;
          }
          if ((pieceMatch['status'] ?? '').toString().toLowerCase() == 'sold') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Piece "$cleanTag" is already SOLD!'),
                  backgroundColor: const Color(0xFFC0392B),
                ),
              );
            }
            row.tagIdCtrl.clear();
            return;
          }
          if (_txType.toLowerCase().contains('issue') && (pieceMatch['status'] ?? '').toString().toLowerCase() == 'preserved') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Piece "$cleanTag" is currently PRESERVED (already issued in another transaction)!'),
                  backgroundColor: const Color(0xFFC0392B),
                ),
              );
            }
            row.tagIdCtrl.clear();
            return;
          }
        }

        row.tagIdCtrl.text = cleanTag;
        final gross = (data['grossWeight'] ?? data['grossWt'] ?? 0.0).toDouble();
        final net = (data['netWeight'] ?? data['netWt'] ?? 0.0).toDouble();
        final purityVal = (data['purityVal'] ?? 916.0).toDouble();

        row.itemNameCtrl.text = data['name'] ?? data['productName'] ?? '';
        row.grossWtCtrl.text = gross.toStringAsFixed(3);
        row.purityCtrl.text = purityVal.toStringAsFixed(1);

        final double otherWt = (gross - net).clamp(0.0, double.infinity);
        final hasExtra =
            (data['extraCharges'] is List &&
            (data['extraCharges'] as List).isNotEmpty);

        setState(() {
          row.subRows.clear();
          row.otherWtChecked = otherWt > 0.0 || hasExtra;
          row.netWtCtrl.text = net.toStringAsFixed(3);
          row.stoneWtCtrl.text = otherWt.toStringAsFixed(3);

          if (hasExtra) {
            final list = data['extraCharges'] as List;
            for (var charge in list) {
              if (charge is Map) {
                final rawWt = ((charge['weight'] ?? 0.0) as num).toDouble();
                final sName = charge['styleName']?.toString() ?? 'Less Wt';
                // Diamond weight is stored in carats → convert to grams (1 ct = 0.2 g)
                final isDiamond = sName.trim().toLowerCase().contains(
                  'diamond',
                );
                final displayWt = isDiamond ? rawWt * 0.2 : rawWt;
                final sub = OutsourceSubBillingRow(
                  styleName: sName,
                  weight: displayWt.toStringAsFixed(3),
                  pcs: (charge['pcs'] ?? 1).toString(),
                  remarks: charge['remarks']?.toString() ?? '',
                );
                row.subRows.add(sub);
                _attachSubRowListeners(row, sub);
              }
            }
          } else if (otherWt > 0) {
            final sub = OutsourceSubBillingRow(
              styleName: 'Less Wt',
              weight: otherWt.toStringAsFixed(3),
              pcs: '1',
            );
            row.subRows.add(sub);
            _attachSubRowListeners(row, sub);
          }
        });

        _syncRowWeights(row);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tag "$tagId" not found in inventory.')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching tag details: $e");
    }
  }

  void _attachListeners(OutsourceItemRowController row) {
    row.grossWtCtrl.addListener(() => _syncRowWeights(row));
    row.stoneWtCtrl.addListener(() => _syncRowWeights(row, fromOther: true));
    row.netWtCtrl.addListener(() => _syncRowWeights(row, fromNet: true));
    row.purityCtrl.addListener(() => _syncRowWeights(row));
    row.qtyCtrl.addListener(_recalculateTotals);
    row.wastageWtCtrl.addListener(_recalculateTotals);
  }

  void _recalculateTotals() {
    double tg = 0.0;
    double tn = 0.0;
    double tf = 0.0;
    int tq = 0;

    for (var row in _itemRows) {
      final gross = double.tryParse(row.grossWtCtrl.text.trim()) ?? 0.0;
      final net = double.tryParse(row.netWtCtrl.text.trim()) ?? 0.0;
      final fine = double.tryParse(row.fineWtCtrl.text.trim()) ?? 0.0;
      final qty = int.tryParse(row.qtyCtrl.text.trim()) ?? 0;

      tg += gross;
      tn += net;
      tf += fine;
      tq += qty;
    }

    setState(() {
      _totalGross = tg;
      _totalNet = tn;
      _totalFine = tf;
      _totalQty = tq;
    });
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('suppliers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        _suppliers = list;
        _filteredSuppliers = list;
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
      setState(() => _isLoadingSuppliers = false);
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 56.0),
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: _isLoadingSuppliers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brown,
                          ),
                        ),
                      ),
                    )
                  : _filteredSuppliers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No suppliers found',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredSuppliers.length,
                      itemBuilder: (context, idx) {
                        final item = _filteredSuppliers[idx];
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) {
                            setState(() {
                              _artisanCtrl.text = item;
                            });
                            _artisanFocusNode.unfocus();
                            _hideOverlay();
                          },
                          child: InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadReferencedIssueDetails(String txNo) async {
    if (txNo.trim().isEmpty || _txType != 'Outsource Receipt') return;
    try {
      final cleanTxNo = txNo.trim().toUpperCase();
      final snap = await FirebaseFirestore.instance
          .collection('outsource_manufacturing_entries')
          .where('transactionNo', isEqualTo: cleanTxNo)
          .where('transactionType', isEqualTo: 'Outsource Issue')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final issueObj = OutsourceManufacturing.fromMap(
          data,
          snap.docs.first.id,
        );

        // Clear current item rows
        for (var row in _itemRows) {
          row.dispose();
        }
        _itemRows.clear();

        // Populate rows with issue items
        for (var item in issueObj.items) {
          _addNewItemRow(item: item);
        }

        setState(() {});
        _recalculateTotals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded ${issueObj.items.length} items from Issue $cleanTxNo',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading referenced issue details: $e');
    }
  }

  Future<void> _fetchMatchingIssues() async {
    final artisan = _artisanCtrl.text.trim();
    if (artisan.isEmpty || _txType != 'Outsource Receipt') {
      setState(() {
        _matchingIssues = [];
        _filteredIssues = [];
      });
      return;
    }
    setState(() => _isLoadingIssues = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('outsource_manufacturing_entries')
          .where('artisanName', isEqualTo: artisan)
          .where('transactionType', isEqualTo: 'Outsource Issue')
          .where('status', isEqualTo: 'ON PROCESS')
          .get();

      final list = snap.docs
          .map((doc) => doc.data()['transactionNo']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        _matchingIssues = list;
        _filteredIssues = list;
      });
    } catch (e) {
      debugPrint('Error fetching matching outsource issue bills: $e');
    } finally {
      setState(() => _isLoadingIssues = false);
      if (_refNoOverlayEntry != null) {
        _refNoOverlayEntry!.markNeedsBuild();
      }
    }
  }

  void _showRefNoOverlay() {
    _hideRefNoOverlay();
    if (!mounted) return;
    if (_txType != 'Outsource Receipt') return;
    _refNoOverlayEntry = _createRefNoOverlayEntry();
    Overlay.of(context).insert(_refNoOverlayEntry!);
  }

  void _hideRefNoOverlay() {
    if (_refNoOverlayEntry != null) {
      _refNoOverlayEntry!.remove();
      _refNoOverlayEntry = null;
    }
  }

  OverlayEntry _createRefNoOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _refNoLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 56.0),
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: _isLoadingIssues
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brown,
                          ),
                        ),
                      ),
                    )
                  : _filteredIssues.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No process jobs found',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredIssues.length,
                      itemBuilder: (context, idx) {
                        final item = _filteredIssues[idx];
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) {
                            setState(() {
                              _refNoCtrl.text = item;
                            });
                            _refNoFocusNode.unfocus();
                            _hideRefNoOverlay();
                            _loadReferencedIssueDetails(item);
                          },
                          child: InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _hideRefNoOverlay();
    _artisanFocusNode.dispose();
    _refNoFocusNode.dispose();
    for (var row in _itemRows) {
      row.dispose();
    }
    _artisanCtrl.dispose();
    _refNoCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy EEE');

    return AlertDialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.existing == null
                ? 'New Outsource Job Entry'
                : 'Edit Outsource Job Entry',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _brown,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Tx Type & Date & Status
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Transaction Type *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _txType,
                                        isExpanded: true,
                                        items:
                                            [
                                                  'Outsource Issue',
                                                  'Outsource Receipt',
                                                ]
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(
                                                      t,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: widget.existing != null
                                            ? null
                                            : (v) {
                                                setState(() {
                                                  _txType = v!;
                                                  _txNo = widget.generateTxNo(
                                                    _txType,
                                                  );
                                                  for (var row in _itemRows) {
                                                    if (row.itemNameCtrl.text ==
                                                            'Raw Gold Bar' ||
                                                        row.itemNameCtrl.text ==
                                                            'Gold Jewellery') {
                                                      row.itemNameCtrl.text =
                                                          _txType ==
                                                              'Outsource Issue'
                                                          ? 'Raw Gold Bar'
                                                          : 'Gold Jewellery';
                                                    }
                                                  }
                                                });
                                              },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _date,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() => _date = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            dateFormat.format(_date),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: _brown,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _status,
                                        isExpanded: true,
                                        selectedItemBuilder:
                                            (BuildContext context) {
                                              return [
                                                'ON PROCESS',
                                                'COMPLETED',
                                                'CONVERTED TO SALE',
                                                'RETURNED',
                                                'CANCELLED',
                                              ].map((s) {
                                                return Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: buildStatusChip(s),
                                                );
                                              }).toList();
                                            },
                                        items:
                                            [
                                                  'ON PROCESS',
                                                  'COMPLETED',
                                                  'CONVERTED TO SALE',
                                                  'RETURNED',
                                                  'CANCELLED',
                                                ]
                                                .map(
                                                  (s) => DropdownMenuItem(
                                                    value: s,
                                                    child: buildStatusChip(s),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) =>
                                            setState(() => _status = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 2: Tx No & Artisan & Reference No
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Transaction No',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Text(
                                      _txNo,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CompositedTransformTarget(
                                link: _layerLink,
                                child: _buildFormField(
                                  label: 'Artisan / Goldsmith *',
                                  controller: _artisanCtrl,
                                  focusNode: _artisanFocusNode,
                                  hint: 'e.g. Goldsmith Kumar',
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Artisan required'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CompositedTransformTarget(
                                link: _refNoLayerLink,
                                child: _buildFormField(
                                  label: 'Reference / Order No',
                                  controller: _refNoCtrl,
                                  focusNode: _refNoFocusNode,
                                  hint: 'e.g. ORD-10042',
                                  validator: (v) =>
                                      _txType == 'Outsource Receipt' &&
                                          (v == null || v.trim().isEmpty)
                                      ? 'Reference No required'
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'ITEM DETAILS & WEIGHTS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                        const Divider(color: _border),
                        const SizedBox(height: 8),

                        LayoutBuilder(
                          builder: (context, tableConstraints) {
                            final minWidth = _txType == 'Outsource Receipt'
                                ? 1150.0
                                : 1050.0;
                            final targetWidth =
                                tableConstraints.maxWidth > minWidth
                                ? tableConstraints.maxWidth
                                : minWidth;

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: _border),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: targetWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // ITEMS TABLE HEADER
                                      Container(
                                        color: _headerBg,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(
                                              width: 30,
                                              child: Text(
                                                '#',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 120,
                                              child: Text(
                                                'Tag ID',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 180,
                                              child: Text(
                                                'Item Name',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 60,
                                              child: Text(
                                                'Qty',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 80,
                                              child: Text(
                                                'Gross Wt',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 40,
                                              child: Text(
                                                'O.W.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 80,
                                              child: Text(
                                                'Other Wt',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 80,
                                              child: Text(
                                                'Net Wt',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 80,
                                              child: Text(
                                                'Purity',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 80,
                                              child: Text(
                                                'Fine Wt',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            if (_txType ==
                                                'Outsource Receipt') ...[
                                              const SizedBox(width: 8),
                                              const SizedBox(
                                                width: 80,
                                                child: Text(
                                                  'Wastage(g)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: _brown,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Remarks',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _brown,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 40,
                                            ), // Delete button spacer
                                          ],
                                        ),
                                      ),

                                      // ITEMS LIST builder
                                      Container(
                                        height: 220,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: _border),
                                          ),
                                        ),
                                        child: ListView.builder(
                                          itemCount: _itemRows.length,
                                          itemBuilder: (ctx, idx) {
                                            final row = _itemRows[idx];
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: _border,
                                                          ),
                                                        ),
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 30,
                                                        child: Text(
                                                          '${idx + 1}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 120,
                                                        child: SizedBox(
                                                          height: 32,
                                                          child: TextField(
                                                            controller:
                                                                row.tagIdCtrl,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                ),
                                                            decoration: InputDecoration(
                                                              hintText:
                                                                  'Tag ID',
                                                              isDense: true,
                                                              contentPadding:
                                                                  const EdgeInsets.fromLTRB(
                                                                    6,
                                                                    8,
                                                                    2,
                                                                    8,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color:
                                                                          _border,
                                                                    ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color:
                                                                          _border,
                                                                    ),
                                                              ),
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color:
                                                                          _brown,
                                                                    ),
                                                              ),
                                                              suffixIcon: InkWell(
                                                                onTap: () async {
                                                                  String? res =
                                                                      await openQrScanner(
                                                                        context,
                                                                      );
                                                                  if (res !=
                                                                          null &&
                                                                      res !=
                                                                          '-1' &&
                                                                      res.isNotEmpty) {
                                                                    row
                                                                        .tagIdCtrl
                                                                        .text = res
                                                                        .trim()
                                                                        .toUpperCase();
                                                                    _fetchTagDetails(
                                                                      res,
                                                                      row,
                                                                    );
                                                                  }
                                                                },
                                                                child: const Icon(
                                                                  Icons
                                                                      .qr_code_scanner,
                                                                  size: 14,
                                                                  color:
                                                                      _brownLight,
                                                                ),
                                                              ),
                                                              suffixIconConstraints:
                                                                  const BoxConstraints(
                                                                    minWidth:
                                                                        22,
                                                                    minHeight:
                                                                        22,
                                                                  ),
                                                            ),
                                                            onSubmitted: (val) =>
                                                                _fetchTagDetails(
                                                                  val,
                                                                  row,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 180,
                                                        child: _buildGridField(
                                                          row.itemNameCtrl,
                                                          hint: 'Item Name',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 60,
                                                        child: _buildGridField(
                                                          row.qtyCtrl,
                                                          isNum: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: _buildGridField(
                                                          row.grossWtCtrl,
                                                          isNum: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 40,
                                                        child: Center(
                                                          child: Checkbox(
                                                            value: row
                                                                .otherWtChecked,
                                                            activeColor: _brown,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                row.otherWtChecked =
                                                                    val ??
                                                                    false;
                                                                if (row
                                                                    .otherWtChecked) {
                                                                  if (row
                                                                      .subRows
                                                                      .isEmpty) {
                                                                    final newSub = OutsourceSubBillingRow(
                                                                      styleName:
                                                                          'Less Wt',
                                                                      weight:
                                                                          '0.000',
                                                                      pcs: '1',
                                                                    );
                                                                    row.subRows
                                                                        .add(
                                                                          newSub,
                                                                        );
                                                                    _attachSubRowListeners(
                                                                      row,
                                                                      newSub,
                                                                    );
                                                                  }
                                                                } else {
                                                                  for (var sr
                                                                      in row
                                                                          .subRows) {
                                                                    sr.dispose();
                                                                  }
                                                                  row.subRows
                                                                      .clear();
                                                                }
                                                                _syncRowWeights(
                                                                  row,
                                                                );
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: _buildGridField(
                                                          row.stoneWtCtrl,
                                                          readOnly: row
                                                              .otherWtChecked,
                                                          isNum: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: _buildGridField(
                                                          row.netWtCtrl,
                                                          readOnly: !row
                                                              .otherWtChecked,
                                                          isNum: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: _buildGridField(
                                                          row.purityCtrl,
                                                          isNum: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: _buildGridField(
                                                          row.fineWtCtrl,
                                                          readOnly: true,
                                                        ),
                                                      ),
                                                      if (_txType ==
                                                          'Outsource Receipt') ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        SizedBox(
                                                          width: 80,
                                                          child: _buildGridField(
                                                            row.wastageWtCtrl,
                                                            isNum: true,
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: _buildGridField(
                                                          row.remarksCtrl,
                                                          hint: 'Remarks',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 40,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors.red,
                                                            size: 18,
                                                          ),
                                                          onPressed: () =>
                                                              _removeRow(idx),
                                                          padding:
                                                              EdgeInsets.zero,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (row.otherWtChecked)
                                                  ...row.subRows
                                                      .asMap()
                                                      .entries
                                                      .map(
                                                        (e) => _buildSubRow(
                                                          row,
                                                          e.value,
                                                          idx,
                                                          e.key,
                                                        ),
                                                      ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _addNewItemRow(),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: _brown,
                              ),
                              label: const Text(
                                'Add Item Row',
                                style: TextStyle(
                                  color: _brown,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        _buildFormField(
                          label: 'Overall Remarks',
                          controller: _remarksCtrl,
                          maxLines: 4,
                          hint: 'Overall transaction remarks...',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // RIGHT COLUMN (WEIGHT SUMMARY SIDEBAR)
              SizedBox(
                width: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _headerBg,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'WEIGHT SUMMARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _brown,
                              ),
                            ),
                            const Divider(color: _border, height: 16),
                            _buildTotalSummaryRow(
                              'Total Quantity:',
                              '$_totalQty pcs',
                            ),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow(
                              'Total Gross Wt:',
                              '${_totalGross.toStringAsFixed(3)} g',
                            ),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow(
                              'Total Net Wt:',
                              '${_totalNet.toStringAsFixed(3)} g',
                              isBold: true,
                            ),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow(
                              'Total Fine Wt:',
                              '${_totalFine.toStringAsFixed(3)} g',
                              isBold: true,
                              color: Colors.brown.shade800,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _brownLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brown,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  if (_itemRows.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please add at least one item.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final List<OutsourceManufacturingItem> items =
                                      [];
                                  for (var row in _itemRows) {
                                    final itemName = row.itemNameCtrl.text
                                        .trim();
                                    final qty =
                                        int.tryParse(row.qtyCtrl.text.trim()) ??
                                        1;
                                    final gross =
                                        double.tryParse(
                                          row.grossWtCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final stone =
                                        double.tryParse(
                                          row.stoneWtCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final net =
                                        double.tryParse(
                                          row.netWtCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final purity =
                                        double.tryParse(
                                          row.purityCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final fine =
                                        double.tryParse(
                                          row.fineWtCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final remarks = row.remarksCtrl.text.trim();

                                    items.add(
                                      OutsourceManufacturingItem(
                                        tagId: row.tagIdCtrl.text
                                            .trim()
                                            .toUpperCase(),
                                        itemName: itemName.isEmpty
                                            ? 'Item'
                                            : itemName,
                                        quantity: qty,
                                        grossWeight: gross,
                                        stoneWeight: stone,
                                        netWeight: net,
                                        purity: purity,
                                        fineWeight: fine,
                                        wastageWeight:
                                            double.tryParse(
                                              row.wastageWtCtrl.text.trim(),
                                            ) ??
                                            0.0,
                                        labourRate: 0.0,
                                        labourType: 'Per Gram',
                                        remarks: remarks,
                                        extraCharges: row.subRows
                                            .map(
                                              (sr) => {
                                                'styleName': sr.styleName,
                                                'weight':
                                                    double.tryParse(
                                                      sr.weightController.text
                                                          .trim(),
                                                    ) ??
                                                    0.0,
                                                'pcs':
                                                    int.tryParse(
                                                      sr.pcsController.text
                                                          .trim(),
                                                    ) ??
                                                    1,
                                                'remarks': sr
                                                    .remarksController
                                                    .text
                                                    .trim(),
                                              },
                                            )
                                            .toList(),
                                      ),
                                    );
                                  }

                                  final record = OutsourceManufacturing(
                                    docId: widget.existing?.docId ?? '',
                                    transactionNo: _txNo,
                                    date: _date,
                                    transactionType: _txType,
                                    artisanName: _artisanCtrl.text.trim(),
                                    referenceNo: _refNoCtrl.text.trim(),
                                    items: items,
                                    totalGrossWeight: _totalGross,
                                    totalNetWeight: _totalNet,
                                    totalFineWeight: _totalFine,
                                    totalQuantity: _totalQty,
                                    remarks: _remarksCtrl.text.trim(),
                                    status: _status,
                                    isReverseCharge: false,
                                    isTdsApplicable: false,
                                    gstPercent: 0.0,
                                    tdsPercent: 0.0,
                                    totalLabourAmt: 0.0,
                                    cgstAmt: 0.0,
                                    sgstAmt: 0.0,
                                    tdsAmt: 0.0,
                                    netPayableAmt: 0.0,
                                    createdAt:
                                        widget.existing?.createdAt ??
                                        DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  );

                                  widget.onSave(record);
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                'Save Job Entry',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridField(
    TextEditingController ctrl, {
    bool readOnly = false,
    bool isNum = false,
    String? hint,
  }) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _brown),
          ),
          filled: readOnly,
          fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildTotalSummaryRow(
    String label,
    String val, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: _brownLight,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? (isBold ? _brown : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _brown,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          focusNode: focusNode,
          style: TextStyle(
            fontSize: 13,
            fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _brown),
            ),
            filled: readOnly,
            fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSubRow(
    OutsourceItemRowController parentRow,
    OutsourceSubBillingRow subRow,
    int parentIndex,
    int subIndex,
  ) {
    return Container(
      color: const Color(0xFFFDFBF7),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 30), // aligned under index
          SizedBox(
            width: 250,
            child: Text(
              subIndex == 0
                  ? "↳ Other Wt. Style Name:"
                  : "↳ Additional Style Name:",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _brownLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons: + / -
          SizedBox(
            width: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      final newSub = OutsourceSubBillingRow(
                        styleName: 'Less Wt',
                        weight: '0.000',
                        pcs: '1',
                      );
                      parentRow.subRows.insert(subIndex + 1, newSub);
                      _attachSubRowListeners(parentRow, newSub);
                    });
                    _syncRowWeights(parentRow);
                  },
                  child: const Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: Color(0xFFCA6F1E),
                  ),
                ),
                if (parentRow.subRows.length > 1) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        final removed = parentRow.subRows.removeAt(subIndex);
                        removed.dispose();
                      });
                      _syncRowWeights(parentRow);
                    },
                    child: const Icon(
                      Icons.remove_circle_outline,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Style dropdown
          SizedBox(
            width: 130,
            height: 28,
            child: _buildSubRowDropdown(
              value: subRow.styleName,
              items: const [
                'Less Wt',
                'Black Beads',
                'Extra Charges',
                'Hallmark Charge',
                'Kedia',
                'Mani/Moti',
                'Rodium Charges',
                'diamond',
              ],
              onChanged: (val) {
                setState(() {
                  subRow.styleName = val ?? 'Less Wt';
                });
                _syncRowWeights(parentRow);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Weight field
          SizedBox(
            width: 65,
            child: _buildGridField(subRow.weightController, isNum: true),
          ),
          const SizedBox(width: 8),
          // Pcs field
          SizedBox(
            width: 40,
            child: _buildGridField(subRow.pcsController, isNum: true),
          ),
          const SizedBox(width: 8),
          // Remarks/Description
          Expanded(
            child: _buildGridField(subRow.remarksController, hint: 'Remarks'),
          ),
          const SizedBox(width: 40), // spacer for delete button alignment
        ],
      ),
    );
  }

  Widget _buildSubRowDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
