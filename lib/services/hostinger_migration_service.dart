import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'api_service.dart';

class HostingerMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _api = ApiService();

  Future<Map<String, int>> runFullMigration({
    Function(String status)? onProgress,
  }) async {
    final results = <String, int>{
      'categories': 0,
      'products': 0,
      'bills': 0,
      'vendor_issues': 0,
    };

    // 1. Migrate Masters (Categories, Materials, Units)
    onProgress?.call('Migrating categories and dropdown master values...');
    try {
      final collections = {
        'categories': 'category',
        'materials': 'material',
        'units': 'unit',
        'weight_units': 'weight_unit',
        'item_names': 'item_name',
      };

      for (final entry in collections.entries) {
        final snap = await _firestore.collection(entry.key).get();
        for (final doc in snap.docs) {
          final name = (doc.data()['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            await _api.addMasterItem(entry.value, name);
            results['categories'] = (results['categories'] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint('Error migrating master items: $e');
    }

    // 2. Migrate Products
    onProgress?.call('Migrating products & inventory from Firebase...');
    try {
      final productMap = <String, Product>{};

      // Check both collections
      for (final col in ['jewelry_inventory', 'products']) {
        final snap = await _firestore.collection(col).get();
        for (final doc in snap.docs) {
          try {
            final data = doc.data();
            final p = Product.fromJson(data);
            final tagId = p.tagId.trim().isEmpty ? doc.id : p.tagId;
            final updatedP = p.copyWith(tagId: tagId);
            productMap[tagId.trim().toLowerCase()] = updatedP;
          } catch (e) {
            debugPrint('Failed to parse product ${doc.id}: $e');
          }
        }
      }

      for (final p in productMap.values) {
        try {
          await _api.saveProduct(p);
          results['products'] = (results['products'] ?? 0) + 1;
        } catch (e) {
          debugPrint('Error saving product ${p.tagId} to Hostinger: $e');
        }
      }
    } catch (e) {
      debugPrint('Error migrating products: $e');
    }

    // 3. Migrate Bills
    onProgress?.call('Migrating sales bills and invoices...');
    try {
      final snap = await _firestore.collection('bills').get();
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final docId = doc.id;
          final billNo = (data['billNo'] ?? docId).toString();
          
          final billPayload = Map<String, dynamic>.from(data);
          billPayload['docId'] = docId;
          billPayload['billNo'] = billNo;

          // Convert Timestamp to ISO8601 string if present
          if (billPayload['billDate'] is Timestamp) {
            billPayload['billDate'] = (billPayload['billDate'] as Timestamp).toDate().toIso8601String();
          }

          await _api.createBill(billPayload);
          results['bills'] = (results['bills'] ?? 0) + 1;
        } catch (e) {
          debugPrint('Error saving bill ${doc.id} to Hostinger: $e');
        }
      }
    } catch (e) {
      debugPrint('Error migrating bills: $e');
    }

    // 4. Migrate Vendor Issues
    onProgress?.call('Migrating vendor issues...');
    try {
      final snap = await _firestore.collection('vendor_issues').get();
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final docId = doc.id;
          final issueDate = data['issueDate'];
          String dateStr = DateTime.now().toIso8601String();
          if (issueDate is Timestamp) {
            dateStr = issueDate.toDate().toIso8601String();
          }

          final payload = {
            'docId': docId,
            'vendorName': data['vendorName'] ?? '',
            'issueDate': dateStr,
            'status': data['status'] ?? 'Pending',
            'items': data['items'] ?? [],
            'totalAmount': data['totalAmount'] ?? 0.0,
            'notes': data['notes'] ?? '',
          };

          await _api.createVendorIssue(payload);
          results['vendor_issues'] = (results['vendor_issues'] ?? 0) + 1;
        } catch (e) {
          debugPrint('Error migrating vendor issue ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error migrating vendor issues: $e');
    }

    onProgress?.call('Migration complete!');
    return results;
  }
}
