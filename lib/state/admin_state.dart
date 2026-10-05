import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/connectivity_helper.dart';
import '../models/product.dart';
import '../models/live_rate.dart';
import '../models/item.dart';
import '../models/vendor_issue.dart';

import '../services/live_rate_service.dart';
import '../services/api_service.dart';


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

  List<String> _issueTypes = [
    'Damaged', 'Defective', 'Wrong Item Sent', 'Quality Issue', 'Broken in Transit', 'Other'
  ];
  List<String> get issueTypes => _issueTypes;

  Future<void> fetchIssueTypes() async {
    try {
      final res = await ApiService().getSetting('vendor_issue_types');
      if (res is List) {
        _issueTypes = List<String>.from(res);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching issue types: $e");
    }
  }

  Future<void> updateIssueTypes(List<String> newTypes) async {
    try {
      await ApiService().saveSetting('vendor_issue_types', newTypes);
      _issueTypes = newTypes;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating issue types: $e");
    }
  }

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
    fetchIssueTypes();
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
      final res = await ApiService().getSetting('metal_groups_master');
      if (res is List) {
        _customMetalGroups = res.map((d) {
          final data = Map<String, dynamic>.from(d as Map);
          return MetalGroup(
            metalId: data['metalId']?.toString().trim() ?? '',
            groupName: data['groupName']?.toString().trim() ?? '',
            linkedRateId: data['linkedRateId']?.toString().trim(),
          );
        }).where((m) => m.metalId.isNotEmpty).toList();
        notifyListeners();
      }
    } catch (_) {}
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
    final list = deduped.values.toList();
    list.sort((a, b) => _compareTags(a.tagId, b.tagId));
    return list;
  }

  static int _compareTags(String a, String b) {
    final matchA = RegExp(r'^([a-zA-Z\-_]*)\s*(\d+)?(.*)$').firstMatch(a.trim());
    final matchB = RegExp(r'^([a-zA-Z\-_]*)\s*(\d+)?(.*)$').firstMatch(b.trim());
    if (matchA != null && matchB != null) {
      final prefixA = matchA.group(1)?.toLowerCase() ?? '';
      final prefixB = matchB.group(1)?.toLowerCase() ?? '';
      if (prefixA != prefixB) {
        return prefixA.compareTo(prefixB);
      }
      final numA = int.tryParse(matchA.group(2) ?? '');
      final numB = int.tryParse(matchB.group(2) ?? '');
      if (numA != null && numB != null && numA != numB) {
        return numA.compareTo(numB);
      }
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  /// Public accessor — applies tombstone filtering so views get clean list.
  List<Product> get products => _products;

  final List<String> _dynamicCategories = [];
  final List<String> _dynamicMaterials = [];
  final List<String> _dynamicUnits = [];
  final List<String> _dynamicWeightUnits = [];
  final List<String> _dynamicItemNames = [];
  final List<String> _dynamicVendors = [];

  final Set<String> _deletedCategories = {};
  final Set<String> _deletedMaterials = {};
  final Set<String> _deletedUnits = {};
  final Set<String> _deletedWeightUnits = {};
  final Set<String> _deletedItemNames = {};
  final Set<String> _deletedVendors = {};

  final List<String> _defaultMaterials = [
    'Brass', 'Silver', 'Panchaloha', 'Wood', 'Clay', 'Marble', 'Plastic/Steel', 'N/A'
  ];
  final List<String> _defaultUnits = ['Piece', 'Set', 'Pair', 'Box', 'Packet'];
  final List<String> _defaultWeightUnits = ['g', 'kg', 'mg', 'carat'];
  final List<String> _defaultItemNames = [
    'Ganesh Idol',
    'Lakshmi Idol',
    'Saraswati Idol',
    'Murugan Idol',
    'Krishna Idol',
    'Shiva Parvathi Idol',
    'Hanuman Idol',
    'Diya / Vilakku',
    'Kamatchi Vilakku',
    'Annam Vilakku',
    'Pooja Thali Set',
    'Agarbathi Stand',
    'Dhoop / Sambrani Stand',
    'Bell / Ghanti',
    'Kalasam',
    'Chowki / Peeta',
    'Panchapatra Udharani',
    'Photo Frame',
    'Hanging Diya',
    'Kumkum Box',
  ];

  List<String> get categories {
    final set = <String>{
      'All Categories',
      ..._categories.where((c) => c != 'All Categories'),
      ..._dynamicCategories,
      ..._products.map((p) => p.category).where((c) => c.isNotEmpty)
    };
    return set.where((c) => !_deletedCategories.contains(c) || c == 'All Categories').toList();
  }

  List<String> get materials {
    final set = <String>{
      ..._defaultMaterials,
      ..._dynamicMaterials,
      ..._products.map((p) => p.material).where((m) => m.isNotEmpty)
    };
    return set.where((m) => !_deletedMaterials.contains(m)).toList();
  }

  List<String> get units {
    final set = <String>{
      ..._defaultUnits,
      ..._dynamicUnits,
      ..._products.map((p) => p.unit).where((u) => u.isNotEmpty)
    };
    return set.where((u) => !_deletedUnits.contains(u)).toList();
  }

  List<String> get weightUnits {
    final set = <String>{
      ..._defaultWeightUnits,
      ..._dynamicWeightUnits,
      ..._products.map((p) => p.weightUnit).where((u) => u.isNotEmpty)
    };
    return set.where((u) => !_deletedWeightUnits.contains(u)).toList();
  }

  List<String> get itemNames {
    final set = <String>{
      ..._defaultItemNames,
      ..._dynamicItemNames,
      ..._products.map((p) => p.name.trim()).where((n) => n.isNotEmpty)
    };
    final list = set.where((n) => !_deletedItemNames.contains(n)).toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get vendors {
    final set = <String>{
      ..._dynamicVendors,
      ..._products.map((p) => p.vendor.trim()).where((v) => v.isNotEmpty)
    };
    final list = set.where((v) => !_deletedVendors.contains(v)).toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }



  void addCategory(String newCat) {
    final trimmed = newCat.trim();
    if (trimmed.isNotEmpty) {
      _deletedCategories.remove(trimmed);
      if (!_dynamicCategories.contains(trimmed)) {
        _dynamicCategories.add(trimmed);
        try {
          ApiService().addMasterItem('categories', trimmed);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> renameCategory(String oldCat, String newCat) async {
    final oldTrimmed = oldCat.trim();
    final newTrimmed = newCat.trim();
    if (newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    _deletedCategories.remove(newTrimmed);
    _deletedCategories.add(oldTrimmed);
    _dynamicCategories.remove(oldTrimmed);
    if (!_dynamicCategories.contains(newTrimmed)) {
      _dynamicCategories.add(newTrimmed);
    }
    notifyListeners();
    try {
      await ApiService().addMasterItem('categories', newTrimmed);
    } catch (_) {}
  }

  Future<void> deleteCategory(String cat) async {
    final trimmed = cat.trim();
    _dynamicCategories.remove(trimmed);
    _deletedCategories.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('categories', trimmed); } catch (_) {}
  }

  void addMaterial(String newMat) {
    final trimmed = newMat.trim();
    if (trimmed.isNotEmpty) {
      _deletedMaterials.remove(trimmed);
      if (!_dynamicMaterials.contains(trimmed)) {
        _dynamicMaterials.add(trimmed);
        try {
          ApiService().addMasterItem('materials', trimmed);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> renameMaterial(String oldMat, String newMat) async {
    final oldTrimmed = oldMat.trim();
    final newTrimmed = newMat.trim();
    if (newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    _deletedMaterials.remove(newTrimmed);
    _deletedMaterials.add(oldTrimmed);
    _dynamicMaterials.remove(oldTrimmed);
    if (!_dynamicMaterials.contains(newTrimmed)) {
      _dynamicMaterials.add(newTrimmed);
    }
    notifyListeners();
    try {
      await ApiService().addMasterItem('materials', newTrimmed);
    } catch (_) {}
  }

  Future<void> deleteMaterial(String mat) async {
    final trimmed = mat.trim();
    _dynamicMaterials.remove(trimmed);
    _deletedMaterials.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('materials', trimmed); } catch (_) {}
  }

  void addVendor(String newVendor) {
    final trimmed = newVendor.trim();
    if (trimmed.isNotEmpty) {
      _deletedVendors.remove(trimmed);
      if (!_dynamicVendors.contains(trimmed)) {
        _dynamicVendors.add(trimmed);
        try {
          ApiService().addMasterItem('vendors', trimmed);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> renameVendor(String oldVendor, String newVendor) async {
    final oldTrimmed = oldVendor.trim();
    final newTrimmed = newVendor.trim();
    if (newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;
    _deletedVendors.remove(newTrimmed);
    _deletedVendors.add(oldTrimmed);
    _dynamicVendors.remove(oldTrimmed);
    if (!_dynamicVendors.contains(newTrimmed)) {
      _dynamicVendors.add(newTrimmed);
    }
    notifyListeners();
    try {
      await ApiService().addMasterItem('vendors', newTrimmed);
    } catch (_) {}
  }

  Future<void> deleteVendor(String vendor) async {
    final trimmed = vendor.trim();
    _dynamicVendors.remove(trimmed);
    _deletedVendors.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('vendors', trimmed); } catch (_) {}
  }

  void addUnit(String newUnit) {
    final trimmed = newUnit.trim();
    if (trimmed.isNotEmpty) {
      _deletedUnits.remove(trimmed);
      if (!_dynamicUnits.contains(trimmed)) {
        _dynamicUnits.add(trimmed);
        try {
          ApiService().addMasterItem('units', trimmed);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> renameUnit(String oldUnit, String newUnit) async {
    final oldTrimmed = oldUnit.trim();
    final newTrimmed = newUnit.trim();
    if (newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    _deletedUnits.remove(newTrimmed);
    _deletedUnits.add(oldTrimmed);
    _dynamicUnits.remove(oldTrimmed);
    if (!_dynamicUnits.contains(newTrimmed)) {
      _dynamicUnits.add(newTrimmed);
    }
    notifyListeners();
    try {
      await ApiService().addMasterItem('units', newTrimmed);
    } catch (_) {}
  }

  Future<void> deleteUnit(String unit) async {
    final trimmed = unit.trim();
    _dynamicUnits.remove(trimmed);
    _deletedUnits.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('units', trimmed); } catch (_) {}
  }

  Future<void> addWeightUnit(String unit) async {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) return;
    if (!_defaultWeightUnits.contains(trimmed)) {
      _deletedWeightUnits.remove(trimmed);
      if (!_dynamicWeightUnits.contains(trimmed)) {
        _dynamicWeightUnits.add(trimmed);
        try {
          ApiService().addMasterItem('weight_units', trimmed);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> updateWeightUnit(String oldUnit, String newUnit) async {
    final oldTrimmed = oldUnit.trim();
    final newTrimmed = newUnit.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    if (!_defaultWeightUnits.contains(newTrimmed)) {
      _deletedWeightUnits.remove(newTrimmed);
      _deletedWeightUnits.add(oldTrimmed);
      _dynamicWeightUnits.remove(oldTrimmed);
      if (!_dynamicWeightUnits.contains(newTrimmed)) {
        _dynamicWeightUnits.add(newTrimmed);
      }
      notifyListeners();
      try {
        await ApiService().addMasterItem('weight_units', newTrimmed);
      } catch (_) {}
    }
  }

  Future<void> deleteWeightUnit(String unit) async {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) return;
    _dynamicWeightUnits.remove(trimmed);
    _deletedWeightUnits.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('weight_units', trimmed); } catch (_) {}
  }

  void addItemName(String newName) {
    final trimmed = newName.trim();
    if (trimmed.isNotEmpty) {
      _deletedItemNames.remove(trimmed);
      if (!_dynamicItemNames.contains(trimmed)) {
        _dynamicItemNames.add(trimmed);
        try {
          ApiService().addMasterItem('item_names', trimmed);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> renameItemName(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    _deletedItemNames.remove(newTrimmed);
    _deletedItemNames.add(oldTrimmed);
    _dynamicItemNames.remove(oldTrimmed);
    if (!_dynamicItemNames.contains(newTrimmed)) {
      _dynamicItemNames.add(newTrimmed);
    }
    notifyListeners();
    try {
      await ApiService().addMasterItem('item_names', newTrimmed);
    } catch (_) {}
  }

  Future<void> deleteItemName(String name) async {
    final trimmed = name.trim();
    _dynamicItemNames.remove(trimmed);
    _deletedItemNames.add(trimmed);
    notifyListeners();
    try { await ApiService().deleteMasterItem('item_names', trimmed); } catch (_) {}
  }

  // ─── Fetch from collections (both jewelry_inventory & products) ──────────

  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;

  Future<void> fetchProducts() async {
    _isLoadingProducts = true;
    notifyListeners();

    try {
      debugPrint('[AdminState] Fetching products from Hostinger...');
      final hostingerProducts = await ApiService().getProducts();
      debugPrint('[AdminState] Got ${hostingerProducts.length} products from API');
      _productsList = hostingerProducts;
      _productsMap.clear();
      _jewelryInventoryMap.clear();
      for (final p in hostingerProducts) {
        _productsMap[p.tagId.toLowerCase()] = p;
      }
    } catch (e) {
      debugPrint('[AdminState] fetchProducts error: $e');
    } finally {
      _isLoadingProducts = false;
    }

    try {
      final cats = await ApiService().getMasterItems('categories');
      for (final c in cats) {
        if (!_deletedCategories.contains(c) && !_dynamicCategories.contains(c)) {
          _dynamicCategories.add(c);
        }
      }
      final mats = await ApiService().getMasterItems('materials');
      for (final m in mats) {
        if (!_deletedMaterials.contains(m) && !_dynamicMaterials.contains(m)) {
          _dynamicMaterials.add(m);
        }
      }
      final vends = await ApiService().getMasterItems('vendors');
      for (final v in vends) {
        if (!_deletedVendors.contains(v) && !_dynamicVendors.contains(v)) {
          _dynamicVendors.add(v);
        }
      }
    } catch (e) {
      debugPrint('[AdminState] fetchMasterItems error: $e');
    }

    _debouncedNotify();
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
  int get totalStockQuantity => _products.fold(0, (total, p) => total + p.quantity);
  int get availableProductsCount =>
      _products.where((p) => p.status != 'Sold Out' && p.status != 'Discontinued' && p.quantity > 0).length;
  int get lowStockCount => _products.where((p) => p.isLowStock).length;
  int get outOfStockCount => _products.where((p) => p.isOutOfStock).length;
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
    ratesMap.forEach((id, newRate) {
      if (_liveRates.containsKey(id)) {
        _liveRates[id] = _liveRates[id]!.copyWith(ratePerGram: newRate);
      }
    });

    notifyListeners();

    try {
      final data = currentLiveRatesData.toDocMap();
      await ApiService().saveSetting('rates', data);
    } catch (e) {
      debugPrint("Error saving live rates: $e");
    }
  }

  Future<void> updateDiamondRates(Map<String, double> newRates) async {
    newRates.forEach((key, val) {
      _diamondRates[key] = val;
    });

    notifyListeners();

    try {
      final data = currentLiveRatesData.toDocMap();
      await ApiService().saveSetting('rates', data);
    } catch (e) {
      debugPrint("Error saving diamond rates: $e");
    }
  }

  Future<void> addProduct(Product product) async {
    final docId = product.tagId.trim().isNotEmpty
        ? product.tagId.trim()
        : 'TAG_${DateTime.now().millisecondsSinceEpoch}';

    final updatedProduct = product.copyWith(tagId: docId);

    try {
      await ApiService().saveProduct(updatedProduct);
    } catch (e) {
      debugPrint('Hostinger saveProduct error: $e');
    }

    final key = docId.toLowerCase();
    _jewelryInventoryMap[key] = updatedProduct;
    _productsMap[key] = updatedProduct;
    _productsList.removeWhere((p) => p.tagId.toLowerCase() == key);
    _productsList.add(updatedProduct);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    try {
      await ApiService().updateProduct(product);
    } catch (e) {
      debugPrint('Hostinger updateProduct error: $e');
    }

    final key = product.tagId.trim().toLowerCase();
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
        await ApiService().deleteProduct(id);
      } catch (e) {
        debugPrint('Hostinger deleteProduct error: $e');
      }
    }
  }

  Future<void> logVendorIssue(VendorIssue issue) async {
    try {
      final docId = 'VI-${DateTime.now().millisecondsSinceEpoch}';
      // Build a payload matching what vendor_issues.php expects
      final payload = {
        'docId': docId,
        'vendorName': issue.vendor,
        'status': issue.actionTaken,
        'totalAmount': issue.refundAmount,
        'notes': issue.notes,
        'issueDate': issue.dateReported.toIso8601String(),
        'items': [
          {
            'tagId': issue.tagId,
            'productName': issue.productName,
            'qty': issue.quantity,
            'quantity': issue.quantity,
            'issueType': issue.issueType,
            'actionTaken': issue.actionTaken,
            'refundAmount': issue.refundAmount,
            'photoUrl': issue.photoUrl,
          }
        ],
      };
      await ApiService().createVendorIssue(payload);
    } catch (e) {
      debugPrint("Error logging vendor issue: $e");
    }

    final product = lookupProduct(issue.tagId);
    if (product != null) {
      final newQty = (product.quantity - issue.quantity).clamp(0, 999999);
      final newIssueQty = product.issueQuantity + issue.quantity;

      String newStatus;
      if (newQty == 0) {
        newStatus = 'Out of Stock';
      } else if (newQty < 5) {
        newStatus = 'Low Stock';
      } else {
        newStatus = 'In Stock';
      }

      final updatedProduct = product.copyWith(
        quantity: newQty,
        issueQuantity: newIssueQty,
        status: newStatus,
      );
      await updateProduct(updatedProduct);
    }
  }

  Future<void> updateVendorIssueAction(String issueId, String tagId, String newAction) async {
    try {
      // Fetch current issue to get previousAction and quantity
      final allIssues = await ApiService().getVendorIssues();
      final issueMap = allIssues.firstWhere(
        (m) => m['id']?.toString() == issueId || m['docId']?.toString() == issueId,
        orElse: () => <String, dynamic>{},
      );
      if (issueMap.isEmpty) return;

      final issueData = VendorIssue.fromJson(issueMap, id: issueId);
      final previousAction = issueData.actionTaken;
      if (previousAction == newAction) return;

      await ApiService().updateVendorIssue(issueId, {'status': newAction});

      final product = lookupProduct(tagId);
      if (product != null) {
        int newQty = product.quantity;
        int newIssueQty = product.issueQuantity;

        if (newAction == 'Replacement Received' && previousAction != 'Replacement Received') {
          newQty += issueData.quantity;
          newIssueQty = (newIssueQty - issueData.quantity).clamp(0, 999999);
        } else if (previousAction == 'Replacement Received' && newAction != 'Replacement Received') {
          newQty = (newQty - issueData.quantity).clamp(0, 999999);
          newIssueQty += issueData.quantity;
        } else if ((newAction == 'Returned to Vendor' || newAction == 'Refund Received' || newAction == 'Discarded') &&
                   (previousAction == 'Pending' || previousAction == 'Damaged/Defective')) {
          newIssueQty = (newIssueQty - issueData.quantity).clamp(0, 999999);
        } else if ((newAction == 'Pending' || newAction == 'Damaged/Defective') &&
                   (previousAction == 'Returned to Vendor' || previousAction == 'Refund Received' || previousAction == 'Discarded')) {
          newIssueQty += issueData.quantity;
        }

        String newStatus;
        if (newQty == 0) {
          newStatus = 'Out of Stock';
        } else if (newQty < 5) {
          newStatus = 'Low Stock';
        } else {
          newStatus = 'In Stock';
        }

        final updatedProduct = product.copyWith(
          quantity: newQty,
          issueQuantity: newIssueQty,
          status: newStatus,
        );
        await updateProduct(updatedProduct);
      }
    } catch (e) {
      debugPrint("Error updating vendor issue action: $e");
    }
  }

  Future<void> processCustomerReturn({
    required String originalBillNo,
    required String customerName,
    required String customerMobile,
    required String returnReason,
    required double totalRefund,
    required String paymentMode,
    required List<Map<String, dynamic>> items,
  }) async {
    String nextId = 'RT-001';
    try {
      final bills = await ApiService().getBills();
      final returnBills = bills.where((d) => d['billType'] == 'Return').toList();
      if (returnBills.isNotEmpty) {
        final lastId = returnBills.first['billNo'] as String? ?? '';
        final match = RegExp(r'\d+').firstMatch(lastId);
        if (match != null) {
          final val = int.tryParse(match.group(0)!) ?? 0;
          nextId = 'RT-${(val + 1).toString().padLeft(3, '0')}';
        }
      }
    } catch (e) {
      debugPrint("Error generating return bill no: $e");
    }

    final updatedItems = items.map((i) => {...i, 'originalBillNo': originalBillNo}).toList();

    final billData = {
      'billNo': nextId,
      'originalBillNo': originalBillNo, // Might be dropped by backend
      'billType': 'Return',
      'customerName': customerName,
      'customerMobile': customerMobile,
      'billDate': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'items': updatedItems, // Safely stored as JSON by backend
      'totalPayable': totalRefund,
      'returnReason': returnReason,
      'returnStatus': 'Processed',
      'paymentMode': paymentMode,
      'narration': 'Return for $originalBillNo',
    };

    await ApiService().createBill(billData);

    for (final item in items) {
      final tagId = item['tagId'];
      final qty = (item['qty'] as num).toInt();
      final condition = item['condition'] as String;

      final product = lookupProduct(tagId);
      if (product != null) {
        // Only add back to inventory if condition is Good
        if (condition.toLowerCase() == 'good') {
          final newQty = product.quantity + qty;
          String newStatus;
          if (newQty == 0) {
            newStatus = 'Out of Stock';
          } else if (newQty < 5) {
            newStatus = 'Low Stock';
          } else {
            newStatus = 'In Stock';
          }
          
          await updateProduct(product.copyWith(
            quantity: newQty,
            status: newStatus,
          ));
        } else {
          // If defective, do not add back to sellable inventory.
          // It is already logged as an issue in the return bill.
        }
        
        if (condition == 'Defective') {
          final issue = VendorIssue(
             id: '',
             tagId: product.tagId,
             productName: product.name,
             vendor: product.vendor,
             quantity: qty,
             issueType: 'Customer Defect Return',
             actionTaken: 'Pending',
             dateReported: DateTime.now(),
             notes: 'Returned by customer (Bill: $originalBillNo). Reason: $returnReason',
             refundAmount: 0.0,
          );
          await logVendorIssue(issue);
        }
      }
    }
  }
}

