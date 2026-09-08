import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/product_repository.dart';
import '../../models/item.dart';
import '../../models/product.dart';
import '../../models/item_prefix.dart';

enum ItemSaveStatus { idle, saving, success, error }

class ItemViewModel extends ChangeNotifier {
  final ProductRepository _repository;

  ItemSaveStatus _status = ItemSaveStatus.idle;
  String? _errorMessage;
  String? _lastSavedDocId;

  List<String> _existingPrefixes = [];
  List<ItemPrefix> _prefixMasters = [];
  bool _isLoadingPrefixes = false;

  List<String> _existingItemNames = [];
  bool _isLoadingItemNames = false;

  List<String> _existingSupplierCodes = [];
  bool _isLoadingSupplierCodes = false;

  ItemViewModel({ProductRepository? repository})
      : _repository = repository ?? ProductRepository() {
    loadUniqueLabelPrefixes();
    loadUniqueItemNames();
    loadUniqueSupplierCodes();
  }

  ItemSaveStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _status == ItemSaveStatus.saving;
  bool get isSuccess => _status == ItemSaveStatus.success;
  String? get lastSavedDocId => _lastSavedDocId;

  List<String> get existingPrefixes => _existingPrefixes;
  List<ItemPrefix> get prefixMasters => _prefixMasters;
  bool get isLoadingPrefixes => _isLoadingPrefixes;

  List<String> get existingItemNames => _existingItemNames;
  bool get isLoadingItemNames => _isLoadingItemNames;

  List<String> get existingSupplierCodes => _existingSupplierCodes;
  bool get isLoadingSupplierCodes => _isLoadingSupplierCodes;

  Future<void> loadUniqueLabelPrefixes() async {
    _isLoadingPrefixes = true;
    notifyListeners();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('item_prefixes')
          .orderBy('createdAt', descending: true)
          .get();
      _prefixMasters = snap.docs.map((doc) => ItemPrefix.fromFirestore(doc)).toList();
      final seen = <String>{};
      _existingPrefixes = [];
      for (final p in _prefixMasters) {
        if (p.prefix.isNotEmpty && seen.add(p.prefix)) {
          _existingPrefixes.add(p.prefix);
        }
      }
    } catch (e) {
      debugPrint('Error fetching prefixes: $e');
    } finally {
      _isLoadingPrefixes = false;
      notifyListeners();
    }
  }

  String _normalizeKaratGroup(String input) {
    final s = input.toUpperCase().replaceAll(' ', '').replaceAll('K', 'KT');
    if (s.contains('24')) return '24KT';
    if (s.contains('22') || s.contains('916')) return '22KT';
    if (s.contains('18') && !s.contains('18D')) return '18KT';
    if (s.contains('14')) return '14KT';
    if (s.contains('925') || s.contains('SILVER') || (s.startsWith('S') && !s.startsWith('ST'))) return 'S925';
    if (s.contains('DIAMOND') || s.contains('DIA') || s.contains('18D')) return 'DI';
    if (s.contains('PLATINUM') || s.startsWith('PT')) return 'PT';
    return s;
  }

  List<ItemPrefix> getPrefixesForMetalGroup(MetalGroup? group, {String? selectedItemName}) {
    if (group == null || _prefixMasters.isEmpty) return _prefixMasters;

    final targetGroupNorm = _normalizeKaratGroup('${group.metalId} ${group.groupName}');
    final targetItemNameNorm = (selectedItemName ?? '').toUpperCase().trim();

    final filtered = _prefixMasters.where((p) {
      final pGroupNorm = _normalizeKaratGroup(p.groupName);

      // Check if group names match by exact ID, normalized ID, or normalized full group details
      final bool matchesGroup = (p.groupName.toUpperCase() == group.metalId.toUpperCase()) ||
                                (pGroupNorm == _normalizeKaratGroup(group.metalId)) ||
                                (pGroupNorm == targetGroupNorm);

      // 1. Strict Karat / Metal Group Matching:
      if (!matchesGroup) {
        return false;
      }

      // 2. Item Name Matching (if specified):
      if (targetItemNameNorm.isNotEmpty && p.itemName.isNotEmpty) {
        final pItemNorm = p.itemName.toUpperCase().trim();
        if (pItemNorm != targetItemNameNorm &&
            !targetItemNameNorm.contains(pItemNorm) &&
            !pItemNorm.contains(targetItemNameNorm)) {
          return false;
        }
      }

      return true;
    }).toList();

    return filtered;
  }

  Future<void> loadUniqueItemNames() async {
    _isLoadingItemNames = true;
    notifyListeners();
    try {
      _existingItemNames = await _repository.getUniqueItemNames();
    } catch (e) {
      debugPrint('Error fetching item names: $e');
    } finally {
      _isLoadingItemNames = false;
      notifyListeners();
    }
  }

  Future<void> addItemName(String name) async {
    try {
      await _repository.saveItemName(name);
      await loadUniqueItemNames();
    } catch (e) {
      debugPrint('Error saving item name: $e');
    }
  }

  Future<void> deleteItemName(String name) async {
    try {
      await _repository.deleteItemName(name);
      await loadUniqueItemNames();
    } catch (e) {
      debugPrint('Error deleting item name: $e');
    }
  }

  Future<void> loadUniqueSupplierCodes() async {
    _isLoadingSupplierCodes = true;
    notifyListeners();
    try {
      _existingSupplierCodes = await _repository.getUniqueSupplierCodes();
    } catch (e) {
      debugPrint('Error fetching supplier codes: $e');
    } finally {
      _isLoadingSupplierCodes = false;
      notifyListeners();
    }
  }

  Future<void> addSupplierCode(String code) async {
    try {
      await _repository.saveSupplierCode(code);
      await loadUniqueSupplierCodes();
    } catch (e) {
      debugPrint('Error saving supplier code: $e');
    }
  }

  Future<void> deleteSupplierCode(String code) async {
    try {
      await _repository.deleteSupplierCode(code);
      await loadUniqueSupplierCodes();
    } catch (e) {
      debugPrint('Error deleting supplier code: $e');
    }
  }

  // ─── Master data additions ──────────────────────────────────────────────────
  List<MetalGroup> _customMetalGroups = [];
  bool _isLoadingMetalGroups = false;

  List<MetalGroup> get metalGroups =>
      _customMetalGroups.isEmpty ? MetalGroup.predefined : _customMetalGroups;
  bool get isLoadingMetalGroups => _isLoadingMetalGroups;

  Future<void> loadMetalGroups() async {
    _isLoadingMetalGroups = true;
    notifyListeners();
    try {
      final list = await _repository.getUniqueMetalGroups();
      _customMetalGroups = list
          .map((m) => MetalGroup(
              metalId: m['metalId']!, groupName: m['groupName']!, linkedRateId: m['linkedRateId']))
          .toList();
    } catch (e) {
      debugPrint('Error loading metal groups: $e');
    } finally {
      _isLoadingMetalGroups = false;
      notifyListeners();
    }
  }

  Future<void> addMetalGroup(String metalId, String groupName, {String? linkedRateId}) async {
    try {
      await _repository.saveMetalGroup(metalId, groupName, linkedRateId: linkedRateId);
      await loadMetalGroups();
    } catch (e) {
      debugPrint('Error saving metal group: $e');
    }
  }

  Future<void> deleteMetalGroup(String metalId, String groupName) async {
    try {
      await _repository.deleteMetalGroup(metalId, groupName);
      await loadMetalGroups();
    } catch (e) {
      debugPrint('Error deleting metal group: $e');
    }
  }

  List<String> _customExtraStyles = [];
  bool _isLoadingExtraStyles = false;

  List<String> get extraStyles {
    return _customExtraStyles;
  }
  bool get isLoadingExtraStyles => _isLoadingExtraStyles;

  Future<void> loadExtraStyles() async {
    _isLoadingExtraStyles = true;
    notifyListeners();
    try {
      _customExtraStyles = await _repository.getUniqueExtraStyles();
    } catch (e) {
      debugPrint('Error loading extra styles: $e');
    } finally {
      _isLoadingExtraStyles = false;
      notifyListeners();
    }
  }

  Future<void> addExtraStyle(String name) async {
    try {
      await _repository.saveExtraStyle(name);
      await loadExtraStyles();
    } catch (e) {
      debugPrint('Error saving extra style: $e');
    }
  }

  Future<void> deleteExtraStyle(String name) async {
    try {
      await _repository.deleteExtraStyle(name);
      await loadExtraStyles();
    } catch (e) {
      debugPrint('Error deleting extra style: $e');
    }
  }

  // ─── Classification state ───────────────────────────────────────────────────
  String _itemType = 'Ornaments';
  MetalGroup _metalGroup = MetalGroup.predefined.first;
  String _metalName = 'Gold';
  bool _isFixGroup = false;
  bool _isPreDef = false;
  bool _sameMetal = true;
  bool _reqItemInCounterReport = true;

  String get itemType => _itemType;
  MetalGroup get metalGroup => _metalGroup;
  String get metalName => _metalName;
  bool get isFixGroup => _isFixGroup;
  bool get sameMetal => _sameMetal;
  bool get reqItemInCounterReport => _reqItemInCounterReport;

  void updateClassification({
    String? itemType,
    MetalGroup? metalGroup,
    String? metalName,
    bool? isFixGroup,
    bool? isPreDef,
    bool? sameMetal,
    bool? reqItemInCounterReport,
  }) {
    if (itemType != null) _itemType = itemType;
    if (metalGroup != null) _metalGroup = metalGroup;
    if (metalName != null) _metalName = metalName;
    if (isFixGroup != null) _isFixGroup = isFixGroup;
    if (isPreDef != null) _isPreDef = isPreDef;
    if (sameMetal != null) _sameMetal = sameMetal;
    if (reqItemInCounterReport != null) {
      _reqItemInCounterReport = reqItemInCounterReport;
    }
    notifyListeners();
  }

  // ─── Custom UI & Calculations Fields ───────────────────────────────────────
  String _jobNo = 'None';
  String _size = '';
  String _remarks = '';
  String _rfidNo = '';
  String _oldBarcode = '';
  String _jobRef = '';

  String _labOn = 'Net Wt';
  double _labRate = 0.0;
  double _labPer = 0.0;
  double _metalRate = 0.0;
  double _costRate = 0.0;

  bool _hasOtherWeights = false;
  List<ExtraChargeRow> _extraCharges = [];

  String get jobNo => _jobNo;
  String get size => _size;
  String get remarks => _remarks;
  String get rfidNo => _rfidNo;
  String get oldBarcode => _oldBarcode;
  String get jobRef => _jobRef;

  String get labOn => _labOn;
  double get labRate => _labRate;
  double get labPer => _labPer;
  double get metalRate => _metalRate;
  double get costRate => _costRate;

  bool get hasOtherWeights => _hasOtherWeights;
  List<ExtraChargeRow> get extraCharges => _extraCharges;

  void updateCustomFields({
    String? jobNo,
    String? size,
    String? remarks,
    String? rfidNo,
    String? oldBarcode,
    String? jobRef,
    String? labOn,
    double? labRate,
    double? labPer,
    double? metalRate,
    double? costRate,
    bool? hasOtherWeights,
    List<ExtraChargeRow>? extraCharges,
  }) {
    if (jobNo != null) _jobNo = jobNo;
    if (size != null) _size = size;
    if (remarks != null) _remarks = remarks;
    if (rfidNo != null) _rfidNo = rfidNo;
    if (oldBarcode != null) _oldBarcode = oldBarcode;
    if (jobRef != null) _jobRef = jobRef;
    if (labOn != null) _labOn = labOn;
    if (labRate != null) _labRate = labRate;
    if (labPer != null) _labPer = labPer;
    if (metalRate != null) _metalRate = metalRate;
    if (costRate != null) _costRate = costRate;
    if (hasOtherWeights != null) _hasOtherWeights = hasOtherWeights;
    if (extraCharges != null) _extraCharges = extraCharges;
    notifyListeners();
  }

  // ─── Weight state ───────────────────────────────────────────────────────────
  double _grossWt = 0.0;
  double _stoneWt = 0.0;
  double _otherWt = 0.0;
  double _purity = 91.6;
  double _todaysRate = 0.0;
  int _pcs = 1;

  void updateWeights({
    double? gross,
    double? stone,
    double? other,
    double? purityVal,
    double? rate,
    int? pcsVal,
  }) {
    if (gross != null) _grossWt = gross;
    if (stone != null) _stoneWt = stone;
    if (other != null) _otherWt = other;
    if (purityVal != null) _purity = purityVal;
    if (rate != null) {
      _todaysRate = rate;
      if (_metalRate == 0.0) _metalRate = rate;
      if (_costRate == 0.0) _costRate = rate;
    }
    if (pcsVal != null) _pcs = pcsVal;
    notifyListeners();
  }

  // ─── Stone & Diamond state ──────────────────────────────────────────────────
  double _diamondWt = 0.0;
  int _diamondPcs = 0;
  double _diamondAmt = 0.0;
  String _diamondClarity = 'VVS';
  String _diamondColor = 'G-H';
  double _extraStoneWt = 0.0;
  int _extraStonePcs = 0;
  double _extraStoneAmt = 0.0;
  double _extraOtherWt = 0.0;
  double _extraOtherAmt = 0.0;

  String get diamondClarity => _diamondClarity;
  String get diamondColor => _diamondColor;

  void updateStones({
    double? dWt,
    int? dPcs,
    double? dAmt,
    String? dClarity,
    String? dColor,
    double? sWt,
    int? sPcs,
    double? sAmt,
    double? oWt,
    double? oAmt,
  }) {
    if (dWt != null) _diamondWt = dWt;
    if (dPcs != null) _diamondPcs = dPcs;
    if (dAmt != null) _diamondAmt = dAmt;
    if (dClarity != null) _diamondClarity = dClarity;
    if (dColor != null) _diamondColor = dColor;
    if (sWt != null) _extraStoneWt = sWt;
    if (sPcs != null) _extraStonePcs = sPcs;
    if (sAmt != null) _extraStoneAmt = sAmt;
    if (oWt != null) _extraOtherWt = oWt;
    if (oAmt != null) _extraOtherAmt = oAmt;
    notifyListeners();
  }

  // ─── Sales Labour / Making Charge state ────────────────────────────────────
  String _salLabRateType = 'Per Gram Net Wt';
  double _salLabRate = 0.0;

  String get salLabRateType => _salLabRateType;

  void updateSalesLabour(String rateType, double rate) {
    _salLabRateType = rateType;
    _salLabRate = rate;
    notifyListeners();
  }

  // ─── Purchase Wastage state ─────────────────────────────────────────────────
  String _purLabRateType = 'Per Gram Net Wt';
  double _purLabRate = 0.0;
  String _purWastCalcOn = 'Net Wt'; // Gross Wt | Net Wt | Fine Wt
  double _purWastPer = 0.0;
  String _purWastAddIn = 'Net Wt'; // Net Wt | Gross Wt

  String get purLabRateType => _purLabRateType;
  String get purWastCalcOn => _purWastCalcOn;
  String get purWastAddIn => _purWastAddIn;

  void updatePurchaseWastage({
    String? purLabRateType,
    double? purLabRate,
    String? wastCalcOn,
    double? wastPer,
    String? wastAddIn,
  }) {
    if (purLabRateType != null) _purLabRateType = purLabRateType;
    if (purLabRate != null) _purLabRate = purLabRate;
    if (wastCalcOn != null) _purWastCalcOn = wastCalcOn;
    if (wastPer != null) _purWastPer = wastPer;
    if (wastAddIn != null) _purWastAddIn = wastAddIn;
    notifyListeners();
  }

  // ─── Tax state ──────────────────────────────────────────────────────────────
  double _cgstPer = 0.0;
  double _sgstPer = 0.0;
  double _igstPer = 0.0;

  void updateTaxes({double? cgst, double? sgst, double? igst}) {
    if (cgst != null) _cgstPer = cgst;
    if (sgst != null) _sgstPer = sgst;
    if (igst != null) _igstPer = igst;
    notifyListeners();
  }

  // ─── Calculated Getters ─────────────────────────────────────────────────────

  double get billDiWt {
    if (_hasOtherWeights) {
      double sum = 0.0;
      for (final row in _extraCharges) {
        if (row.styleName.toLowerCase().contains('diamond')) {
          sum += row.weight;
        }
      }
      return sum;
    }
    return _diamondWt;
  }

  int get billDiPcs {
    if (_hasOtherWeights) {
      int sum = 0;
      for (final row in _extraCharges) {
        if (row.styleName.toLowerCase().contains('diamond')) {
          sum += row.pcs;
        }
      }
      return sum;
    }
    return _diamondPcs;
  }

  double get billStoneWt {
    if (_hasOtherWeights) {
      double sum = 0.0;
      for (final row in _extraCharges) {
        final styleLower = row.styleName.toLowerCase();
        if (!styleLower.contains('diamond') && !styleLower.contains('less')) {
          sum += row.weight;
        }
      }
      return sum;
    }
    return _extraStoneWt;
  }

  int get billStonePcs {
    if (_hasOtherWeights) {
      int sum = 0;
      for (final row in _extraCharges) {
        final styleLower = row.styleName.toLowerCase();
        if (!styleLower.contains('diamond') && !styleLower.contains('less')) {
          sum += row.pcs;
        }
      }
      return sum;
    }
    return _extraStonePcs;
  }

  double get totalTableWeight {
    if (!_hasOtherWeights) return 0.0;
    return _extraCharges.fold(0.0, (acc, row) => acc + row.weight);
  }

  double get physicalNetWt {
    if (_hasOtherWeights) {
      double sumOtherGrams = 0.0;
      double sumDiamondCarats = 0.0;
      for (final row in _extraCharges) {
        if (row.styleName.toLowerCase().contains('diamond')) {
          sumDiamondCarats += row.weight;
        } else {
          sumOtherGrams += row.weight;
        }
      }
      final diamondGrams = sumDiamondCarats * 0.2;
      final v = _grossWt - diamondGrams - sumOtherGrams;
      return v < 0 ? 0.0 : v;
    } else {
      return calculateNetWeight(
        grossWeight: _grossWt,
        diamondWeightCarat: _diamondWt,
        stoneWeight: _extraStoneWt,
        otherWeight: _otherWt,
      );
    }
  }

  /// NetWt = GrossWt - DiamondWt(g) - StoneWt - OtherWt + Wastage Wt (if added in Net/Gross Wt)
  /// Diamond is entered in carats → 1 ct = 0.2 g
  static double calculateNetWeight({
    required double grossWeight,
    required double diamondWeightCarat,
    required double stoneWeight,
    required double otherWeight,
  }) {
    final diamondGrams = diamondWeightCarat * 0.2;
    final v = grossWeight - diamondGrams - stoneWeight - otherWeight;
    return v < 0 ? 0.0 : v;
  }

  double get netWt {
    double wt = physicalNetWt;
    if (_purWastAddIn == 'Net Wt' || _purWastAddIn == 'Gross Wt') {
      wt += purWastWeight;
    }
    return wt;
  }

  double get grossWt {
    double wt = _grossWt;
    if (_purWastAddIn == 'Gross Wt') {
      wt += purWastWeight;
    }
    return wt;
  }

  /// FineWt = NetWt × (Purity / 100)
  double get fineWt => netWt * (_purity / 100);

  /// AlloyWt = GrossWt - FineWt
  double get alloyWt {
    final v = grossWt - fineWt;
    return v < 0 ? 0.0 : v;
  }

  /// MetalAmt = NetWt × TodaysRate (default, or custom metalRate)
  double get metalAmt => netWt * (_metalRate != 0.0 ? _metalRate : _todaysRate);

  /// costMetalAmount = NetWt * costRate
  double get costMetalAmount =>
      netWt * (_costRate != 0.0 ? _costRate : _todaysRate);

  /// Sales Labour Amount based on selected rate type
  double get labourAmount => calculatedLabAmt;

  double get calculatedLabAmt {
    double base = 0.0;
    switch (_labOn) {
      case 'Per Gram Gross Wt':
      case 'Gross Wt':
        base = grossWt;
        break;
      case 'Per Gram Net Wt':
      case 'Net Wt':
        base = netWt;
        break;
      case 'Per Gram Fine Wt':
      case 'Fine Wt':
        base = fineWt;
        break;
      case 'Per Piece':
      case 'Pcs':
        base = _pcs.toDouble();
        break;
      case 'Percentage':
        return metalAmt * (_labRate / 100);
      case 'Percentage on Gross Wt':
        return (grossWt * _metalRate) * (_labRate / 100);
      case 'Percentage on Net Wt':
        return (netWt * _metalRate) * (_labRate / 100);
      case 'Percentage on Fine Wt':
        return (fineWt * _metalRate) * (_labRate / 100);
      case 'Fixed':
        return _labRate;
      default:
        base = netWt;
    }
    double ratePart = base * _labRate;
    double perPart = metalAmt * (_labPer / 100);
    return ratePart + perPart;
  }

  double get calculatedCostLabourAmt {
    double base = 0.0;
    switch (_purLabRateType) {
      case 'Per Gram Gross Wt':
      case 'Gross Wt':
        base = grossWt;
        break;
      case 'Per Gram Net Wt':
      case 'Net Wt':
        base = netWt;
        break;
      case 'Per Gram Fine Wt':
      case 'Fine Wt':
        base = fineWt;
        break;
      case 'Per Piece':
      case 'Pcs':
        base = _pcs.toDouble();
        break;
      case 'Percentage on Gross Wt':
        return (grossWt * (_costRate != 0.0 ? _costRate : _todaysRate)) * (_purLabRate / 100);
      case 'Percentage on Net Wt':
        return (netWt * (_costRate != 0.0 ? _costRate : _todaysRate)) * (_purLabRate / 100);
      case 'Percentage on Fine Wt':
        return (fineWt * (_costRate != 0.0 ? _costRate : _todaysRate)) * (_purLabRate / 100);
      case 'Fixed':
        return _purLabRate;
      default:
        base = netWt;
    }
    return base * _purLabRate;
  }

  double get totalOthChrg {
    if (!_hasOtherWeights) return 0.0;
    return _extraCharges.fold(0.0, (acc, row) => acc + row.salAmt);
  }

  double get totalCostOthChrg {
    if (!_hasOtherWeights) return 0.0;
    return _extraCharges.fold(0.0, (acc, row) => acc + row.costAmt);
  }

  /// Purchase Wastage Weight
  double get purWastWeight {
    final baseWt = _purWastCalcOn == 'Gross Wt'
        ? _grossWt
        : (_purWastCalcOn == 'Fine Wt'
            ? (physicalNetWt * (_purity / 100))
            : physicalNetWt);
    return baseWt * (_purWastPer / 100);
  }

  /// Subtotal before tax
  double get amount {
    if (_hasOtherWeights) {
      return metalAmt + labourAmount + totalOthChrg;
    } else {
      return metalAmt +
          labourAmount +
          _diamondAmt +
          _extraStoneAmt +
          _extraOtherAmt;
    }
  }

  double get cgstAmt => amount * (_cgstPer / 100);
  double get sgstAmt => amount * (_sgstPer / 100);
  double get igstAmt => amount * (_igstPer / 100);
  double get totalAmount => amount + cgstAmt + sgstAmt + igstAmt;

  // Bill metrics
  double get totCostAmt =>
      costMetalAmount + calculatedCostLabourAmt + totalCostOthChrg;
  double get totAmt => amount;
  double get totalMarkupPer =>
      totCostAmt > 0 ? ((totAmt - totCostAmt) / totCostAmt) * 100 : 0.0;
  double get totSalesAmt => totAmt;

  Future<void> saveItem({
    required String tagId,
    required String name,
    required String shortName,
    required String hsnCode,
    required String supplierCode,
    required bool keepLabels,
    required String labelPrefix,
    required String labelNumbering,
    required int labelStartFrom,
    required String counterNo,
    required String rejectionItemCode,
    required String rejectionItemName,
    required String tradName,
    required String adminEmail,
    required String productName,
    required String description,
    required bool uploadInWebsite,
    required List<String> imageUrls,
    required String arImageUrl,
    required String videoUrl,
    String productStatus = 'Shop product',
    bool yetToAdd = false,
    bool isEdit = false,
    bool inShop = true,
    List<String> addTagIds = const [],
    List<String> deleteTagIds = const [],
    List<String> existingRelatedTagIds = const [],
    List<Map<String, dynamic>>? initialPieces,
  }) async {
    _status = ItemSaveStatus.saving;
    notifyListeners();

    try {
      if (name.trim().isNotEmpty) {
        await _repository.saveItemName(name);
      }

      final baseTag = getBaseTagId(tagId);

      if (isEdit) {
        // Load existing pieces array or build fallback from initial data
        List<Map<String, dynamic>> currentPieces = [];
        if (initialPieces != null && initialPieces.isNotEmpty) {
          currentPieces = List<Map<String, dynamic>>.from(initialPieces);
        } else {
          try {
            final docSnap = await FirebaseFirestore.instance
                .collection('jewelry_inventory')
                .doc(baseTag)
                .get();
            if (docSnap.exists && docSnap.data()?['pieces'] is List) {
              currentPieces = List<Map<String, dynamic>>.from(
                (docSnap.data()!['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
              );
            }
          } catch (_) {}
        }

        if (currentPieces.isEmpty && existingRelatedTagIds.isNotEmpty) {
          for (final tid in existingRelatedTagIds) {
            currentPieces.add({
              'tagId': tid,
              'status': 'Available',
              'soldAt': null,
              'billNo': null,
            });
          }
        }

        // 1. Remove deleted pieces
        if (deleteTagIds.isNotEmpty) {
          currentPieces.removeWhere((p) => deleteTagIds.contains(p['tagId']));
        }

        // 2. Add newly incoming piece tags if count increased
        for (final newTag in addTagIds) {
          if (!currentPieces.any((p) => p['tagId'] == newTag)) {
            currentPieces.add({
              'tagId': newTag,
              'status': 'Available',
              'soldAt': null,
              'billNo': null,
            });
          }
        }

        final int finalTotalPcs = currentPieces.isNotEmpty ? currentPieces.length : _pcs;
        final int finalAvailablePcs = currentPieces.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'available').length;
        final String finalStatus = (finalAvailablePcs <= 0) ? 'Out of stock' : productStatus;

        final updates = <String, dynamic>{
          'tagId': baseTag,
          'productId': baseTag,
          'name': productName.trim().isNotEmpty ? productName.trim() : name,
          'productName': productName.trim().isNotEmpty ? productName.trim() : name,
          'shortName': shortName,
          'hsnCode': hsnCode,
          'supplierCode': supplierCode,
          'category': _itemType.isNotEmpty ? _itemType : 'Ornaments',
          'itemType': _itemType,
          'metalId': _metalGroup.metalId,
          'metalGroupName': _metalGroup.groupName,
          'metalName': _metalName,
          'metalType': _metalName.isNotEmpty ? _metalName : 'Gold',
          'purity': _purity > 0 ? '$_purity%' : (_metalGroup.metalId.isNotEmpty ? _metalGroup.metalId : '22KT'),
          'purityVal': _purity,
          'tradName': tradName,
          'isFixGroup': _isFixGroup,
          'isPreDef': _isPreDef,
          'sameMetal': _sameMetal,
          'reqItemInCounterReport': _reqItemInCounterReport,
          'rejectionItemCode': rejectionItemCode,
          'rejectionItemName': rejectionItemName,
          'keepLabels': keepLabels,
          'labelPrefix': labelPrefix,
          'labelNumbering': labelNumbering,
          'labelStartFrom': labelStartFrom,
          'counterNo': counterNo,
          'grossWt': _grossWt,
          'grossWeight': _grossWt,
          'stoneWt': _stoneWt,
          'otherWt': _otherWt,
          'netWt': netWt,
          'netWeight': netWt,
          'alloyWt': alloyWt,
          'fineWt': fineWt,
          'pcs': finalTotalPcs,
          'availablePcs': finalAvailablePcs,
          'pieces': currentPieces,
          'diamondWt': billDiWt,
          'diamondWeight': billDiWt,
          'diamondPcs': billDiPcs,
          'diamondPieceCount': billDiPcs,
          'diamondAmt': _diamondAmt,
          'diamondClarity': _diamondClarity,
          'diamondColor': _diamondColor,
          'extraStoneWt': billStoneWt,
          'extraStonePcs': billStonePcs,
          'extraStoneAmt': _extraStoneAmt,
          'extraOtherWt': _extraOtherWt,
          'extraOtherAmt': _extraOtherAmt,
          'salLabRateType': _salLabRateType,
          'salLabRate': _salLabRate,
          'labourAmount': labourAmount,
          'purLabRateType': _purLabRateType,
          'purLabRate': _purLabRate,
          'purWastCalcOn': _purWastCalcOn,
          'purWastPer': _purWastPer,
          'purWastAddIn': _purWastAddIn,
          'todaysRate': _todaysRate,
          'metalAmt': metalAmt,
          'amount': amount,
          'cgstPer': _cgstPer,
          'cgstAmt': cgstAmt,
          'sgstPer': _sgstPer,
          'sgstAmt': sgstAmt,
          'igstPer': _igstPer,
          'igstAmt': igstAmt,
          'totalAmount': totalAmount,
          'calculatedPrice': totalAmount > 0 ? totalAmount : amount,
          'price': totalAmount > 0 ? totalAmount : amount,
          'description': description,
          'uploadInWebsite': uploadInWebsite,
          'imageUrls': imageUrls,
          'arImageUrl': arImageUrl,
          'videoUrl': videoUrl,
          'productStatus': finalStatus,
          'yetToAdd': yetToAdd,
          'jobNo': _jobNo,
          'size': _size,
          'remarks': _remarks,
          'rfidNo': _rfidNo,
          'oldBarcode': _oldBarcode,
          'jobRef': _jobRef,
          'labOn': _labOn,
          'labRate': _labRate,
          'labPer': _labPer,
          'labAmt': calculatedLabAmt,
          'metalRate': _metalRate != 0.0 ? _metalRate : _todaysRate,
          'metalAmount': metalAmt,
          'costRate': _costRate != 0.0 ? _costRate : _todaysRate,
          'costAmount': costMetalAmount,
          'hasOtherWeights': _hasOtherWeights,
          'extraCharges': _extraCharges.map((e) => e.toMap()).toList(),
          'inShop': inShop,
          'searchKeywords': ProductRepository.buildSearchKeywords(name),
          'updatedBy': adminEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Write single master document to Firestore
        await FirebaseFirestore.instance
            .collection('jewelry_inventory')
            .doc(baseTag)
            .set(updates, SetOptions(merge: true));

        // Clean up any legacy sub-documents if they were explicitly removed
        for (final tagToDelete in deleteTagIds) {
          if (tagToDelete != baseTag) {
            FirebaseFirestore.instance
                .collection('jewelry_inventory')
                .doc(tagToDelete)
                .delete()
                .catchError((_) {});
          }
        }

        _lastSavedDocId = baseTag;
      } else {
        final count = _pcs > 1 ? _pcs : 1;

        final List<Map<String, dynamic>> piecesList = [];
        for (int i = 1; i <= count; i++) {
          piecesList.add({
            'tagId': count > 1 ? '$baseTag[$i]' : baseTag,
            'status': 'Available',
            'soldAt': null,
            'billNo': null,
          });
        }

        final item = JewelryItem(
          tagId: baseTag,
          name: name,
          shortName: shortName,
          hsnCode: hsnCode,
          supplierCode: supplierCode,
          itemType: _itemType,
          metalId: _metalGroup.metalId,
          metalGroupName: _metalGroup.groupName,
          metalName: _metalName,
          metalType: _itemType,
          tradName: tradName,
          isFixGroup: _isFixGroup,
          isPreDef: _isPreDef,
          sameMetal: _sameMetal,
          reqItemInCounterReport: _reqItemInCounterReport,
          rejectionItemCode: rejectionItemCode,
          rejectionItemName: rejectionItemName,
          keepLabels: keepLabels,
          labelPrefix: labelPrefix,
          labelNumbering: labelNumbering,
          labelStartFrom: labelStartFrom,
          counterNo: counterNo,
          grossWt: _grossWt,
          stoneWt: _stoneWt,
          otherWt: _otherWt,
          netWt: netWt,
          purity: _purity,
          alloyWt: alloyWt,
          fineWt: fineWt,
          pcs: count,
          availablePcs: count,
          pieces: piecesList,
          diamondWt: billDiWt,
          diamondPcs: billDiPcs,
          diamondAmt: _diamondAmt,
          diamondClarity: _diamondClarity,
          diamondColor: _diamondColor,
          extraStoneWt: billStoneWt,
          extraStonePcs: billStonePcs,
          extraStoneAmt: _extraStoneAmt,
          extraOtherWt: _extraOtherWt,
          extraOtherAmt: _extraOtherAmt,
          salLabRateType: _salLabRateType,
          salLabRate: _salLabRate,
          labourAmount: labourAmount,
          purLabRateType: _purLabRateType,
          purLabRate: _purLabRate,
          purWastCalcOn: _purWastCalcOn,
          purWastPer: _purWastPer,
          purWastAddIn: _purWastAddIn,
          todaysRate: _todaysRate,
          metalAmt: metalAmt,
          amount: amount,
          cgstPer: _cgstPer,
          cgstAmt: cgstAmt,
          sgstPer: _sgstPer,
          sgstAmt: sgstAmt,
          igstPer: _igstPer,
          igstAmt: igstAmt,
          totalAmount: totalAmount,
          productName: productName,
          description: description,
          uploadInWebsite: uploadInWebsite,
          imageUrls: imageUrls,
          arImageUrl: arImageUrl,
          videoUrl: videoUrl,
          productStatus: productStatus,
          yetToAdd: yetToAdd,
          jobNo: _jobNo,
          size: _size,
          remarks: _remarks,
          rfidNo: _rfidNo,
          oldBarcode: _oldBarcode,
          jobRef: _jobRef,
          labOn: _labOn,
          labRate: _labRate,
          labPer: _labPer,
          labAmt: calculatedLabAmt,
          metalRate: _metalRate != 0.0 ? _metalRate : _todaysRate,
          metalAmount: metalAmt,
          costRate: _costRate != 0.0 ? _costRate : _todaysRate,
          costAmount: costMetalAmount,
          hasOtherWeights: _hasOtherWeights,
          extraCharges: _extraCharges.map((e) => e.toMap()).toList(),
        );

        final data = item.toMap();
        data['inShop'] = inShop;
        data['searchKeywords'] = ProductRepository.buildSearchKeywords(name);
        data['createdBy'] = adminEmail;
        data['updatedBy'] = adminEmail;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        final savedId = await _repository.saveJewelryItem(data);
        _lastSavedDocId = savedId;
      }

      _status = ItemSaveStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ItemSaveStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    _status = ItemSaveStatus.idle;
    _errorMessage = null;
    _lastSavedDocId = null;
    notifyListeners();
  }
}

class ExtraChargeRow {
  String pcsName;
  String styleName;
  String packet;
  String size;
  double weight;
  int pcs;
  String amtOn; // "Weight" | "Pcs" | "Fixed"
  double costRate;
  double costAmt;
  double salRate;
  double salAmt;

  ExtraChargeRow({
    this.pcsName = '',
    this.styleName = 'Less Wt',
    this.packet = '',
    this.size = '',
    this.weight = 0.0,
    this.pcs = 1,
    this.amtOn = 'Weight',
    this.costRate = 0.0,
    this.costAmt = 0.0,
    this.salRate = 0.0,
    this.salAmt = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'pcsName': pcsName,
        'styleName': styleName,
        'packet': packet,
        'size': size,
        'weight': weight,
        'pcs': pcs,
        'amtOn': amtOn,
        'costRate': costRate,
        'costAmt': costAmt,
        'salRate': salRate,
        'salAmt': salAmt,
      };

  factory ExtraChargeRow.fromMap(Map<String, dynamic> map) => ExtraChargeRow(
        pcsName: map['pcsName']?.toString() ?? '',
        styleName: map['styleName']?.toString() ?? 'Less Wt',
        packet: map['packet']?.toString() ?? '',
        size: map['size']?.toString() ?? '',
        weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
        pcs: (map['pcs'] as num?)?.toInt() ?? 1,
        amtOn: map['amtOn']?.toString() ?? 'Weight',
        costRate: (map['costRate'] as num?)?.toDouble() ?? 0.0,
        costAmt: (map['costAmt'] as num?)?.toDouble() ?? 0.0,
        salRate: (map['salRate'] as num?)?.toDouble() ?? 0.0,
        salAmt: (map['salAmt'] as num?)?.toDouble() ?? 0.0,
      );
}
