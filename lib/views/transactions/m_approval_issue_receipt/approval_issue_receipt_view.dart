import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../state/admin_state.dart';
import '../../../utils/pdf_approval_issue_receipt.dart';
import '../../../models/product.dart';
import '../../../products/repositories/product_repository.dart';
import 'approval_issue_receipt_model.dart';

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
  if (normalized == 'ON PROCESS' || normalized == 'DRAFT' || normalized == 'PENDING' || normalized == 'ISSUED') {
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
      status.replaceAll('_', ' ').toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
    ),
  );
}

class ApprovalIssueReceiptView extends StatefulWidget {
  final AdminState state;

  const ApprovalIssueReceiptView({super.key, required this.state});

  @override
  State<ApprovalIssueReceiptView> createState() => _ApprovalIssueReceiptViewState();
}

class _ApprovalIssueReceiptViewState extends State<ApprovalIssueReceiptView> {
  final List<ApprovalIssueReceipt> _records = [];
  bool _isLoading = false;

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  ApprovalIssueReceipt? _selectedRecord;
  bool _processOnly = false;
  List<String> _assayCentres = ['All'];
  String _selectedAssayCentre = 'All';

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
          .collection('approval_issue_receipts')
          .orderBy('createdAt', descending: true)
          .get();

      final fetched = snap.docs
          .map((doc) => ApprovalIssueReceipt.fromMap(doc.data(), doc.id))
          .toList();

      final uniqueCentres = fetched.map((r) => r.approvalCentre).toSet().toList();
      uniqueCentres.sort();

      final uniqueItems = fetched.map((r) => r.itemName).where((s) => s.isNotEmpty).toSet().toList();
      uniqueItems.sort();

      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(fetched);
          _assayCentres = ['All', ...uniqueCentres];
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

  List<ApprovalIssueReceipt> get _filteredRecords {
    return _records.where((r) {
      final matchSearch = _searchQuery.isEmpty ||
          r.transactionNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.approvalCentre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.referenceIssueNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.assayResult.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchType = _typeFilter == 'All' ||
          r.transactionType.toLowerCase() == _typeFilter.toLowerCase();

      final matchStatus = _statusFilter == 'All' ||
          r.status.toLowerCase() == _statusFilter.toLowerCase() ||
          r.status.replaceAll('_', ' ').toLowerCase() == _statusFilter.toLowerCase() ||
          (_statusFilter == 'ON PROCESS' && (r.status.toLowerCase() == 'draft' || r.status.toLowerCase() == 'pending'));

      final matchAssayCentre = _selectedAssayCentre == 'All' || r.approvalCentre == _selectedAssayCentre;

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

      return matchSearch && matchType && matchStatus && matchAssayCentre && matchProcessOnly && matchDate;
    }).toList();
  }

  String _generateNextTxNumber(String type) {
    final prefix = type.toLowerCase().contains('receipt') ? 'AR-' : 'AI-';
    final count = _records.where((r) => r.transactionNo.startsWith(prefix)).length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  List<ApprovalIssueReceipt> _getAvailableIssuesForLinking(ApprovalIssueReceipt? editingRecord) {
    return _records.where((r) {
      final isMatchingLinked = editingRecord != null &&
          (r.transactionNo == editingRecord.referenceIssueNo ||
           (editingRecord.referenceIssueDocId.isNotEmpty && r.docId == editingRecord.referenceIssueDocId));
      return isMatchingLinked || (r.isIssue && r.status != 'CANCELLED' && r.status != 'COMPLETED');
    }).toList();
  }

  void _convertIssueToReceipt(ApprovalIssueReceipt issue) {
    final receiptRecord = ApprovalIssueReceipt(
      docId: '',
      transactionNo: _generateNextTxNumber('Approval Receipt'),
      date: DateTime.now(),
      transactionType: 'Approval Receipt',
      approvalCentre: issue.approvalCentre,
      referenceIssueNo: issue.transactionNo,
      referenceIssueDocId: issue.docId,
      itemName: issue.itemName,
      quantity: issue.quantity,
      grossWeight: issue.grossWeight,
      stoneWeight: issue.stoneWeight,
      netWeight: issue.netWeight,
      originalPurity: issue.originalPurity,
      approvedPurity: issue.originalPurity,
      originalFineWeight: issue.originalFineWeight,
      approvedFineWeight: issue.originalFineWeight,
      difference: 0.0,
      assayResult: '',
      remarks: 'Converted from Issue ${issue.transactionNo}',
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _openEntryDialog(receiptRecord);
  }

  void _openEntryDialog([ApprovalIssueReceipt? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ApprovalIssueReceiptFormDialog(
        existing: existing,
        generateTxNo: _generateNextTxNumber,
        availableIssues: _getAvailableIssuesForLinking(existing),
        suppliers: _supplierNames,
        itemNames: _uniqueItemNames,
        onSave: (record, linkedIssueToComplete) async {
          try {
            if (existing == null || existing.docId.isEmpty) {
              final docRef = await FirebaseFirestore.instance
                  .collection('approval_issue_receipts')
                  .add(record.toMap());
              final newRecord = ApprovalIssueReceipt.fromMap(record.toMap(), docRef.id);
              setState(() => _records.insert(0, newRecord));
            } else {
              await FirebaseFirestore.instance
                  .collection('approval_issue_receipts')
                  .doc(existing.docId)
                  .update(record.toMap());
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) setState(() => _records[idx] = record);
            }

            // Update linked issue status to COMPLETED if applicable
            if (linkedIssueToComplete != null) {
              final idx = _records.indexWhere((r) => r.docId == linkedIssueToComplete.docId || r.transactionNo == linkedIssueToComplete.transactionNo);
              if (idx != -1) {
                final updatedIssue = ApprovalIssueReceipt(
                  docId: _records[idx].docId,
                  transactionNo: _records[idx].transactionNo,
                  date: _records[idx].date,
                  transactionType: _records[idx].transactionType,
                  approvalCentre: _records[idx].approvalCentre,
                  referenceIssueNo: _records[idx].referenceIssueNo,
                  referenceIssueDocId: _records[idx].referenceIssueDocId,
                  tagId: _records[idx].tagId,
                  itemName: _records[idx].itemName,
                  quantity: _records[idx].quantity,
                  grossWeight: _records[idx].grossWeight,
                  stoneWeight: _records[idx].stoneWeight,
                  netWeight: _records[idx].netWeight,
                  originalPurity: _records[idx].originalPurity,
                  approvedPurity: record.approvedPurity,
                  originalFineWeight: _records[idx].originalFineWeight,
                  approvedFineWeight: record.approvedFineWeight,
                  difference: record.difference,
                  assayResult: record.assayResult,
                  status: 'COMPLETED',
                  remarks: _records[idx].remarks,
                  createdAt: _records[idx].createdAt,
                  updatedAt: DateTime.now(),
                );
                setState(() => _records[idx] = updatedIssue);
                try {
                  await FirebaseFirestore.instance
                      .collection('approval_issue_receipts')
                      .doc(_records[idx].docId)
                      .update({
                    'status': 'COMPLETED',
                    'approvedPurity': record.approvedPurity,
                    'approvedFineWeight': record.approvedFineWeight,
                    'difference': record.difference,
                    'assayResult': record.assayResult,
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
                    transactionType: 'Approval Issue',
                    transactionNo: record.transactionNo,
                  );
                }
              } else {
                final returnTag = record.tagId.isNotEmpty ? record.tagId : (linkedIssueToComplete?.tagId ?? '');
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
                  content: Text('Approval transaction ${record.transactionNo} saved successfully!'),
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

  Future<void> _cancelRecord(ApprovalIssueReceipt record) async {
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
      final updated = ApprovalIssueReceipt(
        docId: record.docId,
        transactionNo: record.transactionNo,
        date: record.date,
        transactionType: record.transactionType,
        approvalCentre: record.approvalCentre,
        referenceIssueNo: record.referenceIssueNo,
        referenceIssueDocId: record.referenceIssueDocId,
        tagId: record.tagId,
        itemName: record.itemName,
        quantity: record.quantity,
        grossWeight: record.grossWeight,
        stoneWeight: record.stoneWeight,
        netWeight: record.netWeight,
        originalPurity: record.originalPurity,
        approvedPurity: record.approvedPurity,
        originalFineWeight: record.originalFineWeight,
        approvedFineWeight: record.approvedFineWeight,
        difference: record.difference,
        assayResult: record.assayResult,
        status: 'CANCELLED',
        remarks: record.remarks,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
      );

      try {
        await FirebaseFirestore.instance
            .collection('approval_issue_receipts')
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

  void _showViewDetailsDialog(ApprovalIssueReceipt r) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Approval Entry ${r.transactionNo}', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)),
            _buildStatusChip(r.status),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Date', dateFormat.format(r.date)),
              _buildDetailRow('Type', r.transactionType),
              _buildDetailRow('Assay / Approval Centre', r.approvalCentre),
              _buildDetailRow('Ref. Issue No', r.referenceIssueNo.isEmpty ? '-' : r.referenceIssueNo),
              const Divider(color: _border),
              _buildDetailRow('Item Name', r.itemName),
              _buildDetailRow('Quantity', r.quantity.toString()),
              _buildDetailRow('Gross Weight', '${r.grossWeight.toStringAsFixed(3)} g'),
              _buildDetailRow('Net Weight', '${r.netWeight.toStringAsFixed(3)} g', isBold: true),
              const Divider(color: _border),
              _buildDetailRow('Original Purity', r.originalPurity.toStringAsFixed(1)),
              _buildDetailRow('Approved Purity', r.approvedPurity.toStringAsFixed(1), isHighlight: true),
              _buildDetailRow('Original Fine Weight', '${r.originalFineWeight.toStringAsFixed(3)} g'),
              _buildDetailRow('Approved Fine Weight', '${r.approvedFineWeight.toStringAsFixed(3)} g', isBold: true),
              _buildDetailRow('Difference', '${r.difference.toStringAsFixed(3)} g'),
              if (r.assayResult.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildDetailRow('Assay Result', r.assayResult, isHighlight: true),
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
              PdfApprovalIssueReceipt.printPdf(r);
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
              color: isHighlight ? Colors.purple[900] : (isBold ? _brown : Colors.black87),
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
                              'Assay Centre',
                              _selectedAssayCentre,
                              _assayCentres,
                              (val) => setState(() {
                                _selectedAssayCentre = val!;
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
                              ['All', 'Approval Issue', 'Approval Receipt'],
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
                                  hintText: 'Search by Tx No, Centre, Item, Result...',
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
                              _selectedRecord!.transactionType != 'Approval Issue' ||
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
                          : () => PdfApprovalIssueReceipt.printPdf(_selectedRecord!),
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
                              Icon(Icons.verified_outlined, size: 48, color: Colors.brown[200]),
                              const SizedBox(height: 12),
                              const Text(
                                'No Approval Issue / Receipt entries found',
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
                                  _buildHeaderCell('Assay Centre', flex: 3),
                                  _buildHeaderCell('Type', flex: 2),
                                  _buildHeaderCell('Ref Issue No', flex: 2),
                                  _buildHeaderCell('Item Name', flex: 3),
                                  _buildHeaderCell('Net Wt', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Orig Purity', flex: 1, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Appr Purity', flex: 1, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Orig Fine', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Appr Fine', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Diff', flex: 2, alignment: Alignment.centerRight),
                                  _buildHeaderCell('Assay Result', flex: 2),
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
                                            Text(r.approvalCentre, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            flex: 3,
                                          ),
                                          _buildRowCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: r.isIssue ? Colors.indigo[50] : Colors.deepOrange[50],
                                                border: Border.all(color: r.isIssue ? Colors.indigo[300]! : Colors.deepOrange[300]!),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                r.transactionType,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: r.isIssue ? Colors.indigo[900] : Colors.deepOrange[900],
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
                                            Text('${r.netWeight.toStringAsFixed(3)} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(r.originalPurity.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                                            flex: 1,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(
                                              r.approvedPurity > 0 ? r.approvedPurity.toStringAsFixed(1) : '-',
                                              style: TextStyle(fontSize: 12, fontWeight: r.approvedPurity > 0 ? FontWeight.bold : FontWeight.normal, color: r.approvedPurity > 0 ? Colors.purple : Colors.black87),
                                            ),
                                            flex: 1,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text('${r.originalFineWeight.toStringAsFixed(3)} g', style: const TextStyle(fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text('${r.approvedFineWeight.toStringAsFixed(3)} g', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 12)),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(
                                              r.difference == 0 ? '-' : '${r.difference.toStringAsFixed(3)} g',
                                              style: TextStyle(
                                                color: r.difference < 0 ? Colors.red[800] : (r.difference > 0 ? Colors.green[800] : Colors.black87),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            flex: 2,
                                            alignment: Alignment.centerRight,
                                          ),
                                          _buildRowCell(
                                            Text(r.assayResult.isEmpty ? '-' : r.assayResult, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            flex: 2,
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
                                                          .collection('approval_issue_receipts')
                                                          .doc(r.docId)
                                                          .update({'status': newValue, 'updatedAt': Timestamp.now()});
                                                      
                                                      final updatedRecord = ApprovalIssueReceipt(
                                                        docId: r.docId,
                                                        transactionNo: r.transactionNo,
                                                        date: r.date,
                                                        transactionType: r.transactionType,
                                                        approvalCentre: r.approvalCentre,
                                                        referenceIssueNo: r.referenceIssueNo,
                                                        referenceIssueDocId: r.referenceIssueDocId,
                                                        itemName: r.itemName,
                                                        quantity: r.quantity,
                                                        grossWeight: r.grossWeight,
                                                        stoneWeight: r.stoneWeight,
                                                        netWeight: r.netWeight,
                                                        originalPurity: r.originalPurity,
                                                        approvedPurity: r.approvedPurity,
                                                        originalFineWeight: r.originalFineWeight,
                                                        approvedFineWeight: r.approvedFineWeight,
                                                        difference: r.difference,
                                                        assayResult: r.assayResult,
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
                                  double totNet = 0.0;
                                  double totOrigFine = 0.0;
                                  double totApprFine = 0.0;
                                  double totDiff = 0.0;
                                  for (final r in filtered) {
                                    totNet += r.netWeight;
                                    totOrigFine += r.originalFineWeight;
                                    totApprFine += r.approvedFineWeight;
                                    totDiff += r.difference;
                                  }
                                  
                                  return Row(
                                    children: [
                                      Text(
                                        'Total Entries: ${filtered.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Net Wt: ${totNet.toStringAsFixed(3)} g  |  '
                                        'Orig Fine: ${totOrigFine.toStringAsFixed(3)} g  |  '
                                        'Appr Fine: ${totApprFine.toStringAsFixed(3)} g  |  '
                                        'Difference: ${totDiff.toStringAsFixed(3)} g',
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

// ── Entry Form Modal Dialog for Approval ─────────────────────────────────────

class _ApprovalIssueReceiptFormDialog extends StatefulWidget {
  final ApprovalIssueReceipt? existing;
  final String Function(String type) generateTxNo;
  final List<ApprovalIssueReceipt> availableIssues;
  final List<String> suppliers;
  final List<String> itemNames;
  final Function(ApprovalIssueReceipt record, ApprovalIssueReceipt? linkedIssueToComplete) onSave;

  const _ApprovalIssueReceiptFormDialog({
    this.existing,
    required this.generateTxNo,
    required this.availableIssues,
    required this.suppliers,
    required this.itemNames,
    required this.onSave,
  });

  @override
  State<_ApprovalIssueReceiptFormDialog> createState() => _ApprovalIssueReceiptFormDialogState();
}

class _ApprovalIssueReceiptFormDialogState extends State<_ApprovalIssueReceiptFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _txNo;
  late DateTime _date;
  String _txType = 'Approval Issue';
  final _centreCtrl = TextEditingController(text: '');
  ApprovalIssueReceipt? _selectedLinkedIssue;
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
  final _origPurityCtrl = TextEditingController(text: '995.0');
  final _apprPurityCtrl = TextEditingController(text: '995.0');
  final _origFineWtCtrl = TextEditingController(text: '0.000');
  final _apprFineWtCtrl = TextEditingController(text: '0.000');
  final _diffCtrl = TextEditingController(text: '0.000');
  final _assayResultCtrl = TextEditingController(text: 'Passed — Hallmark Certified 916/995');
  final _remarksCtrl = TextEditingController();
  String _status = 'ON PROCESS';

  // Billing fields (Approval Receipt only)
  final _ratePerPieceCtrl = TextEditingController();
  final _serviceChargeAmtCtrl = TextEditingController();
  final _netAmtCtrl = TextEditingController();
  final _paymentReferenceCtrl = TextEditingController();
  List<String> _bookNames = ['None'];
  String? _selectedPaymentBook = 'None';
  bool _isPaid = false;

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
          _origPurityCtrl.text = purityVal.toString();
          _apprPurityCtrl.text = purityVal.toString();
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
    _loadBookNames();
    if (widget.existing != null) {
      final e = widget.existing!;
      _txNo = e.transactionNo;
      _date = e.date;
      _txType = e.transactionType;
      _centreCtrl.text = e.approvalCentre;
      _tagIdCtrl.text = e.tagId;
      _itemNameCtrl.text = e.itemName;
      _qtyCtrl.text = e.quantity.toString();
      _grossWtCtrl.text = e.grossWeight.toStringAsFixed(3);
      _stoneWtCtrl.text = e.stoneWeight.toStringAsFixed(3);
      _netWtCtrl.text = e.netWeight.toStringAsFixed(3);
      _origPurityCtrl.text = e.originalPurity.toStringAsFixed(1);
      _apprPurityCtrl.text = e.approvedPurity.toStringAsFixed(1);
      _origFineWtCtrl.text = e.originalFineWeight.toStringAsFixed(3);
      _apprFineWtCtrl.text = e.approvedFineWeight.toStringAsFixed(3);
      _diffCtrl.text = e.difference.toStringAsFixed(3);
      _assayResultCtrl.text = e.assayResult;
      _remarksCtrl.text = e.remarks;
      _serviceChargeAmtCtrl.text = e.serviceChargeAmount > 0 ? e.serviceChargeAmount.toString() : '';
      _netAmtCtrl.text = e.netAmount > 0 ? e.netAmount.toStringAsFixed(2) : '';
      _paymentReferenceCtrl.text = e.paymentReference;
      _isPaid = e.isPaid;
      _selectedPaymentBook = e.paymentBook.isNotEmpty ? e.paymentBook : 'None';
      // Reverse-calculate rate per piece if possible
      final qty = e.quantity > 0 ? e.quantity : 1;
      if (e.serviceChargeAmount > 0) {
        _ratePerPieceCtrl.text = (e.serviceChargeAmount / qty).toStringAsFixed(2);
      }

      if (e.referenceIssueNo.isNotEmpty) {
        try {
          _selectedLinkedIssue = widget.availableIssues.firstWhere(
            (issue) => issue.transactionNo == e.referenceIssueNo || (e.referenceIssueDocId.isNotEmpty && issue.docId == e.referenceIssueDocId),
          );
        } catch (_) {}
      }
      
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
    }

    _grossWtCtrl.addListener(_recalculate);
    _stoneWtCtrl.addListener(_recalculate);
    _origPurityCtrl.addListener(_recalculate);
    _apprPurityCtrl.addListener(_recalculate);
    _qtyCtrl.addListener(_onQtyChanged);
    _centreCtrl.addListener(_onCentreNameChanged);
    _serviceChargeAmtCtrl.addListener(_recalculateBilling);
    _ratePerPieceCtrl.addListener(_onRatePerPieceChanged);
  }

  Future<void> _loadBookNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final fetched = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? doc.id)
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _bookNames = ['None', 'Cash', 'Card', 'UPI', ...fetched];
          if (_selectedPaymentBook != null && !_bookNames.contains(_selectedPaymentBook)) {
            _bookNames.add(_selectedPaymentBook!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading book names: $e');
    }
  }

  void _onRatePerPieceChanged() {
    final rate = double.tryParse(_ratePerPieceCtrl.text.trim()) ?? 0.0;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final svcAmt = rate * qty;
    // Update service charge without triggering its own listener loop
    _serviceChargeAmtCtrl.removeListener(_recalculateBilling);
    if (rate > 0) {
      _serviceChargeAmtCtrl.text = svcAmt.toStringAsFixed(2);
    } else {
      _serviceChargeAmtCtrl.text = '';
    }
    _serviceChargeAmtCtrl.addListener(_recalculateBilling);
    _recalculateBilling();
  }

  void _recalculateBilling() {
    final svcAmt = double.tryParse(_serviceChargeAmtCtrl.text.trim()) ?? 0.0;
    final taxPct = 18.0;
    final tax = svcAmt * taxPct / 100.0;
    final net = svcAmt + tax;
    setState(() {
      _netAmtCtrl.text = net.toStringAsFixed(2);
    });
  }

  void _onCentreNameChanged() {
    if (mounted) {
      setState(() {
        _selectedLinkedIssue = null;
      });
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
    _onRatePerPieceChanged();
  }

  void _onLinkedIssueSelected(ApprovalIssueReceipt? issue) {
    setState(() {
      _selectedLinkedIssue = issue;
      if (issue != null) {
        _centreCtrl.text = issue.approvalCentre;
        _itemNameCtrl.text = issue.itemName;
        _grossWtCtrl.text = issue.grossWeight.toStringAsFixed(3);
        _stoneWtCtrl.text = issue.stoneWeight.toStringAsFixed(3);
        
        // Fetch quantity and set max limit
        _qtyCtrl.text = issue.quantity.toString();
        _maxPcs = issue.quantity;
        _dbPcs = issue.quantity;
        _dbGross = issue.grossWeight;
        _dbOther = issue.stoneWeight;

        // Original Purity comes from the linked Issue (was entered at issue time)
        _origPurityCtrl.text = issue.originalPurity > 0 ? issue.originalPurity.toStringAsFixed(1) : '';
        _origFineWtCtrl.text = issue.originalFineWeight > 0 ? issue.originalFineWeight.toStringAsFixed(3) : '0.000';
        // Approved Purity & Assay Result must be entered fresh — lab results at receipt time
        _apprPurityCtrl.text = '';
        _apprFineWtCtrl.text = '0.000';
        _diffCtrl.text = '0.000';
        _assayResultCtrl.text = '';
      }
    });
    _recalculate();
    _onRatePerPieceChanged();
  }

  void _recalculate() {
    final gross = double.tryParse(_grossWtCtrl.text.trim()) ?? 0.0;
    final stone = double.tryParse(_stoneWtCtrl.text.trim()) ?? 0.0;
    final origPurity = double.tryParse(_origPurityCtrl.text.trim()) ?? 0.0;
    final apprPurity = double.tryParse(_apprPurityCtrl.text.trim()) ?? origPurity;

    final net = (gross - stone).clamp(0.0, double.infinity);
    final origFine = (net * origPurity / 1000.0).clamp(0.0, double.infinity);
    final apprFine = (net * apprPurity / 1000.0).clamp(0.0, double.infinity);
    final diff = apprFine - origFine;

    setState(() {
      _netWtCtrl.text = net.toStringAsFixed(3);
      _origFineWtCtrl.text = origFine.toStringAsFixed(3);
      _apprFineWtCtrl.text = apprFine.toStringAsFixed(3);
      _diffCtrl.text = diff.toStringAsFixed(3);
    });
  }

  @override
  void dispose() {
    _centreCtrl.removeListener(_onCentreNameChanged);
    _qtyCtrl.removeListener(_onQtyChanged);
    _serviceChargeAmtCtrl.removeListener(_recalculateBilling);
    _ratePerPieceCtrl.removeListener(_onRatePerPieceChanged);
    _centreCtrl.dispose();
    _tagIdCtrl.dispose();
    _tagFocusNode.dispose();
    _itemNameCtrl.dispose();
    _qtyCtrl.dispose();
    _grossWtCtrl.dispose();
    _stoneWtCtrl.dispose();
    _netWtCtrl.dispose();
    _origPurityCtrl.dispose();
    _apprPurityCtrl.dispose();
    _origFineWtCtrl.dispose();
    _apprFineWtCtrl.dispose();
    _diffCtrl.dispose();
    _assayResultCtrl.dispose();
    _remarksCtrl.dispose();
    _ratePerPieceCtrl.dispose();
    _serviceChargeAmtCtrl.dispose();
    _netAmtCtrl.dispose();
    _paymentReferenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.existing == null ? 'New Approval Issue / Receipt' : 'Edit Approval Entry',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: _brownLight),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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
                                        items: ['Approval Issue', 'Approval Receipt']
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
                                                    // Clear purity & assay fields — must be entered fresh for each transaction
                                                    _origPurityCtrl.text = '';
                                                    _apprPurityCtrl.text = '';
                                                    _origFineWtCtrl.text = '0.000';
                                                    _apprFineWtCtrl.text = '0.000';
                                                    _diffCtrl.text = '0.000';
                                                    _assayResultCtrl.text = '';
                                                    _ratePerPieceCtrl.text = '';
                                                    _serviceChargeAmtCtrl.text = '';
                                                    _netAmtCtrl.text = '';
                                                    _paymentReferenceCtrl.text = '';
                                                    _selectedPaymentBook = 'None';
                                                    _isPaid = false;
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

                        // Row 2: Approval Centre & Linked Issue Selector
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Approval / Assay Centre *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                                  const SizedBox(height: 4),
                                  Autocomplete<String>(
                                    initialValue: TextEditingValue(text: _centreCtrl.text),
                                    optionsBuilder: (TextEditingValue tv) {
                                      if (tv.text.isEmpty) return widget.suppliers;
                                      return widget.suppliers.where(
                                        (s) => s.toLowerCase().contains(tv.text.toLowerCase()),
                                      );
                                    },
                                    onSelected: (s) {
                                      _centreCtrl.text = s;
                                    },
                                    fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                                      ctrl.text = _centreCtrl.text;
                                      ctrl.addListener(() => _centreCtrl.text = ctrl.text);
                                      return TextFormField(
                                        controller: ctrl,
                                        focusNode: fn,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. BIS Hallmark Testing Centre',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                          filled: false,
                                          suffixIcon: widget.suppliers.isEmpty ? null : const Icon(Icons.arrow_drop_down, color: _brownLight),
                                        ),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Centre name required' : null,
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
                                    DropdownButtonFormField<ApprovalIssueReceipt>(
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
                                      hint: const Text('Select AI Voucher'),
                                      items: widget.availableIssues
                                          .where((issue) => issue.approvalCentre.toLowerCase().trim() == _centreCtrl.text.toLowerCase().trim())
                                          .map((issue) {
                                        return DropdownMenuItem<ApprovalIssueReceipt>(
                                          value: issue,
                                          child: Text(
                                            '${issue.transactionNo} (${issue.itemName})',
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

                        if (_txType == 'Approval Issue') ...[
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
                                      if (_txType.contains('Receipt')) return const Iterable<String>.empty();
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
                                      final isReceipt = _txType.contains('Receipt');
                                      return TextFormField(
                                        controller: ctrl,
                                        focusNode: fn,
                                        readOnly: isReceipt,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Gold Bangle 916 Hallmark',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                                          filled: isReceipt,
                                          fillColor: isReceipt ? const Color(0xFFF5F5F5) : Colors.white,
                                          suffixIcon: (widget.itemNames.isEmpty || isReceipt) ? null : const Icon(Icons.arrow_drop_down, color: _brownLight),
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

                        // Purity & Fine Weight — shown for BOTH Issue and Receipt (Issue: to record issued purity; Receipt: in PURITY & ASSAY section below)
                        if (_txType == 'Approval Issue') ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Purity (e.g. 916.0) *',
                                  controller: _origPurityCtrl,
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
                                  label: 'Fine Weight (g) [Auto]',
                                  readOnly: true,
                                  controller: _origFineWtCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_txType.contains('Receipt')) ...[
                          const Text('PURITY & ASSAY COMPARISON', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                          const Divider(color: _border),
                          const SizedBox(height: 8),

                          // Original Purity, Approved Purity
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Original Purity (e.g. 916.0) *',
                                  controller: _origPurityCtrl,
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
                                  label: 'Approved Purity (e.g. 918.5) *',
                                  controller: _apprPurityCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final p = double.tryParse(v ?? '');
                                    if (p == null || p <= 0 || p > 1000) return 'Range 1-1000';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Original Fine Wt, Approved Fine Wt, Difference
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Original Fine Weight (g) [Auto]',
                                  readOnly: true,
                                  controller: _origFineWtCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Approved Fine Weight (g) [Auto]',
                                  readOnly: true,
                                  controller: _apprFineWtCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Difference (g) [Auto]',
                                  readOnly: true,
                                  controller: _diffCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Assay Result Details
                          _buildFormField(
                            label: 'Assay Result / Certification Details',
                            controller: _assayResultCtrl,
                            hint: 'e.g. Passed 916 Hallmark (Certificate # H-8891)',
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Remarks (always shown)
                        _buildFormField(
                          label: 'Remarks',
                          controller: _remarksCtrl,
                          maxLines: 4,
                          hint: 'Optional notes regarding approval/testing...',
                        ),
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
                            color: Colors.indigo[50]!.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.indigo[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LINKED ISSUE STATS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              const Divider(color: Colors.indigo, height: 12),
                              _buildTotalSummaryRow('Issued Net Wt:', '${_selectedLinkedIssue!.netWeight.toStringAsFixed(3)} g'),
                              const SizedBox(height: 4),
                              _buildTotalSummaryRow('Orig Fine Wt:', '${_selectedLinkedIssue!.originalFineWeight.toStringAsFixed(3)} g'),
                              const SizedBox(height: 4),
                              _buildTotalSummaryRow('Orig Purity:', _selectedLinkedIssue!.originalPurity.toStringAsFixed(1)),
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
                            if (_txType == 'Approval Issue') ...[
                              _buildTotalSummaryRow(
                                'Purity:',
                                (double.tryParse(_origPurityCtrl.text.trim()) ?? 0.0) > 0
                                    ? '${(double.tryParse(_origPurityCtrl.text.trim()) ?? 0.0).toStringAsFixed(1)} / 1000'
                                    : '—',
                              ),
                              const SizedBox(height: 6),
                              _buildTotalSummaryRow('Fine Weight:', '${(double.tryParse(_origFineWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g', isBold: true, color: Colors.brown.shade800),
                            ] else ...[
                              _buildTotalSummaryRow('Orig Fine:', '${(double.tryParse(_origFineWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g'),
                              const SizedBox(height: 6),
                              _buildTotalSummaryRow('Approved Fine:', '${(double.tryParse(_apprFineWtCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g', isBold: true, color: Colors.brown.shade800),
                            ],
                            if (_txType.contains('Receipt')) ...[
                              const Divider(color: _border, height: 16),
                              _buildTotalSummaryRow(
                                'Purity Difference:',
                                '${(double.tryParse(_diffCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g',
                                isBold: true,
                                color: (double.tryParse(_diffCtrl.text.trim()) ?? 0.0) < 0
                                    ? Colors.red.shade700
                                    : ((double.tryParse(_diffCtrl.text.trim()) ?? 0.0) > 0 ? Colors.green.shade700 : Colors.black87),
                              ),
                            ] else ...[
                              const Divider(color: _border, height: 16),
                              _buildTotalSummaryRow(
                                'Purity Difference:',
                                '${(double.tryParse(_diffCtrl.text.trim()) ?? 0.0).toStringAsFixed(3)} g',
                                isBold: true,
                                color: (double.tryParse(_diffCtrl.text.trim()) ?? 0.0) < 0
                                    ? Colors.red.shade700
                                    : ((double.tryParse(_diffCtrl.text.trim()) ?? 0.0) > 0 ? Colors.green.shade700 : Colors.black87),
                              ),
                            ],
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
                                  final gross = double.parse(_grossWtCtrl.text.trim());
                                  final stone = double.parse(_stoneWtCtrl.text.trim());
                                  final net = double.parse(_netWtCtrl.text.trim());
                                  final origPurity = double.parse(_origPurityCtrl.text.trim());
                                  final apprPurity = double.parse(_apprPurityCtrl.text.trim());
                                  final origFine = double.parse(_origFineWtCtrl.text.trim());
                                  final apprFine = double.parse(_apprFineWtCtrl.text.trim());
                                  final diff = double.parse(_diffCtrl.text.trim());
                                  final qty = int.parse(_qtyCtrl.text.trim());

                                  final record = ApprovalIssueReceipt(
                                    docId: widget.existing?.docId ?? '',
                                    transactionNo: _txNo,
                                    date: _date,
                                    transactionType: _txType,
                                    approvalCentre: _centreCtrl.text.trim(),
                                    referenceIssueNo: _selectedLinkedIssue?.transactionNo ?? widget.existing?.referenceIssueNo ?? '',
                                    referenceIssueDocId: _selectedLinkedIssue?.docId ?? widget.existing?.referenceIssueDocId ?? '',
                                    tagId: _txType.contains('Issue') ? _tagIdCtrl.text.trim().toUpperCase() : '',
                                    itemName: _itemNameCtrl.text.trim(),
                                    quantity: qty,
                                    grossWeight: gross,
                                    stoneWeight: stone,
                                    netWeight: net,
                                    originalPurity: origPurity,
                                    approvedPurity: apprPurity,
                                    originalFineWeight: origFine,
                                    approvedFineWeight: apprFine,
                                    difference: diff,
                                    assayResult: _assayResultCtrl.text.trim(),
                                    status: _status,
                                    remarks: _remarksCtrl.text.trim(),
                                    createdAt: widget.existing?.createdAt ?? DateTime.now(),
                                    updatedAt: DateTime.now(),
                                    serviceChargeAmount: double.tryParse(_serviceChargeAmtCtrl.text.trim()) ?? 0.0,
                                    taxPercentage: 18.0,
                                    taxAmount: (double.tryParse(_serviceChargeAmtCtrl.text.trim()) ?? 0.0) * 0.18,
                                    netAmount: double.tryParse(_netAmtCtrl.text.trim()) ?? 0.0,
                                    paymentBook: _isPaid ? (_selectedPaymentBook ?? '') : '',
                                    paymentReference: _isPaid ? _paymentReferenceCtrl.text.trim() : '',
                                    isPaid: _isPaid,
                                  );

                                  ApprovalIssueReceipt? linkedIssueToComplete;
                                  if (_txType.contains('Receipt') && _selectedLinkedIssue != null) {
                                    linkedIssueToComplete = _selectedLinkedIssue;
                                  }

                                  widget.onSave(record, linkedIssueToComplete);
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
