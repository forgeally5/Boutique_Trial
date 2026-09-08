import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../state/admin_state.dart';
import '../../../utils/pdf_refinery_issue_receipt.dart';
import '../../../models/product.dart';
import '../../../products/repositories/product_repository.dart';
import 'refinery_issue_receipt_model.dart';

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
  if (normalized == 'ON PROCESS' || normalized == 'DRAFT' || normalized == 'ISSUED' || normalized == 'PARTIALLY RECEIVED' || normalized == 'PARTIALLY_RECEIVED') {
    bg = Colors.orange[50]!;
    text = Colors.orange[800]!;
    border = Colors.orange[200]!;
  } else if (normalized == 'COMPLETED') {
    bg = Colors.green[50]!;
    text = Colors.green[800]!;
    border = Colors.green[200]!;
  } else if (normalized == 'CONVERTED TO SALE' || normalized == 'CONVERTED_TO_SALE') {
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

class RefineryIssueReceiptView extends StatefulWidget {
  final AdminState state;

  const RefineryIssueReceiptView({super.key, required this.state});

  @override
  State<RefineryIssueReceiptView> createState() => _RefineryIssueReceiptViewState();
}

class _RefineryIssueReceiptViewState extends State<RefineryIssueReceiptView> {
  final List<RefineryIssueReceipt> _records = [];
  bool _isLoading = false;

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  RefineryIssueReceipt? _selectedRecord;
  bool _processOnly = false;
  List<String> _refineries = ['All'];
  String _selectedRefinery = 'All';

  // Supplier & item name dropdowns for form dialog
  List<String> _supplierNames = [];
  List<String> _uniqueItemNames = [];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
    _loadSuppliers();
    _loadItemNames();
  }

  Future<void> _loadItemNames() async {
    try {
      final list = await ProductRepository().getUniqueItemNames();
      if (mounted) {
        setState(() {
          _uniqueItemNames = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading master item names: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) setState(() => _supplierNames = list);
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('refinery_issue_receipts')
          .orderBy('createdAt', descending: true)
          .get();

      final fetched = snap.docs
          .map((doc) => RefineryIssueReceipt.fromMap(doc.data(), doc.id))
          .toList();

      final uniqueRefineries = fetched.map((r) => r.refineryName).toSet().toList();
      uniqueRefineries.sort();

      final uniqueItems = fetched.map((r) => r.itemName).where((s) => s.isNotEmpty).toSet().toList();
      uniqueItems.sort();

      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(fetched);
          _refineries = ['All', ...uniqueRefineries];
          // Merge with defaults
          final merged = {..._uniqueItemNames, ...uniqueItems}.toList()..sort();
          _uniqueItemNames = merged;
        });
      }
    } catch (e) {
      debugPrint('Firestore load error (using local state): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<RefineryIssueReceipt> get _filteredRecords {
    return _records.where((r) {
      final matchSearch = _searchQuery.isEmpty ||
          r.transactionNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.refineryName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.referenceIssueNo.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchType = _typeFilter == 'All' ||
          r.transactionType.toLowerCase() == _typeFilter.toLowerCase();

      final matchStatus = _statusFilter == 'All' ||
          r.status.toLowerCase() == _statusFilter.toLowerCase() ||
          (_statusFilter == 'ON PROCESS' && (r.status.toLowerCase() == 'draft' || r.status.toLowerCase() == 'issued' || r.status.toLowerCase() == 'partially received' || r.status.toLowerCase() == 'partially_received'));

      final matchRefinery = _selectedRefinery == 'All' || r.refineryName == _selectedRefinery;

      final matchProcessOnly = !_processOnly ||
          r.status.toUpperCase() == 'ON PROCESS' ||
          r.status.toUpperCase() == 'DRAFT' ||
          r.status.toUpperCase() == 'PENDING' ||
          r.status.toUpperCase() == 'ISSUED' ||
          r.status.toUpperCase() == 'PARTIALLY RECEIVED' ||
          r.status.toUpperCase() == 'PARTIALLY_RECEIVED';

      bool matchDate = true;
      if (_fromDate != null) {
        matchDate = matchDate && r.date.isAfter(_fromDate!.subtract(const Duration(days: 1)));
      }
      if (_toDate != null) {
        matchDate = matchDate && r.date.isBefore(_toDate!.add(const Duration(days: 1)));
      }

      return matchSearch && matchType && matchStatus && matchRefinery && matchProcessOnly && matchDate;
    }).toList();
  }

  String _generateNextTxNumber(String type) {
    final prefix = type.toLowerCase().contains('receipt') ? 'RR-' : 'RI-';
    final count = _records.where((r) => r.transactionNo.startsWith(prefix)).length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  List<RefineryIssueReceipt> _getAvailableIssuesForLinking(RefineryIssueReceipt? editingRecord) {
    return _records.where((r) {
      final isMatchingLinked = editingRecord != null &&
          (r.transactionNo == editingRecord.referenceIssueNo ||
           (editingRecord.referenceIssueDocId.isNotEmpty && r.docId == editingRecord.referenceIssueDocId));
      return isMatchingLinked || (r.isIssue && r.status != 'CANCELLED' && r.status != 'COMPLETED');
    }).toList();
  }

  double _getAlreadyReceivedFineWeight(String issueDocId, String issueTxNo) {
    double total = 0.0;
    for (final r in _records) {
      if (!r.isIssue && r.status != 'CANCELLED') {
        if ((issueDocId.isNotEmpty && r.referenceIssueDocId == issueDocId) ||
            (issueTxNo.isNotEmpty && r.referenceIssueNo == issueTxNo)) {
          total += r.fineWeight;
        }
      }
    }
    return total;
  }

  void _convertIssueToReceipt(RefineryIssueReceipt issue) {
    final receiptRecord = RefineryIssueReceipt(
      docId: '',
      transactionNo: _generateNextTxNumber('Refinery Receipt'),
      date: DateTime.now(),
      transactionType: 'Refinery Receipt',
      refineryName: issue.refineryName,
      referenceIssueNo: issue.transactionNo,
      referenceIssueDocId: issue.docId,
      itemName: issue.itemName,
      quantity: issue.quantity,
      grossWeight: issue.grossWeight,
      stoneWeight: issue.stoneWeight,
      netWeight: issue.netWeight,
      purity: issue.purity,
      fineWeight: issue.fineWeight,
      issuedFineWeight: issue.fineWeight,
      receivedFineWeight: issue.fineWeight,
      lossDifference: 0.0,
      remarks: 'Converted from Issue ${issue.transactionNo}',
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _openEntryDialog(receiptRecord);
  }

  void _openEntryDialog([RefineryIssueReceipt? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RefineryIssueReceiptFormDialog(
        existing: existing,
        generateTxNo: _generateNextTxNumber,
        availableIssues: _getAvailableIssuesForLinking(existing),
        getAlreadyReceivedFineWeight: _getAlreadyReceivedFineWeight,
        suppliers: _supplierNames,
        itemNames: _uniqueItemNames,
        onSave: (record, linkedIssueToUpdate) async {
          try {
            String bankEntryId = record.bankEntryDocId;

            // Handle Bank/Cash Book Payment Bookkeeping
            if (record.isPaid && record.netAmount > 0 && record.paymentBook.isNotEmpty) {
              final bankData = {
                'voucherNo': 'B-${record.transactionNo}',
                'voucherDate': DateFormat('dd/MM/yyyy EEE').format(record.date),
                'accountName': record.refineryName,
                'voucherType': 'Payment',
                'totalAmount': record.netAmount.toStringAsFixed(2),
                'bookName': record.paymentBook,
                'reference': record.paymentReference,
                'refNo': '1',
                'date': DateFormat('dd/MM/yyyy EEE').format(record.date),
                'memoVoucher': 'No',
                'narration': 'Refining service payment for ${record.transactionNo}. Ref: ${record.paymentReference}',
              };

              if (bankEntryId.isNotEmpty) {
                // Update existing bank entry
                await FirebaseFirestore.instance
                    .collection('bank_entries')
                    .doc(bankEntryId)
                    .set(bankData, SetOptions(merge: true));
              } else {
                // Create new bank entry
                final bankRef = await FirebaseFirestore.instance
                    .collection('bank_entries')
                    .add({...bankData, 'createdAt': FieldValue.serverTimestamp()});
                bankEntryId = bankRef.id;
              }
            } else {
              // If it was paid but now unpaid, delete the bank entry
              if (bankEntryId.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('bank_entries')
                      .doc(bankEntryId)
                      .delete();
                } catch (_) {}
                bankEntryId = '';
              }
            }

            // Create record data map to save
            final finalRecordMap = record.toMap();
            finalRecordMap['bankEntryDocId'] = bankEntryId;

            if (existing == null || existing.docId.isEmpty) {
              final docRef = await FirebaseFirestore.instance
                  .collection('refinery_issue_receipts')
                  .add(finalRecordMap);
              final newRecord = RefineryIssueReceipt.fromMap(finalRecordMap, docRef.id);
              setState(() => _records.insert(0, newRecord));
            } else {
              await FirebaseFirestore.instance
                  .collection('refinery_issue_receipts')
                  .doc(existing.docId)
                  .update(finalRecordMap);
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) {
                setState(() => _records[idx] = RefineryIssueReceipt.fromMap(finalRecordMap, existing.docId));
              }
            }

            // Update linked issue status if necessary
            if (linkedIssueToUpdate != null) {
              final idx = _records.indexWhere((r) => r.docId == linkedIssueToUpdate.docId || r.transactionNo == linkedIssueToUpdate.transactionNo);
              if (idx != -1) {
                final updatedIssue = RefineryIssueReceipt(
                  docId: _records[idx].docId,
                  transactionNo: _records[idx].transactionNo,
                  date: _records[idx].date,
                  transactionType: _records[idx].transactionType,
                  refineryName: _records[idx].refineryName,
                  referenceIssueNo: _records[idx].referenceIssueNo,
                  referenceIssueDocId: _records[idx].referenceIssueDocId,
                  tagId: _records[idx].tagId,
                  itemName: _records[idx].itemName,
                  quantity: _records[idx].quantity,
                  grossWeight: _records[idx].grossWeight,
                  stoneWeight: _records[idx].stoneWeight,
                  netWeight: _records[idx].netWeight,
                  purity: _records[idx].purity,
                  fineWeight: _records[idx].fineWeight,
                  issuedFineWeight: _records[idx].fineWeight,
                  receivedFineWeight: linkedIssueToUpdate.receivedFineWeight,
                  lossDifference: linkedIssueToUpdate.lossDifference,
                  status: linkedIssueToUpdate.status,
                  remarks: _records[idx].remarks,
                  createdAt: _records[idx].createdAt,
                  updatedAt: DateTime.now(),
                );
                setState(() => _records[idx] = updatedIssue);
                try {
                  await FirebaseFirestore.instance
                      .collection('refinery_issue_receipts')
                      .doc(_records[idx].docId)
                      .update({
                    'status': linkedIssueToUpdate.status,
                    'receivedFineWeight': linkedIssueToUpdate.receivedFineWeight,
                    'lossDifference': linkedIssueToUpdate.lossDifference,
                    'updatedAt': Timestamp.now(),
                  });
                } catch (_) {}
              }
            }

            // Manage Inventory Piece Preservation
            try {
              if (record.isIssue) {
                if (record.tagId.isNotEmpty) {
                  await ProductRepository().markPiecePreserved(
                    tagId: record.tagId,
                    transactionType: 'Refinery Issue',
                    transactionNo: record.transactionNo,
                  );
                }
              } else {
                final returnTag = record.tagId.isNotEmpty ? record.tagId : (linkedIssueToUpdate?.tagId ?? '');
                if (returnTag.isNotEmpty) {
                  await ProductRepository().markPieceAvailable(tagId: returnTag);
                }
              }
            } catch (e) {
              debugPrint('Error updating inventory stock preservation: $e');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refinery transaction ${record.transactionNo} saved successfully!'),
                  backgroundColor: Colors.green[800],
                ),
              );
            }
          } catch (e) {
            if (existing == null) {
              setState(() => _records.insert(0, record));
            } else {
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) setState(() => _records[idx] = record);
            }
          }
        },
      ),
    );
  }

  Future<void> _cancelRecord(RefineryIssueReceipt record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancellation', style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel transaction ${record.transactionNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No', style: TextStyle(color: _brownLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Transaction'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = RefineryIssueReceipt(
        docId: record.docId,
        transactionNo: record.transactionNo,
        date: record.date,
        transactionType: record.transactionType,
        refineryName: record.refineryName,
        referenceIssueNo: record.referenceIssueNo,
        referenceIssueDocId: record.referenceIssueDocId,
        tagId: record.tagId,
        itemName: record.itemName,
        quantity: record.quantity,
        grossWeight: record.grossWeight,
        stoneWeight: record.stoneWeight,
        netWeight: record.netWeight,
        purity: record.purity,
        fineWeight: record.fineWeight,
        issuedFineWeight: record.issuedFineWeight,
        receivedFineWeight: record.receivedFineWeight,
        lossDifference: record.lossDifference,
        status: 'CANCELLED',
        remarks: record.remarks,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
      );

      try {
        await FirebaseFirestore.instance
            .collection('refinery_issue_receipts')
            .doc(record.docId)
            .update({'status': 'CANCELLED', 'updatedAt': Timestamp.now()});
        
        if (record.isIssue && record.tagId.isNotEmpty) {
          await ProductRepository().markPieceAvailable(tagId: record.tagId);
        }
      } catch (_) {}

      final idx = _records.indexWhere((r) => r.docId == record.docId);
      if (idx != -1) {
        setState(() => _records[idx] = updated);
      }
    }
  }

  void _showViewDetailsDialog(RefineryIssueReceipt r) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Refinery Entry ${r.transactionNo}', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)),
            _buildStatusChip(r.status),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Date', dateFormat.format(r.date)),
              _buildDetailRow('Type', r.transactionType),
              _buildDetailRow('Refinery Name', r.refineryName),
              _buildDetailRow('Ref. Issue No', r.referenceIssueNo.isEmpty ? '-' : r.referenceIssueNo),
              const Divider(color: _border),
              _buildDetailRow('Item Name', r.itemName),
              _buildDetailRow('Quantity', r.quantity.toString()),
              _buildDetailRow('Gross Weight', '${r.grossWeight.toStringAsFixed(3)} g'),
              _buildDetailRow('Other Weight', '${r.stoneWeight.toStringAsFixed(3)} g'),
              _buildDetailRow('Net Weight', '${r.netWeight.toStringAsFixed(3)} g', isBold: true),
              _buildDetailRow('Purity', r.purity.toStringAsFixed(1)),
              _buildDetailRow('Fine Weight', '${r.fineWeight.toStringAsFixed(3)} g', isBold: true),
              if (!r.isIssue || r.issuedFineWeight > 0) ...[
                const Divider(color: _border),
                _buildDetailRow('Issued Fine Weight', '${r.issuedFineWeight.toStringAsFixed(3)} g'),
                _buildDetailRow('Received Fine Weight', '${r.receivedFineWeight.toStringAsFixed(3)} g'),
                _buildDetailRow('Process Loss / Diff', '${r.lossDifference.toStringAsFixed(3)} g', isHighlight: true),
              ],
              if (r.remarks.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Remarks', r.remarks),
              ]
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16, color: _brown),
            label: const Text('PDF / Print', style: TextStyle(color: _brown)),
            onPressed: () {
              Navigator.pop(ctx);
              PdfRefineryIssueReceipt.printPdf(r);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C41))),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? Colors.red[900] : (isBold ? _brown : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
      String label, String value, List<String> items, ValueChanged<String?> onChanged,
      {bool isPrimary = false}) {
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
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _brownLight)),
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
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.grey, size: 16),
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.normal),
                onChanged: onChanged,
                items: uniqueItems
                    .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: isPrimary && displayValue == item
                                    ? _brown
                                    : Colors.black))))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(String label, String value,
      {required VoidCallback onTap}) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _brownLight)),
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
                  Text(value,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black)),
                  const Icon(Icons.calendar_today,
                      color: Colors.grey, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {Color? iconColor, VoidCallback? onTap}) {
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
            border: Border.all(color: _border.withValues(alpha: isEnabled ? 1.0 : 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: isEnabled ? (iconColor ?? _brown) : Colors.grey),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: isEnabled ? _brown : Colors.grey,
                    height: 1.1,
                    fontWeight: FontWeight.w500),
              ),
            ],
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
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterRow(
                              'Refinery',
                              _selectedRefinery,
                              _refineries,
                              (val) => setState(() {
                                _selectedRefinery = val!;
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
                              ['All', 'Refinery Issue', 'Refinery Receipt'],
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
                              ['All', 'ON PROCESS', 'COMPLETED', 'CONVERTED TO SALE', 'RETURNED', 'CANCELLED'],
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
                                    _fromDate == null ? '-' : dateFormat.format(_fromDate!),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _fromDate ?? DateTime.now(),
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
                                const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDateTile(
                                    '',
                                    _toDate == null ? '-' : dateFormat.format(_toDate!),
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
                                  hintText: 'Search by Tx No, Refinery, Item, Ref Issue...',
                                  prefixIcon: const Icon(Icons.search, color: _brownLight, size: 14),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _processOnly ? _brown : Colors.white,
                              side: BorderSide(color: _processOnly ? _brown : _border),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                              icon: const Icon(Icons.clear, size: 16, color: Colors.red),
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
                      onTap: _selectedRecord == null || _selectedRecord!.status == 'CANCELLED'
                          ? null
                          : () => _openEntryDialog(_selectedRecord),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.cancel,
                      'Cancel',
                      iconColor: Colors.red,
                      onTap: _selectedRecord == null || _selectedRecord!.status == 'CANCELLED'
                          ? null
                          : () => _cancelRecord(_selectedRecord!),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.swap_horiz,
                      'Convert\nReceipt',
                      iconColor: Colors.green,
                      onTap: _selectedRecord == null ||
                              _selectedRecord!.transactionType != 'Refinery Issue' ||
                              _selectedRecord!.status == 'CANCELLED' ||
                              _selectedRecord!.status == 'COMPLETED'
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
                          : () => PdfRefineryIssueReceipt.printPdf(_selectedRecord!),
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

          // Data Table Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _brown))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.precision_manufacturing_outlined, size: 48, color: Colors.brown[200]),
                              const SizedBox(height: 12),
                              const Text(
                                'No Refinery Issue / Receipt entries found',
                                style: TextStyle(fontSize: 15, color: _brownLight, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 16, color: _brown),
                                label: const Text('Create First Entry', style: TextStyle(color: _brown)),
                                onPressed: () => _openEntryDialog(),
                              )
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // CUSTOM RESPONSIVE TABLE HEADER
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: const BoxDecoration(
                                color: _headerBg,
                                border: Border(bottom: BorderSide(color: _border)),
                              ),
                              child: Row(
                                children: [
                                  _buildHeaderCell('Tx No', flex: 2),
                                  _buildHeaderCell('Date', flex: 2),
                                  _buildHeaderCell('Refinery Name', flex: 3),
                                  _buildHeaderCell('Type', flex: 2),
                                  _buildHeaderCell('Ref Issue No', flex: 2),
                                  _buildHeaderCell('Item Name', flex: 3),
                                  _buildHeaderCell('Gross Wt', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Net Wt', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Purity', flex: 1, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Fine Wt', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Loss / Diff', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Status', flex: 2, alignment: Alignment.center),
                                ],
                              ),
                            ),
                            // TABLE BODY ROW LIST
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final r = filtered[index];
                                  final isSelected = _selectedRecord?.docId == r.docId;
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRecord = r;
                                      });
                                    },
                                    onDoubleTap: () {
                                      setState(() {
                                        _selectedRecord = r;
                                      });
                                      if (r.status != 'CANCELLED') {
                                        _openEntryDialog(r);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFFDF6ED) : (index % 2 == 0 ? Colors.white : const Color(0xFFFCFAF7)),
                                        border: const Border(bottom: BorderSide(color: _border, width: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildRowCell(
                                            Text(r.transactionNo, style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 12)),
                                            flex: 2,
                                          ),
                                          _buildRowCell(
                                            Text(dateFormat.format(r.date), style: const TextStyle(fontSize: 12)),
                                            flex: 2,
                                          ),
                                          _buildRowCell(
                                            Text(r.refineryName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            flex: 3,
                                          ),
                                          _buildRowCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: r.isIssue ? Colors.purple[50] : Colors.teal[50],
                                                border: Border.all(color: r.isIssue ? Colors.purple[300]! : Colors.teal[300]!),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                r.transactionType,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: r.isIssue ? Colors.purple[900] : Colors.teal[900],
                                                ),
                                              ),
                                            ),
                                            flex: 2,
                                          ),
                                          _buildRowCell(
                                            Text(r.referenceIssueNo.isEmpty ? '-' : r.referenceIssueNo, style: const TextStyle(fontSize: 12)),
                                            flex: 2,
                                          ),
                                          _buildRowCell(
                                            Text(r.itemName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            flex: 3,
                                          ),
                                          _buildRowCell(
                                            Text('${r.grossWeight.toStringAsFixed(3)} g', style: const TextStyle(fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text('${r.netWeight.toStringAsFixed(3)} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(r.purity.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                                            flex: 1,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text('${r.fineWeight.toStringAsFixed(3)} g', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(
                                              r.lossDifference > 0 ? '${r.lossDifference.toStringAsFixed(3)} g' : '-',
                                              style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                value: () {
                                                  String currentStatus = r.status.toUpperCase();
                                                  if (currentStatus == 'DRAFT' || currentStatus == 'ISSUED' || currentStatus == 'PARTIALLY RECEIVED' || currentStatus == 'PARTIALLY_RECEIVED' || currentStatus == 'PENDING') {
                                                    currentStatus = 'ON PROCESS';
                                                  }
                                                  if (currentStatus == 'CONVERTED_TO_SALE') {
                                                    currentStatus = 'CONVERTED TO SALE';
                                                  }
                                                  return currentStatus;
                                                }(),
                                                isDense: true,
                                                elevation: 2,
                                                icon: const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
                                                selectedItemBuilder: (BuildContext context) {
                                                  return <String>['ON PROCESS', 'COMPLETED', 'CONVERTED TO SALE', 'RETURNED', 'CANCELLED']
                                                      .map<Widget>((String value) {
                                                    return Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: value == 'COMPLETED'
                                                              ? Colors.green[50]
                                                              : (value == 'CANCELLED'
                                                                  ? Colors.red[50]
                                                                  : (value == 'CONVERTED TO SALE' ? Colors.purple[50] : (value == 'RETURNED' ? Colors.blue[50] : Colors.orange[50]))),
                                                          borderRadius: BorderRadius.circular(3),
                                                        ),
                                                        child: Text(
                                                          value,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: value == 'COMPLETED'
                                                                ? Colors.green[800]
                                                                : (value == 'CANCELLED'
                                                                    ? Colors.red[800]
                                                                    : (value == 'CONVERTED TO SALE' ? Colors.purple[800] : (value == 'RETURNED' ? Colors.blue[800] : Colors.orange[800]))),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                                items: <String>['ON PROCESS', 'COMPLETED', 'CONVERTED TO SALE', 'RETURNED', 'CANCELLED']
                                                    .map<DropdownMenuItem<String>>((String value) {
                                                  return DropdownMenuItem<String>(
                                                    value: value,
                                                    child: buildStatusChip(value),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) async {
                                                  if (newValue != null && newValue != r.status) {
                                                    try {
                                                      await FirebaseFirestore.instance
                                                          .collection('refinery_issue_receipts')
                                                          .doc(r.docId)
                                                          .update({'status': newValue, 'updatedAt': Timestamp.now()});
                                                      
                                                      final updatedRecord = RefineryIssueReceipt(
                                                        docId: r.docId,
                                                        transactionNo: r.transactionNo,
                                                        date: r.date,
                                                        transactionType: r.transactionType,
                                                        refineryName: r.refineryName,
                                                        referenceIssueNo: r.referenceIssueNo,
                                                        referenceIssueDocId: r.referenceIssueDocId,
                                                        itemName: r.itemName,
                                                        quantity: r.quantity,
                                                        grossWeight: r.grossWeight,
                                                        stoneWeight: r.stoneWeight,
                                                        netWeight: r.netWeight,
                                                        purity: r.purity,
                                                        fineWeight: r.fineWeight,
                                                        issuedFineWeight: r.issuedFineWeight,
                                                        receivedFineWeight: r.receivedFineWeight,
                                                        lossDifference: r.lossDifference,
                                                        status: newValue,
                                                        remarks: r.remarks,
                                                        createdAt: r.createdAt,
                                                        updatedAt: DateTime.now(),
                                                      );
                                                      
                                                      setState(() {
                                                        final idx = _records.indexWhere((rec) => rec.docId == r.docId);
                                                        if (idx != -1) {
                                                          _records[idx] = updatedRecord;
                                                        }
                                                      });
                                                      if (!context.mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Status updated to $newValue')),
                                                      );
                                                    } catch (e) {
                                                      if (!context.mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error updating status: $e')),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                            flex: 2,
                                            alignment: Alignment.center,
                                          ),

                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // BOTTOM TOTALS RECORD SUMMARY ROW
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: const BoxDecoration(
                                color: _headerBg,
                                border: Border(top: BorderSide(color: _border)),
                              ),
                              child: Builder(
                                builder: (context) {
                                  double totGross = 0.0;
                                  double totNet = 0.0;
                                  double totFine = 0.0;
                                  double totLoss = 0.0;
                                  for (final r in filtered) {
                                    totGross += r.grossWeight;
                                    totNet += r.netWeight;
                                    totFine += r.fineWeight;
                                    totLoss += r.lossDifference;
                                  }
                                  
                                  return Row(
                                    children: [
                                      Text(
                                        'Total Entries: ${filtered.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Gross Wt: ${totGross.toStringAsFixed(3)} g  |  '
                                        'Net Wt: ${totNet.toStringAsFixed(3)} g  |  '
                                        'Fine Wt: ${totFine.toStringAsFixed(3)} g  |  '
                                        'Loss/Diff: ${totLoss.toStringAsFixed(3)} g',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown),
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
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return buildStatusChip(status);
  }

  Widget _buildHeaderCell(String label, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildRowCell(Widget child, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: child,
      ),
    );
  }
}

// ── Entry Form Modal Dialog for Refinery ─────────────────────────────────────

class _RefineryIssueReceiptFormDialog extends StatefulWidget {
  final RefineryIssueReceipt? existing;
  final String Function(String type) generateTxNo;
  final List<RefineryIssueReceipt> availableIssues;
  final double Function(String docId, String txNo) getAlreadyReceivedFineWeight;
  final List<String> suppliers;
  final List<String> itemNames;
  final Function(RefineryIssueReceipt record, RefineryIssueReceipt? linkedIssueToUpdate) onSave;

  const _RefineryIssueReceiptFormDialog({
    this.existing,
    required this.generateTxNo,
    required this.availableIssues,
    required this.getAlreadyReceivedFineWeight,
    required this.suppliers,
    required this.itemNames,
    required this.onSave,
  });

  @override
  State<_RefineryIssueReceiptFormDialog> createState() => _RefineryIssueReceiptFormDialogState();
}

class _RefineryIssueReceiptFormDialogState extends State<_RefineryIssueReceiptFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _txNo;
  late DateTime _date;
  String _txType = 'Refinery Issue';
  final _refineryCtrl = TextEditingController(text: '');
  RefineryIssueReceipt? _selectedLinkedIssue;
  int _maxPcs = 9999;
  int _dbPcs = 1;
  double _dbGross = 0.0;
  double _dbOther = 0.0;
  final _tagIdCtrl = TextEditingController();
  final _tagFocusNode = FocusNode();
  final _itemNameCtrl = TextEditingController(text: '');
  final _qtyCtrl = TextEditingController(text: '1');
  final _grossWtCtrl = TextEditingController(text: '0.000');
  final _stoneWtCtrl = TextEditingController(text: '0.000');
  final _netWtCtrl = TextEditingController(text: '0.000');
  final _purityCtrl = TextEditingController(text: '995.0');
  final _fineWtCtrl = TextEditingController(text: '0.000');
  final _remarksCtrl = TextEditingController();
  String _status = 'ON PROCESS';

  // New fields for separate received weights and refining charge type
  final _receivedGrossWtCtrl = TextEditingController(text: '0.000');
  final _receivedStoneWtCtrl = TextEditingController(text: '0.000');
  final _receivedNetWtCtrl = TextEditingController(text: '0.000');
  final _receivedPurityCtrl = TextEditingController(text: '995.0');
  final _receivedFineWtCtrl = TextEditingController(text: '0.000');
  String _refiningChargeType = 'Per Gram Fine Wt';
  List<Map<String, dynamic>> _suppliersList = [];

  // New fields for financial/refining details and payment bookkeeping
  final _goldRateCtrl = TextEditingController();
  final _lossGainAmtCtrl = TextEditingController(text: '0.00');
  final _refiningServiceRateCtrl = TextEditingController();
  final _refiningServiceAmtCtrl = TextEditingController(text: '0.00');
  final _taxPercentageCtrl = TextEditingController(text: '18.0');
  final _taxAmtCtrl = TextEditingController(text: '0.00');
  final _netAmtCtrl = TextEditingController(text: '0.00');
  bool _isPaid = false;
  List<String> _bookNames = [];
  String? _selectedPaymentBook;
  final _paymentReferenceCtrl = TextEditingController();
  String _bankEntryDocId = '';

  // Issue tracking helper values
  double _issuedFineWeightVal = 0.0;
  double _alreadyReceivedFineWeightVal = 0.0;
  double _outstandingFineWeightVal = 0.0;
  double _lossDiffVal = 0.0;

  Future<void> _fetchTagDetails(String tagId) async {
    if (tagId.trim().isEmpty) return;
    try {
      final cleanTag = tagId.trim().toUpperCase();
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(cleanTag).get();
      if (!doc.exists || doc.data() == null) {
        final base = getBaseTagId(cleanTag);
        if (base != cleanTag) {
          doc = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(base).get();
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
            return;
          }
        }

        _tagIdCtrl.text = cleanTag;
        
        final name = data['name'] ?? data['productName'] ?? data['itemName'] ?? '';
        final gross = (data['grossWeight'] ?? data['grossWt'] ?? 0.0).toDouble();
        final net = (data['netWeight'] ?? data['netWt'] ?? 0.0).toDouble();
        final int pcsVal = (data['pcs'] as num?)?.toInt() ??
            (data['pieces'] as num?)?.toInt() ??
            (data['quantity'] as num?)?.toInt() ?? 1;

        double other = 0.0;
        final extraCharges = data['extraCharges'];
        if (extraCharges is List && extraCharges.isNotEmpty) {
          for (var charge in extraCharges) {
            if (charge is Map) {
              final w = ((charge['weight'] ?? 0.0) as num).toDouble();
              final style = (charge['styleName'] ?? '').toString().toLowerCase().trim();
              if (style == 'diamond') {
                other += w * 0.2;
              } else {
                other += w;
              }
            }
          }
        }

        if (other == 0.0) {
          if (data['otherWt'] != null && (data['otherWt'] as num).toDouble() > 0) {
            other = (data['otherWt'] as num).toDouble();
          } else if (data['stoneWt'] != null && (data['stoneWt'] as num).toDouble() > 0) {
            other = (data['stoneWt'] as num).toDouble();
          } else {
            other = (gross - net).clamp(0.0, double.infinity);
          }
        }
        
        final purityVal = (data['purityVal'] ?? data['purity'] ?? 995.0).toDouble();

        setState(() {
          _maxPcs = pcsVal; // store for max validation
          _dbPcs = pcsVal;
          _dbGross = gross;
          _dbOther = other;
          if (name.isNotEmpty) _itemNameCtrl.text = name;
          _qtyCtrl.text = '1'; // always start with 1 pcs
          _grossWtCtrl.text = gross.toStringAsFixed(3);
          _stoneWtCtrl.text = other.toStringAsFixed(3);
          _netWtCtrl.text = net.toStringAsFixed(3);
          _purityCtrl.text = purityVal.toString();
        });
        
        _recalculate();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Tag "$cleanTag" not found in inventory.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching tag details: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _txNo = e.transactionNo;
      _date = e.date;
      _txType = e.transactionType;
      _refineryCtrl.text = e.refineryName;
      _tagIdCtrl.text = e.tagId;
      _itemNameCtrl.text = e.itemName;
      _qtyCtrl.text = e.quantity.toString();
      _grossWtCtrl.text = e.grossWeight.toStringAsFixed(3);
      _stoneWtCtrl.text = e.stoneWeight.toStringAsFixed(3);
      _netWtCtrl.text = e.netWeight.toStringAsFixed(3);
      _purityCtrl.text = e.purity.toStringAsFixed(1);
      _fineWtCtrl.text = e.fineWeight.toStringAsFixed(3);
      _remarksCtrl.text = e.remarks;

      _receivedGrossWtCtrl.text = e.receivedGrossWeight.toStringAsFixed(3);
      _receivedStoneWtCtrl.text = e.receivedStoneWeight.toStringAsFixed(3);
      _receivedNetWtCtrl.text = e.receivedNetWeight.toStringAsFixed(3);
      _receivedPurityCtrl.text = e.receivedPurity.toStringAsFixed(1);
      _receivedFineWtCtrl.text = e.receivedFineWeight.toStringAsFixed(3);
      final rawType = e.refiningChargeType.isNotEmpty ? e.refiningChargeType : 'Per Gram Fine Wt';
      _refiningChargeType = rawType == 'Fixed' ? 'Fixed Service Charge' : rawType;

      _goldRateCtrl.text = e.goldRate > 0 ? e.goldRate.toString() : '';
      _lossGainAmtCtrl.text = e.lossGainAmount.toStringAsFixed(2);
      _refiningServiceRateCtrl.text = e.refiningServiceRate > 0 ? e.refiningServiceRate.toString() : '';
      _refiningServiceAmtCtrl.text = e.refiningServiceAmount.toStringAsFixed(2);
      _taxPercentageCtrl.text = e.taxPercentage.toString();
      _taxAmtCtrl.text = e.taxAmount.toStringAsFixed(2);
      _netAmtCtrl.text = e.netAmount.toStringAsFixed(2);
      _isPaid = e.isPaid;
      _selectedPaymentBook = e.paymentBook.isNotEmpty ? e.paymentBook : null;
      _paymentReferenceCtrl.text = e.paymentReference;
      _bankEntryDocId = e.bankEntryDocId;

      if (e.referenceIssueNo.isNotEmpty) {
        try {
          _selectedLinkedIssue = widget.availableIssues.firstWhere(
            (issue) => issue.transactionNo == e.referenceIssueNo || (e.referenceIssueDocId.isNotEmpty && issue.docId == e.referenceIssueDocId),
          );
        } catch (_) {}
      }

      if (_selectedLinkedIssue != null) {
        _issuedFineWeightVal = _selectedLinkedIssue!.fineWeight;
        _alreadyReceivedFineWeightVal = widget.getAlreadyReceivedFineWeight(_selectedLinkedIssue!.docId, _selectedLinkedIssue!.transactionNo);
        _outstandingFineWeightVal = (_issuedFineWeightVal - _alreadyReceivedFineWeightVal).clamp(0.0, double.infinity);
      } else {
        _issuedFineWeightVal = e.issuedFineWeight;
        _alreadyReceivedFineWeightVal = e.receivedFineWeight;
        _outstandingFineWeightVal = 0.0;
      }
      
      _lossDiffVal = e.lossDifference;
      
      _dbPcs = e.quantity;
      _dbGross = e.grossWeight;
      _dbOther = e.stoneWeight;
      _maxPcs = 9999;

      final statusUpper = e.status.toUpperCase();
      if (statusUpper == 'DRAFT' || statusUpper == 'ISSUED' || statusUpper == 'PARTIALLY RECEIVED' || statusUpper == 'PARTIALLY_RECEIVED' || statusUpper == 'PENDING') {
        _status = 'ON PROCESS';
      } else if (statusUpper == 'CONVERTED_TO_SALE') {
        _status = 'CONVERTED TO SALE';
      } else {
        _status = statusUpper;
      }
    } else {
      _date = DateTime.now();
      _txNo = widget.generateTxNo(_txType);
      _outstandingFineWeightVal = 0.0;
    }

    _grossWtCtrl.addListener(_recalculate);
    _stoneWtCtrl.addListener(_recalculate);
    _purityCtrl.addListener(_recalculate);
    _qtyCtrl.addListener(_onQtyChanged);
    _refineryCtrl.addListener(_onRefineryNameChanged);

    _receivedGrossWtCtrl.addListener(_recalculate);
    _receivedStoneWtCtrl.addListener(_recalculate);
    _receivedPurityCtrl.addListener(_recalculate);

    _goldRateCtrl.addListener(_recalculateFinancials);
    _refiningServiceRateCtrl.addListener(_recalculateFinancials);
    _refiningServiceAmtCtrl.addListener(_recalculateFinancials);
    _taxPercentageCtrl.addListener(_recalculateFinancials);
    _netAmtCtrl.addListener(_recalculateFinancials);

    _loadSuppliersList();
    _fetchBookNames();
  }

  Future<void> _fetchBookNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final list = snap.docs.map((d) => d.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      
      final Set<String> combined = {'Cash', 'Card', 'UPI'};
      combined.addAll(list);

      if (mounted) {
        setState(() {
          _bookNames = combined.toList();
          if (_selectedPaymentBook == null && _bookNames.isNotEmpty) {
            _selectedPaymentBook = _bookNames.first;
          }
        });
      }
    } catch (_) {}
  }

  void _loadSuppliersList() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      _suppliersList = snap.docs.map((doc) => doc.data()).toList();
      
      // Update tax scheme based on the selected/loaded refinery
      if (widget.existing != null) {
        _updateTaxSchemeForSupplier(widget.existing!.refineryName);
      } else if (_refineryCtrl.text.isNotEmpty) {
        _updateTaxSchemeForSupplier(_refineryCtrl.text);
      }
    } catch (_) {}
  }

  void _updateTaxSchemeForSupplier(String name) {
    if (name.isEmpty) return;
    try {
      final supplier = _suppliersList.firstWhere(
        (e) => (e['name'] ?? e['companyName'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (supplier.isNotEmpty) {
        _recalculateFinancials();
      }
    } catch (_) {}
  }

  void _recalculateFinancials() {
    final goldRate = double.tryParse(_goldRateCtrl.text.trim()) ?? 0.0;
    final serviceRate = double.tryParse(_refiningServiceRateCtrl.text.trim()) ?? 0.0;
    final taxPct = double.tryParse(_taxPercentageCtrl.text.trim()) ?? 0.0;

    final lossAmt = _lossDiffVal * goldRate;
    double serviceAmt = 0.0;
    double taxAmt = 0.0;
    double netAmt = 0.0;

    if (_refiningChargeType == 'Fixed Net Amount') {
      netAmt = double.tryParse(_netAmtCtrl.text.trim()) ?? 0.0;
      serviceAmt = netAmt / (1.0 + (taxPct / 100.0));
      taxAmt = netAmt - serviceAmt;

      _refiningServiceAmtCtrl.removeListener(_recalculateFinancials);
      _refiningServiceAmtCtrl.text = serviceAmt.toStringAsFixed(2);
      _refiningServiceAmtCtrl.addListener(_recalculateFinancials);
    } else if (_refiningChargeType == 'Fixed Service Charge' || _refiningChargeType == 'Fixed') {
      serviceAmt = double.tryParse(_refiningServiceAmtCtrl.text.trim()) ?? 0.0;
      taxAmt = serviceAmt * (taxPct / 100.0);
      netAmt = serviceAmt + taxAmt;

      _netAmtCtrl.removeListener(_recalculateFinancials);
      _netAmtCtrl.text = netAmt.toStringAsFixed(2);
      _netAmtCtrl.addListener(_recalculateFinancials);
    } else {
      double weightForCharge = 0.0;
      final recGross = double.tryParse(_receivedGrossWtCtrl.text.trim()) ?? 0.0;
      final recNet = double.tryParse(_receivedNetWtCtrl.text.trim()) ?? 0.0;
      final recFine = double.tryParse(_receivedFineWtCtrl.text.trim()) ?? 0.0;

      if (_refiningChargeType == 'Per Gram Gross Wt') {
        weightForCharge = recGross;
      } else if (_refiningChargeType == 'Per Gram Net Wt') {
        weightForCharge = recNet;
      } else if (_refiningChargeType == 'Per Gram Fine Wt') {
        weightForCharge = recFine;
      }

      serviceAmt = weightForCharge * serviceRate;
      taxAmt = serviceAmt * (taxPct / 100.0);
      netAmt = serviceAmt + taxAmt;

      _refiningServiceAmtCtrl.removeListener(_recalculateFinancials);
      _refiningServiceAmtCtrl.text = serviceAmt.toStringAsFixed(2);
      _refiningServiceAmtCtrl.addListener(_recalculateFinancials);

      _netAmtCtrl.removeListener(_recalculateFinancials);
      _netAmtCtrl.text = netAmt.toStringAsFixed(2);
      _netAmtCtrl.addListener(_recalculateFinancials);
    }

    setState(() {
      _lossGainAmtCtrl.text = lossAmt.toStringAsFixed(2);
      _taxAmtCtrl.text = taxAmt.toStringAsFixed(2);
    });
  }

  void _onRefineryNameChanged() {
    if (mounted) {
      setState(() {});
      _updateTaxSchemeForSupplier(_refineryCtrl.text);
    }
  }

  void _onQtyChanged() {
    final text = _qtyCtrl.text.trim();
    if (text.isEmpty) return;
    int qty = int.tryParse(text) ?? 1;

    if (qty > _maxPcs) {
      qty = _maxPcs;
      _qtyCtrl.removeListener(_onQtyChanged);
      _qtyCtrl.text = qty.toString();
      _qtyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _qtyCtrl.text.length));
      _qtyCtrl.addListener(_onQtyChanged);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Max stock available is $_maxPcs pcs'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (qty < 1) {
      qty = 1;
      _qtyCtrl.removeListener(_onQtyChanged);
      _qtyCtrl.text = qty.toString();
      _qtyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _qtyCtrl.text.length));
      _qtyCtrl.addListener(_onQtyChanged);
    }

    if (_dbPcs > 0) {
      final factor = qty / _dbPcs;
      _grossWtCtrl.removeListener(_recalculate);
      _stoneWtCtrl.removeListener(_recalculate);

      _grossWtCtrl.text = (_dbGross * factor).toStringAsFixed(3);
      _stoneWtCtrl.text = (_dbOther * factor).toStringAsFixed(3);

      _grossWtCtrl.addListener(_recalculate);
      _stoneWtCtrl.addListener(_recalculate);
      _recalculate();
    }
  }

  void _onLinkedIssueSelected(RefineryIssueReceipt? issue) {
    setState(() {
      _selectedLinkedIssue = issue;
      if (issue != null) {
        _refineryCtrl.text = issue.refineryName;
        _itemNameCtrl.text = issue.itemName;
        _purityCtrl.text = issue.purity.toStringAsFixed(1);
        _issuedFineWeightVal = issue.fineWeight;
        _alreadyReceivedFineWeightVal = widget.getAlreadyReceivedFineWeight(issue.docId, issue.transactionNo);
        _outstandingFineWeightVal = (_issuedFineWeightVal - _alreadyReceivedFineWeightVal).clamp(0.0, double.infinity);
        
        // Auto populate original issue details (read-only references)
        _grossWtCtrl.text = issue.grossWeight.toStringAsFixed(3);
        _stoneWtCtrl.text = issue.stoneWeight.toStringAsFixed(3);
        _netWtCtrl.text = issue.netWeight.toStringAsFixed(3);
        _fineWtCtrl.text = issue.fineWeight.toStringAsFixed(3);

        // Keep received fields empty for manual entry
        _receivedGrossWtCtrl.text = '';
        _receivedStoneWtCtrl.text = '';
        _receivedPurityCtrl.text = '';
        _receivedNetWtCtrl.text = '0.000';
        _receivedFineWtCtrl.text = '0.000';
        
        _updateTaxSchemeForSupplier(issue.refineryName);
      }
    });
    _recalculate();
  }

  void _recalculate() {
    final gross = double.tryParse(_grossWtCtrl.text.trim()) ?? 0.0;
    final stone = double.tryParse(_stoneWtCtrl.text.trim()) ?? 0.0;
    final purity = double.tryParse(_purityCtrl.text.trim()) ?? 0.0;

    final net = (gross - stone).clamp(0.0, double.infinity);
    final fine = (net * purity / 1000.0).clamp(0.0, double.infinity);

    // Calculate Received Weights
    final recGross = double.tryParse(_receivedGrossWtCtrl.text.trim()) ?? 0.0;
    final recStone = double.tryParse(_receivedStoneWtCtrl.text.trim()) ?? 0.0;
    final recPurity = double.tryParse(_receivedPurityCtrl.text.trim()) ?? 0.0;

    final recNet = (recGross - recStone).clamp(0.0, double.infinity);
    final recFine = (recNet * recPurity / 1000.0).clamp(0.0, double.infinity);

    double lossDiff = 0.0;
    if (_txType.contains('Receipt') && _selectedLinkedIssue != null) {
      final totalReceivedAfterThis = _alreadyReceivedFineWeightVal + recFine;
      lossDiff = (_issuedFineWeightVal - totalReceivedAfterThis).clamp(0.0, double.infinity);
    }

    setState(() {
      _netWtCtrl.text = net.toStringAsFixed(3);
      _fineWtCtrl.text = fine.toStringAsFixed(3);
      
      _receivedNetWtCtrl.text = recNet.toStringAsFixed(3);
      _receivedFineWtCtrl.text = recFine.toStringAsFixed(3);
      
      _lossDiffVal = lossDiff;
    });
    _recalculateFinancials();
  }

  @override
  void dispose() {
    _goldRateCtrl.removeListener(_recalculateFinancials);
    _refiningServiceRateCtrl.removeListener(_recalculateFinancials);
    _refiningServiceAmtCtrl.removeListener(_recalculateFinancials);
    _taxPercentageCtrl.removeListener(_recalculateFinancials);
    _netAmtCtrl.removeListener(_recalculateFinancials);

    _goldRateCtrl.dispose();
    _lossGainAmtCtrl.dispose();
    _refiningServiceRateCtrl.dispose();
    _refiningServiceAmtCtrl.dispose();
    _taxPercentageCtrl.dispose();
    _taxAmtCtrl.dispose();
    _netAmtCtrl.dispose();
    _paymentReferenceCtrl.dispose();

    _receivedGrossWtCtrl.removeListener(_recalculate);
    _receivedStoneWtCtrl.removeListener(_recalculate);
    _receivedPurityCtrl.removeListener(_recalculate);
    
    _receivedGrossWtCtrl.dispose();
    _receivedStoneWtCtrl.dispose();
    _receivedNetWtCtrl.dispose();
    _receivedPurityCtrl.dispose();
    _receivedFineWtCtrl.dispose();

    _refineryCtrl.removeListener(_onRefineryNameChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _refineryCtrl.dispose();
    _tagIdCtrl.dispose();
    _tagFocusNode.dispose();
    _itemNameCtrl.dispose();
    _qtyCtrl.dispose();
    _grossWtCtrl.dispose();
    _stoneWtCtrl.dispose();
    _netWtCtrl.dispose();
    _purityCtrl.dispose();
    _fineWtCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.existing == null ? 'New Refinery Entry' : 'Edit Refinery Entry',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 16),
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
              // LEFT COLUMN: MAIN FIELDS & ITEM DETAILS
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VOUCHER DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                        const Divider(color: _border),
                        const SizedBox(height: 8),

                        // Row 1: Transaction No, Date, Type
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'Voucher No',
                                readOnly: true,
                                controller: TextEditingController(text: _txNo),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Voucher Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _border),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xFFF5F5F5),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(dateFormat.format(_date), style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                        const Icon(Icons.lock_outline, size: 14, color: Colors.black38),
                                      ],
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
                                  const Text('Transaction Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _border),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _txType,
                                        items: ['Refinery Issue', 'Refinery Receipt']
                                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                            .toList(),
                                        onChanged: widget.existing != null
                                            ? null
                                            : (v) {
                                                if (v != null) {
                                                  setState(() {
                                                    _txType = v;
                                                    _status = v.contains('Receipt') ? 'COMPLETED' : 'ON PROCESS';
                                                    _txNo = widget.generateTxNo(v);
                                                    _selectedLinkedIssue = null;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Refinery Name & Linked Issue Selector
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Refinery Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                  const SizedBox(height: 4),
                                  Autocomplete<String>(
                                    initialValue: TextEditingValue(text: _refineryCtrl.text),
                                    optionsBuilder: (TextEditingValue tv) {
                                      if (tv.text.isEmpty) return widget.suppliers;
                                      return widget.suppliers.where(
                                        (s) => s.toLowerCase().contains(tv.text.toLowerCase()),
                                      );
                                    },
                                    onSelected: (s) {
                                      _refineryCtrl.text = s;
                                    },
                                    fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                                      ctrl.text = _refineryCtrl.text;
                                      ctrl.addListener(() => _refineryCtrl.text = ctrl.text);
                                      return TextFormField(
                                        controller: ctrl,
                                        focusNode: fn,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Royal Gold Refinery',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                          filled: false,
                                          suffixIcon: widget.suppliers.isEmpty ? null : const Icon(Icons.arrow_drop_down, color: _brownLight),
                                        ),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Refinery name required' : null,
                                      );
                                    },
                                    optionsViewBuilder: (ctx, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(8),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              itemBuilder: (ctx2, i) {
                                                final opt = options.elementAt(i);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(opt, style: const TextStyle(fontSize: 13)),
                                                  onTap: () => onSelected(opt),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (_txType.contains('Receipt')) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Linked Issue Transaction *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<RefineryIssueReceipt>(
                                      key: ValueKey(_selectedLinkedIssue),
                                      initialValue: _selectedLinkedIssue,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      hint: const Text('Select RI Voucher'),
                                      items: widget.availableIssues
                                          .where((issue) => issue.refineryName.toLowerCase().trim() == _refineryCtrl.text.toLowerCase().trim())
                                          .map((issue) {
                                        final alreadyRec = widget.getAlreadyReceivedFineWeight(issue.docId, issue.transactionNo);
                                        final outFine = (issue.fineWeight - alreadyRec).clamp(0.0, double.infinity);
                                        return DropdownMenuItem<RefineryIssueReceipt>(
                                          value: issue,
                                          child: Text(
                                            '${issue.transactionNo} (${outFine.toStringAsFixed(3)}g out)',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _onLinkedIssueSelected,
                                      validator: (v) {
                                        if (_txType.contains('Receipt') && v == null && widget.existing == null) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text('ITEM DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                        const Divider(color: _border),
                        const SizedBox(height: 8),

                        if (_txType == 'Refinery Issue') ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tag ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _tagIdCtrl,
                                      focusNode: _tagFocusNode,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Scan or enter Tag ID',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                        filled: false,
                                      ),
                                      onFieldSubmitted: (v) => _fetchTagDetails(v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Search button
                                  Material(
                                    color: _brown,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _fetchTagDetails(_tagIdCtrl.text),
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(Icons.search, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // QR / Barcode scan button
                                  Material(
                                    color: Colors.teal,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () async {
                                        String? res = await openQrScanner(context);
                                        if (res != null && res != '-1' && res.isNotEmpty) {
                                          final cleanTag = parseScannedTagId(res);
                                          _tagIdCtrl.text = cleanTag;
                                          _fetchTagDetails(cleanTag);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Row 3: Item Name, Quantity
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Item Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                  const SizedBox(height: 4),
                                  Autocomplete<String>(
                                    initialValue: TextEditingValue(text: _itemNameCtrl.text),
                                    optionsBuilder: (TextEditingValue tv) {
                                      if (tv.text.isEmpty) return widget.itemNames;
                                      return widget.itemNames.where(
                                        (s) => s.toLowerCase().contains(tv.text.toLowerCase()),
                                      );
                                    },
                                    onSelected: (s) {
                                      _itemNameCtrl.text = s;
                                    },
                                    fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                                      ctrl.text = _itemNameCtrl.text;
                                      ctrl.addListener(() => _itemNameCtrl.text = ctrl.text);
                                      return TextFormField(
                                        controller: ctrl,
                                        focusNode: fn,
                                        enabled: !_txType.contains('Receipt'),
                                        style: TextStyle(fontSize: 13, color: _txType.contains('Receipt') ? Colors.grey[700] : Colors.black),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Melting Gold Dust',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                          filled: _txType.contains('Receipt'),
                                          fillColor: _txType.contains('Receipt') ? const Color(0xFFF5F5F5) : Colors.white,
                                          suffixIcon: widget.itemNames.isEmpty || _txType.contains('Receipt') ? null : const Icon(Icons.arrow_drop_down, color: _brownLight),
                                        ),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Item name required' : null,
                                      );
                                    },
                                    optionsViewBuilder: (ctx, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(8),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              itemBuilder: (ctx2, i) {
                                                final opt = options.elementAt(i);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(opt, style: const TextStyle(fontSize: 13)),
                                                  onTap: () => onSelected(opt),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'Quantity *',
                                controller: _qtyCtrl,
                                readOnly: _txType.contains('Receipt'),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final q = int.tryParse(v ?? '');
                                  if (q == null || q < 1) return 'Min 1';
                                  if (q > _maxPcs) return 'Max: $_maxPcs pcs';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 4: Gross Wt, Other Wt, Net Wt (Calculated)
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'Gross Weight (g) *',
                                controller: _grossWtCtrl,
                                readOnly: _txType.contains('Receipt'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  final g = double.tryParse(v ?? '');
                                  if (g == null || g < 0) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'Other Weight (g)',
                                controller: _stoneWtCtrl,
                                readOnly: _txType.contains('Receipt'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  final s = double.tryParse(v ?? '');
                                  if (s == null || s < 0) return 'Invalid';
                                  final g = double.tryParse(_grossWtCtrl.text.trim()) ?? 0.0;
                                  if (s > g) return 'Other > Gross';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'Net Weight (g) [Auto]',
                                readOnly: true,
                                controller: _netWtCtrl,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 5: Purity, Fine Weight (Calculated)
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: _txType.contains('Receipt') ? 'Issued Purity (e.g. 916.0)' : 'Estimated Purity (e.g. 916.0) *',
                                controller: _purityCtrl,
                                readOnly: _txType.contains('Receipt'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  final p = double.tryParse(v ?? '');
                                  if (p == null || p <= 0 || p > 1000) return 'Range 1-1000';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: 'Issued Fine Wt (g) [Auto]',
                                readOnly: true,
                                controller: _fineWtCtrl,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Remarks
                        _buildFormField(
                          label: 'Remarks',
                          controller: _remarksCtrl,
                          maxLines: 3,
                          hint: 'Optional notes regarding refining process or loss...',
                        ),

                        if (_txType.contains('Receipt')) ...[
                          const SizedBox(height: 20),
                          const Text('RECEIVED ITEM DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                          const Divider(color: _border),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Received Gross Weight (g) *',
                                  controller: _receivedGrossWtCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final g = double.tryParse(v ?? '');
                                    if (g == null || g < 0) return 'Required';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Received Other Weight (g)',
                                  controller: _receivedStoneWtCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final s = double.tryParse(v ?? '');
                                    if (s == null || s < 0) return 'Invalid';
                                    final g = double.tryParse(_receivedGrossWtCtrl.text.trim()) ?? 0.0;
                                    if (s > g) return 'Other > Gross';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Received Net Weight (g) [Auto]',
                                  readOnly: true,
                                  controller: _receivedNetWtCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Received Purity (e.g. 995.0) *',
                                  controller: _receivedPurityCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final p = double.tryParse(v ?? '');
                                    if (p == null || p <= 0 || p > 1000) return 'Range 1-1000';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Received Fine Weight (g) [Auto]',
                                  readOnly: true,
                                  controller: _receivedFineWtCtrl,
                                  validator: (v) {
                                    final fine = double.tryParse(v ?? '') ?? 0.0;
                                    if (_selectedLinkedIssue != null) {
                                      if (fine > (_outstandingFineWeightVal + 0.005)) {
                                        return 'Exceeds outstanding (${_outstandingFineWeightVal.toStringAsFixed(3)}g)';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // RIGHT COLUMN: LINKED INFO, SUMMARY & SAVE ACTIONS
              SizedBox(
                width: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status dropdown card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                            const Divider(color: _border, height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: _border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _status,
                                  selectedItemBuilder: (BuildContext context) {
                                    return ['ON PROCESS', 'COMPLETED', 'CONVERTED TO SALE', 'RETURNED', 'CANCELLED'].map((s) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: buildStatusChip(s),
                                      );
                                    }).toList();
                                  },
                                  items: ['ON PROCESS', 'COMPLETED', 'CONVERTED TO SALE', 'RETURNED', 'CANCELLED']
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: buildStatusChip(s),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _status = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Linked Issue Details Card
                      if (_txType.contains('Receipt') && _selectedLinkedIssue != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple[50]!.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.purple[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LINKED ISSUE STATS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                              const Divider(color: Colors.purple, height: 12),
                              _buildTotalSummaryRow('Issued Fine Wt:', '${_issuedFineWeightVal.toStringAsFixed(3)} g'),
                              const SizedBox(height: 4),
                              _buildTotalSummaryRow('Prev Received:', '${_alreadyReceivedFineWeightVal.toStringAsFixed(3)} g'),
                              const SizedBox(height: 4),
                              _buildTotalSummaryRow('Outstanding:', '${_outstandingFineWeightVal.toStringAsFixed(3)} g', isBold: true, color: Colors.red[900]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Summary Card
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
                            const Text('YIELD SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                            const Divider(color: _border, height: 16),
                            _buildTotalSummaryRow('Total Quantity:', '${int.tryParse(_qtyCtrl.text.trim()) ?? 1} pcs'),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow('Gross Weight:', '${(double.tryParse(_grossWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g'),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow('Net Weight:', '${(double.tryParse(_netWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g', isBold: true),
                            const SizedBox(height: 6),
                            _buildTotalSummaryRow('Fine Weight:', '${(double.tryParse(_fineWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g', isBold: true, color: Colors.brown.shade800),
                            if (_txType.contains('Receipt')) ...[
                              const Divider(color: _border, height: 16),
                              _buildTotalSummaryRow('Melting Loss:', '${_lossDiffVal.toStringAsFixed(3)} g', isBold: true, color: Colors.red.shade700),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sidebar Save / Cancel Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: _brownLight, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brown,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  if (_txType.contains('Receipt') && _isPaid && (_selectedPaymentBook == null || _selectedPaymentBook!.isEmpty)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('⚠️ Please select a Bank/Cash account to record payment.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  final gross = double.parse(_grossWtCtrl.text.trim());
                                  final stone = double.parse(_stoneWtCtrl.text.trim());
                                  final net = double.parse(_netWtCtrl.text.trim());
                                  final purity = double.parse(_purityCtrl.text.trim());
                                  final fine = double.parse(_fineWtCtrl.text.trim());
                                  final qty = int.parse(_qtyCtrl.text.trim());

                                  final recGross = _txType.contains('Receipt') ? (double.tryParse(_receivedGrossWtCtrl.text.trim()) ?? 0.0) : 0.0;
                                  final recStone = _txType.contains('Receipt') ? (double.tryParse(_receivedStoneWtCtrl.text.trim()) ?? 0.0) : 0.0;
                                  final recNet = _txType.contains('Receipt') ? (double.tryParse(_receivedNetWtCtrl.text.trim()) ?? 0.0) : 0.0;
                                  final recPurity = _txType.contains('Receipt') ? (double.tryParse(_receivedPurityCtrl.text.trim()) ?? 0.0) : 0.0;
                                  final recFine = _txType.contains('Receipt') ? (double.tryParse(_receivedFineWtCtrl.text.trim()) ?? 0.0) : 0.0;

                                  final record = RefineryIssueReceipt(
                                    docId: widget.existing?.docId ?? '',
                                    transactionNo: _txNo,
                                    date: _date,
                                    transactionType: _txType,
                                    refineryName: _refineryCtrl.text.trim(),
                                    referenceIssueNo: _selectedLinkedIssue?.transactionNo ?? widget.existing?.referenceIssueNo ?? '',
                                    referenceIssueDocId: _selectedLinkedIssue?.docId ?? widget.existing?.referenceIssueDocId ?? '',
                                    tagId: _txType.contains('Issue') ? _tagIdCtrl.text.trim().toUpperCase() : '',
                                    itemName: _itemNameCtrl.text.trim(),
                                    quantity: qty,
                                    grossWeight: gross,
                                    stoneWeight: stone,
                                    netWeight: net,
                                    purity: purity,
                                    fineWeight: _txType.contains('Receipt') ? recFine : fine,
                                    issuedFineWeight: _txType.contains('Receipt') ? _issuedFineWeightVal : fine,
                                    receivedFineWeight: _txType.contains('Receipt') ? recFine : 0.0,
                                    lossDifference: _lossDiffVal,
                                    status: _status,
                                    remarks: _remarksCtrl.text.trim(),
                                    createdAt: widget.existing?.createdAt ?? DateTime.now(),
                                    updatedAt: DateTime.now(),
                                    goldRate: double.tryParse(_goldRateCtrl.text.trim()) ?? 0.0,
                                    lossGainAmount: double.tryParse(_lossGainAmtCtrl.text.trim()) ?? 0.0,
                                    refiningServiceRate: double.tryParse(_refiningServiceRateCtrl.text.trim()) ?? 0.0,
                                    refiningServiceAmount: double.tryParse(_refiningServiceAmtCtrl.text.trim()) ?? 0.0,
                                    taxPercentage: double.tryParse(_taxPercentageCtrl.text.trim()) ?? 0.0,
                                    taxAmount: double.tryParse(_taxAmtCtrl.text.trim()) ?? 0.0,
                                    netAmount: double.tryParse(_netAmtCtrl.text.trim()) ?? 0.0,
                                    paymentBook: _isPaid ? (_selectedPaymentBook ?? '') : '',
                                    paymentReference: _isPaid ? _paymentReferenceCtrl.text.trim() : '',
                                    isPaid: _isPaid,
                                    bankEntryDocId: _bankEntryDocId,
                                    receivedGrossWeight: recGross,
                                    receivedStoneWeight: recStone,
                                    receivedNetWeight: recNet,
                                    receivedPurity: recPurity,
                                    refiningChargeType: _refiningChargeType,
                                  );

                                  RefineryIssueReceipt? linkedIssueToUpdate;
                                  if (_txType.contains('Receipt') && _selectedLinkedIssue != null) {
                                    final totalReceivedFine = _alreadyReceivedFineWeightVal + recFine;
                                    final newStatus = (totalReceivedFine >= _issuedFineWeightVal - 0.005) ? 'COMPLETED' : 'PARTIALLY RECEIVED';
                                    final loss = (_issuedFineWeightVal - totalReceivedFine).clamp(0.0, double.infinity);

                                    linkedIssueToUpdate = RefineryIssueReceipt(
                                      docId: _selectedLinkedIssue!.docId,
                                      transactionNo: _selectedLinkedIssue!.transactionNo,
                                      date: _selectedLinkedIssue!.date,
                                      transactionType: _selectedLinkedIssue!.transactionType,
                                      refineryName: _selectedLinkedIssue!.refineryName,
                                      referenceIssueNo: '',
                                      referenceIssueDocId: '',
                                      tagId: _selectedLinkedIssue!.tagId,
                                      itemName: _selectedLinkedIssue!.itemName,
                                      quantity: _selectedLinkedIssue!.quantity,
                                      grossWeight: _selectedLinkedIssue!.grossWeight,
                                      stoneWeight: _selectedLinkedIssue!.stoneWeight,
                                      netWeight: _selectedLinkedIssue!.netWeight,
                                      purity: _selectedLinkedIssue!.purity,
                                      fineWeight: _selectedLinkedIssue!.fineWeight,
                                      issuedFineWeight: _selectedLinkedIssue!.fineWeight,
                                      receivedFineWeight: totalReceivedFine,
                                      lossDifference: loss,
                                      status: newStatus,
                                      remarks: _selectedLinkedIssue!.remarks,
                                      createdAt: _selectedLinkedIssue!.createdAt,
                                    );
                                  }

                                  widget.onSave(record, linkedIssueToUpdate);
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildTotalSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
    ValueChanged<String>? onFieldSubmitted,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          focusNode: focusNode,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(fontSize: 13, fontWeight: readOnly ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
            filled: readOnly,
            fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
          ),
        ),
      ],
    );
  }
}
