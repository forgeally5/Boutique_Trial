import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../../state/admin_state.dart';
import '../../../utils/pdf_customer_issue_receipt.dart';
import 'customer_issue_receipt_model.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../dialogs/add_customer_dialog.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import '../a_sales_entry/sales_entry_view.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

class CustomerIssueReceiptView extends StatefulWidget {
  final AdminState state;

  const CustomerIssueReceiptView({super.key, required this.state});

  @override
  State<CustomerIssueReceiptView> createState() => _CustomerIssueReceiptViewState();
}

class _CustomerIssueReceiptViewState extends State<CustomerIssueReceiptView> {
  final List<CustomerIssueReceipt> _records = [];
  bool _isLoading = false;
  int? _selectedIndex;

  // Filters
  String _customerFilter = 'All';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showPendingOnly = false;

  List<String> _customersList = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
    _loadCustomersList();
  }

  Future<void> _loadCustomersList() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('customers').get();
      final list = snap.docs.map((doc) => doc.data()['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() {
          _customersList = ['All', ...list.toSet()];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _selectedIndex = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customer_issue_receipts')
          .orderBy('createdAt', descending: true)
          .get();

      final fetched = snap.docs
          .map((doc) => CustomerIssueReceipt.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(fetched);
        });
      }
    } catch (e) {
      debugPrint('Firestore load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CustomerIssueReceipt> get _filteredRecords {
    return _records.where((r) {
      final matchCustomer = _customerFilter == 'All' ||
          r.customerName.toLowerCase() == _customerFilter.toLowerCase();

      final matchType = _typeFilter == 'All' ||
          r.transactionType.toLowerCase() == _typeFilter.toLowerCase();

      final matchStatus = _statusFilter == 'All' ||
          r.status.toLowerCase() == _statusFilter.toLowerCase() ||
          (_statusFilter == 'PENDING' && r.status == 'PENDING') ||
          (_statusFilter == 'ON PROCESS' && r.status == 'PENDING');

      final matchPending = !_showPendingOnly || (r.isIssue && r.status == 'PENDING');

      bool matchDate = true;
      if (_fromDate != null) {
        matchDate = matchDate && r.date.isAfter(_fromDate!.subtract(const Duration(days: 1)));
      }
      if (_toDate != null) {
        matchDate = matchDate && r.date.isBefore(_toDate!.add(const Duration(days: 1)));
      }

      return matchCustomer && matchType && matchStatus && matchDate && matchPending;
    }).toList();
  }

  String _generateNextTxNumber(String type) {
    final prefix = type.toLowerCase().contains('receipt') ? 'CR-' : 'CI-';
    final count = _records.where((r) => r.transactionNo.startsWith(prefix)).length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  void _openEntryDialog([CustomerIssueReceipt? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CustomerIssueReceiptFormDialog(
        existing: existing,
        generateTxNo: _generateNextTxNumber,
        state: widget.state,
        onSave: (record) async {
          try {
              // 1. Save Transaction to DB
              final dataToSave = record.toMap();
              
              final connectivityResult = await Connectivity().checkConnectivity();
              final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

              if (isOnline) {
                if (existing == null) {
                  final docRef = await FirebaseFirestore.instance
                      .collection('customer_issue_receipts')
                      .add(dataToSave);
                  final newRecord = CustomerIssueReceipt.fromMap(dataToSave, docRef.id);
              setState(() {
                _records.insert(0, newRecord);
                _selectedIndex = null;
              });
            } else {
              await FirebaseFirestore.instance
                  .collection('customer_issue_receipts')
                  .doc(existing.docId)
                  .update(dataToSave);
              final idx = _records.indexWhere((r) => r.docId == existing.docId);
              if (idx != -1) {
                setState(() {
                  _records[idx] = record;
                  _selectedIndex = null;
                });
              }
            }

            // 2. Integration / DB logic
            if (existing != null) {
              // Delete old ledger entries for this transaction to avoid duplicates
              final ledgerSnap = await FirebaseFirestore.instance
                  .collection('customer_ledger')
                  .where('description', isEqualTo: 'Approval Issue ${existing.transactionNo}')
                  .get();
              for (var doc in ledgerSnap.docs) {
                await doc.reference.delete();
              }

              // Revert old inventory changes from the original transaction
              if (existing.isIssue) {
                for (var item in existing.items) {
                  if (item.tagId.isNotEmpty) {
                    final tagDoc = await FirebaseFirestore.instance
                        .collection('jewelry_inventory')
                        .doc(item.tagId.toUpperCase())
                        .get();
                    if (tagDoc.exists && tagDoc.data() != null) {
                      final data = tagDoc.data()!;
                      final int currentPcs = (data['pcs'] ?? data['pieces'] ?? data['quantity'] ?? 0) as int;
                      final int currentIssued = (data['issuedPcs'] ?? 0) as int;

                      final newPcs = currentPcs + item.pcs;
                      final newIssued = (currentIssued - item.pcs).clamp(0, 99999);
                      final newStatus = newPcs <= 0 ? 'Out on Approval' : 'In Stock';

                      await FirebaseFirestore.instance
                          .collection('jewelry_inventory')
                          .doc(item.tagId.toUpperCase())
                          .update({
                        'pcs': newPcs,
                        'pieces': newPcs,
                        'quantity': newPcs,
                        'issuedPcs': newIssued,
                        'status': newStatus,
                        'productStatus': newStatus,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }
                  }
                }
              } else if (existing.receiptSubtype == 'Approval Return') {
                for (var item in existing.items) {
                  if (item.tagId.isNotEmpty) {
                    final tagDoc = await FirebaseFirestore.instance
                        .collection('jewelry_inventory')
                        .doc(item.tagId.toUpperCase())
                        .get();
                    if (tagDoc.exists && tagDoc.data() != null) {
                      final data = tagDoc.data()!;
                      final int currentPcs = (data['pcs'] ?? data['pieces'] ?? data['quantity'] ?? 0) as int;
                      final int currentIssued = (data['issuedPcs'] ?? 0) as int;

                      final newPcs = (currentPcs - item.pcs).clamp(0, 99999);
                      final newIssued = currentIssued + item.pcs;
                      final newStatus = newPcs <= 0 ? 'Out on Approval' : 'In Stock';

                      await FirebaseFirestore.instance
                          .collection('jewelry_inventory')
                          .doc(item.tagId.toUpperCase())
                          .update({
                        'pcs': newPcs,
                        'pieces': newPcs,
                        'quantity': newPcs,
                        'issuedPcs': newIssued,
                        'status': newStatus,
                        'productStatus': newStatus,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }
                  }
                }
              }
            }

            // Apply new stock changes
            if (record.isIssue) {
              // Update Inventory: mark piece as Preserved
              for (var item in record.items) {
                if (item.tagId.isNotEmpty) {
                  await ProductRepository().markPiecePreserved(
                    tagId: item.tagId,
                    transactionType: 'Customer Issue',
                    transactionNo: record.transactionNo,
                  );
                }
              }
              // Update Customer Ledger (memo)
              await FirebaseFirestore.instance.collection('customer_ledger').add({
                'customerId': record.customerName,
                'type': 'memo',
                'amount': record.totalAmount,
                'date': record.date,
                'description': 'Approval Issue ${record.transactionNo}',
              });
            } else {
               if (record.receiptSubtype == 'Approval Return') {
                  // Revert original issue
                  if (record.referenceEntryId.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('customer_issue_receipts').doc(record.referenceEntryId).update({
                      'status': 'RETURNED'
                    });
                  }
                  // Revert Inventory (mark piece as Available)
                  for (var item in record.items) {
                    if (item.tagId.isNotEmpty) {
                      await ProductRepository().markPieceAvailable(tagId: item.tagId);
                    }
                  }
               } else if (record.receiptSubtype == 'Old Gold Purchase') {
                 // 1. Generate OG stock in inventory
                 for (int i=0; i<record.items.length; i++) {
                   final item = record.items[i];
                   final ogTag = 'OG-${DateFormat('yyyyMMdd').format(DateTime.now())}-${record.transactionNo}-$i';
                   await FirebaseFirestore.instance.collection('jewelry_inventory').doc(ogTag).set({
                     'tagId': ogTag,
                     'name': item.itemName,
                     'category': 'Old Gold Stock',
                     'metalType': item.metalType,
                     'grossWeight': item.grossWeight,
                     'netWeight': item.netWeight,
                     'status': 'In Stock',
                     'createdAt': FieldValue.serverTimestamp(),
                   });
                 }
                 // 2. Trigger Cash/Bank/Card Receipt Outflow
                 if (record.paymentCash > 0 || record.paymentBank > 0 || record.paymentCard > 0) {
                    final rowData = [];
                    if (record.paymentCash > 0) rowData.add({'book':'Cash', 'mode':'Cash', 'amount':record.paymentCash});
                    if (record.paymentBank > 0) rowData.add({'book':'Bank', 'mode':'Bank', 'amount':record.paymentBank});
                    if (record.paymentCard > 0) rowData.add({'book':'Card', 'mode':'Card', 'amount':record.paymentCard});
                    
                    await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').add({
                      'voucherNo': 'PAY-${record.transactionNo}',
                      'voucherDate': DateFormat('dd/MM/yyyy EEE').format(record.date),
                      'accountName': record.customerName,
                      'amount': record.totalAmount,
                      'narration': 'Old Gold Purchase Settlement',
                      'rows': rowData,
                      'type': 'Payment',
                    });
                 }
                 // 3. Journal Entry
                 await FirebaseFirestore.instance.collection('journal_entries').add({
                    'voucherNo': 'JV-${record.transactionNo}',
                    'date': record.date,
                    'narration': 'Old Gold Purchase',
                    'rows': [
                      {'account': 'Old Gold Stock', 'debit': record.totalAmount, 'credit': 0},
                      {'account': 'Customer / Cash / Bank', 'debit': 0, 'credit': record.totalAmount},
                    ]
                 });
               }
             } // closes else (record.isIssue == false)
            } else {
               if (!dataToSave['transactionNo'].toString().endsWith('-OFF')) {
                  dataToSave['transactionNo'] = '${dataToSave['transactionNo']}-OFF';
               }
               
               final List<Map<String, dynamic>> inventoryUpdates = [];
                 final List<Map<String, dynamic>> ledgerUpdates = [];
                 final List<Map<String, dynamic>> docUpdates = [];
                 final List<Map<String, dynamic>> docDeletes = [];

                 if (existing != null) {
                    docDeletes.add({
                       'collection': 'customer_ledger',
                       'field': 'description',
                       'isEqualTo': 'Approval Issue ${existing.transactionNo}'
                    });
                    
                    if (existing.isIssue) {
                       for (var item in existing.items) {
                          if (item.tagId.isNotEmpty) {
                              inventoryUpdates.add({
                                'tagId': item.tagId,
                                'pcsDelta': item.pcs,
                                'issuedPcsDelta': -item.pcs,
                                'setStatus': 'In Stock',
                              });
                          }
                       }
                    } else if (existing.receiptSubtype == 'Approval Return') {
                       for (var item in existing.items) {
                          if (item.tagId.isNotEmpty) {
                              inventoryUpdates.add({
                                'tagId': item.tagId,
                                'pcsDelta': -item.pcs,
                                'issuedPcsDelta': item.pcs,
                                'setStatus': 'Out on Approval',
                              });
                          }
                       }
                    }
                 }

                 if (record.isIssue) {
                    for (var item in record.items) {
                       if (item.tagId.isNotEmpty) {
                           inventoryUpdates.add({
                               'tagId': item.tagId,
                               'pcsDelta': -item.pcs,
                               'issuedPcsDelta': item.pcs,
                               'setStatus': 'Out on Approval',
                           });
                       }
                    }
                    ledgerUpdates.add({
                       'customerId': record.customerName,
                       'type': 'memo',
                       'amount': record.totalAmount,
                       'date': record.date, 
                       'description': 'Approval Issue ${record.transactionNo}',
                    });
                 } else {
                    if (record.receiptSubtype == 'Approval Return') {
                        if (record.referenceEntryId.isNotEmpty) {
                            docUpdates.add({
                                'collection': 'customer_issue_receipts',
                                'docId': record.referenceEntryId,
                                'data': {'status': 'RETURNED'}
                            });
                        }
                        for (var item in record.items) {
                            if (item.tagId.isNotEmpty) {
                                inventoryUpdates.add({
                                    'tagId': item.tagId,
                                    'pcsDelta': item.pcs,
                                    'issuedPcsDelta': -item.pcs,
                                    'setStatus': 'In Stock',
                                });
                            }
                        }
                    } else if (record.receiptSubtype == 'Old Gold Purchase') {
                       for (int i=0; i<record.items.length; i++) {
                         final item = record.items[i];
                         final ogTag = 'OG-${DateFormat('yyyyMMdd').format(DateTime.now())}-${record.transactionNo}-$i';
                         await LocalDbService().insertEntry(
                           'jewelry_inventory',
                           {
                             'tagId': ogTag,
                             'name': item.itemName,
                             'category': 'Old Gold Stock',
                             'metalType': item.metalType,
                             'grossWeight': item.grossWeight,
                             'netWeight': item.netWeight,
                             'status': 'In Stock',
                             'createdAt': FieldValue.serverTimestamp(),
                           },
                           operation: 'SET',
                           docId: ogTag,
                         );
                       }
                       
                       if (record.paymentCash > 0 || record.paymentBank > 0 || record.paymentCard > 0) {
                          final rowData = [];
                          if (record.paymentCash > 0) rowData.add({'book':'Cash', 'mode':'Cash', 'amount':record.paymentCash});
                          if (record.paymentBank > 0) rowData.add({'book':'Bank', 'mode':'Bank', 'amount':record.paymentBank});
                          if (record.paymentCard > 0) rowData.add({'book':'Card', 'mode':'Card', 'amount':record.paymentCard});
                          
                          await LocalDbService().insertEntry(
                            'cash_bank_card_receipt_entries',
                            {
                              'voucherNo': 'PAY-${record.transactionNo}',
                              'voucherDate': DateFormat('dd/MM/yyyy EEE').format(record.date),
                              'accountName': record.customerName,
                              'amount': record.totalAmount,
                              'narration': 'Old Gold Purchase Settlement',
                              'rows': rowData,
                              'type': 'Payment',
                            },
                            operation: 'ADD',
                          );
                       }
                       
                       await LocalDbService().insertEntry(
                          'journal_entries',
                          {
                            'voucherNo': 'JV-${record.transactionNo}',
                            'date': record.date,
                            'narration': 'Old Gold Purchase',
                            'rows': [
                              {'account': 'Old Gold Stock', 'debit': record.totalAmount, 'credit': 0},
                              {'account': 'Customer / Cash / Bank', 'debit': 0, 'credit': record.totalAmount},
                            ]
                          },
                          operation: 'ADD',
                       );
                    }
                 }

                 dataToSave['inventoryUpdates'] = inventoryUpdates;
                 dataToSave['ledgerUpdates'] = ledgerUpdates;
                 dataToSave['documentUpdates'] = docUpdates;
                 dataToSave['documentDeletes'] = docDeletes;
                 
                 await LocalDbService().insertEntry(
                    'customer_issue_receipts',
                    dataToSave,
                    operation: existing != null ? 'UPDATE' : 'ADD',
                    docId: existing?.docId,
                 );
                 SyncService().syncNow();
                 dataToSave['docId'] = existing?.docId ?? 'offline_dummy_id';
                 
                 final newRecord = CustomerIssueReceipt.fromMap(dataToSave, dataToSave['docId']);
                 if (existing == null) {
                   setState(() {
                     _records.insert(0, newRecord);
                     _selectedIndex = null;
                   });
                 } else {
                   final idx = _records.indexWhere((r) => r.docId == existing.docId);
                   if (idx != -1) {
                     setState(() {
                       _records[idx] = newRecord;
                       _selectedIndex = null;
                     });
                   }
                 }
              }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Customer transaction ${record.transactionNo} saved successfully!'),
                  backgroundColor: Colors.green[800],
                ),
              );
            }
          } catch (e) {
            debugPrint('Failed to save transaction: $e');
          }
        },
      ),
    );
  }

  void _convertToSale(CustomerIssueReceipt r) async {
    // Check latest status in Firestore to prevent double conversion
    try {
      final doc = await FirebaseFirestore.instance.collection('customer_issue_receipts').doc(r.docId).get();
      if (doc.exists && doc.data() != null) {
        final currentStatus = doc.data()!['status']?.toString() ?? 'PENDING';
        if (currentStatus != 'PENDING') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ This memo has already been converted to Sale! (Status: $currentStatus)'),
                backgroundColor: const Color(0xFFD35400),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Error checking memo status: $e");
    }

    if (!mounted) return;

    // 1. Open checkboxes dialog to select returned items vs sold items
    final dynamic conversionResult = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ApprovalConversionDialog(
          memo: r,
          state: widget.state,
          generateTxNo: _generateNextTxNumber,
        );
      },
    );

    if (conversionResult == null || conversionResult is! Map<String, dynamic>) {
      // User cancelled conversion dialog
      return;
    }

    final Map<String, dynamic> initialData = Map<String, dynamic>.from(conversionResult['initialData']);

    // 2. Open Sales Entry Dialog
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final dynamic salesEntryResult = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: size.width * 0.95,
            height: size.height * 0.95,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SalesEntryView(
                state: widget.state,
                initialData: initialData,
                onBack: (val) => Navigator.pop(context, val),
              ),
            ),
          ),
        );
      },
    );

    if (salesEntryResult != null && salesEntryResult is Map) {
      try {
        final List<CustomerIssueReceiptItem> finalSoldItems = [];
        final List<CustomerIssueReceiptItem> finalReturnedItems = [];

        final billedItemsList = salesEntryResult['billedItems'] as List?;
        for (var item in r.items) {
          final tag = item.tagId.trim().toUpperCase();
          Map<String, dynamic>? billed;
          if (billedItemsList != null) {
            for (final b in billedItemsList) {
              if (b is Map && (b['tagId'] ?? '').toString().toUpperCase().trim() == tag) {
                billed = Map<String, dynamic>.from(b);
                break;
              }
            }
          }

          if (billed != null) {
            final int billedPcs = billed['pcs'] as int;
            if (billedPcs >= item.pcs) {
              finalSoldItems.add(item);
            } else {
              final soldPcs = billedPcs;
              final returnedPcs = item.pcs - soldPcs;

              final avgGross = item.grossWeight / item.pcs;
              final avgNet = item.netWeight / item.pcs;
              final avgStone = item.stoneWeight / item.pcs;
              final avgAmount = item.amount / item.pcs;

              finalSoldItems.add(CustomerIssueReceiptItem(
                tagId: item.tagId,
                itemName: item.itemName,
                metalType: item.metalType,
                purity: item.purity,
                grossWeight: avgGross * soldPcs,
                stoneWeight: avgStone * soldPcs,
                netWeight: avgNet * soldPcs,
                ratePerGram: item.ratePerGram,
                amount: avgAmount * soldPcs,
                makingCharges: item.makingCharges,
                deductionPercent: item.deductionPercent,
                photoUrls: item.photoUrls,
                remarks: item.remarks,
                branchId: item.branchId,
                pcs: soldPcs,
              ));

              if (returnedPcs > 0) {
                finalReturnedItems.add(CustomerIssueReceiptItem(
                  tagId: item.tagId,
                  itemName: item.itemName,
                  metalType: item.metalType,
                  purity: item.purity,
                  grossWeight: avgGross * returnedPcs,
                  stoneWeight: avgStone * returnedPcs,
                  netWeight: avgNet * returnedPcs,
                  ratePerGram: item.ratePerGram,
                  amount: avgAmount * returnedPcs,
                  makingCharges: item.makingCharges,
                  deductionPercent: item.deductionPercent,
                  photoUrls: item.photoUrls,
                  remarks: item.remarks,
                  branchId: item.branchId,
                  pcs: returnedPcs,
                ));
              }
            }
          } else {
            finalReturnedItems.add(item);
          }
        }

        final double finalSaleAmount = double.tryParse(salesEntryResult['totalAmount']?.toString() ?? '') ?? r.totalAmount;

        final connectivityResult = await Connectivity().checkConnectivity();
        final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

        if (isOnline) {
          // A. Generate Customer Receipt (Approval Return) in Firestore
          if (finalReturnedItems.isNotEmpty) {
            final receiptTxNo = _generateNextTxNumber('Customer Receipt');
            final receiptData = CustomerIssueReceipt(
              docId: '',
              transactionNo: receiptTxNo,
              date: DateTime.now(),
              transactionType: 'Customer Receipt',
              receiptSubtype: 'Approval Return',
              customerName: r.customerName,
              referenceNo: r.transactionNo,
              branchId: r.branchId,
              staffId: r.staffId,
              expectedReturnDate: null,
              items: finalReturnedItems,
              totalGrossWeight: finalReturnedItems.fold(0.0, (acc, item) => acc + item.grossWeight),
              totalNetWeight: finalReturnedItems.fold(0.0, (acc, item) => acc + item.netWeight),
              totalDiamondWeight: 0.0,
              totalAmount: finalReturnedItems.fold(0.0, (acc, item) => acc + item.amount),
              paymentCash: 0.0,
              paymentBank: 0.0,
              paymentCard: 0.0,
              termsText: '',
              isSignedPhysically: false,
              status: 'COMPLETED',
              remarks: 'Auto-generated receipt for items returned during conversion of ${r.transactionNo}',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              referenceEntryId: r.docId,
            );

            await FirebaseFirestore.instance.collection('customer_issue_receipts').add(receiptData.toMap());

            // Release stock for returned items
            for (var item in finalReturnedItems) {
              if (item.tagId.isNotEmpty) {
                await ProductRepository().markPieceAvailable(tagId: item.tagId);
              }
            }
          }

          // B. For sold items, update piece status to Sold in jewelry_inventory
          final saleVoucherNo = salesEntryResult['voucherNo']?.toString();
          for (var item in finalSoldItems) {
            if (item.tagId.isNotEmpty) {
              await ProductRepository().markPieceSold(tagId: item.tagId, billNo: saleVoucherNo);
            }
          }

          // C. Update source memo status and totalAmount to CONVERTED_TO_SALE and actual billed amount
          await FirebaseFirestore.instance.collection('customer_issue_receipts').doc(r.docId).update({
            'status': 'CONVERTED_TO_SALE',
            'totalAmount': finalSaleAmount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
           // OFFLINE QUEUE
           final List<Map<String, dynamic>> inventoryUpdates = [];
           final List<Map<String, dynamic>> docUpdates = [];

           if (finalReturnedItems.isNotEmpty) {
              final receiptTxNo = '${_generateNextTxNumber('Customer Receipt')}-OFF';
              final receiptData = CustomerIssueReceipt(
                docId: '',
                transactionNo: receiptTxNo,
                date: DateTime.now(),
                transactionType: 'Customer Receipt',
                receiptSubtype: 'Approval Return',
                customerName: r.customerName,
                referenceNo: r.transactionNo,
                branchId: r.branchId,
                staffId: r.staffId,
                expectedReturnDate: null,
                items: finalReturnedItems,
                totalGrossWeight: finalReturnedItems.fold(0.0, (acc, item) => acc + item.grossWeight),
                totalNetWeight: finalReturnedItems.fold(0.0, (acc, item) => acc + item.netWeight),
                totalDiamondWeight: 0.0,
                totalAmount: finalReturnedItems.fold(0.0, (acc, item) => acc + item.amount),
                paymentCash: 0.0,
                paymentBank: 0.0,
                paymentCard: 0.0,
                termsText: '',
                isSignedPhysically: false,
                status: 'COMPLETED',
                remarks: 'Auto-generated offline receipt for items returned during conversion of ${r.transactionNo}',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                referenceEntryId: r.docId,
              );
              final returnedMap = receiptData.toMap();
              
              for (var item in finalReturnedItems) {
                 if (item.tagId.isNotEmpty) {
                    inventoryUpdates.add({
                       'tagId': item.tagId,
                       'pcsDelta': item.pcs,
                       'issuedPcsDelta': -item.pcs,
                       'setStatus': 'In Stock'
                    });
                 }
              }
              returnedMap['inventoryUpdates'] = inventoryUpdates;
              await LocalDbService().insertEntry(
                 'customer_issue_receipts',
                 returnedMap,
                 operation: 'ADD'
              );
           }
           
           final List<Map<String, dynamic>> soldInventoryUpdates = [];
           for (var item in finalSoldItems) {
              if (item.tagId.isNotEmpty) {
                 soldInventoryUpdates.add({
                    'tagId': item.tagId,
                    'pcsDelta': 0, // already handled by SalesEntryView offline logic? Wait, SalesEntryView deducts pcs. We just need to deduct issuedPcs!
                    'issuedPcsDelta': -item.pcs,
                    'setStatus': 'Sold'
                 });
              }
           }
           
           docUpdates.add({
              'collection': 'customer_issue_receipts',
              'docId': r.docId,
              'data': {
                 'status': 'CONVERTED_TO_SALE',
                 'totalAmount': finalSaleAmount
              }
           });
           
           await LocalDbService().insertEntry(
              'offline_metadata', 
              {
                 'inventoryUpdates': soldInventoryUpdates,
                 'documentUpdates': docUpdates
              },
              operation: 'UPDATE'
           );
           SyncService().syncNow();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memo successfully converted to Sale!'), backgroundColor: Colors.green),
        );
        
        setState(() {
          final idx = _records.indexWhere((x) => x.docId == r.docId);
          if (idx != -1) _records[idx] = CustomerIssueReceipt.fromMap({...r.toMap(), 'status': 'CONVERTED_TO_SALE', 'totalAmount': finalSaleAmount}, r.docId);
          _selectedIndex = null;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating database after sale: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRecord(CustomerIssueReceipt record) async {
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
      final updatedMap = record.toMap();
      updatedMap['status'] = 'CANCELLED';
      updatedMap['updatedAt'] = Timestamp.now();
      final updated = CustomerIssueReceipt.fromMap(updatedMap, record.docId);

      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

        if (isOnline) {
          await FirebaseFirestore.instance
              .collection('customer_issue_receipts')
              .doc(record.docId)
              .update({'status': 'CANCELLED', 'updatedAt': Timestamp.now()});
              
          if (record.isIssue) {
            for (var item in record.items) {
              if (item.tagId.isNotEmpty) {
                final tagIdUpper = item.tagId.toUpperCase().trim();
                final docRef = FirebaseFirestore.instance.collection('jewelry_inventory').doc(tagIdUpper);
                final docSnap = await docRef.get();
                if (docSnap.exists && docSnap.data() != null) {
                  final dbData = docSnap.data()!;
                  final int currentPcs = (dbData['pcs'] ?? dbData['pieces'] ?? dbData['quantity'] ?? 0) as int;
                  final int currentIssued = (dbData['issuedPcs'] ?? 0) as int;

                  final int newPcs = currentPcs + item.pcs;
                  final int newIssued = (currentIssued - item.pcs).clamp(0, 99999);
                  final newStatus = newPcs <= 0 ? 'Out on Approval' : 'In Stock';

                  await docRef.update({
                    'pcs': newPcs,
                    'pieces': newPcs,
                    'quantity': newPcs,
                    'issuedPcs': newIssued,
                    'status': newStatus,
                    'productStatus': newStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await docRef.set({
                    'status': 'In Stock',
                    'pcs': item.pcs,
                    'issuedPcs': 0,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              }
            }
          }
        } else {
           final List<Map<String, dynamic>> inventoryUpdates = [];
           if (record.isIssue) {
              for (var item in record.items) {
                 if (item.tagId.isNotEmpty) {
                    inventoryUpdates.add({
                       'tagId': item.tagId,
                       'pcsDelta': item.pcs,
                       'issuedPcsDelta': -item.pcs,
                       'setStatus': 'In Stock'
                    });
                 }
              }
           }
           await LocalDbService().insertEntry(
              'customer_issue_receipts',
              {
                 'inventoryUpdates': inventoryUpdates,
                 'status': 'CANCELLED',
                 'updatedAt': Timestamp.now()
              },
              operation: 'UPDATE',
              docId: record.docId
           );
           SyncService().syncNow();
        }
      } catch (_) {}

      final idx = _records.indexWhere((r) => r.docId == record.docId);
      if (idx != -1) {
        setState(() {
          _records[idx] = updated;
          _selectedIndex = null;
        });
      }
    }
  }

  void _showViewDetailsDialog(CustomerIssueReceipt r) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Transaction ${r.transactionNo}', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)),
            _buildStatusChip(r.status),
          ],
        ),
        content: SizedBox(
          width: 800,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildDetailRow('Date', dateFormat.format(r.date))),
                  Expanded(child: _buildDetailRow('Type', '${r.transactionType} ${r.receiptSubtype.isNotEmpty ? "(${r.receiptSubtype})" : ""}')),
                  Expanded(child: _buildDetailRow('Customer', r.customerName)),
                  Expanded(child: _buildDetailRow('Ref No', r.referenceNo.isEmpty ? '-' : r.referenceNo)),
                ],
              ),
              const Divider(color: _border),
              const SizedBox(height: 8),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, color: _brown)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: _border),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: _headerBg),
                        children: [
                          _buildTableHeader('Tag/SKU'),
                          _buildTableHeader('Item Name'),
                          _buildTableHeader('Gross (g)'),
                          _buildTableHeader('Net (g)'),
                          _buildTableHeader('Rate'),
                          _buildTableHeader('Amount'),
                        ]
                      ),
                      ...r.items.map((i) => TableRow(
                        children: [
                          _buildTableCell(i.tagId),
                          _buildTableCell(i.itemName),
                          _buildTableCell(i.grossWeight.toStringAsFixed(3)),
                          _buildTableCell(i.netWeight.toStringAsFixed(3)),
                          _buildTableCell(i.ratePerGram.toStringAsFixed(2)),
                          _buildTableCell(i.amount.toStringAsFixed(2)),
                        ]
                      )),
                    ],
                  ),
                ),
              ),
              const Divider(color: _border),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildDetailRow('Total Gross', '${r.totalGrossWeight.toStringAsFixed(3)} g', isBold: true),
                  const SizedBox(width: 20),
                  _buildDetailRow('Total Net', '${r.totalNetWeight.toStringAsFixed(3)} g', isBold: true),
                  const SizedBox(width: 20),
                  _buildDetailRow('Total Amount', '₹${r.totalAmount.toStringAsFixed(2)}', isBold: true),
                ],
              ),
              if (!r.isIssue) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildDetailRow('Cash', '₹${r.paymentCash.toStringAsFixed(2)}'),
                    const SizedBox(width: 10),
                    _buildDetailRow('Bank', '₹${r.paymentBank.toStringAsFixed(2)}'),
                    const SizedBox(width: 10),
                    _buildDetailRow('Card', '₹${r.paymentCard.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (r.isIssue && r.status == 'PENDING')
             OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                label: const Text('Convert to Sale', style: TextStyle(color: Colors.green)),
                onPressed: () {
                   Navigator.pop(ctx);
                   _convertToSale(r);
                },
             ),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16, color: _brown),
            label: const Text('PDF / Print', style: TextStyle(color: _brown)),
            onPressed: () {
              Navigator.pop(ctx);
              PdfCustomerIssueReceipt.printPdf(r);
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

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
    );
  }

  Widget _buildTableCell(String content) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(content, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildDetailRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C41))),
          Flexible(
            child: Text(
              val,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isBold ? _brown : Colors.black87,
              ),
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

  Widget _buildRowCell(String text, {int flex = 2, bool isBold = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final dateFormat = DateFormat('dd/MM/yyyy');

    CustomerIssueReceipt? selectedRecord;
    if (_selectedIndex != null && _selectedIndex! < filtered.length) {
      selectedRecord = filtered[_selectedIndex!];
    }

    final bool isConvertEnabled = selectedRecord != null &&
        selectedRecord.isIssue &&
        selectedRecord.status == 'PENDING';

    final bool isCancelEnabled = selectedRecord != null &&
        selectedRecord.status != 'CANCELLED';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: _bg,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Top Action & Filter Area ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters (Left)
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterRow(
                                  'Customer',
                                  _customerFilter,
                                  _customersList,
                                  (val) => setState(() {
                                        _customerFilter = val!;
                                        _selectedIndex = null;
                                      }),
                                  isPrimary: true),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFilterRow(
                                  'Type',
                                  _typeFilter,
                                  ['All', 'Customer Issue', 'Customer Receipt'],
                                  (val) => setState(() {
                                        _typeFilter = val!;
                                        _selectedIndex = null;
                                      })),
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
                                  ['All', 'PENDING', 'COMPLETED', 'RETURNED', 'CONVERTED_TO_SALE', 'CANCELLED'],
                                  (val) => setState(() {
                                        _statusFilter = val!;
                                        _selectedIndex = null;
                                      })),
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
                                              lastDate: DateTime(2030));
                                          if (picked != null) {
                                            setState(() {
                                              _fromDate = picked;
                                              _selectedIndex = null;
                                            });
                                          }
                                        }),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('To',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _brown)),
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
                                              lastDate: DateTime(2030));
                                          if (picked != null) {
                                            setState(() {
                                              _toDate = picked;
                                              _selectedIndex = null;
                                            });
                                          }
                                        }),
                                  ),
                                  if (_fromDate != null || _toDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                                      onPressed: () => setState(() {
                                        _fromDate = null;
                                        _toDate = null;
                                        _selectedIndex = null;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('Pending Approvals Only', style: TextStyle(fontSize: 11)),
                              selected: _showPendingOnly,
                              selectedColor: Colors.red[100],
                              checkmarkColor: Colors.red[800],
                              labelStyle: TextStyle(
                                  color: _showPendingOnly ? Colors.red[900] : Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                              onSelected: (val) => setState(() {
                                _showPendingOnly = val;
                                _selectedIndex = null;
                              }),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Action Buttons (Right)
                  Expanded(
                    flex: 5,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        _buildActionButton(Icons.add_circle_outline, 'Add', onTap: () => _openEntryDialog()),
                        _buildActionButton(Icons.edit_outlined, 'Modify', onTap: selectedRecord == null ? null : () {
                          _openEntryDialog(selectedRecord);
                        }),
                        _buildActionButton(Icons.cancel_outlined, 'Cancel', iconColor: Colors.deepOrange, onTap: !isCancelEnabled ? null : () {
                          _cancelRecord(selectedRecord!);
                        }),
                        _buildActionButton(Icons.check_circle_outline, 'Convert\nSale', iconColor: Colors.green, onTap: !isConvertEnabled ? null : () {
                          _convertToSale(selectedRecord!);
                        }),
                        _buildActionButton(Icons.print_outlined, 'Print', iconColor: Colors.deepOrange, onTap: selectedRecord == null ? null : () {
                          PdfCustomerIssueReceipt.printPdf(selectedRecord!);
                        }),
                        _buildActionButton(Icons.pageview_outlined, 'View', onTap: selectedRecord == null ? null : () {
                          _showViewDetailsDialog(selectedRecord!);
                        }),
                        _buildActionButton(Icons.refresh, 'Refresh', onTap: _fetchRecords),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Data Table Area ────────────────────────────────────────────────
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text('Transaction No',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Date',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 3,
                              child: Text('Customer',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Type',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 1,
                              child: Text('Items',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Total Gross',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Total Net',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Amount',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                          Expanded(
                              flex: 2,
                              child: Text('Status',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _brown))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border, thickness: 1),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: _brown))
                          : filtered.isEmpty
                              ? const Center(
                                  child: Text('No records found.',
                                      style: TextStyle(
                                          color: _brownLight, fontSize: 13)))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final entry = filtered[index];
                                    final isEven = index % 2 == 0;
                                    final isSelected = _selectedIndex == index;
                                    final bool isOverdue = entry.isIssue &&
                                        entry.status == 'PENDING' &&
                                        entry.expectedReturnDate != null &&
                                        entry.expectedReturnDate!.isBefore(DateTime.now());

                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = index),
                                      onDoubleTap: () => _showViewDetailsDialog(entry),
                                      child: Container(
                                        color: isSelected
                                            ? const Color(0xFFFDF6ED)
                                            : (isOverdue
                                                ? Colors.red[50]
                                                : (isEven ? Colors.white : _headerBg)),
                                        child: Row(
                                          children: [
                                            _buildRowCell(entry.transactionNo, flex: 2, isBold: true),
                                            _buildRowCell(dateFormat.format(entry.date), flex: 2),
                                            _buildRowCell(entry.customerName, flex: 3),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                alignment: Alignment.centerLeft,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(entry.transactionType,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: entry.isIssue
                                                                ? Colors.blue[900]
                                                                : Colors.amber[900])),
                                                    if (entry.receiptSubtype.isNotEmpty)
                                                      Text(entry.receiptSubtype,
                                                          style: const TextStyle(
                                                              fontSize: 10, color: Colors.grey))
                                                  ],
                                                ),
                                              ),
                                            ),
                                            _buildRowCell('${entry.items.length}', flex: 1),
                                            _buildRowCell(entry.totalGrossWeight.toStringAsFixed(3), flex: 2),
                                            _buildRowCell(entry.totalNetWeight.toStringAsFixed(3), flex: 2, isBold: true),
                                            _buildRowCell('₹${entry.totalAmount.toStringAsFixed(2)}', flex: 2, isBold: true),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                alignment: Alignment.centerLeft,
                                                child: _buildStatusChip(entry.status),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: _headerBg,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${filtered.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _brown)),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.grey[200]!;
    Color text = Colors.grey[800]!;

    if (status == 'COMPLETED') { bg = Colors.green[50]!; text = Colors.green[800]!; }
    else if (status == 'PENDING') { bg = Colors.orange[50]!; text = Colors.orange[800]!; }
    else if (status == 'CONVERTED_TO_SALE') { bg = Colors.purple[50]!; text = Colors.purple[800]!; }
    else if (status == 'RETURNED') { bg = Colors.blue[50]!; text = Colors.blue[800]!; }
    else if (status == 'CANCELLED') { bg = Colors.red[50]!; text = Colors.red[800]!; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: text.withValues(alpha: 0.3))),
      child: Text(status == 'PENDING' ? 'ON PROCESS' : status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

// ── Entry Form Modal Dialog ──────────────────────────────────────────────────

class _CustomerIssueReceiptFormDialog extends StatefulWidget {
  final CustomerIssueReceipt? existing;
  final String Function(String type) generateTxNo;
  final Function(CustomerIssueReceipt record) onSave;
  final AdminState state;

  const _CustomerIssueReceiptFormDialog({
    this.existing,
    required this.generateTxNo,
    required this.onSave,
    required this.state,
  });

  @override
  State<_CustomerIssueReceiptFormDialog> createState() => _CustomerIssueReceiptFormDialogState();
}

class ItemRowController {
  final TextEditingController tagIdCtrl;
  final TextEditingController itemNameCtrl;
  final TextEditingController metalTypeCtrl;
  final TextEditingController purityCtrl;
  final TextEditingController grossWtCtrl;
  final TextEditingController stoneWtCtrl;
  final TextEditingController deductionPercentCtrl;
  final TextEditingController netWtCtrl;
  final TextEditingController ratePerGramCtrl;
  final TextEditingController makingChargesCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController remarksCtrl;
  final TextEditingController pcsCtrl;
  List<String> photoUrls;
  String selectedCounter;
  int maxPcs = 9999;
  double baseAmountPerPiece = 0.0;
  bool othWtChecked = false;

  ItemRowController({
    String tagId = '',
    String itemName = '',
    String metalType = 'Gold',
    String purity = '22.0',
    String grossWt = '0.000',
    String stoneWt = '0.000',
    String deductionPercent = '0.0',
    String netWt = '0.000',
    String ratePerGram = '0.0',
    String makingCharges = '0.0',
    String amount = '0.0',
    String remarks = '',
    String pcs = '1',
    List<String> photos = const [],
    this.selectedCounter = '',
  }) : tagIdCtrl = TextEditingController(text: tagId),
       itemNameCtrl = TextEditingController(text: itemName),
       metalTypeCtrl = TextEditingController(text: metalType),
       purityCtrl = TextEditingController(text: purity),
       grossWtCtrl = TextEditingController(text: grossWt),
       stoneWtCtrl = TextEditingController(text: stoneWt),
       deductionPercentCtrl = TextEditingController(text: deductionPercent),
       netWtCtrl = TextEditingController(text: netWt),
       ratePerGramCtrl = TextEditingController(text: ratePerGram),
       makingChargesCtrl = TextEditingController(text: makingCharges),
       amountCtrl = TextEditingController(text: amount),
       remarksCtrl = TextEditingController(text: remarks),
       pcsCtrl = TextEditingController(text: pcs),
       photoUrls = List.from(photos);

  void dispose() {
    tagIdCtrl.dispose(); itemNameCtrl.dispose(); metalTypeCtrl.dispose(); purityCtrl.dispose();
    grossWtCtrl.dispose(); stoneWtCtrl.dispose(); deductionPercentCtrl.dispose(); netWtCtrl.dispose();
    ratePerGramCtrl.dispose(); makingChargesCtrl.dispose(); amountCtrl.dispose(); remarksCtrl.dispose();
    pcsCtrl.dispose();
  }
}

class _CustomerIssueReceiptFormDialogState extends State<_CustomerIssueReceiptFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _txNo;
  late DateTime _date;
  DateTime? _expectedReturnDate;
  String _txType = 'Customer Issue';
  String _receiptSubtype = 'Approval Return';
  final _customerCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  
  final List<ItemRowController> _itemRows = [];
  
  final _cashCtrl = TextEditingController(text: '0.0');
  final _bankCtrl = TextEditingController(text: '0.0');
  final _cardCtrl = TextEditingController(text: '0.0');
  final _termsCtrl = TextEditingController();
  bool _isSigned = false;
  String _status = 'PENDING';
  final _remarksCtrl = TextEditingController();

  double _totalGross = 0.0;
  double _totalNet = 0.0;
  double _totalAmount = 0.0;

  List<String> _salesmanOptions = [];
  List<String> _counterOptions = [];
  List<String> _itemOptions = [];
  List<String> _customerOptions = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _txNo = e.transactionNo;
      _date = e.date;
      _txType = e.transactionType;
      _receiptSubtype = e.receiptSubtype.isEmpty ? 'Approval Return' : e.receiptSubtype;
      _customerCtrl.text = e.customerName;
      _refNoCtrl.text = e.referenceNo;
      _branchCtrl.text = e.branchId;
      _staffCtrl.text = e.staffId;
      _expectedReturnDate = e.expectedReturnDate;
      
      for (var item in e.items) {
        final row = ItemRowController(
          tagId: item.tagId,
          itemName: item.itemName,
          metalType: item.metalType,
          purity: item.purity.toString(),
          grossWt: item.grossWeight.toStringAsFixed(3),
          stoneWt: item.stoneWeight.toStringAsFixed(3),
          deductionPercent: item.deductionPercent.toStringAsFixed(2),
          netWt: item.netWeight.toStringAsFixed(3),
          ratePerGram: item.ratePerGram.toStringAsFixed(2),
          makingCharges: item.makingCharges.toStringAsFixed(2),
          amount: item.amount.toStringAsFixed(2),
          remarks: item.remarks,
          photos: item.photoUrls,
          selectedCounter: item.branchId,
          pcs: item.pcs.toString(),
        );
        row.baseAmountPerPiece = item.pcs > 0 ? (item.amount / item.pcs) : item.amount;
        _itemRows.add(row);
      }
      _cashCtrl.text = e.paymentCash.toStringAsFixed(2);
      _bankCtrl.text = e.paymentBank.toStringAsFixed(2);
      _cardCtrl.text = e.paymentCard.toStringAsFixed(2);
      _termsCtrl.text = e.termsText;
      _isSigned = e.isSignedPhysically;
      _status = e.status;
      _remarksCtrl.text = e.remarks;
    } else {
      _date = DateTime.now();
      _expectedReturnDate = DateTime.now().add(const Duration(days: 7));
      _txNo = widget.generateTxNo(_txType);
      _addNewItemRow();
    }
    
    _loadDropdownOptions();
    for (var row in _itemRows) {
      _attachListeners(row);
    }
    _recalculateTotals();
    _fetchAvailableStockForExistingItems();
  }

  Future<void> _fetchAvailableStockForExistingItems() async {
    if (widget.existing == null) return;
    try {
      for (int i = 0; i < _itemRows.length; i++) {
        final row = _itemRows[i];
        final tagId = row.tagIdCtrl.text.trim().toUpperCase();
        if (tagId.isEmpty) continue;
        
        final doc = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(tagId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final int stockPcs = (data['pcs'] as num?)?.toInt() ??
              (data['pieces'] as num?)?.toInt() ??
              (data['quantity'] as num?)?.toInt() ?? 0;
              
          int originallyIssued = 0;
          if (widget.existing != null) {
            final matchedItem = widget.existing!.items.firstWhere(
              (item) => item.tagId.trim().toUpperCase() == tagId,
              orElse: () => CustomerIssueReceiptItem(tagId: '', itemName: '', metalType: 'Gold', purity: 0, grossWeight: 0, stoneWeight: 0, netWeight: 0, ratePerGram: 0, amount: 0, makingCharges: 0, remarks: '', photoUrls: [], branchId: '', pcs: 0),
            );
            originallyIssued = matchedItem.pcs;
          }
          
          setState(() {
            row.maxPcs = stockPcs + originallyIssued;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching stock for existing items: $e");
    }
  }

  Future<void> _loadDropdownOptions() async {
    try {
      final repo = ProductRepository();
      final salesmen = await repo.getUniqueSalesmen();
      final counters = await repo.getUniqueCounters();
      final items = await repo.getUniqueItemNames();
      
      final custSnap = await FirebaseFirestore.instance.collection('customers').get();
      final customers = custSnap.docs.map((doc) => doc.data()['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
      customers.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _salesmanOptions = List.from(salesmen.toSet());
          _counterOptions = List.from(counters.toSet());
          _itemOptions = List.from(items.toSet());
          _customerOptions = List.from(customers.toSet());
          
           if (_staffCtrl.text.isEmpty && _salesmanOptions.isNotEmpty) {
            _staffCtrl.text = _salesmanOptions.first;
          }
          if (_branchCtrl.text.isEmpty && _counterOptions.isNotEmpty) {
            _branchCtrl.text = _counterOptions.first;
          }
          if (_customerCtrl.text.isEmpty && _customerOptions.isNotEmpty) {
            _customerCtrl.text = _customerOptions.first;
          }

          // Populate default counter for row selectedCounter
          for (var r in _itemRows) {
            if (r.selectedCounter.isEmpty && _counterOptions.isNotEmpty) {
              r.selectedCounter = _counterOptions.first;
            }
          }
          
          if (_staffCtrl.text.isNotEmpty && !_salesmanOptions.contains(_staffCtrl.text)) {
            _salesmanOptions.add(_staffCtrl.text);
          }
          if (_branchCtrl.text.isNotEmpty && !_counterOptions.contains(_branchCtrl.text)) {
            _counterOptions.add(_branchCtrl.text);
          }
          if (_customerCtrl.text.isNotEmpty && !_customerOptions.contains(_customerCtrl.text)) {
            _customerOptions.add(_customerCtrl.text);
          }
          
          for (var row in _itemRows) {
            final name = row.itemNameCtrl.text.trim();
            if (name.isNotEmpty && !_itemOptions.contains(name)) {
              _itemOptions.add(name);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading dropdown options: $e');
    }
  }
  
  void _attachListeners(ItemRowController row) {
    row.grossWtCtrl.addListener(() => _recalcRow(row));
    row.stoneWtCtrl.addListener(() => _recalcRow(row));
    row.deductionPercentCtrl.addListener(() => _recalcRow(row));
    row.ratePerGramCtrl.addListener(() => _recalcRow(row));
    row.makingChargesCtrl.addListener(() => _recalcRow(row));
    row.pcsCtrl.addListener(() => _recalcRow(row));
  }

  void _recalcRow(ItemRowController row) {
    final gross = double.tryParse(row.grossWtCtrl.text.trim()) ?? 0.0;
    final stone = row.othWtChecked ? (double.tryParse(row.stoneWtCtrl.text.trim()) ?? 0.0) : 0.0;
    final deductPct = double.tryParse(row.deductionPercentCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(row.ratePerGramCtrl.text.trim()) ?? 0.0;
    final making = double.tryParse(row.makingChargesCtrl.text.trim()) ?? 0.0;
    int enteredPcs = int.tryParse(row.pcsCtrl.text.trim()) ?? 1;
    if (enteredPcs <= 0) enteredPcs = 1;

    // Clamp pcs to stock limit
    if (row.maxPcs > 0 && row.maxPcs < 9999 && enteredPcs > row.maxPcs) {
      final clamped = row.maxPcs.toString();
      if (row.pcsCtrl.text.trim() != clamped) {
        row.pcsCtrl.removeListener(() => _recalcRow(row));
        row.pcsCtrl.text = clamped;
        row.pcsCtrl.addListener(() => _recalcRow(row));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('⚠️ Max stock available is ${row.maxPcs} pcs'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ));
          }
        });
      }
      enteredPcs = row.maxPcs;
    }

    double net = (gross - stone).clamp(0.0, double.infinity);
    if (deductPct > 0) {
      net = net - (net * (deductPct / 100.0));
    }

    double amount;
    if (row.tagIdCtrl.text.trim().isNotEmpty && row.baseAmountPerPiece > 0) {
      amount = row.baseAmountPerPiece * enteredPcs;
    } else {
      amount = (net * rate) + making;
    }

    if (double.tryParse(row.netWtCtrl.text) != net) row.netWtCtrl.text = net.toStringAsFixed(3);
    if (double.tryParse(row.amountCtrl.text) != amount) row.amountCtrl.text = amount.toStringAsFixed(2);
    
    _recalculateTotals();
  }

  void _recalculateTotals() {
    double gross = 0;
    double net = 0;
    double amt = 0;
    for (var row in _itemRows) {
      gross += double.tryParse(row.grossWtCtrl.text.trim()) ?? 0.0;
      net += double.tryParse(row.netWtCtrl.text.trim()) ?? 0.0;
      amt += double.tryParse(row.amountCtrl.text.trim()) ?? 0.0;
    }
    setState(() {
      _totalGross = gross;
      _totalNet = net;
      if (widget.existing != null && widget.existing!.status == 'CONVERTED_TO_SALE') {
        _totalAmount = widget.existing!.totalAmount;
      } else {
        _totalAmount = amt;
      }
    });
  }
  
  void _addNewItemRow() {
    setState(() {
      final defaultCounter = _branchCtrl.text.isNotEmpty 
          ? _branchCtrl.text 
          : (_counterOptions.isNotEmpty ? _counterOptions.first : 'C1');
      final newRow = ItemRowController(selectedCounter: defaultCounter);
      if (_itemOptions.isNotEmpty) {
        newRow.itemNameCtrl.text = _itemOptions.first;
      }
      _attachListeners(newRow);
      _itemRows.add(newRow);
    });
  }
  
  void _removeRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows[index].dispose();
        _itemRows.removeAt(index);
        _recalculateTotals();
      });
    }
  }

  Future<void> _fetchTagDetails(String tagId, ItemRowController row) async {
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
        final lines = cleanTag.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
      
      cleanTag = cleanTag.split('-P')[0].split('-p')[0].split('/P')[0].trim().toUpperCase();

      // Check for duplicate scan
      bool isDuplicate = false;
      for (int i = 0; i < _itemRows.length; i++) {
        if (_itemRows[i] != row && _itemRows[i].tagIdCtrl.text.trim().toUpperCase() == cleanTag) {
          isDuplicate = true;
          break;
        }
      }

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Item "$cleanTag" is already added to this receipt.'),
              backgroundColor: const Color(0xFFC0392B),
            ),
          );
        }
        row.tagIdCtrl.clear();
        return;
      }

      Future<DocumentSnapshot<Map<String, dynamic>>> queryDb(String tag) async {
        DocumentSnapshot<Map<String, dynamic>> d = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(tag).get();
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

        // Mirror Sales Entry: otherWt → stoneWt → sum extraCharges → gross-net
        double other = 0.0;
        if (data['otherWt'] != null && (data['otherWt'] as num).toDouble() > 0) {
          other = (data['otherWt'] as num).toDouble();
        } else if (data['stoneWt'] != null && (data['stoneWt'] as num).toDouble() > 0) {
          other = (data['stoneWt'] as num).toDouble();
        } else {
          final extraCharges = data['extraCharges'];
          if (extraCharges is List && extraCharges.isNotEmpty) {
            for (var charge in extraCharges) {
              if (charge is Map) {
                final rawWt = ((charge['weight'] ?? 0.0) as num).toDouble();
                final sName = (charge['styleName'] ?? '').toString().trim().toLowerCase();
                // Diamond weight is stored in carats → convert to grams (1 ct = 0.2 g)
                final isDiamond = sName.contains('diamond');
                other += isDiamond ? rawWt * 0.2 : rawWt;
              }
            }
          }
          if (other == 0) {
            other = (gross - net).clamp(0.0, double.infinity);
          }
        }
        final hasExtra = data['extraCharges'] is List && (data['extraCharges'] as List).isNotEmpty;
        final purityVal = (data['purityVal'] ?? 22.0).toDouble();
        final rate = (data['metalRate'] ?? data['rate'] ?? 0.0).toDouble();
        final name = data['name'] ?? data['productName'] ?? '';
        final int stockPcs = (data['pcs'] as num?)?.toInt() ??
            (data['pieces'] as num?)?.toInt() ??
            (data['quantity'] as num?)?.toInt() ?? 1;
        final double dbTotalAmt = (data['totalAmount'] ?? data['calculatedPrice'] ?? 0.0).toDouble();
        row.baseAmountPerPiece = dbTotalAmt;

        int originallyIssued = 0;
        if (widget.existing != null) {
          final matchedItem = widget.existing!.items.firstWhere(
            (item) => item.tagId.trim().toUpperCase() == cleanTag,
            orElse: () => CustomerIssueReceiptItem(tagId: '', itemName: '', metalType: 'Gold', purity: 0, grossWeight: 0, stoneWeight: 0, netWeight: 0, ratePerGram: 0, amount: 0, makingCharges: 0, remarks: '', photoUrls: [], branchId: '', pcs: 0),
          );
          originallyIssued = matchedItem.pcs;
        }

        setState(() {
          if (name.isNotEmpty) {
            if (!_itemOptions.contains(name)) {
              _itemOptions.add(name);
            }
            row.itemNameCtrl.text = name;
          }
          row.grossWtCtrl.text = gross.toStringAsFixed(3);
          // Set othWtChecked: true when other weight > 0 OR extraCharges exist (mirrors Sales Entry)
          row.othWtChecked = other > 0 || hasExtra;
          row.stoneWtCtrl.text = other.toStringAsFixed(3);
          row.netWtCtrl.text = net.toStringAsFixed(3);
          row.purityCtrl.text = purityVal.toString();
          row.ratePerGramCtrl.text = rate.toStringAsFixed(2);
          row.maxPcs = stockPcs + originallyIssued;
          row.pcsCtrl.text = '1';
        });

        _recalcRow(row);
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

  Future<void> _uploadPhoto(ItemRowController row) async {
    if (row.photoUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 images per row allowed.')));
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (pickedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading image...')));
      final url = await CloudinaryService().uploadXFile(pickedFile);
      if (url != null && mounted) {
        setState(() => row.photoUrls.add(url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded!'), backgroundColor: Colors.green));
      }
    }
  }

  void _triggerNewCustomerCreation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddCustomerDialog(
        isSupplier: false,
        onSaved: (Map<String, dynamic> customerData) {
          final name = customerData['name'] ?? customerData['familyHead'] ?? '';
          if (mounted && name.isNotEmpty) {
            setState(() {
              if (!_customerOptions.contains(name)) {
                _customerOptions.add(name);
                _customerOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              }
              _customerCtrl.text = name;
            });
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final bool isIssue = _txType == 'Customer Issue';
    final bool isOldGold = !isIssue && _receiptSubtype == 'Old Gold Purchase';

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.existing == null ? 'New Customer Transaction' : 'Edit Customer Entry', style: const TextStyle(fontWeight: FontWeight.bold, color: _brown, fontSize: 18)),
            IconButton(icon: const Icon(Icons.close, color: _brownLight), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
      content: SizedBox(
        width: 1100,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER ROW 1
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Transaction Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(height: 4),
                          Container(
                            height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8), color: Colors.white),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true, value: _txType,
                                items: ['Customer Issue', 'Customer Receipt'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: widget.existing != null ? null : (v) {
                                  if (v != null) {
                                    setState(() { 
                                      _txType = v; _txNo = widget.generateTxNo(v); 
                                      _status = v == 'Customer Issue' ? 'PENDING' : 'COMPLETED';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(label: 'Transaction No', readOnly: true, controller: TextEditingController(text: _txNo))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (picked != null) setState(() => _date = picked);
                            },
                            child: Container(
                              height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8), color: const Color(0xFFFAFAFA)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dateFormat.format(_date), style: const TextStyle(fontSize: 13)), const Icon(Icons.calendar_today, size: 16, color: _brownLight)]),
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
                          const Text('Customer Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_customerCtrl.text),
                            initialValue: (_customerOptions.contains(_customerCtrl.text) ? _customerCtrl.text : (_customerOptions.isNotEmpty ? _customerOptions.first : null)),
                            isDense: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '__ADD_NEW_CUSTOMER__',
                                child: Text(
                                  '+ Add Customer',
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              ..._customerOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (v) {
                              if (v == '__ADD_NEW_CUSTOMER__') {
                                _triggerNewCustomerCreation();
                              } else if (v != null) {
                                setState(() {
                                  _customerCtrl.text = v;
                                });
                              }
                            },
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // HEADER ROW 2
                Row(
                  children: [
                    if (!isIssue)
                      const Expanded(
                        child: SizedBox(),
                      )
                    else 
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expected Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: _expectedReturnDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                                if (picked != null) setState(() => _expectedReturnDate = picked);
                              },
                              child: Container(
                                height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8), color: const Color(0xFFFAFAFA)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dateFormat.format(_expectedReturnDate ?? DateTime.now()), style: const TextStyle(fontSize: 13)), const Icon(Icons.event, size: 16, color: _brownLight)]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(label: 'Ref No / Order No', controller: _refNoCtrl)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salesperson', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(height: 4),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: (_salesmanOptions.contains(_staffCtrl.text) ? _staffCtrl.text : (_salesmanOptions.isNotEmpty ? _salesmanOptions.first : null)),
                                items: _salesmanOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _staffCtrl.text = v;
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
                
                const SizedBox(height: 16),
                const Text('ITEM DETAILS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                const SizedBox(height: 8),

                // ITEMS TABLE HEADER
                Container(
                  color: _headerBg,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(isOldGold ? 'Description' : 'Tag ID', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      if (!isOldGold) Expanded(flex: 3, child: const Text('Item Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Counter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 1, child: const Text('Pcs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Gross Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Oth. Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      if (isOldGold) Expanded(flex: 2, child: const Text('Deduct %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Net Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Rate/g', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      if (isOldGold) Expanded(flex: 2, child: const Text('Making', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      if (_txType != 'Customer Receipt') Expanded(flex: 2, child: const Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      Expanded(flex: 2, child: const Text('Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      const SizedBox(width: 30), // Delete icon
                    ],
                  ),
                ),
                
                // ITEMS LIST
                Container(
                  height: 250,
                  decoration: BoxDecoration(border: Border.all(color: _border)),
                  child: ListView.builder(
                    itemCount: _itemRows.length,
                    itemBuilder: (ctx, idx) {
                      final row = _itemRows[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: isOldGold
                                  ? _buildGridField(row.itemNameCtrl, hint: 'Description')
                                  : SizedBox(
                                      height: 32,
                                      child: TextField(
                                        controller: row.tagIdCtrl,
                                        style: const TextStyle(fontSize: 11),
                                        decoration: InputDecoration(
                                          hintText: 'Scan Tag',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.fromLTRB(6, 8, 2, 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                                          suffixIcon: InkWell(
                                            onTap: () async {
                                              String? res = await openQrScanner(context);
                                              if (res != null && res != '-1' && res.isNotEmpty) {
                                                row.tagIdCtrl.text = res.trim().toUpperCase();
                                                _fetchTagDetails(res, row);
                                              }
                                            },
                                            child: const Icon(Icons.qr_code_scanner, size: 14, color: _brownLight),
                                          ),
                                          suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        ),
                                        onSubmitted: (val) => _fetchTagDetails(val, row),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            if (!isOldGold)
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: (_itemOptions.contains(row.itemNameCtrl.text) ? row.itemNameCtrl.text : (_itemOptions.isNotEmpty ? _itemOptions.first : null)),
                                  isDense: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: _itemOptions.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        row.itemNameCtrl.text = v;
                                      });
                                    }
                                  },
                                ),
                              ),
                            if (!isOldGold) const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: (_counterOptions.contains(row.selectedCounter) ? row.selectedCounter : (_counterOptions.isNotEmpty ? _counterOptions.first : null)),
                                isDense: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                                items: _counterOptions.map((counter) => DropdownMenuItem(value: counter, child: Text(counter, style: const TextStyle(fontSize: 11)))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      row.selectedCounter = v;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 1,
                              child: _buildGridField(row.pcsCtrl, isNum: true),
                            ),
                            const SizedBox(width: 4),
                            Expanded(flex: 2, child: _buildGridField(row.grossWtCtrl, isNum: true)),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: row.othWtChecked,
                                      activeColor: _brown,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) {
                                        setState(() {
                                          row.othWtChecked = val ?? false;
                                          if (!row.othWtChecked) {
                                            row.stoneWtCtrl.text = '0.000';
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: row.othWtChecked
                                        ? _buildGridField(row.stoneWtCtrl, isNum: true)
                                        : Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: _border),
                                              borderRadius: BorderRadius.circular(4),
                                              color: const Color(0xFFF5F5F5),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (isOldGold) Expanded(flex: 2, child: _buildGridField(row.deductionPercentCtrl, isNum: true)),
                            if (isOldGold) const SizedBox(width: 4),
                            Expanded(flex: 2, child: _buildGridField(row.netWtCtrl, readOnly: true)),
                            const SizedBox(width: 4),
                            Expanded(flex: 2, child: _buildGridField(row.ratePerGramCtrl, isNum: true)),
                            const SizedBox(width: 4),
                            if (isOldGold) Expanded(flex: 2, child: _buildGridField(row.makingChargesCtrl, isNum: true)),
                            if (isOldGold) const SizedBox(width: 4),
                            if (_txType != 'Customer Receipt') Expanded(flex: 2, child: _buildGridField(row.amountCtrl, readOnly: true)),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2, 
                              child: Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.camera_alt_outlined, size: 16, color: _brown), onPressed: () => _uploadPhoto(row), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  Text('${row.photoUrls.length}/3', style: const TextStyle(fontSize: 10)),
                                ],
                              )
                            ),
                            SizedBox(width: 30, child: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _removeRow(idx), padding: EdgeInsets.zero)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _addNewItemRow,
                    icon: const Icon(Icons.add_circle_outline, color: _brown),
                    label: const Text('Add Item Row', style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const Divider(color: _border, height: 24),
                
                // FOOTER: TOTALS AND PAYMENT
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOldGold) ...[
                             const Text('Payment Settlement (Outflow to Customer)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brown)),
                             const SizedBox(height: 8),
                             Row(
                               children: [
                                 Expanded(child: _buildFormField(label: 'Cash', controller: _cashCtrl, keyboardType: TextInputType.number)),
                                 const SizedBox(width: 8),
                                 Expanded(child: _buildFormField(label: 'Bank', controller: _bankCtrl, keyboardType: TextInputType.number)),
                                 const SizedBox(width: 8),
                                 Expanded(child: _buildFormField(label: 'Card', controller: _cardCtrl, keyboardType: TextInputType.number)),
                               ],
                             ),
                             const SizedBox(height: 12),
                          ],
                          _buildFormField(label: 'Remarks', controller: _remarksCtrl, maxLines: 2),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(value: _isSigned, activeColor: _brown, onChanged: (val) => setState(() => _isSigned = val ?? false)),
                              const Text('Signed Physically by Customer (Attach copy later)', style: TextStyle(fontSize: 12, color: _brown)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _headerBg, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            _buildTotalRow('Total Gross Wt:', '${_totalGross.toStringAsFixed(3)} g'),
                            const SizedBox(height: 8),
                            _buildTotalRow('Total Net Wt:', '${_totalNet.toStringAsFixed(3)} g', isBold: true),
                            const Divider(color: _border, height: 24),
                            _buildTotalRow('Total Amount:', '₹${_totalAmount.toStringAsFixed(2)}', isBold: true, color: Colors.blue.shade800),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: _border)), onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _brownLight))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_itemRows.isEmpty || _itemRows.first.grossWtCtrl.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item.')));
                 return;
              }

              // Validate pieces against available inventory stock
              if (isIssue) {
                for (int i = 0; i < _itemRows.length; i++) {
                  final row = _itemRows[i];
                  final enteredPcs = int.tryParse(row.pcsCtrl.text.trim()) ?? 1;
                  if (enteredPcs > row.maxPcs) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 28),
                            SizedBox(width: 8),
                            Text('Stock Limit Exceeded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        content: Text('Row ${i + 1} entered pieces ($enteredPcs) exceeds available inventory stock (${row.maxPcs} pcs) for this tag.'),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                }
              }

              final paymentCash = double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
              final paymentBank = double.tryParse(_bankCtrl.text.trim()) ?? 0.0;
              final paymentCard = double.tryParse(_cardCtrl.text.trim()) ?? 0.0;

              if (isOldGold) {
                final sumPayments = paymentCash + paymentBank + paymentCard;
                if ((sumPayments - _totalAmount).abs() > 1.0) { // allow 1 rs rounding
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Payment settlement must equal Total Amount!'), backgroundColor: Colors.red));
                   return;
                }
              }

              final itemsList = _itemRows.map((r) => CustomerIssueReceiptItem(
                tagId: r.tagIdCtrl.text.trim().toUpperCase(),
                itemName: r.itemNameCtrl.text.trim(),
                metalType: r.metalTypeCtrl.text.trim(),
                purity: double.tryParse(r.purityCtrl.text.trim()) ?? 0.0,
                grossWeight: double.tryParse(r.grossWtCtrl.text.trim()) ?? 0.0,
                stoneWeight: double.tryParse(r.stoneWtCtrl.text.trim()) ?? 0.0,
                deductionPercent: double.tryParse(r.deductionPercentCtrl.text.trim()) ?? 0.0,
                netWeight: double.tryParse(r.netWtCtrl.text.trim()) ?? 0.0,
                ratePerGram: double.tryParse(r.ratePerGramCtrl.text.trim()) ?? 0.0,
                amount: double.tryParse(r.amountCtrl.text.trim()) ?? 0.0,
                makingCharges: double.tryParse(r.makingChargesCtrl.text.trim()) ?? 0.0,
                remarks: r.remarksCtrl.text.trim(),
                photoUrls: r.photoUrls,
                branchId: r.selectedCounter,
                pcs: int.tryParse(r.pcsCtrl.text.trim()) ?? 1,
              )).toList();

              final record = CustomerIssueReceipt(
                docId: widget.existing?.docId ?? '',
                transactionNo: _txNo,
                date: _date,
                transactionType: _txType,
                receiptSubtype: _receiptSubtype,
                customerName: _customerCtrl.text.trim(),
                referenceNo: _refNoCtrl.text.trim(),
                branchId: itemsList.isNotEmpty ? itemsList.first.branchId : _branchCtrl.text.trim(),
                staffId: _staffCtrl.text.trim(),
                expectedReturnDate: _expectedReturnDate,
                items: itemsList,
                totalGrossWeight: _totalGross,
                totalNetWeight: _totalNet,
                totalDiamondWeight: 0.0,
                totalAmount: _totalAmount,
                paymentCash: paymentCash,
                paymentBank: paymentBank,
                paymentCard: paymentCard,
                termsText: _termsCtrl.text.trim(),
                isSignedPhysically: _isSigned,
                status: _status,
                remarks: _remarksCtrl.text.trim(),
                createdAt: widget.existing?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              widget.onSave(record);
              Navigator.pop(context);
            }
          },
          child: const Text('Save Transaction'),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String val, {bool isBold = false, Color? color}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: _brown)), Text(val, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? _brown))]);
  }

  Widget _buildGridField(TextEditingController controller, {String? hint, bool readOnly = false, bool isNum = false}) {
    return TextFormField(
      controller: controller, readOnly: readOnly,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(fontSize: 11, fontWeight: readOnly ? FontWeight.bold : FontWeight.normal),
      decoration: InputDecoration(
        hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
        filled: readOnly, fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
      ),
    );
  }

  Widget _buildFormField({required String label, required TextEditingController controller, bool readOnly = false, String? hint, TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)), const SizedBox(height: 4),
        TextFormField(
          controller: controller, readOnly: readOnly, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
          style: TextStyle(fontSize: 13, fontWeight: readOnly ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown)),
            filled: readOnly, fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ApprovalConversionDialog extends StatefulWidget {
  final CustomerIssueReceipt memo;
  final AdminState state;
  final String Function(String type) generateTxNo;

  const _ApprovalConversionDialog({
    required this.memo,
    required this.state,
    required this.generateTxNo,
  });

  @override
  State<_ApprovalConversionDialog> createState() => _ApprovalConversionDialogState();
}

class _ApprovalConversionDialogState extends State<_ApprovalConversionDialog> {
  late List<bool> _selectedItems;
  late List<TextEditingController> _pcsControllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.generate(widget.memo.items.length, (index) => true);
    _pcsControllers = List.generate(
      widget.memo.items.length,
      (idx) => TextEditingController(text: widget.memo.items[idx].pcs.toString()),
    );
  }

  @override
  void dispose() {
    for (var ctrl in _pcsControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convert Approval to Sale', style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Click the items that are converted to sale',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: _border, width: 1, borderRadius: BorderRadius.circular(4)),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(2),
                    5: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: _headerBg),
                      children: const [
                        Padding(padding: EdgeInsets.all(8.0), child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Tag ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Pcs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Net Wt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ...List.generate(widget.memo.items.length, (idx) {
                      final item = widget.memo.items[idx];
                      return TableRow(
                        children: [
                          Checkbox(
                            value: _selectedItems[idx],
                            activeColor: _brown,
                            onChanged: (val) {
                              setState(() {
                                _selectedItems[idx] = val ?? false;
                                if (_selectedItems[idx]) {
                                  _pcsControllers[idx].text = item.pcs.toString();
                                } else {
                                  _pcsControllers[idx].text = '0';
                                }
                              });
                            },
                          ),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(item.itemName, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(item.tagId, style: const TextStyle(fontSize: 12))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                            child: SizedBox(
                              height: 30,
                              child: TextFormField(
                                controller: _pcsControllers[idx],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  final numVal = int.tryParse(val.trim()) ?? 0;
                                  final originalPcs = item.pcs;
                                  if (numVal < 0) {
                                    _pcsControllers[idx].text = '0';
                                  } else if (numVal > originalPcs) {
                                    _pcsControllers[idx].text = originalPcs.toString();
                                  }
                                  
                                  final finalVal = int.tryParse(_pcsControllers[idx].text) ?? 0;
                                  setState(() {
                                    _selectedItems[idx] = finalVal > 0;
                                  });
                                },
                              ),
                            ),
                          ),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text('${item.netWeight.toStringAsFixed(3)} g', style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _brown)),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _brownLight)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _handleConvert,
          child: const Text('Convert to Sale'),
        ),
      ],
    );
  }

  void _handleConvert() async {
    final List<CustomerIssueReceiptItem> soldItems = [];
    final List<CustomerIssueReceiptItem> returnedItems = [];

    for (int i = 0; i < widget.memo.items.length; i++) {
      final item = widget.memo.items[i];
      final originalPcs = item.pcs;
      final enteredPcs = int.tryParse(_pcsControllers[i].text.trim()) ?? 0;

      if (enteredPcs <= 0) {
        returnedItems.add(item);
      } else if (enteredPcs >= originalPcs) {
        soldItems.add(item);
      } else {
        final soldPcs = enteredPcs;
        final returnedPcs = originalPcs - soldPcs;

        final avgGross = item.grossWeight / originalPcs;
        final avgNet = item.netWeight / originalPcs;
        final avgStone = item.stoneWeight / originalPcs;
        final avgAmount = item.amount / originalPcs;

        soldItems.add(CustomerIssueReceiptItem(
          tagId: item.tagId,
          itemName: item.itemName,
          metalType: item.metalType,
          purity: item.purity,
          grossWeight: avgGross * soldPcs,
          stoneWeight: avgStone * soldPcs,
          netWeight: avgNet * soldPcs,
          ratePerGram: item.ratePerGram,
          amount: avgAmount * soldPcs,
          makingCharges: item.makingCharges,
          deductionPercent: item.deductionPercent,
          photoUrls: item.photoUrls,
          remarks: item.remarks,
          branchId: item.branchId,
          pcs: soldPcs,
        ));

        returnedItems.add(CustomerIssueReceiptItem(
          tagId: item.tagId,
          itemName: item.itemName,
          metalType: item.metalType,
          purity: item.purity,
          grossWeight: avgGross * returnedPcs,
          stoneWeight: avgStone * returnedPcs,
          netWeight: avgNet * returnedPcs,
          ratePerGram: item.ratePerGram,
          amount: avgAmount * returnedPcs,
          makingCharges: item.makingCharges,
          deductionPercent: item.deductionPercent,
          photoUrls: item.photoUrls,
          remarks: item.remarks,
          branchId: item.branchId,
          pcs: returnedPcs,
        ));
      }
    }

    if (soldItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one piece to convert to sale.')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      // Fetch customer details for sales entry
      Map<String, dynamic>? customerDetails;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('customers')
            .where('name', isEqualTo: widget.memo.customerName)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          customerDetails = snap.docs.first.data();
        }
      } catch (e) {
        debugPrint("Error fetching customer details: $e");
      }

      final initialData = {
        'acName': widget.memo.customerName,
        'customerDetails': customerDetails,
        'narration': 'Converted from Approval Issue ${widget.memo.transactionNo}',
        'items': soldItems.map((item) {
          final orig = widget.memo.items.firstWhere(
            (x) => x.tagId.toUpperCase().trim() == item.tagId.toUpperCase().trim(),
            orElse: () => item,
          );
          return {
            'itemName': item.itemName,
            'tagId': item.tagId,
            'purity': item.purity.toString(),
            'grossWt': item.grossWeight,
            'othWt': item.stoneWeight,
            'netWeight': item.netWeight,
            'pcs': item.pcs,
            'rate': item.ratePerGram,
            'metalAmt': item.amount,
            'labourOn': 'Per Gram Net Wt',
            'labourRate': item.makingCharges,
            'othWtChecked': item.stoneWeight > 0,
            'extraCharges': [],
            'originalMemoPcs': orig.pcs,
          };
        }).toList(),
      };

      if (!mounted) return;
      Navigator.pop(context, {
        'soldItems': soldItems,
        'returnedItems': returnedItems,
        'initialData': initialData,
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    }
  }
}
