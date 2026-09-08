import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/product.dart';

/// Repository for all [jewelry_inventory] Firestore collection operations.
///
/// Follows the single-responsibility principle — no UI logic here.
/// All methods throw typed [FirebaseException] / [Exception] for the
/// ViewModel to handle and surface to the UI.
class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestore collection for product documents.
  static const String _kCollection = 'jewelry_inventory';

  // ─── Create ────────────────────────────────────────────────────────────────

  /// Saves a new product document to [jewelry_inventory] using the `productId` as the doc ID.
  ///
  /// Returns the generated or provided document ID on success.
  Future<String> saveProduct(Map<String, dynamic> data) async {
    final String docId = data['productId'] as String;
    if (docId.isEmpty) {
      final docRef = await _firestore.collection(_kCollection).add(data);
      return docRef.id;
    } else {
      await _firestore.collection(_kCollection).doc(docId).set(data);
      return docId;
    }
  }

  /// Saves a new jewelry item document to [jewelry_inventory] collection using `tagId` as the doc ID.
  Future<String> saveJewelryItem(Map<String, dynamic> data) async {
    final String docId = (data['tagId'] ?? data['productId'] ?? '') as String;
    if (docId.isEmpty) {
      final docRef = await _firestore.collection(_kCollection).add(data);
      return docRef.id;
    } else {
      await _firestore.collection(_kCollection).doc(docId).set(data, SetOptions(merge: true));
      return docId;
    }
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  /// Updates an existing product document identified by [docId].
  Future<void> updateProduct(String docId, Map<String, dynamic> data) async {
    await _firestore.collection(_kCollection).doc(docId).update(data);
  }

  /// Updates an existing jewelry item document identified by [docId].
  Future<void> updateJewelryItem(String docId, Map<String, dynamic> data) async {
    await _firestore.collection(_kCollection).doc(docId).set(data, SetOptions(merge: true));
  }

  /// Sets piece or standalone product status to 'Preserved' when issued in a transaction.
  Future<void> markPiecePreserved({
    required String tagId,
    required String transactionType,
    required String transactionNo,
  }) async {
    final cleanTag = tagId.trim().toUpperCase();
    if (cleanTag.isEmpty) return;

    final baseTag = getBaseTagId(cleanTag);
    final docRef = _firestore.collection(_kCollection).doc(baseTag);
    final docSnap = await docRef.get();

    if (!docSnap.exists || docSnap.data() == null) {
      final altRef = _firestore.collection(_kCollection).doc(cleanTag);
      final altSnap = await altRef.get();
      if (!altSnap.exists || altSnap.data() == null) return;
      await altRef.update({
        'status': 'Preserved',
        'productStatus': 'Preserved',
        'availablePcs': 0,
        'uploadInWebsite': false,
        'preservedReason': '$transactionType - $transactionNo',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = docSnap.data()!;
    List<Map<String, dynamic>> piecesList = [];
    if (data['pieces'] is List) {
      piecesList = List<Map<String, dynamic>>.from(
        (data['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
      );
    }

    if (piecesList.isNotEmpty) {
      bool found = false;
      for (int i = 0; i < piecesList.length; i++) {
        final pcTag = (piecesList[i]['tagId'] ?? '').toString().trim().toUpperCase();
        if (pcTag == cleanTag || (cleanTag == baseTag && !pcTag.contains('['))) {
          piecesList[i]['status'] = 'Preserved';
          piecesList[i]['issuedTo'] = transactionType;
          piecesList[i]['issueTxNo'] = transactionNo;
          piecesList[i]['issuedAt'] = DateTime.now().toIso8601String();
          found = true;
          break;
        }
      }
      if (!found && cleanTag == baseTag) {
        for (int i = 0; i < piecesList.length; i++) {
          if ((piecesList[i]['status'] ?? '').toString().toLowerCase() == 'available') {
            piecesList[i]['status'] = 'Preserved';
            piecesList[i]['issuedTo'] = transactionType;
            piecesList[i]['issueTxNo'] = transactionNo;
            piecesList[i]['issuedAt'] = DateTime.now().toIso8601String();
            break;
          }
        }
      }

      final int availableCount = piecesList.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'available').length;
      final updateData = <String, dynamic>{
        'pieces': piecesList,
        'availablePcs': availableCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (availableCount <= 0) {
        updateData['status'] = 'Preserved';
        updateData['productStatus'] = 'Preserved';
        updateData['uploadInWebsite'] = false;
      }
      await docRef.update(updateData);
    } else {
      await docRef.update({
        'status': 'Preserved',
        'productStatus': 'Preserved',
        'availablePcs': 0,
        'uploadInWebsite': false,
        'preservedReason': '$transactionType - $transactionNo',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Restores piece or standalone product status from 'Preserved' back to 'Available' when receipt is submitted / returned.
  Future<void> markPieceAvailable({
    required String tagId,
  }) async {
    final cleanTag = tagId.trim().toUpperCase();
    if (cleanTag.isEmpty) return;

    final baseTag = getBaseTagId(cleanTag);
    final docRef = _firestore.collection(_kCollection).doc(baseTag);
    final docSnap = await docRef.get();

    if (!docSnap.exists || docSnap.data() == null) {
      final altRef = _firestore.collection(_kCollection).doc(cleanTag);
      final altSnap = await altRef.get();
      if (!altSnap.exists || altSnap.data() == null) return;
      await altRef.update({
        'status': 'In Stock',
        'productStatus': 'Shop product',
        'availablePcs': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = docSnap.data()!;
    List<Map<String, dynamic>> piecesList = [];
    if (data['pieces'] is List) {
      piecesList = List<Map<String, dynamic>>.from(
        (data['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
      );
    }

    if (piecesList.isNotEmpty) {
      bool found = false;
      for (int i = 0; i < piecesList.length; i++) {
        final pcTag = (piecesList[i]['tagId'] ?? '').toString().trim().toUpperCase();
        if (pcTag == cleanTag || (cleanTag == baseTag && !pcTag.contains('['))) {
          piecesList[i]['status'] = 'Available';
          piecesList[i].remove('issuedTo');
          piecesList[i].remove('issueTxNo');
          piecesList[i].remove('issuedAt');
          found = true;
          break;
        }
      }
      if (!found && cleanTag == baseTag) {
        for (int i = 0; i < piecesList.length; i++) {
          if ((piecesList[i]['status'] ?? '').toString().toLowerCase() == 'preserved') {
            piecesList[i]['status'] = 'Available';
            piecesList[i].remove('issuedTo');
            piecesList[i].remove('issueTxNo');
            piecesList[i].remove('issuedAt');
            break;
          }
        }
      }

      final int availableCount = piecesList.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'available').length;
      final updateData = <String, dynamic>{
        'pieces': piecesList,
        'availablePcs': availableCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (availableCount > 0) {
        updateData['status'] = 'In Stock';
        updateData['productStatus'] = 'Shop product';
      }
      await docRef.update(updateData);
    } else {
      await docRef.update({
        'status': 'In Stock',
        'productStatus': 'Shop product',
        'availablePcs': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Marks a specific piece or standalone product as 'Sold' when billed.
  Future<void> markPieceSold({
    required String tagId,
    String? billNo,
  }) async {
    final cleanTag = tagId.trim().toUpperCase();
    if (cleanTag.isEmpty) return;

    final baseTag = getBaseTagId(cleanTag);
    final docRef = _firestore.collection(_kCollection).doc(baseTag);
    final docSnap = await docRef.get();

    if (!docSnap.exists || docSnap.data() == null) {
      final altRef = _firestore.collection(_kCollection).doc(cleanTag);
      final altSnap = await altRef.get();
      if (!altSnap.exists || altSnap.data() == null) return;
      await altRef.update({
        'status': 'Sold',
        'productStatus': 'Out of stock',
        'availablePcs': 0,
        'uploadInWebsite': false,
        'inWebsite': false,
        'isWebsiteVisible': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = docSnap.data()!;
    List<Map<String, dynamic>> piecesList = [];
    if (data['pieces'] is List) {
      piecesList = List<Map<String, dynamic>>.from(
        (data['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
      );
    }

    if (piecesList.isNotEmpty) {
      bool found = false;
      for (int i = 0; i < piecesList.length; i++) {
        final pcTag = (piecesList[i]['tagId'] ?? '').toString().trim().toUpperCase();
        if (pcTag == cleanTag || (cleanTag == baseTag && !pcTag.contains('['))) {
          piecesList[i]['status'] = 'Sold';
          piecesList[i]['soldAt'] = DateTime.now().toIso8601String();
          if (billNo != null) piecesList[i]['billNo'] = billNo;
          piecesList[i].remove('issuedTo');
          piecesList[i].remove('issueTxNo');
          piecesList[i].remove('issuedAt');
          found = true;
          break;
        }
      }
      if (!found && cleanTag == baseTag) {
        for (int i = 0; i < piecesList.length; i++) {
          final s = (piecesList[i]['status'] ?? '').toString().toLowerCase();
          if (s == 'available' || s == 'preserved') {
            piecesList[i]['status'] = 'Sold';
            piecesList[i]['soldAt'] = DateTime.now().toIso8601String();
            if (billNo != null) piecesList[i]['billNo'] = billNo;
            piecesList[i].remove('issuedTo');
            piecesList[i].remove('issueTxNo');
            piecesList[i].remove('issuedAt');
            break;
          }
        }
      }

      final int availableCount = piecesList.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'available').length;
      final updateData = <String, dynamic>{
        'pieces': piecesList,
        'availablePcs': availableCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (availableCount <= 0) {
        final bool hasPreserved = piecesList.any((p) => (p['status'] ?? '').toString().toLowerCase() == 'preserved');
        updateData['status'] = hasPreserved ? 'Preserved' : 'Out of stock';
        updateData['productStatus'] = hasPreserved ? 'Preserved' : 'Out of stock';
        updateData['uploadInWebsite'] = false;
        updateData['inWebsite'] = false;
        updateData['isWebsiteVisible'] = false;
      }
      await docRef.update(updateData);
    } else {
      await docRef.update({
        'status': 'Sold',
        'productStatus': 'Out of stock',
        'availablePcs': 0,
        'uploadInWebsite': false,
        'inWebsite': false,
        'isWebsiteVisible': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Fetches unique label prefixes from the [item_prefixes] master collection.
  Future<List<String>> getUniqueLabelPrefixes() async {
    final snapshot = await _firestore
        .collection('item_prefixes')
        .orderBy('createdAt', descending: false)
        .get();
    final seen = <String>{};
    final list = <String>[];
    for (final doc in snapshot.docs) {
      final prefix = doc.data()['prefix']?.toString().trim();
      if (prefix != null && prefix.isNotEmpty && seen.add(prefix)) {
        list.add(prefix);
      }
    }
    return list;
  }

  /// Fetches unique item names from item_names_master and item_prefixes collections.
  /// Note: Website product names in jewelry_inventory are kept separate.
  Future<List<String>> getUniqueItemNames() async {
    final seen = <String>{};
    final list = <String>[];

    void addName(String? name) {
      if (name != null) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty && seen.add(trimmed.toUpperCase())) {
          list.add(trimmed);
        }
      }
    }

    try {
      final snapMaster = await _firestore.collection('item_names_master').get();
      for (final doc in snapMaster.docs) {
        addName(doc.data()['name']?.toString());
      }
    } catch (_) {}

    try {
      final snapPrefixes = await _firestore.collection('item_prefixes').get();
      for (final doc in snapPrefixes.docs) {
        addName(doc.data()['itemName']?.toString());
      }
    } catch (_) {}

    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Saves a new item name to [item_names_master] collection if it doesn't already exist.
  Future<void> saveItemName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final existing = await getUniqueItemNames();
    if (existing.any((e) => e.toUpperCase() == trimmed.toUpperCase())) return;

    await _firestore.collection('item_names_master').add({
      'name': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches unique supplier codes from [suppliers] collection.
  Future<List<String>> getUniqueSupplierCodes() async {
    final snapshot = await _firestore
        .collection('suppliers')
        .get();
    final seen = <String>{};
    final list = <String>[];
    for (final doc in snapshot.docs) {
      final code = doc.data()['supplierCode']?.toString().trim();
      if (code != null && code.isNotEmpty && seen.add(code)) {
        list.add(code);
      }
    }
    list.sort();
    return list;
  }

  /// Saves a new supplier code to [supplier_codes_master] collection.
  Future<void> saveSupplierCode(String code) async {
    await _firestore.collection('supplier_codes_master').add({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an item name from [item_names_master] collection.
  Future<void> deleteItemName(String name) async {
    final snapshot = await _firestore
        .collection('item_names_master')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Deletes a supplier code from [supplier_codes_master] collection.
  Future<void> deleteSupplierCode(String code) async {
    final snapshot = await _firestore
        .collection('supplier_codes_master')
        .where('code', isEqualTo: code)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches custom metal groups from the [metal_groups_master] collection.
  Future<List<Map<String, String>>> getUniqueMetalGroups() async {
    final snapshot = await _firestore
        .collection('metal_groups_master')
        .orderBy('createdAt', descending: false)
        .get();
    final list = <Map<String, String>>[];
    for (final doc in snapshot.docs) {
      final metalId = doc.data()['metalId']?.toString().trim() ?? '';
      final groupName = doc.data()['groupName']?.toString().trim() ?? '';
      final linkedRateId = doc.data()['linkedRateId']?.toString().trim() ?? '';
      if (metalId.isNotEmpty && groupName.isNotEmpty) {
        list.add({
          'metalId': metalId,
          'groupName': groupName,
          if (linkedRateId.isNotEmpty) 'linkedRateId': linkedRateId,
        });
      }
    }
    return list;
  }

  /// Saves a new metal group to [metal_groups_master] collection.
  Future<void> saveMetalGroup(String metalId, String groupName, {String? linkedRateId}) async {
    await _firestore.collection('metal_groups_master').add({
      'metalId': metalId,
      'groupName': groupName,
      if (linkedRateId != null && linkedRateId.isNotEmpty) 'linkedRateId': linkedRateId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a metal group from [metal_groups_master] collection.
  Future<void> deleteMetalGroup(String metalId, String groupName) async {
    final snapshot = await _firestore
        .collection('metal_groups_master')
        .where('metalId', isEqualTo: metalId)
        .where('groupName', isEqualTo: groupName)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches unique extra style names from [extra_styles_master] collection.
  Future<List<String>> getUniqueExtraStyles() async {
    final snapshot = await _firestore
        .collection('extra_styles_master')
        .orderBy('createdAt', descending: false)
        .get();
    final seen = <String>{};
    final list = <String>[];
    for (final doc in snapshot.docs) {
      final name = doc.data()['name']?.toString().trim();
      if (name != null && name.isNotEmpty && seen.add(name)) {
        list.add(name);
      }
    }
    // Ensure all 8 default styles exist in the backend
    final defaults = [
      'Less Wt',
      'Black Beads',
      'Extra Charges',
      'Hallmark Charge',
      'Kedia',
      'Mani/Moti',
      'Rodium Charges',
      'diamond'
    ];
    for (final d in defaults) {
      if (!seen.contains(d)) {
        await saveExtraStyle(d);
        list.add(d);
        seen.add(d);
      }
    }
    return list;
  }

  /// Saves a new extra style name to [extra_styles_master] collection.
  Future<void> saveExtraStyle(String name) async {
    await _firestore.collection('extra_styles_master').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an extra style name from [extra_styles_master] collection.
  Future<void> deleteExtraStyle(String name) async {
    final snapshot = await _firestore
        .collection('extra_styles_master')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches unique salesman names from [salesman_master] collection.
  Future<List<String>> getUniqueSalesmen() async {
    final snapshot = await _firestore
        .collection('salesman_master')
        .orderBy('createdAt', descending: false)
        .get();
    final seen = <String>{};
    final list = <String>[];
    for (final doc in snapshot.docs) {
      final name = doc.data()['name']?.toString().trim();
      if (name != null && name.isNotEmpty && seen.add(name)) {
        list.add(name);
      }
    }
    if (list.isEmpty) {
      final defaults = ['Staff 1', 'Staff 2', 'Staff 3', 'Admin'];
      for (final d in defaults) {
        await saveSalesman(d);
        list.add(d);
      }
    }
    return list;
  }

  /// Saves a new salesman name to [salesman_master] collection.
  Future<void> saveSalesman(String name) async {
    await _firestore.collection('salesman_master').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a salesman name from [salesman_master] collection.
  Future<void> deleteSalesman(String name) async {
    final snapshot = await _firestore
        .collection('salesman_master')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches unique counter names from [counter_master] collection.
  Future<List<String>> getUniqueCounters() async {
    final snapshot = await _firestore
        .collection('counter_master')
        .orderBy('createdAt', descending: false)
        .get();
    final seen = <String>{};
    final list = <String>[];
    for (final doc in snapshot.docs) {
      final name = doc.data()['name']?.toString().trim();
      if (name != null && name.isNotEmpty && seen.add(name)) {
        list.add(name);
      }
    }
    if (list.isEmpty) {
      final defaults = ['C1', 'C2', 'C3', 'C4', 'C5'];
      for (final d in defaults) {
        await saveCounter(d);
        list.add(d);
      }
    }
    return list;
  }

  /// Saves a new counter name to [counter_master] collection.
  Future<void> saveCounter(String name) async {
    await _firestore.collection('counter_master').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a counter name from [counter_master] collection.
  Future<void> deleteCounter(String name) async {
    final snapshot = await _firestore
        .collection('counter_master')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Builds the [searchKeywords] list from a product name.
  ///
  /// Strategy: lowercase the name, split on spaces, and accumulate
  /// prefix substrings for each word so partial searches work.
  ///
  /// Example: "Gold Ring" → ["g","go","gol","gold","r","ri","rin","ring","gold ring"]
  static List<String> buildSearchKeywords(String productName) {
    final name = productName.toLowerCase().trim();
    final keywords = <String>{};

    // Add individual word prefixes
    for (final word in name.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }

    // Add full name and full-name prefixes
    for (int i = 1; i <= name.length; i++) {
      keywords.add(name.substring(0, i));
    }

    return keywords.toList()..sort();
  }

  /// Builds the complete Firestore document map from all form fields.
  ///
  /// [productId] — the Tag ID entered by the user (used as the logical ID).
  /// [adminEmail] — the currently logged-in admin's email, stored as
  ///                [createdBy] / [updatedBy] (never null for an admin session).
  static Map<String, dynamic> buildProductDocument({
    required String productId,
    required String productName,
    required String category,
    required String subCategory,
    required String description,
    required String status,
    // Metal
    required String metalColor,
    required List<String> metalTypes,
    required List<String> goldPurities,
    required String roseGoldPurity,
    required List<String> silverColorOptions,
    // Media — already uploaded URLs
    required List<String> productImages,
    required String arExperienceImage,
    required String view360Video,
    // Custom specs
    required List<Map<String, dynamic>> customSpecifications,
    // Labour
    required List<Map<String, dynamic>> labourCost,
    // Pricing
    required double basePrice,
    required bool enableDynamicPrice,
    Map<String, dynamic>? priceBreakdown,
    // Weights & Diamonds
    required double grossWeight,
    required double netWeight,
    required int diamondPieceCount,
    required double diamondWeight,
    required String diamondClarity,
    required String diamondColor,
    // Metadata
    required String adminEmail,
    // Timestamps injected externally so they can be overridden in tests
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    final now = Timestamp.now();

    final metalsToSave = <String>[];
    final puritiesToSave = <String>[];

    if (metalTypes.contains('Gold')) {
      final sortedPurities = List<String>.from(goldPurities)
        ..sort((a, b) {
          const order = {'14K': 1, '18K': 2, '22K': 3};
          return (order[a] ?? 99).compareTo(order[b] ?? 99);
        });
      final formatted = sortedPurities.map((p) => p.toLowerCase().replaceAll('k', 'kt')).toList();
      if (formatted.isNotEmpty) {
        metalsToSave.add('Gold (${formatted.join(', ')})');
      } else {
        metalsToSave.add('Gold');
      }
      puritiesToSave.addAll(sortedPurities);
    }
    if (metalTypes.contains('Rose Gold')) {
      metalsToSave.add('Rose Gold');
      if (!puritiesToSave.contains('18K')) {
        puritiesToSave.add('18K');
      }
    }
    if (metalTypes.contains('Silver')) {
      if (silverColorOptions.isNotEmpty) {
        metalsToSave.add('Silver (${silverColorOptions.join(', ')})');
      } else {
        metalsToSave.add('Silver');
      }
      if (!puritiesToSave.contains('Silver')) {
        puritiesToSave.add('Silver');
      }
    }
    if (metalTypes.contains('Platinum')) {
      metalsToSave.add('Platinum');
      if (!puritiesToSave.contains('Platinum')) {
        puritiesToSave.add('Platinum');
      }
    }

    return {
      // ── Basic Information ─────────────────────────────────────────────────
      'productId': productId,
      'productName': productName,
      'name': productName, // for compatibility with React
      'category': category,
      'subCategory': subCategory,
      'description': description,
      'status': status,
      'createdAt': createdAt ?? now,
      'updatedAt': updatedAt ?? now,

      // ── Metal Attributes ──────────────────────────────────────────────────
      'metalColor': metalColor,
      'metals': metalsToSave,
      'metalTypes': metalTypes,
      'purities': puritiesToSave,
      'goldPurities': goldPurities,
      'roseGoldPurity': roseGoldPurity,
      'silverColorOptions': silverColorOptions,

      // ── Media ─────────────────────────────────────────────────────────────
      'productImages': productImages,
      'images': productImages, // compatibility
      'arImageUrl': arExperienceImage,
      'video360Url': view360Video,

      // ── Custom Specifications ─────────────────────────────────────────────
      'customSpecifications': customSpecifications,
      'customSpecs': customSpecifications.fold<Map<String, String>>({}, (map, spec) {
        final title = spec['title']?.toString() ?? spec['label']?.toString() ?? '';
        final val = spec['value']?.toString() ?? '';
        if (title.isNotEmpty) map[title] = val;
        return map;
      }),

      // ── Labour Costing ────────────────────────────────────────────────────
      'labourCost': labourCost,

      // ── Pricing ───────────────────────────────────────────────────────────
      'basePrice': basePrice,
      'price': basePrice, // compatibility with React
      'enableDynamicPrice': enableDynamicPrice,
      'usePriceBreakdown': enableDynamicPrice, // compatibility with React
      'priceBreakdown': priceBreakdown,

      // ── Weights & Diamonds ────────────────────────────────────────────────
      'grossWeight': grossWeight,
      'grossWt': grossWeight, // for compatibility
      'netWeight': netWeight,
      'netWt': netWeight, // for compatibility
      'diamondWeight': diamondWeight,
      'diamondWt': diamondWeight, // for compatibility
      'diamondClarity': diamondClarity,
      'diamondColor': diamondColor,

      // ── Search ────────────────────────────────────────────────────────────
      'searchKeywords': buildSearchKeywords(productName),

      // ── Metadata ──────────────────────────────────────────────────────────
      'createdBy': adminEmail,
      'updatedBy': adminEmail,
    };
  }
}
