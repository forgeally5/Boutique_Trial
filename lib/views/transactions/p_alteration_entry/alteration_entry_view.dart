import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../../state/admin_state.dart';
import '../../../products/repositories/product_repository.dart';
import 'package:image_picker/image_picker.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../cloudinary_service.dart';
import '../../../utils/pdf_alteration_entry.dart';
import '../../../models/product.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);


double _numVal(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

// ─────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────
Widget _buildAltStatusChip(String status) {
  Color bg = Colors.grey[50]!;
  Color text = Colors.grey[800]!;
  Color border = Colors.grey[300]!;
  final s = status.toUpperCase();
  if (s == 'PENDING') {
    bg = Colors.orange[50]!;
    text = Colors.orange[800]!;
    border = Colors.orange[200]!;
  } else if (s == 'ALLOCATED') {
    bg = Colors.blue[50]!;
    text = Colors.blue[800]!;
    border = Colors.blue[200]!;
  } else if (s == 'COMPLETED') {
    bg = Colors.green[50]!;
    text = Colors.green[800]!;
    border = Colors.green[200]!;
  } else if (s == 'YET TO BILL') {
    bg = Colors.amber[50]!;
    text = Colors.amber[900]!;
    border = Colors.amber[300]!;
  } else if (s == 'CANCELLED') {
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
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────
class AlterationEntry {
  String docId;
  String voucherNo;
  DateTime voucherDate;
  String transactionType; // 'Alteration Issue' or 'Alteration Receipt'
  String repairType;
  String salesman;
  String customerName;
  DateTime? expectedDelivery;
  String tagId;
  String itemName;
  String problemDescription;
  double grossWeight;
  double stoneWeight;
  double netWeight;
  double purity;
  String imageUrl;
  String remarks;
  String status; // Pending, Allocated, Completed, Cancelled
  // Supplier allocation fields
  String supplierName;
  String supplierDeliveryDate;
  String supplierRemarks;
  DateTime createdAt;
  DateTime updatedAt;

  // Financial & Receipt Details
  double repairedGrossWeight;
  double extraGoldAdded;
  double goldRate;
  double goldAmount;
  String labourType; // 'Fixed', 'Per Piece', 'Per Gram Gross Weight', 'Per Gram Net Weight', 'Per Gram Fine Weight', 'Percentage on Gross Weight', 'Percentage on Net Weight', 'Percentage on Fine Weight'
  double labourRate;
  double labourAmount;
  double otherCharges;
  double netAmount;
  String paymentBook;
  String paymentReference;
  String taxScheme; // 'CGST + SGST (Local)' or 'IGST (Interstate)'
  double cgstAmount;
  double sgstAmount;
  double igstAmount;

  AlterationEntry({
    this.docId = '',
    this.voucherNo = '',
    required this.voucherDate,
    this.transactionType = 'Alteration Issue',
    this.repairType = '',
    this.salesman = '',
    this.customerName = '',
    this.expectedDelivery,
    this.tagId = '',
    this.itemName = '',
    this.problemDescription = '',
    this.grossWeight = 0.0,
    this.stoneWeight = 0.0,
    this.netWeight = 0.0,
    this.purity = 916.0,
    this.imageUrl = '',
    this.remarks = '',
    this.status = 'Pending',
    this.supplierName = '',
    this.supplierDeliveryDate = '',
    this.supplierRemarks = '',
    required this.createdAt,
    required this.updatedAt,
    this.repairedGrossWeight = 0.0,
    this.extraGoldAdded = 0.0,
    this.goldRate = 0.0,
    this.goldAmount = 0.0,
    this.labourType = 'Fixed',
    this.labourRate = 0.0,
    this.labourAmount = 0.0,
    this.otherCharges = 0.0,
    this.netAmount = 0.0,
    this.paymentBook = '',
    this.paymentReference = '',
    this.taxScheme = 'CGST + SGST (Local)',
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
  });

  bool get isIssue => transactionType == 'Alteration Issue';

  factory AlterationEntry.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }
    return AlterationEntry(
      docId: id,
      voucherNo: map['voucherNo'] ?? '',
      voucherDate: parseTs(map['voucherDate']),
      transactionType: map['transactionType'] ?? 'Alteration Issue',
      repairType: map['repairType'] ?? '',
      salesman: map['salesman'] ?? '',
      customerName: map['customerName'] ?? '',
      expectedDelivery: map['expectedDelivery'] != null ? parseTs(map['expectedDelivery']) : null,
      tagId: map['tagId'] ?? '',
      itemName: map['itemName'] ?? '',
      problemDescription: map['problemDescription'] ?? '',
      grossWeight: _numVal(map['grossWeight']),
      stoneWeight: _numVal(map['stoneWeight']),
      netWeight: _numVal(map['netWeight']),
      purity: _numVal(map['purity']),
      imageUrl: map['imageUrl'] ?? '',
      remarks: map['remarks'] ?? '',
      status: map['status'] ?? 'Pending',
      supplierName: map['supplierName'] ?? '',
      supplierDeliveryDate: map['supplierDeliveryDate'] ?? '',
      supplierRemarks: map['supplierRemarks'] ?? '',
      createdAt: parseTs(map['createdAt']),
      updatedAt: parseTs(map['updatedAt']),
      repairedGrossWeight: _numVal(map['repairedGrossWeight']),
      extraGoldAdded: _numVal(map['extraGoldAdded']),
      goldRate: _numVal(map['goldRate']),
      goldAmount: _numVal(map['goldAmount']),
      labourType: map['labourType'] ?? 'Fixed',
      labourRate: _numVal(map['labourRate']),
      labourAmount: _numVal(map['labourAmount']),
      otherCharges: _numVal(map['otherCharges']),
      netAmount: _numVal(map['netAmount']),
      paymentBook: map['paymentBook'] ?? '',
      paymentReference: map['paymentReference'] ?? '',
      taxScheme: map['taxScheme'] ?? 'CGST + SGST (Local)',
      cgstAmount: _numVal(map['cgstAmount']),
      sgstAmount: _numVal(map['sgstAmount']),
      igstAmount: _numVal(map['igstAmount']),
    );
  }

  Map<String, dynamic> toMap() => {
    'voucherNo': voucherNo,
    'voucherDate': Timestamp.fromDate(voucherDate),
    'transactionType': transactionType,
    'repairType': repairType,
    'salesman': salesman,
    'customerName': customerName,
    'expectedDelivery': expectedDelivery != null ? Timestamp.fromDate(expectedDelivery!) : null,
    'tagId': tagId,
    'itemName': itemName,
    'problemDescription': problemDescription,
    'grossWeight': grossWeight,
    'stoneWeight': stoneWeight,
    'netWeight': netWeight,
    'purity': purity,
    'imageUrl': imageUrl,
    'remarks': remarks,
    'status': status,
    'supplierName': supplierName,
    'supplierDeliveryDate': supplierDeliveryDate,
    'supplierRemarks': supplierRemarks,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'repairedGrossWeight': repairedGrossWeight,
    'extraGoldAdded': extraGoldAdded,
    'goldRate': goldRate,
    'goldAmount': goldAmount,
    'labourType': labourType,
    'labourRate': labourRate,
    'labourAmount': labourAmount,
    'otherCharges': otherCharges,
    'netAmount': netAmount,
    'paymentBook': paymentBook,
    'paymentReference': paymentReference,
    'taxScheme': taxScheme,
    'cgstAmount': cgstAmount,
    'sgstAmount': sgstAmount,
    'igstAmount': igstAmount,
  };
}

// ─────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────
class AlterationEntryView extends StatefulWidget {
  final AdminState state;
  final String? initialSubSection;

  const AlterationEntryView({
    super.key,
    required this.state,
    this.initialSubSection,
  });

  @override
  State<AlterationEntryView> createState() => _AlterationEntryViewState();
}

class _AlterationEntryViewState extends State<AlterationEntryView> {
  final List<AlterationEntry> _records = [];
  bool _isLoading = false;
  int _activeTab = 0; // 0 = Bookings List, 1 = Supplier Allocation

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  AlterationEntry? _selectedRecord;

  // Dropdown data
  List<String> _supplierNames = [];
  List<String> _itemNames = [];
  List<String> _salesmen = [];
  List<String> _customers = [];

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.initialSubSection?.contains('Receipt') == true) {
      _typeFilter = 'Alteration Receipt';
    }
    _fetchRecords();
    _loadDropdowns();
  }

  @override
  void didUpdateWidget(covariant AlterationEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubSection != oldWidget.initialSubSection) {
      setState(() {
        if (widget.initialSubSection?.contains('Receipt') == true) {
          _typeFilter = 'Alteration Receipt';
        } else if (widget.initialSubSection?.contains('Issue') == true) {
          _typeFilter = 'Alteration Issue';
        } else {
          _typeFilter = 'All';
        }
        _selectedRecord = null;
      });
    }
  }

  Future<void> _loadDropdowns() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      final supp = snap.docs.map((d) => d.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final custSnap = await FirebaseFirestore.instance.collection('customers').get();
      final custs = custSnap.docs.map((d) => d.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final items = await ProductRepository().getUniqueItemNames();
      final sales = await ProductRepository().getUniqueSalesmen();

      if (mounted) {
        setState(() {
          _supplierNames = supp;
          _customers = custs;
          _itemNames = items;
          _salesmen = sales;
        });
      }
    } catch (e) {
      debugPrint('Error loading dropdowns: $e');
    }
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('alteration_entries')
          .orderBy('createdAt', descending: true)
          .get();
      final fetched = snap.docs.map((d) => AlterationEntry.fromMap(d.data(), d.id)).toList();
      if (mounted) {
        setState(() => _records
          ..clear()
          ..addAll(fetched));
      }
    } catch (e) {
      debugPrint('Alteration fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AlterationEntry> get _filteredRecords {
    return _records.where((r) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          r.voucherNo.toLowerCase().contains(q) ||
          r.customerName.toLowerCase().contains(q) ||
          r.itemName.toLowerCase().contains(q) ||
          r.tagId.toLowerCase().contains(q) ||
          r.problemDescription.toLowerCase().contains(q);
      final matchType = _typeFilter == 'All' || r.transactionType == _typeFilter;
      final matchStatus = _statusFilter == 'All' || r.status.toLowerCase() == _statusFilter.toLowerCase();
      bool matchDate = true;
      if (_fromDate != null) matchDate = matchDate && !r.voucherDate.isBefore(_fromDate!);
      if (_toDate != null) matchDate = matchDate && !r.voucherDate.isAfter(_toDate!.add(const Duration(days: 1)));
      return matchSearch && matchType && matchStatus && matchDate;
    }).toList();
  }

  String _generateNextVoucherNo(String type) {
    final prefix = type == 'Alteration Receipt' ? 'ALT-REC-' : 'ALT-ISS-';
    final count = _records.where((r) => r.voucherNo.startsWith(prefix)).length + 1;
    return '$prefix$count';
  }

  void _openEntryDialog([AlterationEntry? existing, AlterationEntry? linkedIssue]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AlterationFormDialog(
        existing: existing,
        linkedIssue: linkedIssue,
        generateVoucherNo: _generateNextVoucherNo,
        availableIssues: _records.where((r) => r.isIssue && r.status != 'Cancelled').toList(),
        suppliers: _supplierNames,
        itemNames: _itemNames,
        salesmen: _salesmen,
        customers: _customers,
        onSave: (record, {AlterationEntry? linkedIssueToComplete}) async {
          try {
            final connectivityResult = await Connectivity().checkConnectivity();
            final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
            
            final data = record.toMap();
            
            if (isOnline) {
              if (existing == null || existing.docId.isEmpty) {
                data['createdAt'] = FieldValue.serverTimestamp();
                final ref = await FirebaseFirestore.instance.collection('alteration_entries').add(data);
                final newRecord = AlterationEntry.fromMap({...data, 'createdAt': Timestamp.now()}, ref.id);
                setState(() => _records.insert(0, newRecord));
              } else {
                await FirebaseFirestore.instance.collection('alteration_entries').doc(existing.docId).update(data);
                final idx = _records.indexWhere((r) => r.docId == existing.docId);
                if (idx != -1) {
                  setState(() => _records[idx] = AlterationEntry.fromMap({...data, 'createdAt': Timestamp.now()}, existing.docId));
                }
              }
              // Mark linked issue as Completed when receipt is saved as Completed
              if (linkedIssueToComplete != null && linkedIssueToComplete.docId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('alteration_entries')
                    .doc(linkedIssueToComplete.docId)
                    .update({'status': 'Completed', 'updatedAt': Timestamp.now()});
                final issueIdx = _records.indexWhere((r) => r.docId == linkedIssueToComplete.docId);
                if (issueIdx != -1) {
                  setState(() => _records[issueIdx].status = 'Completed');
                }
              }
            } else {
               if (!data['voucherNo'].toString().endsWith('-OFF')) {
                  data['voucherNo'] = '${data['voucherNo']}-OFF';
                  record.voucherNo = data['voucherNo'];
               }
               if (linkedIssueToComplete != null && linkedIssueToComplete.docId.isNotEmpty) {
                  await LocalDbService().insertEntry(
                     'alteration_entries', 
                     {'status': 'Completed', 'updatedAt': Timestamp.now()},
                     operation: 'UPDATE', 
                     docId: linkedIssueToComplete.docId
                  );
                  final issueIdx = _records.indexWhere((r) => r.docId == linkedIssueToComplete.docId);
                  if (issueIdx != -1) {
                     setState(() => _records[issueIdx].status = 'Completed');
                  }
               }
               await LocalDbService().insertEntry(
                  'alteration_entries', 
                  data, 
                  operation: existing != null ? 'UPDATE' : 'ADD', 
                  docId: existing?.docId
               );
               SyncService().syncNow();
               
               if (existing == null) {
                  final newRecord = AlterationEntry.fromMap({...data, 'createdAt': Timestamp.now()}, 'offline_dummy_id');
                  setState(() => _records.insert(0, newRecord));
               } else {
                  final idx = _records.indexWhere((r) => r.docId == existing.docId);
                  if (idx != -1) {
                     setState(() => _records[idx] = AlterationEntry.fromMap({...data, 'createdAt': Timestamp.now()}, existing.docId));
                  }
               }
            }

            // Manage Inventory Piece Preservation
            try {
              if (record.transactionType == 'Alteration Issue') {
                if (record.tagId.isNotEmpty) {
                  await ProductRepository().markPiecePreserved(
                    tagId: record.tagId,
                    transactionType: 'Alteration Issue',
                    transactionNo: record.voucherNo,
                  );
                }
              } else {
                final returnTag = record.tagId.isNotEmpty ? record.tagId : (linkedIssueToComplete?.tagId ?? '');
                if (returnTag.isNotEmpty) {
                  await ProductRepository().markPieceAvailable(tagId: returnTag);
                }
              }
            } catch (e) {
              debugPrint('Error updating alteration stock preservation: $e');
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${record.voucherNo} saved successfully!'), backgroundColor: Colors.green[800]),
              );
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
          }
        },
      ),
    );
  }

  Future<void> _cancelRecord(AlterationEntry record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancellation', style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        content: Text('Cancel ${record.voucherNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Entry'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

        if (isOnline) {
           await FirebaseFirestore.instance.collection('alteration_entries').doc(record.docId).update({'status': 'Cancelled', 'updatedAt': Timestamp.now()});
        } else {
           await LocalDbService().insertEntry(
              'alteration_entries', 
              {'status': 'Cancelled', 'updatedAt': Timestamp.now()},
              operation: 'UPDATE', 
              docId: record.docId
           );
           SyncService().syncNow();
        }

        if (record.transactionType == 'Alteration Issue' && record.tagId.isNotEmpty) {
          await ProductRepository().markPieceAvailable(tagId: record.tagId);
        }
        
        final idx = _records.indexWhere((r) => r.docId == record.docId);
        if (idx != -1) {
          setState(() => _records[idx] = AlterationEntry.fromMap({
            ..._records[idx].toMap(),
            'status': 'Cancelled',
            'updatedAt': Timestamp.now(),
          }, record.docId));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openBillDialog(AlterationEntry receipt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AlterationBillDialog(
        receipt: receipt,
        customers: _customers,
        salesmen: _salesmen,
        allReceipts: _records.where((r) => !r.isIssue && r.status == 'Yet to Bill').toList(),
        onSave: (bill) async {
          try {
            final connectivityResult = await Connectivity().checkConnectivity();
            final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
            
            final data = bill.toMap();

            if (isOnline) {
              data['createdAt'] = FieldValue.serverTimestamp();
              await FirebaseFirestore.instance.collection('alteration_bills').add(data);
              if (bill.linkedReceiptDocId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('alteration_entries')
                    .doc(bill.linkedReceiptDocId)
                    .update({'status': 'Completed'});
              }
            } else {
               if (!data['billNo'].toString().endsWith('-OFF')) {
                  data['billNo'] = '${data['billNo']}-OFF';
               }
               if (bill.linkedReceiptDocId.isNotEmpty) {
                  await LocalDbService().insertEntry(
                     'alteration_entries', 
                     {'status': 'Completed'},
                     operation: 'UPDATE', 
                     docId: bill.linkedReceiptDocId
                  );
               }
               await LocalDbService().insertEntry(
                  'alteration_bills', 
                  data, 
                  operation: 'ADD'
               );
               SyncService().syncNow();
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${bill.billNo} created!'), backgroundColor: Colors.green[800]),
              );
              _fetchRecords();
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────
          Row(
            children: [
              _buildTabButton('📋  Alteration Bookings', 0),
              const SizedBox(width: 8),
              _buildTabButton('🔨  Supplier Allocation', 1),
              const SizedBox(width: 8),
              _buildTabButton('🧾  Billing', 2),
            ],
          ),
          const SizedBox(height: 12),

          if (_activeTab == 0) ...[
            // ── Toolbar & Filters ──────────────────────────────────
            _buildToolbar(),
            const SizedBox(height: 12),
            // ── Data Table ─────────────────────────────────────────
            Expanded(child: _buildDataTable()),
          ] else if (_activeTab == 1) ...[
            Expanded(child: _AlterationSupplierAllocationSection(
              records: _records.where((r) => r.isIssue).toList(),
              suppliers: _supplierNames,
              onRefresh: _fetchRecords,
            )),
          ] else ...[
            Expanded(child: _AlterationBillingSection(
              receipts: _records.where((r) => !r.isIssue && r.status == 'Yet to Bill').toList(),
              customers: _customers,
              salesmen: _salesmen,
              bookNames: [],
              onBillSaved: _fetchRecords,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() { _activeTab = index; _selectedRecord = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _brown : Colors.white,
          border: Border.all(color: active ? _brown : _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : _brownLight)),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _buildFilterDropdown('Type', _typeFilter, ['All', 'Alteration Issue', 'Alteration Receipt'], (v) => setState(() { _typeFilter = v!; _selectedRecord = null; }))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFilterDropdown('Status', _statusFilter, ['All', 'Pending', 'Allocated', 'Completed', 'Cancelled'], (v) => setState(() { _statusFilter = v!; _selectedRecord = null; }))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _buildDateTile('Date From', _fromDate == null ? '-' : _dateFormat.format(_fromDate!), onTap: () async {
                    final p = await showDatePicker(context: context, initialDate: _fromDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (p != null) setState(() { _fromDate = p; _selectedRecord = null; });
                  })),
                  const SizedBox(width: 8),
                  const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDateTile('', _toDate == null ? '-' : _dateFormat.format(_toDate!), onTap: () async {
                    final p = await showDatePicker(context: context, initialDate: _toDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (p != null) setState(() { _toDate = p; _selectedRecord = null; });
                  })),
                  if (_fromDate != null || _toDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _fromDate = null; _toDate = null; _selectedRecord = null; })),
                  ],
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 26,
                  child: TextField(
                    onChanged: (v) => setState(() { _searchQuery = v; _selectedRecord = null; }),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search by Voucher No, Customer, Item, Tag ID...',
                      prefixIcon: const Icon(Icons.search, color: _brownLight, size: 14),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Action Buttons
          Row(
            children: [
              _buildActionBtn(Icons.add, 'Add', onTap: () { setState(() => _selectedRecord = null); _openEntryDialog(); }),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.edit, 'Modify', iconColor: Colors.blue,
                  onTap: _selectedRecord == null || _selectedRecord!.status == 'Cancelled' ? null : () => _openEntryDialog(_selectedRecord)),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.cancel, 'Cancel', iconColor: Colors.red,
                  onTap: _selectedRecord == null || _selectedRecord!.status == 'Cancelled' ? null : () => _cancelRecord(_selectedRecord!)),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.refresh, 'Refresh', iconColor: Colors.green, onTap: () {
                setState(() => _selectedRecord = null);
                _fetchRecords();
              }),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.visibility, 'View', iconColor: Colors.deepPurple,
                  onTap: _selectedRecord == null ? null : () => _openEntryDialog(_selectedRecord)),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.swap_horiz, 'Convert', iconColor: Colors.orange,
                  onTap: _selectedRecord == null || _selectedRecord!.status == 'Cancelled'
                      ? null
                      : _selectedRecord!.isIssue
                          // Issue → create a Receipt
                          ? () => _openEntryDialog(null, _selectedRecord)
                          // Receipt (Completed) → create a Bill in Billing tab
                          : _selectedRecord!.status != 'Completed'
                              ? null
                              : () {
                                  setState(() => _activeTab = 2);
                                  // give frame to rebuild, then show bill dialog
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _openBillDialog(_selectedRecord!);
                                  });
                                }),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.print, 'Print', iconColor: Colors.teal,
                  onTap: _selectedRecord == null ? null : () => PdfAlterationEntry.printPdf(_selectedRecord!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final filtered = _filteredRecords;
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            color: _headerBg,
            child: Row(children: [
              _buildHCell('Voucher No', flex: 3),
              _buildHCell('Date', flex: 2),
              _buildHCell('Type', flex: 3),
              _buildHCell('Customer', flex: 3),
              _buildHCell('Item Name', flex: 3),
              _buildHCell('Tag ID', flex: 2),
              _buildHCell('Gross Wt', flex: 2),
              _buildHCell('Net Wt', flex: 2),
              _buildHCell('Purity', flex: 2),
              _buildHCell('Status', flex: 2),
              _buildHCell('Supplier', flex: 3),
              _buildHCell('Delivery', flex: 2),
            ]),
          ),
          const Divider(height: 1, color: _border, thickness: 1),
          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brown))
                : filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.construction_outlined, size: 48, color: Colors.brown[200]),
                          const SizedBox(height: 12),
                          const Text('No Alteration entries found', style: TextStyle(fontSize: 15, color: _brownLight, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, color: _brown),
                            label: const Text('Add New Entry', style: TextStyle(color: _brown)),
                            onPressed: _openEntryDialog,
                          ),
                        ]),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final r = filtered[i];
                          final isSelected = _selectedRecord?.docId == r.docId;
                          return InkWell(
                            onTap: () => setState(() => _selectedRecord = r),
                            onDoubleTap: () => _openEntryDialog(r),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFDF6ED) : (i % 2 == 0 ? Colors.white : const Color(0xFFFAF8F5)),
                                border: const Border(bottom: BorderSide(color: _border)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              child: Row(children: [
                                _buildDCell(r.voucherNo, flex: 3, isBold: true, color: _brown),
                                _buildDCell(_dateFormat.format(r.voucherDate), flex: 2),
                                _buildDCell(r.transactionType.replaceAll('Alteration ', ''), flex: 3),
                                _buildDCell(r.customerName, flex: 3),
                                _buildDCell(r.itemName, flex: 3),
                                _buildDCell(r.tagId, flex: 2),
                                _buildDCell(r.grossWeight.toStringAsFixed(3), flex: 2),
                                _buildDCell(r.netWeight.toStringAsFixed(3), flex: 2),
                                _buildDCell(r.purity.toStringAsFixed(1), flex: 2),
                                Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildAltStatusChip(r.status))),
                                _buildDCell(r.supplierName, flex: 3),
                                _buildDCell(r.supplierDeliveryDate, flex: 2),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
          // Footer Summary
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(color: _headerBg, border: Border(top: BorderSide(color: _border))),
            child: Builder(builder: (ctx) {
              double totGross = 0, totNet = 0;
              for (final r in filtered) { totGross += r.grossWeight; totNet += r.netWeight; }
              return Row(children: [
                Text('Total: ${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
                const Spacer(),
                Text('Gross Wt: ${totGross.toStringAsFixed(3)} g  |  Net Wt: ${totNet.toStringAsFixed(3)} g',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
              ]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(children: [
      SizedBox(width: 55, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
      Expanded(
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true, dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              onChanged: onChanged,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDateTile(String label, String value, {required VoidCallback onTap}) {
    return Row(children: [
      if (label.isNotEmpty) SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(value, style: const TextStyle(fontSize: 12, color: Colors.black)),
              const Icon(Icons.calendar_today, color: Colors.grey, size: 14),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildActionBtn(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
    const btnBg = Color(0xFFF4F0E8);
    final enabled = onTap != null;
    return Material(
      color: enabled ? btnBg : btnBg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(border: Border.all(color: _border.withValues(alpha: enabled ? 1.0 : 0.5)), borderRadius: BorderRadius.circular(4)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: enabled ? (iconColor ?? _brown) : Colors.grey),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: enabled ? _brown : Colors.grey, height: 1.1, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _buildHCell(String label, {int flex = 2}) => Expanded(flex: flex, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 11), overflow: TextOverflow.ellipsis));
  Widget _buildDCell(String text, {int flex = 2, bool isBold = false, Color? color}) => Expanded(flex: flex, child: Text(text, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87), overflow: TextOverflow.ellipsis));
}

// ─────────────────────────────────────────────────────────────
// FORM DIALOG
// ─────────────────────────────────────────────────────────────
class _AlterationFormDialog extends StatefulWidget {
  final AlterationEntry? existing;
  final AlterationEntry? linkedIssue;
  final String Function(String type) generateVoucherNo;
  final List<AlterationEntry> availableIssues;
  final List<String> suppliers;
  final List<String> itemNames;
  final List<String> salesmen;
  final List<String> customers;
  final Function(AlterationEntry record, {AlterationEntry? linkedIssueToComplete}) onSave;

  const _AlterationFormDialog({
    this.existing,
    this.linkedIssue,
    required this.generateVoucherNo,
    required this.availableIssues,
    required this.suppliers,
    required this.itemNames,
    required this.salesmen,
    required this.customers,
    required this.onSave,
  });

  @override
  State<_AlterationFormDialog> createState() => _AlterationFormDialogState();
}

class _AlterationFormDialogState extends State<_AlterationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late String _txType;
  late String _voucherNo;
  late DateTime _voucherDate;
  DateTime? _expectedDelivery;

  String _repairType = 'Size Change';
  String _salesman = '';
  String _customerName = '';

  final _tagIdCtrl = TextEditingController();
  String _itemName = '';
  final _problemCtrl = TextEditingController();
  final _grossWtCtrl = TextEditingController(text: '0.000');
  final _stoneWtCtrl = TextEditingController(text: '0.000');
  final _netWtCtrl = TextEditingController(text: '0.000');
  final _purityCtrl = TextEditingController(text: '916.0');
  final _remarksCtrl = TextEditingController();

  String _imageUrl = '';
  bool _uploadingImage = false;
  String _status = 'Pending';

  // Linked issue (for Receipt)
  AlterationEntry? _linkedIssue;

  bool get _isReceipt => _txType == 'Alteration Receipt';
  bool get _isNew => widget.existing == null || widget.existing!.docId.isEmpty;

  List<String> _repairTypes = ['Size Change', 'Polishing', 'Chain Repair', 'Hook Repair', 'Clasp Repair', 'Stone Setting', 'Rhodium Plating', 'Engraving', 'Other'];
  final List<String> _statusOptions = ['Pending', 'Allocated', 'Yet to Bill', 'Completed', 'Cancelled'];

  // ── Receipt Billing ───────────────────────────────────────────
  final _repairedGrossWtCtrl = TextEditingController(text: '0.000');
  final _extraGoldAddedCtrl  = TextEditingController(text: '0.000');
  final _goldRateCtrl        = TextEditingController(text: '0.00');
  final _goldAmountCtrl      = TextEditingController(text: '0.00');
  final _labourRateCtrl      = TextEditingController(text: '0.00');
  final _labourAmountCtrl    = TextEditingController(text: '0.00');
  final _otherChargesCtrl    = TextEditingController(text: '0.00');
  final _netAmountCtrl       = TextEditingController(text: '0.00');
  final _paymentReferenceCtrl = TextEditingController();

  String _labourType = 'Fixed';
  String _taxScheme = 'CGST + SGST (Local)';
  String? _selectedPaymentBook;
  String _supplierName = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final l = widget.linkedIssue;
    _txType = e?.transactionType ?? (l != null ? 'Alteration Receipt' : 'Alteration Issue');
    _voucherDate = e?.voucherDate ?? DateTime.now();
    _expectedDelivery = e?.expectedDelivery;
    _voucherNo = e?.voucherNo.isNotEmpty == true ? e!.voucherNo : widget.generateVoucherNo(_txType);
    _repairType = e?.repairType.isNotEmpty == true ? e!.repairType : (l?.repairType ?? 'Size Change');
    _salesman = e?.salesman ?? (l?.salesman ?? '');
    _customerName = e?.customerName ?? (l?.customerName ?? '');
    _tagIdCtrl.text = e?.tagId ?? (l?.tagId ?? '');
    _itemName = e?.itemName ?? (l?.itemName ?? '');
    _problemCtrl.text = e?.problemDescription ?? (l?.problemDescription ?? '');
    _grossWtCtrl.text = e?.grossWeight.toStringAsFixed(3) ?? (l?.grossWeight.toStringAsFixed(3) ?? '0.000');
    _stoneWtCtrl.text = e?.stoneWeight.toStringAsFixed(3) ?? (l?.stoneWeight.toStringAsFixed(3) ?? '0.000');
    _netWtCtrl.text = e?.netWeight.toStringAsFixed(3) ?? (l?.netWeight.toStringAsFixed(3) ?? '0.000');
    _purityCtrl.text = e?.purity.toStringAsFixed(1) ?? (l?.purity.toStringAsFixed(1) ?? '916.0');
    _remarksCtrl.text = e?.remarks ?? (l?.remarks ?? '');
    _imageUrl = e?.imageUrl ?? (l?.imageUrl ?? '');
    _status = e?.status ?? (l != null ? 'Yet to Bill' : 'Pending');
    _linkedIssue = l;

    // Receipt billing init from existing or empty
    _repairedGrossWtCtrl.text = e?.repairedGrossWeight.toStringAsFixed(3) ?? '0.000';
    _extraGoldAddedCtrl.text  = e?.extraGoldAdded.toStringAsFixed(3) ?? '0.000';
    _goldRateCtrl.text        = e?.goldRate.toStringAsFixed(2) ?? '0.00';
    _goldAmountCtrl.text      = e?.goldAmount.toStringAsFixed(2) ?? '0.00';
    _labourType               = e?.labourType ?? 'Fixed';
    _labourRateCtrl.text      = e?.labourRate.toStringAsFixed(2) ?? '0.00';
    _labourAmountCtrl.text    = e?.labourAmount.toStringAsFixed(2) ?? '0.00';
    _otherChargesCtrl.text    = e?.otherCharges.toStringAsFixed(2) ?? '0.00';
    _netAmountCtrl.text       = e?.netAmount.toStringAsFixed(2) ?? '0.00';
    _paymentReferenceCtrl.text = e?.paymentReference ?? '';
    _taxScheme                = e?.taxScheme ?? 'CGST + SGST (Local)';
    _selectedPaymentBook      = e?.paymentBook.isNotEmpty == true ? e!.paymentBook : null;
    // Initialize supplier name from existing record or linked issue's supplier
    _supplierName = e?.supplierName ?? (widget.linkedIssue?.supplierName ?? '');

    _grossWtCtrl.addListener(_recalcNet);
    _stoneWtCtrl.addListener(_recalcNet);

    _loadRepairTypes();
  }

  Future<void> _loadRepairTypes() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('repair_types').orderBy('name').get();
      if (snap.docs.isEmpty) {
        // Pre-populate if empty
        final defaults = ['Size Change', 'Polishing', 'Chain Repair', 'Hook Repair', 'Clasp Repair', 'Stone Setting', 'Rhodium Plating', 'Engraving', 'Other'];
        for (final d in defaults) {
          await FirebaseFirestore.instance.collection('repair_types').add({
            'name': d,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        final reloadedSnap = await FirebaseFirestore.instance.collection('repair_types').orderBy('name').get();
        final list = reloadedSnap.docs.map((doc) => doc.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
        if (mounted) {
          setState(() {
            _repairTypes = list;
          });
        }
      } else {
        final list = snap.docs.map((doc) => doc.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
        if (mounted) {
          setState(() {
            _repairTypes = list;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading repair types: $e');
    }
  }

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

        double other = 0.0;
        final rawExtra = data['extraCharges'] ?? data['othersWeight'] ?? data['otherWeight'] ?? data['subRows'];
        if (rawExtra is List && rawExtra.isNotEmpty) {
          for (var charge in rawExtra) {
            if (charge is Map) {
              final w = ((charge['weight'] ?? charge['wt'] ?? 0.0) as num).toDouble();
              final style = (charge['styleName'] ?? charge['name'] ?? '').toString().toLowerCase().trim();
              if (style.contains('diamond')) {
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

        final purityVal = (data['purityVal'] ?? data['purity'] ?? 916.0).toDouble();

        setState(() {
          if (name.isNotEmpty) _itemName = name;
          _grossWtCtrl.text = gross.toStringAsFixed(3);
          _stoneWtCtrl.text = other.toStringAsFixed(3);
          _netWtCtrl.text = net.toStringAsFixed(3);
          _purityCtrl.text = purityVal.toString();
        });
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
      debugPrint('Error fetching tag details: $e');
    }
  }

  @override
  void dispose() {
    _tagIdCtrl.dispose();
    _problemCtrl.dispose();
    _grossWtCtrl.dispose();
    _stoneWtCtrl.dispose();
    _netWtCtrl.dispose();
    _purityCtrl.dispose();
    _remarksCtrl.dispose();
    _repairedGrossWtCtrl.dispose();
    _extraGoldAddedCtrl.dispose();
    _goldRateCtrl.dispose();
    _goldAmountCtrl.dispose();
    _labourRateCtrl.dispose();
    _labourAmountCtrl.dispose();
    _otherChargesCtrl.dispose();
    _netAmountCtrl.dispose();
    _paymentReferenceCtrl.dispose();
    super.dispose();
  }

  void _recalcNet() {
    final g = double.tryParse(_grossWtCtrl.text) ?? 0.0;
    final s = double.tryParse(_stoneWtCtrl.text) ?? 0.0;
    final net = (g - s).clamp(0.0, double.infinity);
    _netWtCtrl.removeListener(_recalcNet);
    _netWtCtrl.text = net.toStringAsFixed(3);
    _netWtCtrl.addListener(_recalcNet);
    if (mounted) setState(() {});
  }

  void _onTypeChanged(String? val) {
    if (val == null) return;
    setState(() {
      _txType = val;
      _voucherNo = widget.generateVoucherNo(_txType);
      _linkedIssue = null;
      if (_isReceipt) {
        _status = 'Yet to Bill';
      } else {
        _status = 'Pending';
      }
    });
  }

  void _onLinkedIssueChanged(AlterationEntry? issue) {
    setState(() {
      _linkedIssue = issue;
      if (issue != null) {
        _customerName = issue.customerName;
        _itemName = issue.itemName;
        _tagIdCtrl.text = issue.tagId;
        _repairType = issue.repairType.isNotEmpty ? issue.repairType : _repairType;
        _grossWtCtrl.removeListener(_recalcNet);
        _stoneWtCtrl.removeListener(_recalcNet);
        _grossWtCtrl.text = issue.grossWeight.toStringAsFixed(3);
        _stoneWtCtrl.text = issue.stoneWeight.toStringAsFixed(3);
        _netWtCtrl.text = issue.netWeight.toStringAsFixed(3);
        _purityCtrl.text = issue.purity.toStringAsFixed(1);
        _grossWtCtrl.addListener(_recalcNet);
        _stoneWtCtrl.addListener(_recalcNet);
        // Auto-fill supplier name from issue
        if (issue.supplierName.isNotEmpty) {
          _supplierName = issue.supplierName;
        }
      }
    });
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: source, imageQuality: 80);
    if (xf == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await CloudinaryService().uploadXFile(xf);
      if (url != null) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer.')));
      return;
    }
    final record = AlterationEntry(
      docId: widget.existing?.docId ?? '',
      voucherNo: _voucherNo,
      voucherDate: _voucherDate,
      transactionType: _txType,
      repairType: _repairType,
      salesman: _salesman,
      customerName: _customerName,
      expectedDelivery: _expectedDelivery,
      tagId: _tagIdCtrl.text.trim(),
      itemName: _itemName,
      problemDescription: _problemCtrl.text.trim(),
      grossWeight: double.tryParse(_grossWtCtrl.text) ?? 0.0,
      stoneWeight: double.tryParse(_stoneWtCtrl.text) ?? 0.0,
      netWeight: double.tryParse(_netWtCtrl.text) ?? 0.0,
      purity: double.tryParse(_purityCtrl.text) ?? 916.0,
      imageUrl: _imageUrl,
      remarks: _remarksCtrl.text.trim(),
      status: _status,
      supplierName: _supplierName,
      supplierDeliveryDate: widget.existing?.supplierDeliveryDate ?? '',
      supplierRemarks: widget.existing?.supplierRemarks ?? '',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      // Receipt billing fields
      repairedGrossWeight: double.tryParse(_repairedGrossWtCtrl.text) ?? 0.0,
      extraGoldAdded: double.tryParse(_extraGoldAddedCtrl.text) ?? 0.0,
      goldRate: double.tryParse(_goldRateCtrl.text) ?? 0.0,
      goldAmount: double.tryParse(_goldAmountCtrl.text) ?? 0.0,
      labourType: _labourType,
      labourRate: double.tryParse(_labourRateCtrl.text) ?? 0.0,
      labourAmount: double.tryParse(_labourAmountCtrl.text) ?? 0.0,
      otherCharges: double.tryParse(_otherChargesCtrl.text) ?? 0.0,
      netAmount: double.tryParse(_netAmountCtrl.text) ?? 0.0,
      paymentBook: _selectedPaymentBook == 'None' ? '' : (_selectedPaymentBook ?? ''),
      paymentReference: _paymentReferenceCtrl.text.trim(),
      taxScheme: _taxScheme,
      cgstAmount: 0.0,
      sgstAmount: 0.0,
      igstAmount: 0.0,
    );
    // If receipt is Completed, pass the linked issue so caller can mark it Completed too
    Navigator.pop(context);
    widget.onSave(record, linkedIssueToComplete: (_isReceipt && _status == 'Completed') ? _linkedIssue : null);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW * 0.95).clamp(1000.0, 1600.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: dialogW,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
        child: Column(
          children: [
            // Title Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.construction, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Text(_isNew ? 'New Alteration Entry' : 'Edit — $_voucherNo',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  _buildAltStatusChip(_status),
                  const SizedBox(width: 16),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white70, size: 20)),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left: Form Fields ──────────────────────────────────
                    Expanded(flex: 4, child: _buildLeftColumn()),
                    Container(width: 1, color: _border),
                    // ── Right: Summary / Photo ─────────────────────────────
                    Expanded(flex: 1, child: _buildRightColumn()),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(color: _headerBg, border: Border(top: BorderSide(color: _border))),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _border)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _brownLight)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Voucher Details ─────────────────────────────────────────
          _buildFormSectionHeader('Voucher Details'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _buildFieldLabel('Voucher No', _buildReadOnlyField(_voucherNo))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Voucher Date', _buildDatePicker(_dateFormat.format(_voucherDate), onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _voucherDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
              if (p != null) setState(() => _voucherDate = p);
            }))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Type', Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: _border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _txType,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  iconSize: 18,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  onChanged: widget.existing == null ? _onTypeChanged : null,
                  items: ['Alteration Issue', 'Alteration Receipt'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                ),
              ),
            ))),
          ]),

          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildFieldLabel('Expected Delivery', _buildDatePicker(_expectedDelivery == null ? 'Select Date' : _dateFormat.format(_expectedDelivery!), onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _expectedDelivery ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2035));
              if (p != null) setState(() => _expectedDelivery = p);
            }))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Status', _buildDropdownField(
              value: _statusOptions.contains(_status) ? _status : 'Pending',
              items: _statusOptions,
              hint: 'Select Status',
              onChanged: (v) => setState(() => _status = v ?? _status),
            ))),
            const SizedBox(width: 8),
            if (_isReceipt) ...[
              Expanded(child: _buildFieldLabel('Linked Issue (Receipt From)', Builder(builder: (ctx) {
                // Filter by currently selected customer (if any)
                final filtered = _customerName.isEmpty
                    ? widget.availableIssues
                    : widget.availableIssues
                        .where((r) => r.customerName.toLowerCase() == _customerName.toLowerCase())
                        .toList();
                // If current _linkedIssue no longer in filtered, reset
                final validLinked = filtered.contains(_linkedIssue) ? _linkedIssue : null;
                return Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: _border)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AlterationEntry>(
                      value: validLinked,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      iconSize: 18,
                      hint: Text(
                        _customerName.isEmpty ? 'Select customer first...' : (filtered.isEmpty ? 'No issues for this customer' : 'Select Issue to link...'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: filtered.isEmpty ? null : _onLinkedIssueChanged,
                      items: filtered.map((issue) => DropdownMenuItem(
                        value: issue,
                        child: Text(
                          '${issue.voucherNo} — ${issue.itemName}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                    ),
                  ),
                );
              }))),
            ] else ...[
              const Expanded(child: SizedBox()),
            ],
          ]),

          const SizedBox(height: 10),
          // ── Customer & Salesman ───────────────────────────────────
          _buildFormSectionHeader('Customer & Salesman Details'),
          const SizedBox(height: 6),
          _buildFieldLabel('Customer *', _buildAutocomplete(
            initialValue: _customerName,
            options: widget.customers,
            hint: 'Select or type customer name',
            onSelected: (v) => setState(() {
              // Clear linked issue if customer changes
              if (v != _customerName) {
                _linkedIssue = null;
              }
              _customerName = v;
            }),
          )),

          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildFieldLabel('Salesman', _buildDropdownField(
              value: _salesman.isEmpty ? null : _salesman,
              items: widget.salesmen,
              hint: 'Select Salesman',
              onChanged: (v) => setState(() => _salesman = v ?? ''),
            ))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Repair Type', _buildDropdownField(
              value: _repairTypes.contains(_repairType) ? _repairType : _repairTypes.first,
              items: _repairTypes,
              hint: 'Select Repair Type',
              onChanged: (v) => setState(() => _repairType = v ?? _repairType),
            ))),
          ]),

          const SizedBox(height: 10),
          // ── Ornament Details ──────────────────────────────────────
          _buildFormSectionHeader('Ornament Details'),
          const SizedBox(height: 6),
          _buildFieldLabel(
            'Tag ID',
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagIdCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Scan / Enter Tag',
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _brown, width: 1.5)),
                    ),
                    onFieldSubmitted: (v) => _fetchTagDetails(v),
                  ),
                ),
                const SizedBox(width: 4),
                // Search button
                Material(
                  color: _brown,
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () => _fetchTagDetails(_tagIdCtrl.text),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.search, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Scan button
                Material(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () async {
                      String? res = await openQrScanner(context);
                      if (res != null && res != '-1' && res.isNotEmpty) {
                        final cleanTag = parseScannedTagId(res);
                        _tagIdCtrl.text = cleanTag;
                        _fetchTagDetails(cleanTag);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          _buildFieldLabel('Item Name', _buildAutocomplete(
            initialValue: _itemName,
            options: widget.itemNames,
            hint: 'Select Item Name',
            readOnly: _isReceipt && _linkedIssue != null,
            onSelected: (v) => setState(() => _itemName = v),
          )),

          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildFieldLabel('Gross Weight (g)', _buildTextField(_grossWtCtrl, hint: '0.000', readOnly: _isReceipt && _linkedIssue != null))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Stone / Other Wt (g)', _buildTextField(_stoneWtCtrl, hint: '0.000', readOnly: _isReceipt && _linkedIssue != null))),
            const SizedBox(width: 8),
            Expanded(child: _buildFieldLabel('Net Weight (g)', _buildReadOnlyField('', controller: _netWtCtrl))),
          ]),

          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildFieldLabel('Purity', _buildTextField(_purityCtrl, hint: '916.0'))),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),

          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFieldLabel('Problem Description', _buildTextField(_problemCtrl, hint: 'e.g., Hook broken, size reduce by 1 inch', maxLines: 2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFieldLabel('Remarks / Narration', _buildTextField(_remarksCtrl, hint: 'Additional notes...', maxLines: 2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Ornament Photo', Icons.camera_alt_outlined),
          const SizedBox(height: 8),
          // Image container
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _uploadingImage
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircularProgressIndicator(color: _brown, strokeWidth: 2),
                    SizedBox(height: 8),
                    Text('Uploading...', style: TextStyle(color: _brownLight, fontSize: 12)),
                  ]))
                : _imageUrl.isNotEmpty
                    ? Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(_imageUrl, fit: BoxFit.cover, width: double.infinity, height: 120)),
                        Positioned(top: 4, right: 4, child: GestureDetector(
                          onTap: () => setState(() => _imageUrl = ''),
                          child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)),
                        )),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.diamond_outlined, size: 36, color: Colors.brown[200]),
                        const SizedBox(height: 6),
                        const Text('No photo attached', style: TextStyle(color: _brownLight, fontSize: 11)),
                      ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _border),
                  foregroundColor: _brown,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.camera_alt, size: 14),
                label: const Text('Camera', style: TextStyle(fontSize: 11)),
                onPressed: _uploadingImage ? null : () => _pickAndUploadImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _border),
                  foregroundColor: _brown,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 14),
                label: const Text('Gallery', style: TextStyle(fontSize: 11)),
                onPressed: _uploadingImage ? null : () => _pickAndUploadImage(ImageSource.gallery),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          // ── Entry Summary ─────────────────────────────────────────
          _buildSectionHeader('Entry Summary', Icons.summarize_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              _buildSummaryRow('Voucher No', _voucherNo, isBold: true),
              _buildSummaryRow('Type', _txType.replaceAll('Alteration ', '')),
              _buildSummaryRow('Date', _dateFormat.format(_voucherDate)),
              if (_expectedDelivery != null) _buildSummaryRow('Delivery', _dateFormat.format(_expectedDelivery!), color: Colors.orange[800]),
              const Divider(color: _border, height: 10),
              _buildSummaryRow('Customer', _customerName.isEmpty ? '-' : _customerName),
              _buildSummaryRow('Item', _itemName.isEmpty ? '-' : _itemName),
              _buildSummaryRow('Repair', _repairType),
              const Divider(color: _border, height: 10),
              _buildSummaryRow('Gross Wt', '${_grossWtCtrl.text} g'),
              _buildSummaryRow('Stone Wt', '${_stoneWtCtrl.text} g'),
              _buildSummaryRow('Net Wt', '${_netWtCtrl.text} g', isBold: true, color: _brown),
              _buildSummaryRow('Purity', _purityCtrl.text),
              const Divider(color: _border, height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Status', style: TextStyle(fontSize: 11, color: _brownLight)),
                _buildAltStatusChip(_status),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: _brownLight),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: _border)),
    ]);
  }

  Widget _buildFormSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _brownLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Widget field) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLight)),
      const SizedBox(height: 4),
      field,
    ]);
  }

  Widget _buildTextField(TextEditingController ctrl, {String hint = '', bool readOnly = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF5F0EA) : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _brown, width: 1.5)),
      ),
    );
  }

  Widget _buildReadOnlyField(String value, {TextEditingController? controller}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFF5F0EA), borderRadius: BorderRadius.circular(5), border: Border.all(color: _border)),
      child: controller != null
          ? ValueListenableBuilder(valueListenable: controller, builder: (context, value, child) => Text(controller.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)))
          : Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
    );
  }

  Widget _buildDropdownField({String? value, required List<String> items, String hint = '', ValueChanged<String?>? onChanged}) {
    final uniqueItems = items.toSet().toList();
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: _border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: uniqueItems.contains(value) ? value : null,
          isExpanded: true, hint: Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          dropdownColor: Colors.white, iconSize: 18,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          onChanged: onChanged,
          items: uniqueItems.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String value, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: _border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildAutocomplete({required String initialValue, required List<String> options, String hint = '', bool readOnly = false, required ValueChanged<String> onSelected}) {
    return Autocomplete<String>(
      key: ValueKey(initialValue),
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (tv) {
        if (tv.text.isEmpty) return options;
        return options.where((o) => o.toLowerCase().contains(tv.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, fn, onSubmit) => TextFormField(
        controller: ctrl,
        focusNode: fn,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          filled: true,
          fillColor: readOnly ? const Color(0xFFF5F0EA) : Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: _brown, width: 1.5)),
        ),
        onChanged: (v) => onSelected(v),
      ),
      optionsViewBuilder: (ctx, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
            child: ListView(shrinkWrap: true, children: opts.map((o) => InkWell(
              onTap: () => onSel(o),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(o, style: const TextStyle(fontSize: 12))),
            )).toList()),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _brownLight)),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.black87), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUPPLIER ALLOCATION SECTION
// ─────────────────────────────────────────────────────────────
class _AlterationSupplierAllocationSection extends StatefulWidget {
  final List<AlterationEntry> records;
  final List<String> suppliers;
  final VoidCallback onRefresh;

  const _AlterationSupplierAllocationSection({
    required this.records,
    required this.suppliers,
    required this.onRefresh,
  });

  @override
  State<_AlterationSupplierAllocationSection> createState() => _AlterationSupplierAllocationSectionState();
}

class _AlterationSupplierAllocationSectionState extends State<_AlterationSupplierAllocationSection> {
  final _dateFormat = DateFormat('dd/MM/yyyy');

  List<AlterationEntry> _allRecords = [];
  final Set<String> _checkedIds = {};

  // Filters
  bool _showPending = true;
  bool _showAllocated = false;
  bool _showAll = false;
  String _customerFilter = 'All';
  List<String> _customerOptions = ['All'];

  // Per-row inline edit data
  final Map<String, TextEditingController> _deliveryCtrl = {};
  final Map<String, TextEditingController> _remarksCtrl = {};
  final Map<String, String> _selectedSupplier = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _AlterationSupplierAllocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) _loadData();
  }

  void _loadData() {
    setState(() {
      _allRecords = List.from(widget.records);
      final custs = _allRecords.map((r) => r.customerName).where((n) => n.isNotEmpty).toSet().toList()..sort();
      _customerOptions = ['All', ...custs];

      for (final r in _allRecords) {
        _selectedSupplier[r.docId] = r.supplierName;
        _deliveryCtrl.putIfAbsent(r.docId, () => TextEditingController(text: r.supplierDeliveryDate));
        _remarksCtrl.putIfAbsent(r.docId, () => TextEditingController(text: r.supplierRemarks));
      }
    });
  }

  List<AlterationEntry> get _filteredRecords {
    return _allRecords.where((r) {
      final cust = _customerFilter == 'All' || r.customerName == _customerFilter;
      bool keepStatus = _showAll;
      if (!_showAll) {
        if (_showPending && r.status == 'Pending') keepStatus = true;
        if (_showAllocated && r.status == 'Allocated') keepStatus = true;
      }
      return cust && keepStatus;
    }).toList();
  }

  Future<void> _saveAllocations() async {
    if (_checkedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one entry.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      for (final docId in _checkedIds) {
        final supplier = _selectedSupplier[docId] ?? '';
        await FirebaseFirestore.instance.collection('alteration_entries').doc(docId).update({
          'supplierName': supplier,
          'supplierDeliveryDate': _deliveryCtrl[docId]?.text ?? '',
          'supplierRemarks': _remarksCtrl[docId]?.text ?? '',
          'status': supplier.isNotEmpty ? 'Allocated' : 'Pending',
          'updatedAt': Timestamp.now(),
        });
      }
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_checkedIds.length} entries allocated!'), backgroundColor: Colors.green[800]));
        setState(() => _checkedIds.clear());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _deliveryCtrl.values) {
      c.dispose();
    }
    for (final c in _remarksCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    return Column(
      children: [
        // Filters toolbar
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              _statusCheck('Pending', _showPending, (v) => setState(() { _showPending = v ?? false; _showAll = false; })),
              const SizedBox(width: 16),
              _statusCheck('Allocated', _showAllocated, (v) => setState(() { _showAllocated = v ?? false; _showAll = false; })),
              const SizedBox(width: 16),
              _statusCheck('Show All', _showAll, (v) => setState(() { _showAll = v ?? false; _showPending = false; _showAllocated = false; })),
              const SizedBox(width: 24),
              const Text('Customer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
              const SizedBox(width: 8),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _customerOptions.contains(_customerFilter) ? _customerFilter : 'All',
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    onChanged: (v) => setState(() => _customerFilter = v ?? 'All'),
                    items: _customerOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  ),
                ),
              ),
              const Spacer(),
              if (_checkedIds.isNotEmpty) ...[
                Text('${_checkedIds.length} selected', style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 14),
                label: Text(_isSaving ? 'Saving...' : 'Save Allocations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _isSaving ? null : _saveAllocations,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: const Icon(Icons.refresh, size: 14, color: _brownLight),
                label: const Text('Refresh', style: TextStyle(fontSize: 12, color: _brownLight)),
                onPressed: widget.onRefresh,
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  color: _headerBg,
                  child: Row(children: [
                    SizedBox(width: 36, child: Checkbox(
                      value: _checkedIds.length == filtered.length && filtered.isNotEmpty, tristate: true,
                      onChanged: (v) => setState(() {
                        if (_checkedIds.length == filtered.length) {
                          _checkedIds.clear();
                        } else {
                          _checkedIds.addAll(filtered.map((r) => r.docId));
                        }
                      }),
                      activeColor: _brown, side: const BorderSide(color: _brownLight),
                    )),
                    _ah('Voucher No', flex: 3),
                    _ah('Customer', flex: 3),
                    _ah('Item Name', flex: 3),
                    _ah('Problem', flex: 3),
                    _ah('Gross Wt', flex: 2),
                    _ah('Net Wt', flex: 2),
                    _ah('Status', flex: 2),
                    _ah('Allocate To (Supplier)', flex: 3),
                    _ah('Expected Del. Date', flex: 3),
                    _ah('Remarks', flex: 3),
                  ]),
                ),
                const Divider(height: 1, color: _border, thickness: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No entries match the current filters', style: TextStyle(color: _brownLight, fontSize: 13)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final r = filtered[i];
                            final checked = _checkedIds.contains(r.docId);
                            return Container(
                              decoration: BoxDecoration(
                                color: checked ? const Color(0xFFFDF3E3) : (i % 2 == 0 ? Colors.white : const Color(0xFFFAF8F5)),
                                border: const Border(bottom: BorderSide(color: _border)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Row(children: [
                                SizedBox(width: 36, child: Checkbox(
                                  value: checked,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _checkedIds.add(r.docId);
                                    } else {
                                      _checkedIds.remove(r.docId);
                                    }
                                  }),
                                  activeColor: _brown, side: const BorderSide(color: _brownLight),
                                )),
                                _ac(r.voucherNo, flex: 3, isBold: true),
                                _ac(r.customerName, flex: 3),
                                _ac(r.itemName, flex: 3),
                                _ac(r.problemDescription, flex: 3),
                                _ac(r.grossWeight.toStringAsFixed(3), flex: 2),
                                _ac(r.netWeight.toStringAsFixed(3), flex: 2),
                                Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildAltStatusChip(r.status))),
                                // Supplier dropdown
                                Expanded(flex: 3, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: widget.suppliers.contains(_selectedSupplier[r.docId] ?? '') ? _selectedSupplier[r.docId] : null,
                                        isExpanded: true, dropdownColor: Colors.white, iconSize: 16,
                                        hint: const Text('Select Supplier', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        onChanged: (v) => setState(() => _selectedSupplier[r.docId] = v ?? ''),
                                        items: widget.suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
                                      ),
                                    ),
                                  ),
                                )),
                                // Delivery date
                                Expanded(flex: 3, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final p = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2035));
                                      if (p != null && mounted) {
                                        setState(() => _deliveryCtrl[r.docId]!.text = _dateFormat.format(p));
                                      }
                                    },
                                    child: Container(
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Expanded(child: Text(_deliveryCtrl[r.docId]?.text ?? '', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                      ]),
                                    ),
                                  ),
                                )),
                                // Supplier Remarks
                                Expanded(flex: 3, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: SizedBox(
                                    height: 30,
                                    child: TextField(
                                      controller: _remarksCtrl[r.docId],
                                      style: const TextStyle(fontSize: 11),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                                        hintText: 'Remarks...',
                                        hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                )),
                              ]),
                            );
                          },
                        ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: const BoxDecoration(color: _headerBg, border: Border(top: BorderSide(color: _border))),
                  child: Row(children: [
                    Text('Total: ${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
                    const SizedBox(width: 16),
                    Text('Allocated: ${filtered.where((r) => r.status == 'Allocated').length}', style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Text('Pending: ${filtered.where((r) => r.status == 'Pending').length}', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCheck(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(children: [
      Checkbox(value: value, onChanged: onChanged, activeColor: _brown, side: const BorderSide(color: _brownLight)),
      Text(label, style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _ah(String label, {int flex = 2}) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 11), overflow: TextOverflow.ellipsis)));
  Widget _ac(String text, {int flex = 2, bool isBold = false}) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? _brown : Colors.black87), overflow: TextOverflow.ellipsis)));
}

// =============================================================================
// ALTERATION BILL MODEL
// =============================================================================
class AlterationBill {
  String docId;
  String billNo;
  DateTime billDate;
  String customerName;
  String salesman;
  String originalJobRef;
  String linkedReceiptDocId;
  String billType;
  // Line item (Section B)
  String itemName;
  String groupName;
  int pcs;
  double grossWt;
  double netWt;
  double fineWt;
  double extraGoldAdded;
  double diamondAmt;
  double stoneAmt;
  String labourType;
  double labourRate;
  double labourAmount;
  double wastagePer;
  double wastageWt;
  double metalRate;
  double metalAmount;
  double otherCharges;
  String narration;
  // Section C
  String paymentMode;
  String paymentReference;
  // Tax
  String taxScheme;
  double cgstAmount;
  double sgstAmount;
  double igstAmount;
  double netAmount;
  DateTime createdAt;
  DateTime updatedAt;

  AlterationBill({
    this.docId = '',
    required this.billNo,
    required this.billDate,
    this.customerName = '',
    this.salesman = '',
    this.originalJobRef = '',
    this.linkedReceiptDocId = '',
    this.billType = 'Alteration Bill',
    this.itemName = '',
    this.groupName = '',
    this.pcs = 1,
    this.grossWt = 0,
    this.netWt = 0,
    this.fineWt = 0,
    this.extraGoldAdded = 0,
    this.diamondAmt = 0,
    this.stoneAmt = 0,
    this.labourType = 'Fixed',
    this.labourRate = 0,
    this.labourAmount = 0,
    this.wastagePer = 0,
    this.wastageWt = 0,
    this.metalRate = 0,
    this.metalAmount = 0,
    this.otherCharges = 0,
    this.narration = '',
    this.paymentMode = '',
    this.paymentReference = '',
    this.taxScheme = 'CGST + SGST (Local)',
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.netAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'billNo': billNo,
    'billDate': Timestamp.fromDate(billDate),
    'customerName': customerName,
    'salesman': salesman,
    'originalJobRef': originalJobRef,
    'linkedReceiptDocId': linkedReceiptDocId,
    'billType': billType,
    'itemName': itemName,
    'groupName': groupName,
    'pcs': pcs,
    'grossWt': grossWt,
    'netWt': netWt,
    'fineWt': fineWt,
    'extraGoldAdded': extraGoldAdded,
    'diamondAmt': diamondAmt,
    'stoneAmt': stoneAmt,
    'labourType': labourType,
    'labourRate': labourRate,
    'labourAmount': labourAmount,
    'wastagePer': wastagePer,
    'wastageWt': wastageWt,
    'metalRate': metalRate,
    'metalAmount': metalAmount,
    'otherCharges': otherCharges,
    'narration': narration,
    'paymentMode': paymentMode,
    'paymentReference': paymentReference,
    'taxScheme': taxScheme,
    'cgstAmount': cgstAmount,
    'sgstAmount': sgstAmount,
    'igstAmount': igstAmount,
    'netAmount': netAmount,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory AlterationBill.fromMap(Map<String, dynamic> m, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return AlterationBill(
      docId: id,
      billNo: m['billNo'] ?? '',
      billDate: ts(m['billDate']),
      customerName: m['customerName'] ?? '',
      salesman: m['salesman'] ?? '',
      originalJobRef: m['originalJobRef'] ?? '',
      linkedReceiptDocId: m['linkedReceiptDocId'] ?? '',
      billType: m['billType'] ?? 'Alteration Bill',
      itemName: m['itemName'] ?? '',
      groupName: m['groupName'] ?? '',
      pcs: (m['pcs'] as num?)?.toInt() ?? 1,
      grossWt: _numVal(m['grossWt']),
      netWt: _numVal(m['netWt']),
      fineWt: _numVal(m['fineWt']),
      extraGoldAdded: _numVal(m['extraGoldAdded']),
      diamondAmt: _numVal(m['diamondAmt']),
      stoneAmt: _numVal(m['stoneAmt']),
      labourType: m['labourType'] ?? 'Fixed',
      labourRate: _numVal(m['labourRate']),
      labourAmount: _numVal(m['labourAmount']),
      wastagePer: _numVal(m['wastagePer']),
      wastageWt: _numVal(m['wastageWt']),
      metalRate: _numVal(m['metalRate']),
      metalAmount: _numVal(m['metalAmount']),
      otherCharges: _numVal(m['otherCharges']),
      narration: m['narration'] ?? '',
      paymentMode: m['paymentMode'] ?? '',
      paymentReference: m['paymentReference'] ?? '',
      taxScheme: m['taxScheme'] ?? 'CGST + SGST (Local)',
      cgstAmount: _numVal(m['cgstAmount']),
      sgstAmount: _numVal(m['sgstAmount']),
      igstAmount: _numVal(m['igstAmount']),
      netAmount: _numVal(m['netAmount']),
      createdAt: ts(m['createdAt']),
      updatedAt: ts(m['updatedAt']),
    );
  }
}

// =============================================================================
// ALTERATION BILLING SECTION (Tab 2)
// =============================================================================
class _AlterationBillingSection extends StatefulWidget {
  final List<AlterationEntry> receipts;
  final List<String> customers;
  final List<String> salesmen;
  final List<String> bookNames;
  final VoidCallback onBillSaved;

  const _AlterationBillingSection({
    required this.receipts,
    required this.customers,
    required this.salesmen,
    required this.bookNames,
    required this.onBillSaved,
  });

  @override
  State<_AlterationBillingSection> createState() => _AlterationBillingSectionState();
}

class _AlterationBillingSectionState extends State<_AlterationBillingSection> {
  final DateFormat _df = DateFormat('dd/MM/yyyy');
  List<AlterationBill> _bills = [];
  bool _loading = false;
  AlterationBill? _selectedBill;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('alteration_bills')
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() => _bills = snap.docs
            .map((d) => AlterationBill.fromMap(d.data(), d.id))
            .toList());
      }
    } catch (e) {
      debugPrint('Bill load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateBillDialog([AlterationEntry? receipt]) {
    final target = receipt ?? (widget.receipts.isEmpty ? null : widget.receipts.first);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed receipts available to bill.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AlterationBillDialog(
        receipt: target,
        customers: widget.customers,
        salesmen: widget.salesmen,
        allReceipts: widget.receipts,
        onSave: (bill) async {
          try {
            final data = bill.toMap();
            data['createdAt'] = FieldValue.serverTimestamp();
            await FirebaseFirestore.instance.collection('alteration_bills').add(data);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${bill.billNo} saved!'), backgroundColor: Colors.green[800]),
              );
              _loadBills();
              widget.onBillSaved();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  void _openViewBillDialog(AlterationBill bill) {
    final targetReceipt = widget.receipts.firstWhere(
      (r) => r.docId == bill.linkedReceiptDocId,
      orElse: () => AlterationEntry(
        voucherDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        customerName: bill.customerName,
        itemName: bill.itemName,
        grossWeight: bill.grossWt,
        netWeight: bill.netWt,
        purity: 916.0,
      ),
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AlterationBillDialog(
        receipt: targetReceipt,
        existingBill: bill,
        readOnly: true,
        customers: widget.customers,
        salesmen: widget.salesmen,
        allReceipts: widget.receipts,
        onSave: (_) {},
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
    const btnBg = Color(0xFFF4F0E8);
    final enabled = onTap != null;
    return Material(
      color: enabled ? btnBg : btnBg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              border: Border.all(color: _border.withValues(alpha: enabled ? 1.0 : 0.5)),
              borderRadius: BorderRadius.circular(4)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: enabled ? (iconColor ?? _brown) : Colors.grey),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: enabled ? _brown : Colors.grey,
                    height: 1.1,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Toolbar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: _brown, size: 18),
          const SizedBox(width: 8),
          const Text('Alteration Bills',
              style: TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 13)),
          const Spacer(),
          Row(
            children: [
              _buildActionBtn(Icons.add, 'Add', onTap: () {
                setState(() => _selectedBill = null);
                _openCreateBillDialog();
              }),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.visibility, 'View',
                  iconColor: Colors.deepPurple,
                  onTap: _selectedBill == null ? null : () => _openViewBillDialog(_selectedBill!)),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.print, 'Print',
                  iconColor: Colors.teal,
                  onTap: _selectedBill == null
                      ? null
                      : () => PdfAlterationEntry.printBillPdf(_selectedBill!)),
              const SizedBox(width: 8),
              _buildActionBtn(Icons.refresh, 'Refresh',
                  iconColor: Colors.green, onTap: _loadBills),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // Table
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _brown))
              : _bills.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.brown[200]),
                        const SizedBox(height: 8),
                        const Text(
                          'No bills yet.\nClick "New Bill" or use Convert from Bookings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _brownLight, fontSize: 13),
                        ),
                      ]),
                    )
                  : Column(children: [
                      // Header
                      Container(
                        color: _headerBg,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(children: [
                          _bh('Bill No', 3),
                          _bh('Date', 2),
                          _bh('Customer', 3),
                          _bh('Job Ref', 3),
                          _bh('Item', 3),
                          _bh('Labour', 2),
                          _bh('GST', 2),
                          _bh('Net Amt', 2),
                          _bh('Payment', 2),
                        ]),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _bills.length,
                          itemBuilder: (ctx, i) {
                            final b = _bills[i];
                            final sel = _selectedBill?.docId == b.docId;
                            final gst = b.cgstAmount + b.sgstAmount + b.igstAmount;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedBill = sel ? null : b),
                              child: Container(
                                color: sel
                                    ? _brown.withValues(alpha: 0.08)
                                    : (i.isOdd ? const Color(0xFFFDF6ED) : Colors.white),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Row(children: [
                                  _bc(b.billNo, 3, bold: true),
                                  _bc(_df.format(b.billDate), 2),
                                  _bc(b.customerName, 3),
                                  _bc(b.originalJobRef, 3),
                                  _bc(b.itemName, 3),
                                  _bc('₹${b.labourAmount.toStringAsFixed(2)}', 2),
                                  _bc('₹${gst.toStringAsFixed(2)}', 2),
                                  _bc('₹${b.netAmount.toStringAsFixed(2)}', 2,
                                      bold: true, color: Colors.green[800]),
                                  _bc(b.paymentMode.isEmpty ? '-' : b.paymentMode, 2),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                      // Footer
                      Container(
                        color: _headerBg,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Text('Total: ${_bills.length}',
                              style: const TextStyle(fontSize: 11, color: _brownLight)),
                          const Spacer(),
                          Text(
                            'Total Net: ₹${_bills.fold(0.0, (s, b) => s + b.netAmount).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                          ),
                        ]),
                      ),
                    ]),
        ),
      ),
    ]);
  }



  Widget _bh(String t, int flex) => Expanded(
      flex: flex,
      child: Text(t,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)));
  Widget _bc(String t, int flex, {bool bold = false, Color? color}) => Expanded(
      flex: flex,
      child: Text(t,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87)));
}

// =============================================================================
// ALTERATION BILL DIALOG
// =============================================================================
class _AlterationBillDialog extends StatefulWidget {
  final AlterationEntry receipt;
  final AlterationBill? existingBill;
  final bool readOnly;
  final List<String> customers;
  final List<String> salesmen;
  final List<AlterationEntry> allReceipts;
  final Function(AlterationBill) onSave;

  const _AlterationBillDialog({
    required this.receipt,
    this.existingBill,
    this.readOnly = false,
    required this.customers,
    required this.salesmen,
    required this.allReceipts,
    required this.onSave,
  });

  @override
  State<_AlterationBillDialog> createState() => _AlterationBillDialogState();
}

class _AlterationBillDialogState extends State<_AlterationBillDialog> {
  final _formKey = GlobalKey<FormState>();
  final _df = DateFormat('dd/MM/yyyy');

  late String _customerName;
  late String _salesman;
  late AlterationEntry _linkedReceipt;
  late String _billNo;
  late DateTime _billDate;
  String _labourType = 'Fixed';
  String _taxScheme = 'CGST + SGST (Local)';
  String _paymentMode = 'Cash';
  List<String> _bookNames = ['None', 'Cash', 'Card', 'UPI'];

  // Section B
  late TextEditingController _itemCtrl, _groupCtrl, _pcsCtrl;
  late TextEditingController _grossCtrl, _netCtrl, _fineCtrl, _extraGoldCtrl;
  late TextEditingController _diamondCtrl, _stoneCtrl;
  late TextEditingController _labourRateCtrl, _labourAmtCtrl;
  late TextEditingController _wastagePerCtrl, _wastageWtCtrl;
  late TextEditingController _metalRateCtrl, _metalAmtCtrl;
  late TextEditingController _otherCtrl, _narrationCtrl;
  // Section C
  late TextEditingController _paymentRefCtrl;

  double get _labourAmt  => double.tryParse(_labourAmtCtrl.text) ?? 0.0;
  double get _metalAmt   => double.tryParse(_metalAmtCtrl.text) ?? 0.0;
  double get _wastageAmt => (double.tryParse(_wastageWtCtrl.text) ?? 0.0) *
      (double.tryParse(_metalRateCtrl.text) ?? 0.0);
  double get _otherChg   => double.tryParse(_otherCtrl.text) ?? 0.0;
  double get _diamondAmt => double.tryParse(_diamondCtrl.text) ?? 0.0;
  double get _stoneAmt   => double.tryParse(_stoneCtrl.text) ?? 0.0;
  double get _subTotal   =>
      _labourAmt + _metalAmt + _wastageAmt + _otherChg + _diamondAmt + _stoneAmt;
  double get _cgst => _taxScheme == 'CGST + SGST (Local)' ? _subTotal * 0.09 : 0.0;
  double get _sgst => _taxScheme == 'CGST + SGST (Local)' ? _subTotal * 0.09 : 0.0;
  double get _igst => _taxScheme == 'IGST (Interstate)' ? _subTotal * 0.18 : 0.0;
  double get _netAmt => _subTotal + _cgst + _sgst + _igst;

  @override
  void initState() {
    super.initState();
    final eb = widget.existingBill;
    if (eb != null) {
      _linkedReceipt = widget.receipt;
      _customerName  = eb.customerName;
      _salesman      = eb.salesman;
      _billDate      = eb.billDate;
      _billNo        = eb.billNo;
      _taxScheme     = eb.taxScheme;
      _labourType    = eb.labourType;
      _paymentMode   = eb.paymentMode.isEmpty ? 'None' : eb.paymentMode;

      _itemCtrl      = TextEditingController(text: eb.itemName);
      _groupCtrl     = TextEditingController(text: eb.groupName);
      _pcsCtrl       = TextEditingController(text: eb.pcs.toString());
      _grossCtrl     = TextEditingController(text: eb.grossWt.toStringAsFixed(3));
      _netCtrl       = TextEditingController(text: eb.netWt.toStringAsFixed(3));
      _fineCtrl      = TextEditingController(text: eb.fineWt.toStringAsFixed(3));
      _extraGoldCtrl = TextEditingController(text: eb.extraGoldAdded.toStringAsFixed(3));
      _diamondCtrl   = TextEditingController(text: eb.diamondAmt.toStringAsFixed(2));
      _stoneCtrl     = TextEditingController(text: eb.stoneAmt.toStringAsFixed(2));
      _labourRateCtrl = TextEditingController(text: eb.labourRate.toStringAsFixed(2));
      _labourAmtCtrl  = TextEditingController(text: eb.labourAmount.toStringAsFixed(2));
      _wastagePerCtrl = TextEditingController(text: eb.wastagePer.toStringAsFixed(2));
      _wastageWtCtrl  = TextEditingController(text: eb.wastageWt.toStringAsFixed(3));
      _metalRateCtrl  = TextEditingController(text: eb.metalRate.toStringAsFixed(2));
      _metalAmtCtrl   = TextEditingController(text: eb.metalAmount.toStringAsFixed(2));
      _otherCtrl      = TextEditingController(text: eb.otherCharges.toStringAsFixed(2));
      _narrationCtrl  = TextEditingController(text: eb.narration);
      _paymentRefCtrl = TextEditingController(text: eb.paymentReference);
    } else {
      _linkedReceipt = widget.receipt;
      _customerName  = widget.receipt.customerName;
      _salesman      = widget.receipt.salesman;
      _billDate      = DateTime.now();
      _billNo        = 'ALT-BILL-1';
      _taxScheme     = widget.receipt.taxScheme;
      _labourType    = widget.receipt.labourType.isNotEmpty ? widget.receipt.labourType : 'Fixed';

      final r = widget.receipt;
      _itemCtrl      = TextEditingController(text: r.itemName);
      _groupCtrl     = TextEditingController();
      _pcsCtrl       = TextEditingController(text: '1');
      _grossCtrl     = TextEditingController(
          text: (r.repairedGrossWeight > 0 ? r.repairedGrossWeight : r.grossWeight).toStringAsFixed(3));
      _netCtrl       = TextEditingController(text: r.netWeight.toStringAsFixed(3));
      _fineCtrl      = TextEditingController(
          text: (r.netWeight * (r.purity / 1000)).toStringAsFixed(3));
      _extraGoldCtrl = TextEditingController(text: r.extraGoldAdded.toStringAsFixed(3));
      _diamondCtrl   = TextEditingController(text: '0.00');
      _stoneCtrl     = TextEditingController(text: '0.00');
      _labourRateCtrl = TextEditingController(text: r.labourRate.toStringAsFixed(2));
      _labourAmtCtrl  = TextEditingController(text: r.labourAmount.toStringAsFixed(2));
      _wastagePerCtrl = TextEditingController(text: '0.00');
      _wastageWtCtrl  = TextEditingController(text: '0.000');
      _metalRateCtrl  = TextEditingController(text: r.goldRate.toStringAsFixed(2));
      _metalAmtCtrl   = TextEditingController(text: r.goldAmount.toStringAsFixed(2));
      _otherCtrl      = TextEditingController(text: r.otherCharges.toStringAsFixed(2));
      _narrationCtrl  = TextEditingController(text: r.problemDescription);
      _paymentRefCtrl = TextEditingController();
    }

    for (final c in [_labourRateCtrl, _grossCtrl, _netCtrl, _fineCtrl,
                     _metalRateCtrl, _extraGoldCtrl, _wastagePerCtrl,
                     _otherCtrl, _diamondCtrl, _stoneCtrl]) {
      c.addListener(_recalculate);
    }

    if (eb == null) {
      _fetchBillNo();
    }
    _loadBookNames();
  }

  Future<void> _fetchBillNo() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('alteration_bills').get();
      if (mounted) {
        setState(() => _billNo =
            'ALT-BILL-${snap.docs.length + 1}');
      }
    } catch (_) {}
  }

  Future<void> _loadBookNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final names = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() => _bookNames = ['None', 'Cash', 'Card', 'UPI', ...names]);
      }
    } catch (_) {}
  }

  void _recalculate() {
    final grossWt    = double.tryParse(_grossCtrl.text) ?? 0.0;
    final netWt      = double.tryParse(_netCtrl.text) ?? 0.0;
    final fineWt     = double.tryParse(_fineCtrl.text) ?? 0.0;
    final wastagePer = double.tryParse(_wastagePerCtrl.text) ?? 0.0;
    final extraGold  = double.tryParse(_extraGoldCtrl.text) ?? 0.0;
    final metalRate  = double.tryParse(_metalRateCtrl.text) ?? 0.0;
    final labourRate = double.tryParse(_labourRateCtrl.text) ?? 0.0;

    // Wastage wt
    _wastageWtCtrl.removeListener(_recalculate);
    _wastageWtCtrl.text = (grossWt * wastagePer / 100.0).toStringAsFixed(3);
    _wastageWtCtrl.addListener(_recalculate);

    // Metal amount
    _metalAmtCtrl.removeListener(_recalculate);
    _metalAmtCtrl.text = (extraGold * metalRate).toStringAsFixed(2);
    _metalAmtCtrl.addListener(_recalculate);

    // Labour amount
    double labourAmt;
    switch (_labourType) {
      case 'Per Gram Gross Weight':       labourAmt = labourRate * grossWt; break;
      case 'Per Gram Net Weight':         labourAmt = labourRate * netWt;   break;
      case 'Per Gram Fine Weight':        labourAmt = labourRate * fineWt;  break;
      case 'Percentage on Gross Weight':  labourAmt = grossWt * labourRate / 100.0; break;
      case 'Percentage on Net Weight':    labourAmt = netWt   * labourRate / 100.0; break;
      case 'Percentage on Fine Weight':   labourAmt = fineWt  * labourRate / 100.0; break;
      default: labourAmt = labourRate; // Fixed / Per Piece
    }
    _labourAmtCtrl.removeListener(_recalculate);
    _labourAmtCtrl.text = labourAmt.toStringAsFixed(2);
    _labourAmtCtrl.addListener(_recalculate);

    if (mounted) setState(() {});
  }

  void _onLinkedReceiptChanged(AlterationEntry? r) {
    if (r == null) return;
    setState(() {
      _linkedReceipt = r;
      _customerName  = r.customerName;
      _labourType    = r.labourType.isNotEmpty ? r.labourType : 'Fixed';
      _taxScheme     = r.taxScheme;
      _itemCtrl.text = r.itemName;
      _grossCtrl.text =
          (r.repairedGrossWeight > 0 ? r.repairedGrossWeight : r.grossWeight).toStringAsFixed(3);
      _netCtrl.text       = r.netWeight.toStringAsFixed(3);
      _fineCtrl.text      = (r.netWeight * (r.purity / 1000)).toStringAsFixed(3);
      _extraGoldCtrl.text = r.extraGoldAdded.toStringAsFixed(3);
      _labourRateCtrl.text = r.labourRate.toStringAsFixed(2);
      _metalRateCtrl.text  = r.goldRate.toStringAsFixed(2);
      _otherCtrl.text      = r.otherCharges.toStringAsFixed(2);
      _narrationCtrl.text  = r.problemDescription;
    });
    _recalculate();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final bill = AlterationBill(
      billNo: _billNo,
      billDate: _billDate,
      customerName: _customerName,
      salesman: _salesman,
      originalJobRef: _linkedReceipt.voucherNo,
      linkedReceiptDocId: _linkedReceipt.docId,
      itemName: _itemCtrl.text.trim(),
      groupName: _groupCtrl.text.trim(),
      pcs: int.tryParse(_pcsCtrl.text) ?? 1,
      grossWt: double.tryParse(_grossCtrl.text) ?? 0,
      netWt: double.tryParse(_netCtrl.text) ?? 0,
      fineWt: double.tryParse(_fineCtrl.text) ?? 0,
      extraGoldAdded: double.tryParse(_extraGoldCtrl.text) ?? 0,
      diamondAmt: double.tryParse(_diamondCtrl.text) ?? 0,
      stoneAmt: double.tryParse(_stoneCtrl.text) ?? 0,
      labourType: _labourType,
      labourRate: double.tryParse(_labourRateCtrl.text) ?? 0,
      labourAmount: _labourAmt,
      wastagePer: double.tryParse(_wastagePerCtrl.text) ?? 0,
      wastageWt: double.tryParse(_wastageWtCtrl.text) ?? 0,
      metalRate: double.tryParse(_metalRateCtrl.text) ?? 0,
      metalAmount: _metalAmt,
      otherCharges: _otherChg,
      narration: _narrationCtrl.text.trim(),
      paymentMode: _paymentMode == 'None' ? '' : _paymentMode,
      paymentReference: _paymentRefCtrl.text.trim(),
      taxScheme: _taxScheme,
      cgstAmount: _cgst,
      sgstAmount: _sgst,
      igstAmount: _igst,
      netAmount: _netAmt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    Navigator.pop(context);
    widget.onSave(bill);
  }

  @override
  void dispose() {
    for (final c in [_itemCtrl, _groupCtrl, _pcsCtrl, _grossCtrl, _netCtrl,
                     _fineCtrl, _extraGoldCtrl, _diamondCtrl, _stoneCtrl,
                     _labourRateCtrl, _labourAmtCtrl, _wastagePerCtrl,
                     _wastageWtCtrl, _metalRateCtrl, _metalAmtCtrl,
                     _otherCtrl, _narrationCtrl, _paymentRefCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW * 0.92).clamp(900.0, 1500.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: dialogW,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Text('New Alteration Bill — $_billNo',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70, size: 20)),
            ]),
          ),
          // Body
          Expanded(
            child: Form(
              key: _formKey,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: _buildLeft()),
                Container(width: 1, color: _border),
                SizedBox(width: 270, child: _buildRight()),
              ]),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white, border: Border(top: BorderSide(color: _border))),
            child: Row(children: [
              const Spacer(),
              if (widget.readOnly)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else ...[
                OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _save,
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildLeft() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── SECTION A ──────────────────────────────────────────────
        _secHead('A', 'Bill Header'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _lbl('Bill No', _roField(_billNo))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Bill Date', _datePicker())),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Bill Type', _roField('Alteration Bill'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 2, child: _lbl('Customer *', _dd(
            value: widget.customers.contains(_customerName) ? _customerName : null,
            items: widget.customers,
            hint: 'Select Customer',
            onChange: (v) => setState(() => _customerName = v ?? ''),
          ))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Salesman', _dd(
            value: widget.salesmen.contains(_salesman) ? _salesman : null,
            items: widget.salesmen,
            hint: 'Select Salesman',
            onChange: (v) => setState(() => _salesman = v ?? ''),
          ))),
        ]),
        const SizedBox(height: 8),
        _lbl('Original Job Ref (Receipt)', Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AlterationEntry>(
              value: _linkedReceipt,
              isExpanded: true,
              dropdownColor: Colors.white,
              iconSize: 18,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              onChanged: widget.readOnly ? null : _onLinkedReceiptChanged,
              items: widget.allReceipts
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          '${r.voucherNo} — ${r.customerName} (${r.itemName})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          ),
        )),

        // ── SECTION B ──────────────────────────────────────────────
        const SizedBox(height: 14),
        _secHead('B', 'Item & Charge Details'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 3, child: _lbl('Item Name', _tf(_itemCtrl, 'e.g. Gold Chain 22K'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Group', _tf(_groupCtrl, 'Gold'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Pcs', _tf(_pcsCtrl, '1'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _lbl('Gross Wt (g)', _tf(_grossCtrl, '0.000'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Net Wt (g)', _tf(_netCtrl, '0.000'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Fine Wt (g)', _tf(_fineCtrl, '0.000'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Extra Gold (g)', _tf(_extraGoldCtrl, '0.000'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _lbl('Diamond Amt (₹)', _tf(_diamondCtrl, '0.00'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Stone Amt (₹)', _tf(_stoneCtrl, '0.00'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Wastage %', _tf(_wastagePerCtrl, '0.00'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Wastage Wt [Auto]', _roWidget(_wastageWtCtrl))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 2, child: _lbl('Labour Type', _dd(
            value: _labourType,
            items: const [
              'Fixed', 'Per Piece',
              'Per Gram Gross Weight', 'Per Gram Net Weight', 'Per Gram Fine Weight',
              'Percentage on Gross Weight', 'Percentage on Net Weight', 'Percentage on Fine Weight',
            ],
            hint: 'Labour Type',
            onChange: (v) => setState(() { _labourType = v ?? _labourType; _recalculate(); }),
          ))),
          const SizedBox(width: 8),
          Expanded(child: _lbl(
            _labourType.startsWith('Percentage') ? 'Labour Rate (%)' : 'Labour Rate (₹)',
            _tf(_labourRateCtrl, '0.00'),
          )),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Labour Amt [Auto]', _roWidget(_labourAmtCtrl))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _lbl('Metal Rate (₹/g)', _tf(_metalRateCtrl, '0.00'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Metal Amt [Auto]', _roWidget(_metalAmtCtrl))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Other Charges (₹)', _tf(_otherCtrl, '0.00'))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Narration', _tf(_narrationCtrl, 'e.g. Hook replaced'))),
        ]),

        // ── SECTION C ──────────────────────────────────────────────
        const SizedBox(height: 14),
        _secHead('C', 'Payment'),
        const SizedBox(height: 8),
        // Tax chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.amber),
            const SizedBox(width: 6),
            Text('Tax: $_taxScheme',
                style: const TextStyle(fontSize: 11, color: _brownLight, fontStyle: FontStyle.italic)),
            const SizedBox(width: 12),
            if (_taxScheme == 'CGST + SGST (Local)') ...[
              Text('CGST 9%: ₹${_cgst.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
              const SizedBox(width: 8),
              Text('SGST 9%: ₹${_sgst.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
            ] else if (_taxScheme == 'IGST (Interstate)') ...[
              Text('IGST 18%: ₹${_igst.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _lbl('Payment Mode', _dd(
            value: _bookNames.contains(_paymentMode) ? _paymentMode : null,
            items: _bookNames,
            hint: 'Select Payment',
            onChange: (v) => setState(() => _paymentMode = v ?? 'Cash'),
          ))),
          const SizedBox(width: 8),
          Expanded(child: _lbl('Cheque / UTR / Ref No', _tf(_paymentRefCtrl, 'e.g. UTR1234567'))),
        ]),
      ]),
    );
  }

  Widget _buildRight() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHead('', 'Bill Summary'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            _sr('Bill No', _billNo, bold: true),
            _sr('Date', _df.format(_billDate)),
            _sr('Customer', _customerName),
            _sr('Ref', _linkedReceipt.voucherNo, color: _brownLight),
            const Divider(color: _border, height: 14),
            _sr('Item', _itemCtrl.text.isEmpty ? '-' : _itemCtrl.text),
            _sr('Gross Wt', '${_grossCtrl.text} g'),
            _sr('Net Wt', '${_netCtrl.text} g', bold: true, color: _brown),
            _sr('Fine Wt', '${_fineCtrl.text} g'),
            const Divider(color: _border, height: 14),
            _sr('Labour Amt', '₹${_labourAmtCtrl.text}'),
            _sr('Metal Amt', '₹${_metalAmtCtrl.text}'),
            _sr('Wastage Amt', '₹${_wastageAmt.toStringAsFixed(2)}'),
            _sr('Diamond/Stone', '₹${(_diamondAmt + _stoneAmt).toStringAsFixed(2)}'),
            _sr('Other Charges', '₹${_otherCtrl.text}'),
            const Divider(color: _border, height: 14),
            _sr('Sub-total', '₹${_subTotal.toStringAsFixed(2)}', bold: true),
            if (_taxScheme == 'CGST + SGST (Local)') ...[
              _sr('CGST (9%)', '₹${_cgst.toStringAsFixed(2)}', color: Colors.deepOrange[700]),
              _sr('SGST (9%)', '₹${_sgst.toStringAsFixed(2)}', color: Colors.deepOrange[700]),
            ] else if (_taxScheme == 'IGST (Interstate)') ...[
              _sr('IGST (18%)', '₹${_igst.toStringAsFixed(2)}', color: Colors.deepOrange[700]),
            ],
            const Divider(color: _border, height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('NET PAYABLE',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                Text('₹${_netAmt.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800])),
              ]),
            ),
            if (_paymentMode.isNotEmpty && _paymentMode != 'None') ...[
              const Divider(color: _border, height: 14),
              _sr('Payment Via', _paymentMode, color: Colors.blue[700]),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Micro helpers ─────────────────────────────────────────────
  Widget _secHead(String letter, String title) => Row(children: [
        if (letter.isNotEmpty)
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: _brown, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(letter,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        if (letter.isNotEmpty) const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: _border)),
      ]);

  Widget _lbl(String label, Widget f) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLight)),
        const SizedBox(height: 3),
        f,
      ]);

  Widget _tf(TextEditingController c, String hint) => TextFormField(
        controller: c,
        enabled: !widget.readOnly,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: _border)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: _brown, width: 1.5)),
        ),
      );

  Widget _roField(String v) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F0EA),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border)),
        child: Text(v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
      );

  Widget _roWidget(TextEditingController c) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F0EA),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border)),
        child: ValueListenableBuilder(
            valueListenable: c,
            builder: (context, value, child) => Text(c.text,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown))),
      );

  Widget _dd({String? value, required List<String> items, String hint = '', ValueChanged<String?>? onChange}) =>
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            hint: Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            dropdownColor: Colors.white,
            iconSize: 18,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            onChanged: widget.readOnly ? null : onChange,
            items: items
                .map((i) => DropdownMenuItem(
                    value: i, child: Text(i, style: const TextStyle(fontSize: 12))))
                .toList(),
          ),
        ),
      );

  Widget _datePicker() => GestureDetector(
        onTap: widget.readOnly
            ? null
            : () async {
                final p = await showDatePicker(
                    context: context,
                    initialDate: _billDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035));
                if (p != null) setState(() => _billDate = p);
              },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_df.format(_billDate),
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
          ]),
        ),
      );

  Widget _sr(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _brownLight)),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                      color: color ?? Colors.black87),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}
