import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/connectivity_helper.dart';
import '../models/product.dart';
import '../models/live_rate.dart';
import '../models/item.dart';

import '../services/live_rate_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminState extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicConnTimer;

  // ── Debounce notifyListeners so rapid Firestore events batch into one rebuild ──
  Timer? _debounceTimer;
  void _debouncedNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), notifyListeners);
  }

  // Static definitions for Diamond Rates table
  static const List<String> clarities = ['IF', 'VVS', 'VS', 'SI', 'I'];
  
  static const Map<String, List<String>> colorGroups = {
    'Colorless': ['D-E', 'E-F'],
    'Near Colorless': ['G-H', 'I-J'],
    'Faint': ['K-L', 'L-M'],
    'Very Light': ['N-O', 'O-P', 'P-Q', 'Q-R'],
    'Light': ['S-T', 'U-V', 'W-X', 'Y-Z'],
  };

  static List<String> get colorRanges => 
      colorGroups.values.expand((element) => element).toList();

  // Live Rates Map
  final Map<String, LiveRate> _liveRates = {
    'gold_24k_trading': LiveRate(id: 'gold_24k_trading', name: 'Gold-24 Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.999),
    'gold_22k_jewellery': LiveRate(id: 'gold_22k_jewellery', name: 'GOLD 22KT JEWELLERY', description: '', ratePerGram: 0.0, purityFineness: 0.916),
    'gold_18k_jewellery': LiveRate(id: 'gold_18k_jewellery', name: 'GOLD 18KT JEWELLERY', description: '', ratePerGram: 0.0, purityFineness: 0.750),
    'old_gold_trading': LiveRate(id: 'old_gold_trading', name: 'Old Gold Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.916),
    'repairing_sample_gold': LiveRate(id: 'repairing_sample_gold', name: 'REPAIRING/SAMPLE (GOLD)', description: '', ratePerGram: 0.0, purityFineness: 0.916),
    'diamond_18k_jewellery': LiveRate(id: 'diamond_18k_jewellery', name: 'DIAMOND 18KT JEWELLERY', description: '', ratePerGram: 0.0, purityFineness: 0.750),
    'diamond_22k_jewellery': LiveRate(id: 'diamond_22k_jewellery', name: 'DIAMOND 22KT JEWELLERY', description: '', ratePerGram: 0.0, purityFineness: 0.916),
    'diamond_trading': LiveRate(id: 'diamond_trading', name: 'Diamond Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.999),
    'stone_trading': LiveRate(id: 'stone_trading', name: 'Stone Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.999),
    'pure_silver_trading': LiveRate(id: 'pure_silver_trading', name: 'Pure Silver Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.999),
    'old_silver_trading': LiveRate(id: 'old_silver_trading', name: 'Old Silver Trading A/c.', description: '', ratePerGram: 0.0, purityFineness: 0.999),
    'silver_925': LiveRate(id: 'silver_925', name: 'SILVER 925', description: '', ratePerGram: 0.0, purityFineness: 0.925),
    'platinum': LiveRate(id: 'platinum', name: 'PLATINUM', description: '', ratePerGram: 0.0, purityFineness: 0.950),
    'old_platinum': LiveRate(id: 'old_platinum', name: 'OLD PLATINUM', description: '', ratePerGram: 0.0, purityFineness: 0.950),
    'alloys': LiveRate(id: 'alloys', name: 'ALLOYS', description: '', ratePerGram: 0.0, purityFineness: 1.0),
  };

  // Diamond Rates Map: key is "CLARITY_COLOR-RANGE" (e.g. "IF_D-E")
  final Map<String, double> _diamondRates = {};

  // Products — separate raw maps per Firestore collection to avoid double-merge cost
  final Map<String, Product> _jewelryInventoryMap = {};
  final Map<String, Product> _productsMap = {};
  List<Product> _productsList = [];

  /// Tombstone set — tagIds deleted by the user in this session.
  /// Prevents Firestore stream events from re-inserting a product that was
  /// already deleted but whose deletion is still propagating across both
  /// collections (race condition between two async deletes).
  final Set<String> _deletedTagIds = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LiveRateService _liveRateService = LiveRateService();

  LiveRatesData get currentLiveRatesData {
    final Map<String, Map<String, double>> nestedRates = {};
    for (var clarity in clarities) {
      nestedRates[clarity] = {};
      for (var color in colorRanges) {
        nestedRates[clarity]![color] = _diamondRates['${clarity}_$color'] ?? 0.0;
      }
    }
    return LiveRatesData(
      gold24KTrading: _liveRates['gold_24k_trading']?.ratePerGram ?? 0.0,
      gold22KJewellery: _liveRates['gold_22k_jewellery']?.ratePerGram ?? 0.0,
      gold18KJewellery: _liveRates['gold_18k_jewellery']?.ratePerGram ?? 0.0,
      oldGoldTrading: _liveRates['old_gold_trading']?.ratePerGram ?? 0.0,
      repairingSampleGold: _liveRates['repairing_sample_gold']?.ratePerGram ?? 0.0,
      diamond18KJewellery: _liveRates['diamond_18k_jewellery']?.ratePerGram ?? 0.0,
      diamond22KJewellery: _liveRates['diamond_22k_jewellery']?.ratePerGram ?? 0.0,
      diamondTrading: _liveRates['diamond_trading']?.ratePerGram ?? 0.0,
      stoneTrading: _liveRates['stone_trading']?.ratePerGram ?? 0.0,
      pureSilverTrading: _liveRates['pure_silver_trading']?.ratePerGram ?? 0.0,
      oldSilverTrading: _liveRates['old_silver_trading']?.ratePerGram ?? 0.0,
      silver925: _liveRates['silver_925']?.ratePerGram ?? 0.0,
      platinum: _liveRates['platinum']?.ratePerGram ?? 0.0,
      oldPlatinum: _liveRates['old_platinum']?.ratePerGram ?? 0.0,
      alloys: _liveRates['alloys']?.ratePerGram ?? 0.0,
      diamondRates: nestedRates,
    );
  }

  void notifyDropdownsUpdated() {
    notifyListeners();
  }

  // Search and Filters
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Statuses';

  // Statuses
  final List<String> _statuses = [
    'All Statuses',
    'Website product',
    'Shop product',
    'Yet to add',
  ];

  // Default devotional-store categories (merged with dynamic Firestore categories in getter)
  final List<String> _categories = [
    'Idols', 'Pooja Thali Sets', 'Lamps/Vilakku', 'Incense/Agarbathi',
    'Camphor', 'Oil/Ghee', 'Bells', 'Kalasam', 'Religious Books',
    'Silver/Brass Items', 'Decorative Items', 'Festival Specials', 'Others',
  ];

  // 'categories' getter is defined below with dynamic merge (line ~279)
  List<String> get statuses => _statuses;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedStatus => _selectedStatus;

  void updateStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  // Filtered Products
  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch =
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.tagId.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          product.category.toUpperCase() == _selectedCategory.toUpperCase();

      final matchesStatus = _selectedStatus == 'All Statuses' ||
          _selectedStatus == 'All Products' ||
          product.status.toLowerCase() == _selectedStatus.toLowerCase();

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  Product? lookupProduct(String tagId) {
    final clean = tagId.trim();
    if (clean.isEmpty) return null;

    final query = clean.toLowerCase();

    for (final p in _products) {
      if (p.tagId.trim().toLowerCase() == query) {
        return p;
      }
    }

    return null;
  }

  AdminState() {
    // Initialize diamond rates to 0.0
    for (var clarity in clarities) {
      for (var range in colorRanges) {
        _diamondRates['${clarity}_$range'] = 0.0;
      }
    }
    _listenToLiveRates();
    fetchProducts();
    fetchMetalGroups();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final bool online = await ConnectivityHelper.isOnline();
      if (_isOnline != online) {
        _isOnline = online;
        notifyListeners(); // connectivity changes are infrequent — OK to notify directly
      }
    });

    ConnectivityHelper.isOnline().then((online) {
      if (_isOnline != online) {
        _isOnline = online;
        notifyListeners();
      }
    });

    // Periodic check every 30s (was 10s) — stored so it can be cancelled on dispose
    _periodicConnTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final bool online = await ConnectivityHelper.isOnline();
        if (_isOnline != online) {
          _isOnline = online;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicConnTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Metal Groups
  List<MetalGroup> _customMetalGroups = [];
  List<MetalGroup> get customMetalGroups => _customMetalGroups.isEmpty ? MetalGroup.predefined : _customMetalGroups;

  Future<void> fetchMetalGroups() async {
    try {
      _firestore.collection('metal_groups_master').snapshots().listen((snapshot) {
        _customMetalGroups = snapshot.docs.map((doc) {
          final data = doc.data();
          return MetalGroup(
            metalId: data['metalId']?.toString().trim() ?? '',
            groupName: data['groupName']?.toString().trim() ?? '',
            linkedRateId: data['linkedRateId']?.toString().trim(),
          );
        }).where((m) => m.metalId.isNotEmpty).toList();
        _debouncedNotify(); // debounced — metal group updates are background events
      });
    } catch (e) {
      debugPrint('Error fetching metal groups: $e');
    }
  }

  /// Fetches the current live rate for a given metalId dynamically by looking up its linkedRateId.
  double getRateForMetalId(String metalId) {
    try {
      final group = customMetalGroups.firstWhere((g) => g.metalId == metalId);
      final linkedId = group.linkedRateId;
      if (linkedId != null && linkedId.isNotEmpty) {
        return _liveRates[linkedId]?.ratePerGram ?? 0.0;
      }
    } catch (_) {
      // Ignore if not found
    }
    return 0.0;
  }

  // ─── Merged products list ──────────────────────────────────────────────────

  List<Product> get _products {
    final Map<String, Product> deduped = {};
    for (var p in _productsList) {
      final key = p.tagId.trim().toLowerCase();
      // Skip products that have been locally deleted (tombstone guard)
      if (key.isNotEmpty && !_deletedTagIds.contains(key)) {
        deduped[key] = p;
      }
    }
    return deduped.values.toList();
  }

  /// Public accessor — applies tombstone filtering so views get clean list.
  List<Product> get products => _products;

  final List<String> _dynamicCategories = [];

  List<String> get categories {
    final set = <String>{
      'All Categories',
      ..._categories.where((c) => c != 'All Categories'),
      ..._dynamicCategories,
      ..._products.map((p) => p.category).where((c) => c.isNotEmpty)
    };
    return set.toList();
  }

  void addCategory(String newCat) {
    final trimmed = newCat.trim();
    if (trimmed.isNotEmpty && !_dynamicCategories.contains(trimmed)) {
      _dynamicCategories.add(trimmed);
      try {
        _firestore.collection('categories').add({'name': trimmed, 'createdAt': FieldValue.serverTimestamp()});
      } catch (_) {}
      notifyListeners();
    }
  }

  // ─── Fetch from collections (both jewelry_inventory & products) ──────────

  Future<void> fetchProducts() async {
    try {
      // 1. Fetch categories
      _firestore.collection('categories').snapshots().listen((snap) {
        for (var doc in snap.docs) {
          final name = doc.data()['name']?.toString() ?? '';
          if (name.isNotEmpty && !_dynamicCategories.contains(name)) {
            _dynamicCategories.add(name);
          }
        }
        _debouncedNotify();
      });

      // 2. Listen to jewelry_inventory — updates separate raw map
      _firestore.collection('jewelry_inventory').snapshots().listen((snapshot) {
        _parseDocsIntoMap(snapshot.docs, _jewelryInventoryMap);
        _rebuildProductsList();
      });

      // 3. Listen to products collection — updates separate raw map
      _firestore.collection('products').snapshots().listen((snapshot) {
        _parseDocsIntoMap(snapshot.docs, _productsMap);
        _rebuildProductsList();
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  /// Parse docs into a dedicated map (per collection) without merging immediately.
  void _parseDocsIntoMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Product> targetMap,
  ) {
    for (final doc in docs) {
      try {
        final data = doc.data();
        final p = Product.fromJson(data);
        final tagId = p.tagId.trim().isEmpty ? doc.id : p.tagId;
        final updatedP = p.copyWith(tagId: tagId);
        if (_isMeaningfulProduct(updatedP)) {
          targetMap[tagId.trim().toLowerCase()] = updatedP;
        }
      } catch (e) {
        debugPrint('Error parsing doc ${doc.id}: $e');
      }
    }
  }

  /// Rebuild the flat products list by merging both collection maps, then debounce notify.
  void _rebuildProductsList() {
    final merged = <String, Product>{};
    // jewelry_inventory wins over products if same tagId
    merged.addAll(_productsMap);
    merged.addAll(_jewelryInventoryMap);
    _productsList = merged.entries
        .where((e) => !_deletedTagIds.contains(e.key))
        .map((e) => e.value)
        .toList();
    _debouncedNotify();
  }

  // _parseAndMergeProducts removed — replaced by _parseDocsIntoMap + _rebuildProductsList

  /// Returns true only for products that have at least a name OR a category
  /// OR a non-zero gross weight. This filters out ghost/orphan Firestore
  /// documents that were created with default/empty values.
  static bool _isMeaningfulProduct(Product p) {
    final hasName = p.name.trim().isNotEmpty;
    final hasCategory = p.category.trim().isNotEmpty;
    final hasWeight = p.grossWeight > 0;
    final hasTagId = p.tagId.trim().isNotEmpty;
    return hasTagId && (hasName || hasCategory || hasWeight);
  }



  List<String> _pendingEstimationTags = [];
  List<String> get pendingEstimationTags => _pendingEstimationTags;
  String? autoOpenAddEntrySection;
  bool autoOpenEstimation = false;
  bool autoOpenAddItem = false;
  bool navigatedFromHomeShortcut = false;
  int? requestedTabIndex;

  void requestNavigateToTab(int tabIndex) {
    requestedTabIndex = tabIndex;
    notifyListeners();
  }

  void setPendingEstimationTags(List<String> tags) {
    _pendingEstimationTags = tags;
    notifyListeners();
  }

  void clearPendingEstimationTags() {
    _pendingEstimationTags = [];
  }

  // Getters
  List<String> get allTagIds => _products.map((p) => p.tagId).toList();
  List<LiveRate> get liveRatesList => _liveRates.values.toList();
  Map<String, LiveRate> get liveRates => _liveRates;
  Map<String, double> get diamondRates => _diamondRates;

  // Analytics Metrics
  int get totalProductsCount => _products.length;
  int get totalStockQuantity => _products.fold(0, (sum, p) => sum + p.quantity);
  int get availableProductsCount =>
      _products.where((p) => p.status != 'Sold Out' && p.status != 'Discontinued' && p.quantity > 0).length;
  int get lowStockCount => _products.where((p) => p.isLowStock).length;
  int get totalCategoriesUsed =>
      _products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().length;

  Map<String, double> get totalWeightBasedStock {
    final Map<String, double> weightByMaterial = {};
    for (var p in _products) {
      if (p.pricingType == 'Weight-Based' && p.status.toLowerCase() == 'in stock') {
        weightByMaterial[p.material] = (weightByMaterial[p.material] ?? 0.0) + p.grossWeight;
      }
    }
    return weightByMaterial;
  }

  int get totalQuantityBasedStock {
    return _products
        .where((p) => p.pricingType == 'Quantity-Based' && p.status.toLowerCase() != 'sold out' && p.status.toLowerCase() != 'discontinued')
        .fold(0, (total, p) => total + p.quantity);
  }

  // Actions
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void _listenToLiveRates() {
    _liveRateService.getLiveRatesStream().listen((rates) async {
      // Initialize doc with our local default values if not present
      if (rates.gold24KTrading == 0.0 && rates.gold22KJewellery == 0.0 && rates.gold18KJewellery == 0.0 && rates.pureSilverTrading == 0.0) {
        final Map<String, Map<String, double>> nestedRates = {};
        for (var clarity in clarities) {
          nestedRates[clarity] = {};
          for (var color in colorRanges) {
            nestedRates[clarity]![color] = _diamondRates['${clarity}_$color'] ?? 0.0;
          }
        }
        final initialData = LiveRatesData(
          gold24KTrading: _liveRates['gold_24k_trading']?.ratePerGram ?? 0.0,
          gold22KJewellery: _liveRates['gold_22k_jewellery']?.ratePerGram ?? 0.0,
          gold18KJewellery: _liveRates['gold_18k_jewellery']?.ratePerGram ?? 0.0,
          oldGoldTrading: _liveRates['old_gold_trading']?.ratePerGram ?? 0.0,
          repairingSampleGold: _liveRates['repairing_sample_gold']?.ratePerGram ?? 0.0,
          diamond18KJewellery: _liveRates['diamond_18k_jewellery']?.ratePerGram ?? 0.0,
          diamond22KJewellery: _liveRates['diamond_22k_jewellery']?.ratePerGram ?? 0.0,
          diamondTrading: _liveRates['diamond_trading']?.ratePerGram ?? 0.0,
          stoneTrading: _liveRates['stone_trading']?.ratePerGram ?? 0.0,
          pureSilverTrading: _liveRates['pure_silver_trading']?.ratePerGram ?? 0.0,
          oldSilverTrading: _liveRates['old_silver_trading']?.ratePerGram ?? 0.0,
          silver925: _liveRates['silver_925']?.ratePerGram ?? 0.0,
          platinum: _liveRates['platinum']?.ratePerGram ?? 0.0,
          oldPlatinum: _liveRates['old_platinum']?.ratePerGram ?? 0.0,
          alloys: _liveRates['alloys']?.ratePerGram ?? 0.0,
          diamondRates: nestedRates,
        );
        await _firestore.collection('settings').doc('rates').set(initialData.toDocMap(), SetOptions(merge: true));
        return;
      }

      // Clean up legacy documents if they exist
      try {
        await _firestore.collection('live_rates').doc('current_rates').delete();
        await _firestore.collection('live_rates').doc('metals').delete();
        await _firestore.collection('live_rates').doc('diamonds').delete();
      } catch (_) {}

      // Unpack values
      _liveRates['gold_24k_trading'] = _liveRates['gold_24k_trading']!.copyWith(ratePerGram: rates.gold24KTrading);
      _liveRates['gold_22k_jewellery'] = _liveRates['gold_22k_jewellery']!.copyWith(ratePerGram: rates.gold22KJewellery);
      _liveRates['gold_18k_jewellery'] = _liveRates['gold_18k_jewellery']!.copyWith(ratePerGram: rates.gold18KJewellery);
      _liveRates['old_gold_trading'] = _liveRates['old_gold_trading']!.copyWith(ratePerGram: rates.oldGoldTrading);
      _liveRates['repairing_sample_gold'] = _liveRates['repairing_sample_gold']!.copyWith(ratePerGram: rates.repairingSampleGold);
      _liveRates['diamond_18k_jewellery'] = _liveRates['diamond_18k_jewellery']!.copyWith(ratePerGram: rates.diamond18KJewellery);
      _liveRates['diamond_22k_jewellery'] = _liveRates['diamond_22k_jewellery']!.copyWith(ratePerGram: rates.diamond22KJewellery);
      _liveRates['diamond_trading'] = _liveRates['diamond_trading']!.copyWith(ratePerGram: rates.diamondTrading);
      _liveRates['stone_trading'] = _liveRates['stone_trading']!.copyWith(ratePerGram: rates.stoneTrading);
      _liveRates['pure_silver_trading'] = _liveRates['pure_silver_trading']!.copyWith(ratePerGram: rates.pureSilverTrading);
      _liveRates['old_silver_trading'] = _liveRates['old_silver_trading']!.copyWith(ratePerGram: rates.oldSilverTrading);
      _liveRates['silver_925'] = _liveRates['silver_925']!.copyWith(ratePerGram: rates.silver925);
      _liveRates['platinum'] = _liveRates['platinum']!.copyWith(ratePerGram: rates.platinum);
      _liveRates['old_platinum'] = _liveRates['old_platinum']!.copyWith(ratePerGram: rates.oldPlatinum);
      _liveRates['alloys'] = _liveRates['alloys']!.copyWith(ratePerGram: rates.alloys);

      for (var clarity in clarities) {
        for (var color in colorRanges) {
          final clarityMap = rates.diamondRates[clarity];
          _diamondRates['${clarity}_$color'] = clarityMap?[color] ?? 0.0;
        }
      }

      // NOTE: _persistCalculationsToFirestore() removed from here.
      // It was causing N+1 Firestore writes on every rate stream event.
      // Recalculations are persisted only when the user explicitly saves rates
      // via updateMultipleLiveRates() or updateDiamondRates().
      _debouncedNotify();
    });
  }

  // _persistCalculationsToFirestore removed (was causing N+1 Firestore writes
  // on every live-rate stream event). Rates are persisted only when the user
  // explicitly calls updateMultipleLiveRates() or updateDiamondRates().

  Future<void> updateLiveRate(String id, double newRate) async {
    await updateMultipleLiveRates({id: newRate});
  }

  Future<void> updateMultipleLiveRates(Map<String, double> ratesMap) async {
    const fieldMap = {
      'gold_24k_trading': 'gold24KTrading',
      'gold_22k_jewellery': 'gold22KJewellery',
      'gold_18k_jewellery': 'gold18KJewellery',
      'old_gold_trading': 'oldGoldTrading',
      'repairing_sample_gold': 'repairingSampleGold',
      'diamond_18k_jewellery': 'diamond18KJewellery',
      'diamond_22k_jewellery': 'diamond22KJewellery',
      'diamond_trading': 'diamondTrading',
      'stone_trading': 'stoneTrading',
      'pure_silver_trading': 'pureSilverTrading',
      'old_silver_trading': 'oldSilverTrading',
      'silver_925': 'silver925',
      'platinum': 'platinum',
      'old_platinum': 'oldPlatinum',
      'alloys': 'alloys',
    };

    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    ratesMap.forEach((id, newRate) {
      final String field = fieldMap[id] ?? '';
      if (field.isNotEmpty) {
        updates[field] = newRate;
        if (field == 'gold22KJewellery') {
          updates['gold22'] = newRate;
        } else if (field == 'gold18KJewellery') {
          updates['gold18'] = newRate;
        } else if (field == 'pureSilverTrading') {
          updates['silver'] = newRate;
        }
        if (_liveRates.containsKey(id)) {
          _liveRates[id] = _liveRates[id]!.copyWith(ratePerGram: newRate);
        }
      }
    });

    notifyListeners();

    if (updates.length > 1) {
      await _firestore.collection('settings').doc('rates').update(updates);
    }
  }

  Future<void> updateDiamondRates(Map<String, double> newRates) async {
    // Merge newRates into current _diamondRates first
    newRates.forEach((key, val) {
      _diamondRates[key] = val;
    });

    final Map<String, Map<String, double>> nestedRates = {};
    for (var clarity in clarities) {
      nestedRates[clarity] = {};
      for (var color in colorRanges) {
        nestedRates[clarity]![color] = _diamondRates['${clarity}_$color'] ?? 0.0;
      }
    }

    await _firestore.collection('settings').doc('rates').update({
      'diamondRates': nestedRates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addProduct(Product product) async {
    final Map<String, dynamic> json = product.toJson();

    if (product.tagId.isNotEmpty) {
      _deletedTagIds.remove(product.tagId.trim().toLowerCase());
    }

    final docId = product.tagId.trim().isNotEmpty
        ? product.tagId.trim()
        : _firestore.collection('jewelry_inventory').doc().id;
    final updatedJson = Map<String, dynamic>.from(json);
    updatedJson['tagId'] = docId;

    await _firestore.collection('jewelry_inventory').doc(docId).set(updatedJson, SetOptions(merge: true));
    await _firestore.collection('products').doc(docId).set(updatedJson, SetOptions(merge: true));

    // Local update
    final updatedProduct = product.copyWith(tagId: docId);
    final key = docId.toLowerCase();
    _jewelryInventoryMap[key] = updatedProduct;
    _productsMap[key] = updatedProduct;
    _productsList.removeWhere((p) => p.tagId.toLowerCase() == key);
    _productsList.add(updatedProduct);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final Map<String, dynamic> json = product.toJson();
    final docId = product.tagId.trim();

    await _firestore.collection('jewelry_inventory').doc(docId).set(json, SetOptions(merge: true));
    await _firestore.collection('products').doc(docId).set(json, SetOptions(merge: true));

    final key = docId.toLowerCase();
    _jewelryInventoryMap[key] = product;
    _productsMap[key] = product;
    final idx = _productsList.indexWhere((p) => p.tagId.toLowerCase() == key);
    if (idx != -1) {
      _productsList[idx] = product;
    } else {
      _productsList.add(product);
    }
    notifyListeners();
  }


  Future<void> deleteProduct(String tagId) async {
    String localGetBaseTagId(String id) {
      final match = RegExp(r'^(.+?)\[\d+\]$').firstMatch(id.trim());
      if (match != null) {
        return match.group(1)!.trim();
      }
      return id.trim();
    }

    final baseTag = localGetBaseTagId(tagId).trim().toLowerCase();
    final List<String> tagsToDelete = [];

    for (final p in _productsList) {
      final pBase = localGetBaseTagId(p.tagId).trim().toLowerCase();
      if (pBase == baseTag) {
        tagsToDelete.add(p.tagId);
      }
    }

    if (!tagsToDelete.contains(tagId)) {
      tagsToDelete.add(tagId);
    }

    for (final id in tagsToDelete) {
      final normId = id.trim().toLowerCase();
      _deletedTagIds.add(normId);
      _jewelryInventoryMap.remove(normId);
      _productsMap.remove(normId);
      _productsList.removeWhere(
        (p) => p.tagId.trim().toLowerCase() == normId,
      );
    }
    notifyListeners();

    for (final id in tagsToDelete) {
      try {
        await _firestore.collection('jewelry_inventory').doc(id).delete();
        await _firestore.collection('products').doc(id).delete();

        // Also query by tagId field in case docId was auto-generated
        final snap1 = await _firestore
            .collection('jewelry_inventory')
            .where('tagId', isEqualTo: id)
            .get();
        for (final doc in snap1.docs) {
          await doc.reference.delete();
        }

        final snap2 = await _firestore
            .collection('products')
            .where('tagId', isEqualTo: id)
            .get();
        for (final doc in snap2.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting product: $e');
      }
    }
  }


  Future<void> fetchAndSaveCloudinaryUrls() async {
    // 1. YOUR CLOUDINARY CREDENTIALS
    // Go to your Cloudinary dashboard to get these!
    final String apiKey = '851329936937915'; 
    final String apiSecret = 'sN8DF0_krnj59GZZCXllsJsdgew';
    final String cloudName = 'df9pn9xey'; 

    try {
      debugPrint("Starting to fetch images from Cloudinary...");
      
      // 2. FETCH FROM CLOUDINARY
      final String basicAuth = 'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/resources/image?max_results=500');
      
      final response = await http.get(uri, headers: {'Authorization': basicAuth});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List resources = data['resources'];
        
        debugPrint("Found ${resources.length} images! Uploading to Firebase...");
        
        // 3. CREATE FIELD AND UPDATE IN FIREBASE
        for (var res in resources) {
          String imageUrl = res['secure_url'];
          
          // This creates a new collection called 'existing_cloudinary_media' 
          // and saves the URL in a field named 'url'
          await _firestore.collection('existing_cloudinary_media').add({
            'url': imageUrl,
            'format': res['format'],
            'created_at': res['created_at'],
          });
        }
        
        debugPrint("SUCCESS: All URLs saved to Firebase!");
      } else {
        debugPrint("Failed to fetch from Cloudinary: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error syncing images: $e");
    }
  }
}

