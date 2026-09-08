import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_db_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncNow();
      }
    });
    
    // Try syncing immediately on startup
    syncNow();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  dynamic _parseTimestamps(dynamic item) {
    if (item is Map) {
      final newMap = <String, dynamic>{};
      item.forEach((key, value) {
        newMap[key] = _parseTimestamps(value);
      });
      return newMap;
    } else if (item is List) {
      return item.map((e) => _parseTimestamps(e)).toList();
    } else if (item is String && item.startsWith('Timestamp(seconds=')) {
      try {
        final secStr = item.split('seconds=')[1].split(',')[0];
        final seconds = int.tryParse(secStr) ?? 0;
        return Timestamp(seconds, 0);
      } catch (_) {
        return FieldValue.serverTimestamp();
      }
    }
    return item;
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final dbService = LocalDbService();
      final unsyncedEntries = await dbService.getUnsyncedEntries();

      for (var entry in unsyncedEntries) {
        String id = entry['id'];
        String collectionName = entry['collectionName'];
        String operation = entry['operation'] ?? 'ADD';
        String? docId = entry['docId'];
        
        // Deserialize and recursively parse stringified Timestamps
        Map<String, dynamic> data = jsonDecode(entry['data']);
        data = _parseTimestamps(data) as Map<String, dynamic>;
        
        // Add the server timestamp back before pushing to Firebase (overwriting the stringified ones)
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        try {
          if (operation == 'ADD') {
            await FirebaseFirestore.instance.collection(collectionName).add(data);
          } else if (operation == 'UPDATE' && docId != null) {
            await FirebaseFirestore.instance.collection(collectionName).doc(docId).update(data);
          } else if (operation == 'SET' && docId != null) {
            await FirebaseFirestore.instance.collection(collectionName).doc(docId).set(data, SetOptions(merge: true));
          } else if (operation == 'INVENTORY_DEDUCTION') {
            final String tagId = data['tagId'] ?? '';
            final String name = data['name'] ?? '';
            final int soldPcsToDeduct = data['soldPcsToDeduct'] ?? 0;

            if (soldPcsToDeduct > 0 && (tagId.isNotEmpty || name.isNotEmpty)) {
              List<DocumentSnapshot> docsToUpdate = [];
              if (tagId.isNotEmpty) {
                final docSnap = await FirebaseFirestore.instance
                    .collection('jewelry_inventory')
                    .doc(tagId.toUpperCase())
                    .get();
                if (docSnap.exists) {
                  docsToUpdate.add(docSnap);
                } else {
                  final snap = await FirebaseFirestore.instance
                      .collection('jewelry_inventory')
                      .where('tagId', isEqualTo: tagId)
                      .get();
                  docsToUpdate.addAll(snap.docs);
                }
              } else {
                final snap = await FirebaseFirestore.instance
                    .collection('jewelry_inventory')
                    .where('name', isEqualTo: name)
                    .get();
                docsToUpdate.addAll(snap.docs);
              }

              for (var doc in docsToUpdate) {
                final docData = doc.data() as Map<String, dynamic>?;
                if (docData == null) continue;
                final currentPcs = (docData['pcs'] as num?)?.toInt() ??
                    (docData['pieces'] as num?)?.toInt() ??
                    (docData['quantity'] as num?)?.toInt() ?? 1;

                int newPcs = currentPcs - soldPcsToDeduct;
                if (newPcs < 0) newPcs = 0;

                final updates = <String, dynamic>{
                  'pcs': newPcs,
                  'pieces': newPcs,
                  'quantity': newPcs,
                };

                if (newPcs <= 0) {
                  updates['productStatus'] = 'Out of stock';
                  updates['uploadInWebsite'] = false;
                  updates['inWebsite'] = false;
                  updates['isWebsiteVisible'] = false;
                }

                await doc.reference.update(updates);
              }
            }
          } else if (operation == 'AP_DEDUCTION') {
            final receiptNo = data['receiptNo'] ?? '';
            final usedInBillNo = data['usedInBillNo'] ?? '';
            
            if (receiptNo.isNotEmpty && usedInBillNo.isNotEmpty) {
              final querySnap = await FirebaseFirestore.instance
                  .collection('advance_payments')
                  .where('receiptNo', isEqualTo: receiptNo)
                  .get();
              for (final doc in querySnap.docs) {
                await doc.reference.update({
                  'status': 'USED',
                  'usedInBillNo': usedInBillNo,
                });
              }
            }
          }
          
          // Post-Sync Ledger Updates for Offline Cash/Bank Entries
          if (operation == 'ADD' || operation == 'UPDATE') {
            if (collectionName == 'cash_entries' || collectionName == 'bank_entries') {
              final bool isOfflineGenerated = data['voucherNo']?.toString().contains('-OFF') ?? false;
              if (isOfflineGenerated && data['rows'] is List) {
                final rows = List<Map<String, dynamic>>.from(data['rows']);
                
                // Pre-fetch all bills to match refNo
                final billsSnap = await FirebaseFirestore.instance.collection('bills').get();

                for (var r in rows) {
                  final ref = (r['refNo'] ?? '').toString().trim();
                  final partyName = (r['acName'] ?? '').toString().trim();
                  final double rowAmt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
                  
                  if (ref.isNotEmpty) {
                    for (var doc in billsSnap.docs) {
                      final d = doc.data();
                      final billNo = (d['voucherNo'] ?? d['billNo'] ?? d['invoiceNo'] ?? doc.id).toString().replaceAll('/', '-');
                      if (billNo == ref) {
                        final double currentPaid = double.tryParse(d['paidAmount']?.toString() ?? '0') ?? 0.0;
                        final double currentTotal = double.tryParse(d['totalAmt']?.toString() ?? d['grandTotal']?.toString() ?? '0') ?? 0.0;
                        final double newPaid = currentPaid + rowAmt;
                        final double newDue = (currentTotal - newPaid).clamp(0.0, double.infinity);
                        final String newStatus = newDue <= 0 ? 'PAID' : 'PARTIAL';
                        
                        await FirebaseFirestore.instance.collection('bills').doc(doc.id).update({
                          'paidAmount': newPaid,
                          'dueAmount': newDue,
                          'status': newStatus,
                          'lastPaymentDate': FieldValue.serverTimestamp(),
                        });
                        break;
                      }
                    }
                  }

                  if (partyName.isNotEmpty) {
                    // Update Customer
                    final custSnap = await FirebaseFirestore.instance.collection('customers').where('name', isEqualTo: partyName).get();
                    if (custSnap.docs.isNotEmpty) {
                      final doc = custSnap.docs.first;
                      final currentBal = double.tryParse(doc.data()['dueAmount']?.toString() ?? doc.data()['pendingBalance']?.toString() ?? '0') ?? 0.0;
                      final newBal = (currentBal - rowAmt).clamp(0.0, double.infinity);
                      await FirebaseFirestore.instance.collection('customers').doc(doc.id).update({
                        'dueAmount': newBal,
                        'pendingBalance': newBal,
                      });
                    } else {
                      // Update Supplier
                      final suppSnap = await FirebaseFirestore.instance.collection('suppliers').where('companyName', isEqualTo: partyName).get();
                      if (suppSnap.docs.isNotEmpty) {
                        final doc = suppSnap.docs.first;
                        final currentBal = double.tryParse(doc.data()['dueAmount']?.toString() ?? doc.data()['pendingBalance']?.toString() ?? '0') ?? 0.0;
                        final newBal = (currentBal - rowAmt).clamp(0.0, double.infinity);
                        await FirebaseFirestore.instance.collection('suppliers').doc(doc.id).update({
                          'dueAmount': newBal,
                          'pendingBalance': newBal,
                        });
                      }
                    }
                  }
                }
              }
            }
          }

          // Post-Sync Generic Inventory Updates for Offline Modules (Phase 3/4)
          if (operation == 'ADD' || operation == 'UPDATE') {
            if (data['inventoryUpdates'] is List) {
              final updates = List<Map<String, dynamic>>.from(data['inventoryUpdates']);
              
              for (var update in updates) {
                final String tagId = (update['tagId'] ?? '').toString().trim().toUpperCase();
                if (tagId.isEmpty) continue;
                
                final docRef = FirebaseFirestore.instance.collection('jewelry_inventory').doc(tagId);
                final docSnap = await docRef.get();
                
                if (docSnap.exists && docSnap.data() != null) {
                  final dbData = docSnap.data()!;
                  final int currentPcs = (dbData['pcs'] ?? dbData['pieces'] ?? dbData['quantity'] ?? 0) as int;
                  final int currentIssued = (dbData['issuedPcs'] ?? 0) as int;
                  
                  final int pcsDelta = (update['pcsDelta'] ?? 0) as int;
                  final int issuedPcsDelta = (update['issuedPcsDelta'] ?? 0) as int;
                  final String? setStatus = update['setStatus'] as String?;
                  
                  final int newPcs = currentPcs + pcsDelta;
                  final int newIssued = (currentIssued + issuedPcsDelta).clamp(0, 99999);
                  
                  final Map<String, dynamic> dbUpdate = {
                    'pcs': newPcs,
                    'pieces': newPcs,
                    'quantity': newPcs,
                    'issuedPcs': newIssued,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  
                  if (setStatus != null && setStatus.isNotEmpty) {
                    dbUpdate['status'] = setStatus;
                    dbUpdate['productStatus'] = setStatus;
                  }
                  
                  await docRef.update(dbUpdate);
                }
              }
            }

            // Post-Sync Generic Document Updates (for reverting/updating original memos, etc.)
            if (data['documentUpdates'] is List) {
              final docUpdates = List<Map<String, dynamic>>.from(data['documentUpdates']);
              for (var docUp in docUpdates) {
                final String collection = docUp['collection'] ?? '';
                final String docId = docUp['docId'] ?? '';
                final Map<String, dynamic> updateData = docUp['data'] ?? {};
                if (collection.isNotEmpty && docId.isNotEmpty && updateData.isNotEmpty) {
                  await FirebaseFirestore.instance.collection(collection).doc(docId).update(updateData);
                }
              }
            }

            // Post-Sync Generic Ledger Updates
            if (data['ledgerUpdates'] is List) {
              final ledgerUpdates = List<Map<String, dynamic>>.from(data['ledgerUpdates']);
              for (var ledger in ledgerUpdates) {
                await FirebaseFirestore.instance.collection('customer_ledger').add(ledger);
              }
            }

            // Post-Sync Generic Deletes
            if (data['documentDeletes'] is List) {
              final deletes = List<Map<String, dynamic>>.from(data['documentDeletes']);
              for (var del in deletes) {
                final String collection = del['collection'] ?? '';
                final String field = del['field'] ?? '';
                final dynamic isEqualTo = del['isEqualTo'];
                
                if (collection.isNotEmpty && field.isNotEmpty && isEqualTo != null) {
                  final snap = await FirebaseFirestore.instance.collection(collection).where(field, isEqualTo: isEqualTo).get();
                  for (var doc in snap.docs) {
                    await doc.reference.delete();
                  }
                }
              }
            }
          }

          // If successful, mark as synced
          await dbService.markAsSynced(id);
          debugPrint('Successfully synced entry: $id to $collectionName');
        } catch (e) {
          debugPrint('Failed to sync entry: $id. Error: $e');
          // We will retry on the next sync run
        }
      }
    } catch (e) {
      debugPrint('Sync process encountered an error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
