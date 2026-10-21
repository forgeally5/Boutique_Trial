import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';
import '../../models/product.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/pdf_report_generator.dart';
import '../../utils/excel_generator.dart';
import '../../widgets/report_export_dialog.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/report_filter_widgets.dart';

class StockReportScreen extends StatefulWidget {
  final FocusNode? searchFocusNode;
  final VoidCallback? onReturnToMainTab;
  const StockReportScreen({super.key, this.searchFocusNode, this.onReturnToMainTab});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen>
    with SingleTickerProviderStateMixin {
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _fmt = DateFormat('dd/MM/yyyy');

  late DateTime _dateFrom;
  late DateTime _dateTo;

  late TabController _subTabController;
  int _currentSubTab = 0;

  late FocusNode _productWiseTabFocusNode;
  bool _ownProductWiseTabFocusNode = false;
  final FocusNode _closingStockTabFocusNode =
      FocusNode(debugLabel: 'subtab_closing_stock');
  final FocusNode _stockLedgerTabFocusNode =
      FocusNode(debugLabel: 'subtab_stock_ledger');

  // Product-wise filters
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode =
      FocusNode(debugLabel: 'stock_prod_search');
  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  final Set<String> _expandedProductCategories = {};

  // Category-wise Closing Stock filters
  final _catSearchCtrl = TextEditingController();
  final FocusNode _catSearchFocusNode =
      FocusNode(debugLabel: 'stock_cat_search');
  String _catStatusFilter = 'All';
  final Set<String> _expandedCategories = {};

  // Stock Ledger filters
  final _ledgerSearchCtrl = TextEditingController();
  final FocusNode _ledgerSearchFocusNode =
      FocusNode(debugLabel: 'stock_ledger_search');
  String _ledgerCategoryFilter = 'All';
  String _ledgerStatusFilter = 'All';
  late DateTime _ledgerDateFrom;
  late DateTime _ledgerDateTo;

  bool _loading = false;

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _categoryClosingRows = [];
  List<Map<String, dynamic>> _filteredCategoryRows = [];
  List<Map<String, dynamic>> _allLedgerRows = [];
  List<Map<String, dynamic>> _filteredLedgerRows = [];
  List<String> _categories = ['All'];

  final _statusOptions = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
    'Damaged/Defective'
  ];

  final _catStatusOptions = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
    _subTabController.addListener(() {
      if (_subTabController.indexIsChanging ||
          _subTabController.index != _currentSubTab) {
        setState(() => _currentSubTab = _subTabController.index);
      }
    });

    if (widget.searchFocusNode != null) {
      _productWiseTabFocusNode = widget.searchFocusNode!;
    } else {
      _productWiseTabFocusNode =
          FocusNode(debugLabel: 'subtab_product_wise');
      _ownProductWiseTabFocusNode = true;
    }

    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    _dateFrom = fyStart;
    _dateTo = now;
    _ledgerDateFrom = fyStart;
    _ledgerDateTo = now;

    _load();
    _searchCtrl.addListener(_applyFilters);
    _catSearchCtrl.addListener(_applyCategoryFilters);
    _ledgerSearchCtrl.addListener(_applyLedgerFilters);

    _searchFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          HardwareKeyboard.instance.isShiftPressed) {
        _productWiseTabFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _catSearchFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          HardwareKeyboard.instance.isShiftPressed) {
        _closingStockTabFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _ledgerSearchFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          HardwareKeyboard.instance.isShiftPressed) {
        _stockLedgerTabFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showBoutiqueDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _applyFilters();
    }
  }

  Future<void> _pickLedgerDate({required bool isFrom}) async {
    final initial = isFrom ? _ledgerDateFrom : _ledgerDateTo;
    final picked = await showBoutiqueDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _ledgerDateFrom = picked : _ledgerDateTo = picked);
      _applyLedgerFilters();
    }
  }

  void _selectSubTab(int index) {
    if (_currentSubTab != index) {
      setState(() => _currentSubTab = index);
      _subTabController.animateTo(index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        if (index == 0) {
          _searchFocusNode.requestFocus();
        } else if (index == 1) {
          _catSearchFocusNode.requestFocus();
        } else {
          _ledgerSearchFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _catSearchCtrl.dispose();
    _ledgerSearchCtrl.dispose();
    _searchFocusNode.dispose();
    _catSearchFocusNode.dispose();
    _ledgerSearchFocusNode.dispose();
    _closingStockTabFocusNode.dispose();
    _stockLedgerTabFocusNode.dispose();
    if (_ownProductWiseTabFocusNode) {
      _productWiseTabFocusNode.dispose();
    }
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final productList = await ApiService().getProducts();

      // Fetch vendor issues to track units currently issued / sent to vendor
      List<Map<String, dynamic>> vendorIssueList = [];
      try {
        vendorIssueList = await ApiService().getVendorIssues();
      } catch (e) {
        debugPrint('Error fetching vendor issues: $e');
      }
      final Map<String, int> issueMap = {};
      for (final vi in vendorIssueList) {
        final status = (vi['status']?.toString() ?? '').toLowerCase();
        if (!status.contains('resolved')) {
          final items = (vi['items'] as List?) ?? [];
          for (final it in items) {
            if (it is Map) {
              final tagId = it['tagId']?.toString().trim() ?? '';
              final q = (it['qty'] as num?)?.toInt() ?? 0;
              if (tagId.isNotEmpty) {
                issueMap[tagId.toUpperCase()] = (issueMap[tagId.toUpperCase()] ?? 0) + q;
              }
            }
          }
        }
      }

      // Fetch sales from bills to compute total sold per product
      final billList = await ApiService().getBills();
      final Map<String, int> soldMap = {};
      for (final bill in billList) {
        final billType = (bill['billType']?.toString() ?? 'Sale').trim();
        final isSale = billType == 'Sale' ||
            billType.isEmpty ||
            billType.toLowerCase() == 'invoice' ||
            billType.toLowerCase() == 'advance payment';
        final isReturn = billType == 'Return' || billType.toLowerCase() == 'customer return';
        if (!isSale && !isReturn) continue;

        final items = (bill['items'] as List?) ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final tagId = item['tagId']?.toString().trim() ?? '';
          final q = (item['qty'] as num?)?.toInt() ?? 0;
          if (tagId.isNotEmpty) {
            final key = tagId.toUpperCase();
            if (isReturn) {
              soldMap[key] = (soldMap[key] ?? 0) - q;
            } else if (isSale) {
              soldMap[key] = (soldMap[key] ?? 0) + q;
            }
          }
        }
      }

      final rows = <Map<String, dynamic>>[];
      final catSet = <String>{};
      final Map<String, Map<String, dynamic>> catAgg = {};
      
      final Map<String, Map<String, dynamic>> productAgg = {};
      final Map<String, Map<String, dynamic>> defectiveAgg = {};

      for (final p in productList) {
        final effectiveSp = p.sellingPrice > 0 ? p.sellingPrice : (p.finalPrice > 0 ? p.finalPrice : p.ratePerGram);
        final effectiveMrp = p.mrp > 0 ? p.mrp : effectiveSp;
        final data = <String, dynamic>{
          'tagId': p.tagId,
          'name': p.name,
          'category': p.category,
          'status': p.status,
          'quantity': p.quantity,
          'issueQuantity': p.issueQuantity,
          'reservedQuantity': p.reservedQuantity,
          'unit': p.unit.isNotEmpty ? p.unit : (p.pricingType == 'Weight-Based' ? p.weightUnit : 'Piece'),
          'mrp': effectiveMrp,
          'sellingPrice': effectiveSp,
          'finalPrice': p.finalPrice,
          'pricingType': p.pricingType,
          'ratePerGram': p.ratePerGram,
          'makingCharges': p.makingCharges,
          'material': p.material,
          'grossWeight': p.grossWeight,
          'netWeight': p.netWeight,
          'weightUnit': p.weightUnit,
          'vendor': p.vendor,
          'addedDate': p.addedDate,
        };
        data['_docId'] = p.tagId;

        final tagId = data['tagId']?.toString().trim() ?? '';
        final tagKey = tagId.toUpperCase();
        final balance = (data['quantity'] as num?)?.toInt() ?? 0;
        final issueQty = math.max((data['issueQuantity'] as num?)?.toInt() ?? 0, issueMap[tagKey] ?? 0);
        final soldQty = (soldMap[tagKey] ?? 0).clamp(0, 999999);
        final totalReceived = (data['totalQuantity'] as num?)?.toInt() ??
            (balance + issueQty + soldQty);

        final cat = (data['category']?.toString().trim().isNotEmpty ?? false)
            ? data['category'].toString().trim()
            : 'Uncategorized';
        catSet.add(cat);

        final double itemStockVal = p.pricingType == 'Weight-Based' && p.grossWeight > 0 && p.ratePerGram > 0
            ? (balance * p.grossWeight * p.ratePerGram)
            : (balance * effectiveSp);

        // Aggregate Product-Wise (Good Stock)
        final prodKey = '${data['name']}_$cat';
        if (productAgg.containsKey(prodKey)) {
          final existing = productAgg[prodKey]!;
          existing['quantity'] = (existing['quantity'] as int) + balance;
          existing['balance'] = (existing['balance'] as int? ?? 0) + balance;
          existing['totalReceived'] = (existing['totalReceived'] as int) + totalReceived;
          existing['issueQty'] = (existing['issueQty'] as int) + issueQty;
          existing['soldQty'] = (existing['soldQty'] as int) + soldQty;
          existing['stockValue'] = (existing['stockValue'] as double) + itemStockVal;
          if (!existing['tagId'].toString().contains(tagId) && existing['tagId'].toString().length < 30) {
             existing['tagId'] = '${existing['tagId']}, $tagId';
          } else if (!existing['tagId'].toString().endsWith('...')) {
             existing['tagId'] = '${existing['tagId']}...';
          }
        } else {
          final goodStock = Map<String, dynamic>.from(data);
          goodStock['category'] = cat;
          goodStock['balance'] = balance;
          goodStock['totalReceived'] = totalReceived;
          goodStock['issueQty'] = issueQty;
          goodStock['soldQty'] = soldQty;
          goodStock['stockValue'] = itemStockVal;
          productAgg[prodKey] = goodStock;
        }

        // Aggregate into Category-wise Closing Stock
        final entry = catAgg.putIfAbsent(cat, () {
          return {
            'category': cat,
            'skuCount': 0,
            'totalPurchased': 0,
            'totalIssued': 0,
            'totalSold': 0,
            'closingQty': 0,
            'closingValue': 0.0,
            'products': <Map<String, dynamic>>[],
          };
        });

        entry['skuCount'] = (entry['skuCount'] as int) + 1;
        entry['totalPurchased'] = (entry['totalPurchased'] as int) + totalReceived;
        entry['totalIssued'] = (entry['totalIssued'] as int) + issueQty;
        entry['totalSold'] = (entry['totalSold'] as int) + soldQty;
        entry['closingQty'] = (entry['closingQty'] as int) + balance;
        entry['closingValue'] = (entry['closingValue'] as double) + itemStockVal;
        
        final goodStockForCat = Map<String, dynamic>.from(data);
        goodStockForCat['category'] = cat;
        goodStockForCat['balance'] = balance;
        goodStockForCat['totalReceived'] = totalReceived;
        goodStockForCat['issueQty'] = issueQty;
        goodStockForCat['soldQty'] = soldQty;
        goodStockForCat['stockValue'] = itemStockVal;
        (entry['products'] as List<Map<String, dynamic>>).add(goodStockForCat);

        // 2. Defective Stock Row
        if (issueQty > 0) {
          if (defectiveAgg.containsKey(prodKey)) {
             final existingDef = defectiveAgg[prodKey]!;
             existingDef['quantity'] = (existingDef['quantity'] as int) + issueQty;
             existingDef['balance'] = (existingDef['balance'] as int? ?? 0) + issueQty;
             existingDef['totalReceived'] = (existingDef['totalReceived'] as int) + issueQty;
             existingDef['issueQty'] = (existingDef['issueQty'] as int) + issueQty;
             existingDef['stockValue'] = (existingDef['stockValue'] as double) + (issueQty * effectiveSp);
             if (!existingDef['tagId'].toString().contains(tagId) && existingDef['tagId'].toString().length < 30) {
               existingDef['tagId'] = '${existingDef['tagId']}, $tagId';
             } else if (!existingDef['tagId'].toString().endsWith('...')) {
               existingDef['tagId'] = '${existingDef['tagId']}...';
             }
          } else {
            final defectiveStock = Map<String, dynamic>.from(data);
            defectiveStock['category'] = cat;
            defectiveStock['name'] = '${data['name']} (Defective)';
            defectiveStock['quantity'] = issueQty;
            defectiveStock['balance'] = issueQty;
            defectiveStock['totalReceived'] = issueQty;
            defectiveStock['issueQty'] = issueQty;
            defectiveStock['soldQty'] = 0;
            defectiveStock['status'] = 'Damaged/Defective';
            defectiveStock['stockValue'] = issueQty * effectiveSp;
            defectiveAgg[prodKey] = defectiveStock;
          }
        }
      }

      // Finalize status for aggregated rows
      for (final row in productAgg.values) {
         final bal = (row['quantity'] as num).toInt();
         if (bal == 0) {
           row['status'] = 'Out of Stock';
         } else if (bal > 0 && bal < 5) {
           row['status'] = 'Low Stock';
         } else {
           row['status'] = 'In Stock';
         }
         rows.add(row);
      }
      rows.addAll(defectiveAgg.values);

      // Finalize category rows with status & sort alphabetically
      final catRows = catAgg.values.map((e) {
        final closingQty = e['closingQty'] as int;
        String cStatus;
        if (closingQty <= 0) {
          cStatus = 'Out of Stock';
        } else if (closingQty < 5) {
          cStatus = 'Low Stock';
        } else {
          cStatus = 'In Stock';
        }
        e['status'] = cStatus;
        return e;
      }).toList()
        ..sort((a, b) =>
            (a['category'] as String).compareTo(b['category'] as String));

      final cats = ['All', ...catSet.toList()..sort()];

      rows.sort((a, b) {
        final tagA = a['tagId']?.toString().trim() ?? '';
        final tagB = b['tagId']?.toString().trim() ?? '';
        final matchA = RegExp(r'^([a-zA-Z\-_]*)\s*(\d+)?(.*)$').firstMatch(tagA);
        final matchB = RegExp(r'^([a-zA-Z\-_]*)\s*(\d+)?(.*)$').firstMatch(tagB);
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
        return tagA.toLowerCase().compareTo(tagB.toLowerCase());
      });

      // ── 3. Build Stock Ledger Rows ───────────────────────────────────
      final Map<String, Product> productLookup = {
        for (final p in productList) p.tagId.trim().toUpperCase(): p
      };

      final List<Map<String, dynamic>> ledgerRows = [];
      final Set<String> processedInwardTagIds = {};

      // Group Inward Bills by tagId
      final Map<String, List<Map<String, dynamic>>> tagInwardBatches = {};
      final inwardBills = billList.where((b) => b['billType'] == 'Inward').toList();
      for (final bill in inwardBills) {
        final bDate = DateTime.tryParse(bill['billDate']?.toString() ?? '') ?? DateTime.now();
        final items = (bill['items'] as List?) ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final tagId = item['tagId']?.toString().trim() ?? '';
          if (tagId.isEmpty) continue;

          final itemDate = item['addedDate'] != null
              ? (DateTime.tryParse(item['addedDate'].toString()) ?? bDate)
              : bDate;

          tagInwardBatches.putIfAbsent(tagId.toUpperCase(), () => []).add({
            'item': item,
            'bill': bill,
            'date': itemDate,
          });
        }
      }

      // Sort batches for each tag chronologically ascending
      for (final entry in tagInwardBatches.entries) {
        entry.value.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      }

      // Process Inward Batches with FIFO allocation of sales and issues
      for (final tagEntry in tagInwardBatches.entries) {
        final tagKey = tagEntry.key;
        final batches = tagEntry.value;
        final prod = productLookup[tagKey];

        final double totalTagIssue = math.max(issueMap[tagKey] ?? 0, prod?.issueQuantity ?? 0).toDouble();
        final double totalTagSold = (soldMap[tagKey] ?? 0).clamp(0, 999999).toDouble();

        double remIssue = totalTagIssue;
        double remSold = totalTagSold;

        for (final b in batches) {
          final item = b['item'] as Map;
          final itemDate = b['date'] as DateTime;
          final tagId = item['tagId']?.toString().trim() ?? '';

          final category = (item['category']?.toString().trim().isNotEmpty ?? false)
              ? item['category'].toString().trim()
              : (prod?.category.trim().isNotEmpty ?? false ? prod!.category.trim() : 'Uncategorized');

          final name = (item['name']?.toString().trim().isNotEmpty ?? false)
              ? item['name'].toString().trim()
              : (prod?.name ?? 'Unknown');

          final isWeight = prod?.pricingType == 'Weight-Based' ||
              (item['pricingType']?.toString() == 'Weight-Based') ||
              ((item['weight'] as num?)?.toDouble() ?? 0.0) > 0;

          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
          final inwardVal = isWeight && weight > 0 ? weight : (qty > 0 ? qty.toDouble() : 1.0);

          final unit = isWeight
              ? (prod?.weightUnit.isNotEmpty == true ? prod!.weightUnit : 'Gram')
              : (prod?.unit.isNotEmpty == true ? prod!.unit : 'Nos');

          final rate = (item['rate'] as num?)?.toDouble() ??
              (prod != null
                  ? (prod.sellingPrice > 0 ? prod.sellingPrice : (prod.finalPrice > 0 ? prod.finalPrice : prod.ratePerGram))
                  : 0.0);

          double allocatedIssue = 0.0;
          double allocatedSold = 0.0;
          double batchClosing = inwardVal;

          if (!isWeight) {
            allocatedIssue = remIssue > 0 ? math.min(remIssue, inwardVal) : 0.0;
            remIssue -= allocatedIssue;

            final remInBatch = math.max(0.0, inwardVal - allocatedIssue);
            allocatedSold = remSold > 0 ? math.min(remSold, remInBatch) : 0.0;
            remSold -= allocatedSold;

            batchClosing = math.max(0.0, inwardVal - allocatedIssue - allocatedSold);
          } else {
            batchClosing = prod?.grossWeight ?? inwardVal;
          }

          final status = batchClosing <= 0
              ? 'Out of Stock'
              : (batchClosing < 5 ? 'Low Stock' : 'In Stock');

          processedInwardTagIds.add(tagKey);

          ledgerRows.add({
            'tagId': tagId,
            'category': category,
            'name': name,
            'date': itemDate,
            'price': rate,
            'inwardQty': inwardVal,
            'unit': unit,
            'isWeight': isWeight,
            'issueQty': allocatedIssue,
            'soldQty': allocatedSold,
            'closingQty': batchClosing,
            'status': status,
            'source': 'Inward Bill',
          });
        }
      }

      // Products without explicit Inward Bills (Catalog / Initial Inventory)
      for (final p in productList) {
        final tag = p.tagId.trim().toUpperCase();
        if (processedInwardTagIds.contains(tag)) continue;

        final isWeight = p.pricingType == 'Weight-Based';
        final sold = isWeight ? 0.0 : (soldMap[tag] ?? 0).toDouble();
        final issue = math.max(issueMap[tag] ?? 0, p.issueQuantity).toDouble();
        final closing = isWeight ? p.grossWeight : p.quantity.toDouble();
        final inwardVal = isWeight ? p.grossWeight : (p.quantity + sold + issue);

        final unit = isWeight
            ? (p.weightUnit.isNotEmpty ? p.weightUnit : 'Gram')
            : (p.unit.isNotEmpty ? p.unit : 'Nos');

        final rate = p.sellingPrice > 0
            ? p.sellingPrice
            : (p.finalPrice > 0 ? p.finalPrice : p.ratePerGram);

        final category =
            p.category.trim().isNotEmpty ? p.category.trim() : 'Uncategorized';
        final status = closing <= 0
            ? 'Out of Stock'
            : (closing < 5 ? 'Low Stock' : 'In Stock');

        ledgerRows.add({
          'tagId': p.tagId,
          'category': category,
          'name': p.name,
          'date': p.addedDate ?? DateTime.now(),
          'price': rate,
          'inwardQty': inwardVal,
          'unit': unit,
          'isWeight': isWeight,
          'issueQty': issue,
          'soldQty': sold,
          'closingQty': closing,
          'status': status,
          'source': 'Product Master',
        });
      }

      // Sort: Category A-Z -> Product Name A-Z -> Date Ascending (shows price progression)
      ledgerRows.sort((a, b) {
        final catCmp =
            (a['category'] as String).toLowerCase().compareTo((b['category'] as String).toLowerCase());
        if (catCmp != 0) return catCmp;
        final nameCmp =
            (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        if (nameCmp != 0) return nameCmp;
        final dateA = a['date'] as DateTime? ?? DateTime(2000);
        final dateB = b['date'] as DateTime? ?? DateTime(2000);
        return dateA.compareTo(dateB);
      });

      setState(() {
        _allProducts = rows;
        _categoryClosingRows = catRows;
        _allLedgerRows = ledgerRows;
        _categories = cats;
        _expandedProductCategories.addAll(cats.where((c) => c != 'All'));
        _loading = false;
      });
      _applyFilters();
      _applyCategoryFilters();
      _applyLedgerFilters();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        BoutiqueToast.showError(context, 'Error loading stock: $e');
      }
    }
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    
    _searchCtrl.clear();
    _catSearchCtrl.clear();
    _ledgerSearchCtrl.clear();

    setState(() {
      _dateFrom = fyStart;
      _dateTo = now;
      _categoryFilter = 'All';
      _statusFilter = 'All';

      _catStatusFilter = 'All';
      _expandedCategories.clear();

      _ledgerCategoryFilter = 'All';
      _ledgerStatusFilter = 'All';
      _ledgerDateFrom = fyStart;
      _ledgerDateTo = now;
    });

    await _load();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allProducts.where((r) {
        if (q.isNotEmpty) {
          final tag = r['tagId']?.toString().toLowerCase() ?? '';
          final name = r['name']?.toString().toLowerCase() ?? '';
          if (!tag.contains(q) && !name.contains(q)) return false;
        }
        if (_categoryFilter != 'All' &&
            r['category']?.toString() != _categoryFilter) {
          return false;
        }
        if (_statusFilter != 'All' &&
            r['status']?.toString() != _statusFilter) {
          return false;
        }
        if (r['addedDate'] != null) {
          final dt = r['addedDate'] is DateTime
              ? r['addedDate'] as DateTime
              : DateTime.tryParse(r['addedDate'].toString());
          if (dt != null) {
            final fromDt = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
            final toDt = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);
            if (dt.isBefore(fromDt) || dt.isAfter(toDt)) {
              return false;
            }
          }
        }
        return true;
      }).toList();
    });
  }

  void _applyCategoryFilters() {
    final q = _catSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredCategoryRows = _categoryClosingRows.where((r) {
        if (q.isNotEmpty) {
          final cat = r['category']?.toString().toLowerCase() ?? '';
          if (!cat.contains(q)) return false;
        }
        if (_catStatusFilter != 'All' &&
            r['status']?.toString() != _catStatusFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _applyLedgerFilters() {
    final q = _ledgerSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredLedgerRows = _allLedgerRows.where((r) {
        if (q.isNotEmpty) {
          final cat = r['category']?.toString().toLowerCase() ?? '';
          final name = r['name']?.toString().toLowerCase() ?? '';
          final tag = r['tagId']?.toString().toLowerCase() ?? '';
          if (!cat.contains(q) && !name.contains(q) && !tag.contains(q)) return false;
        }
        if (_ledgerCategoryFilter != 'All' &&
            r['category']?.toString() != _ledgerCategoryFilter) {
          return false;
        }
        if (_ledgerStatusFilter != 'All' &&
            r['status']?.toString() != _ledgerStatusFilter) {
          return false;
        }
        if (r['date'] != null) {
          final dt = r['date'] is DateTime
              ? r['date'] as DateTime
              : DateTime.tryParse(r['date'].toString());
          if (dt != null) {
            final fromDt = DateTime(_ledgerDateFrom.year, _ledgerDateFrom.month, _ledgerDateFrom.day);
            final toDt = DateTime(_ledgerDateTo.year, _ledgerDateTo.month, _ledgerDateTo.day, 23, 59, 59);
            if (dt.isBefore(fromDt) || dt.isAfter(toDt)) {
              return false;
            }
          }
        }
        return true;
      }).toList();
    });
  }

  // ── Stock Ledger Summary values ──────────────────────────────────────────
  double get _ledgerTotalInward => _filteredLedgerRows.fold(
      0.0, (s, r) => s + ((r['inwardQty'] as num?)?.toDouble() ?? 0.0));

  double get _ledgerTotalIssue => _filteredLedgerRows.fold(
      0.0, (s, r) => s + ((r['issueQty'] as num?)?.toDouble() ?? 0.0));

  double get _ledgerTotalSales => _filteredLedgerRows.fold(
      0.0, (s, r) => s + ((r['soldQty'] as num?)?.toDouble() ?? 0.0));

  double get _ledgerTotalClosing => _filteredLedgerRows.fold(
      0.0, (s, r) => s + ((r['closingQty'] as num?)?.toDouble() ?? 0.0));

  // ── Product-wise Summary values ───────────────────────────────────────────
  double get _totalStockValue => _filtered.fold(
      0.0,
      (s, r) {
        final pt = r['pricingType']?.toString() ?? 'Quantity-Based';
        if (pt == 'Weight-Based') {
          final gw = (r['grossWeight'] as num?)?.toDouble() ?? 0.0;
          final rate = (r['ratePerGram'] as num?)?.toDouble() ?? 0.0;
          return s + (gw * rate);
        } else {
          final bal = ((r['balance'] as num?)?.toDouble() ?? (r['quantity'] as num?)?.toDouble() ?? 0);
          final sp = ((r['sellingPrice'] as num?)?.toDouble() ?? 0);
          return s + (bal * sp);
        }
      });

  int get _totalPurchasedQty => _filtered.fold(
      0, (s, r) => s + ((r['totalReceived'] as num?)?.toInt() ?? 0));

  int get _totalIssuedQty =>
      _filtered.fold(0, (s, r) => s + ((r['issueQty'] as num?)?.toInt() ?? 0));

  int get _totalSoldQty =>
      _filtered.fold(0, (s, r) => s + ((r['soldQty'] as num?)?.toInt() ?? 0));

  int get _totalBalanceQty => _filtered.fold(
      0,
      (s, r) =>
          s +
          ((r['balance'] as num?)?.toInt() ??
              (r['quantity'] as num?)?.toInt() ??
              0));

  int get _lowStockCount =>
      _filtered.where((r) => r['status'] == 'Low Stock').length;

  int get _outOfStockCount =>
      _filtered.where((r) => r['status'] == 'Out of Stock').length;

  // ── Category-wise Closing Stock Summary values ────────────────────────────
  int get _catTotalSkus => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['skuCount'] as num?)?.toInt() ?? 0));

  int get _catTotalPurchased => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalPurchased'] as num?)?.toInt() ?? 0));

  int get _catTotalIssued => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalIssued'] as num?)?.toInt() ?? 0));

  int get _catTotalSold => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['totalSold'] as num?)?.toInt() ?? 0));

  int get _catTotalClosingQty => _filteredCategoryRows.fold(
      0, (s, r) => s + ((r['closingQty'] as num?)?.toInt() ?? 0));

  double get _catTotalClosingValue => _filteredCategoryRows.fold(
      0.0, (s, r) => s + ((r['closingValue'] as num?)?.toDouble() ?? 0.0));

  int get _catZeroStockCount =>
      _filteredCategoryRows.where((r) => (r['closingQty'] as int) <= 0).length;

  // ── Print / Download handlers (Product-wise) ──────────────────────────────
  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateStockReportPdf(
      rows: _filtered,
      categoryFilter: _categoryFilter,
      statusFilter: _statusFilter,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleDownload() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to download.');
      return;
    }
    await ReportExportDialog.show(
      context: context,
      title: 'Product-Wise Stock Report',
      onDownloadPdf: () async {
        final bytes = await generateStockReportPdf(
          rows: _filtered,
          categoryFilter: _categoryFilter,
          statusFilter: _statusFilter,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'stock_report_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadProductStockReportExcel(
          rows: _filtered,
          categoryFilter: _categoryFilter,
          statusFilter: _statusFilter,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
      },
    );
  }

  Future<void> _handleProductExcelDirect() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No product data to export.');
      return;
    }
    try {
      await ExcelGenerator.downloadProductStockReportExcel(
        rows: _filtered,
        categoryFilter: _categoryFilter,
        statusFilter: _statusFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Stock Report (.xlsx) downloaded successfully!');
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Failed to download Stock Report: $e');
    }
  }

  Future<void> _handleCatExcelDirect() async {
    if (_filteredCategoryRows.isEmpty) {
      BoutiqueToast.showError(context, 'No category data to export.');
      return;
    }
    try {
      await ExcelGenerator.downloadCategoryClosingStockExcel(
        rows: _filteredCategoryRows,
        statusFilter: _catStatusFilter,
      );
      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Closing Stock Report (.xlsx) downloaded successfully!');
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Failed to download Closing Stock Report: $e');
    }
  }

  // ── Print / Download handlers (Category-wise Closing Stock) ───────────────
  Future<void> _handleCatPrint() async {
    if (_filteredCategoryRows.isEmpty) {
      BoutiqueToast.showError(context, 'No closing stock data to print.');
      return;
    }
    final bytes = await generateCategoryClosingStockPdf(
      rows: _filteredCategoryRows,
      statusFilter: _catStatusFilter,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleCatDownload() async {
    if (_filteredCategoryRows.isEmpty) {
      BoutiqueToast.showError(context, 'No closing stock data to download.');
      return;
    }
    await ReportExportDialog.show(
      context: context,
      title: 'Closing Stock Report (Category-Wise)',
      onDownloadPdf: () async {
        final bytes = await generateCategoryClosingStockPdf(
          rows: _filteredCategoryRows,
          statusFilter: _catStatusFilter,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'closing_stock_category_wise_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadCategoryClosingStockExcel(
          rows: _filteredCategoryRows,
          statusFilter: _catStatusFilter,
        );
      },
    );
  }

  // ── Print / Download handlers (Stock Ledger) ──────────────────────────────
  Future<void> _handleLedgerExcelDirect() async {
    if (_filteredLedgerRows.isEmpty) {
      BoutiqueToast.showError(context, 'No stock ledger data to export.');
      return;
    }
    try {
      await ExcelGenerator.downloadStockLedgerExcel(
        rows: _filteredLedgerRows,
        categoryFilter: _ledgerCategoryFilter,
        dateFrom: _ledgerDateFrom,
        dateTo: _ledgerDateTo,
      );
      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Stock Ledger (.xlsx) downloaded successfully!');
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Failed to download Stock Ledger: $e');
    }
  }

  Future<void> _handleLedgerDownload() async {
    if (_filteredLedgerRows.isEmpty) {
      BoutiqueToast.showError(context, 'No stock ledger data to download.');
      return;
    }
    await ReportExportDialog.show(
      context: context,
      title: 'Stock Ledger Statement',
      onDownloadPdf: () async {
        final bytes = await generateStockLedgerPdf(
          rows: _filteredLedgerRows,
          categoryFilter: _ledgerCategoryFilter,
          dateFrom: _ledgerDateFrom,
          dateTo: _ledgerDateTo,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'stock_ledger_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadStockLedgerExcel(
          rows: _filteredLedgerRows,
          categoryFilter: _ledgerCategoryFilter,
          dateFrom: _ledgerDateFrom,
          dateTo: _ledgerDateTo,
        );
      },
    );
  }

  Future<void> _handleLedgerPrint() async {
    if (_filteredLedgerRows.isEmpty) {
      BoutiqueToast.showError(context, 'No stock ledger data to print.');
      return;
    }
    final bytes = await generateStockLedgerPdf(
      rows: _filteredLedgerRows,
      categoryFilter: _ledgerCategoryFilter,
      dateFrom: _ledgerDateFrom,
      dateTo: _ledgerDateTo,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_allProducts.isNotEmpty && _categoryClosingRows.isEmpty && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryClosingRows.isEmpty && !_loading) {
          _load();
        }
      });
    }
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // ── Sub-Tab Bar (Product-Wise vs Category-Wise vs Stock Ledger) ──
          Container(
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(
                bottom: BorderSide(color: BoutiqueColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StockSubTabButton(
                  focusNode: _productWiseTabFocusNode,
                  index: 0,
                  icon: Icons.list_alt_rounded,
                  label: 'Product-Wise Stock Report',
                  isSelected: _currentSubTab == 0,
                  order: 1.0,
                  onSelect: () => _selectSubTab(0),
                  onArrowRight: () => _closingStockTabFocusNode.requestFocus(),
                  onArrowLeft: null,
                  onShiftTab: widget.onReturnToMainTab,
                ),
                const SizedBox(width: 6),
                _StockSubTabButton(
                  focusNode: _closingStockTabFocusNode,
                  index: 1,
                  icon: Icons.category_outlined,
                  label: 'Closing Stock Report (Category-Wise)',
                  isSelected: _currentSubTab == 1,
                  order: 2.0,
                  onSelect: () => _selectSubTab(1),
                  onArrowRight: () => _stockLedgerTabFocusNode.requestFocus(),
                  onArrowLeft: () => _productWiseTabFocusNode.requestFocus(),
                  onShiftTab: widget.onReturnToMainTab,
                ),
                const SizedBox(width: 6),
                _StockSubTabButton(
                  focusNode: _stockLedgerTabFocusNode,
                  index: 2,
                  icon: Icons.menu_book_rounded,
                  label: 'Stock Ledger (Format Statement)',
                  isSelected: _currentSubTab == 2,
                  order: 3.0,
                  onSelect: () => _selectSubTab(2),
                  onArrowRight: null,
                  onArrowLeft: () => _closingStockTabFocusNode.requestFocus(),
                  onShiftTab: widget.onReturnToMainTab,
                ),
              ],
            ),
          ),

          // ── Sub-Tab Views ──────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _subTabController,
              children: [
                _buildProductWiseView(),
                _buildCategoryWiseClosingView(),
                _buildStockLedgerView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: PRODUCT-WISE STOCK VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProductWiseView() {
    final Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
    for (final p in _filtered) {
      final cat = (p['category']?.toString().trim().isNotEmpty ?? false)
          ? p['category'].toString().trim()
          : 'Uncategorized';
      groupedByCategory.putIfAbsent(cat, () => []).add(p);
    }
    final sortedCategories = groupedByCategory.keys.toList()..sort();
    final allCatsExpanded = sortedCategories.isNotEmpty &&
        sortedCategories.every((c) => _expandedProductCategories.contains(c));

    return Column(
      children: [
        // ── Filter Bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 3,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(3.0),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search tag ID or product name…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date From
              ReportDatePill(
                label: 'From',
                dt: _dateFrom,
                order: 4.0,
                fmt: _fmt,
                onTap: () => _pickDate(isFrom: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→',
                    style: TextStyle(color: BoutiqueColors.textSecondary)),
              ),
              // Date To
              ReportDatePill(
                label: 'To',
                dt: _dateTo,
                order: 5.0,
                fmt: _fmt,
                onTap: () => _pickDate(isFrom: false),
              ),
              const SizedBox(width: 12),
              // Category
              Expanded(
                flex: 2,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(6.0),
                  child: SearchableDropdownField(
                    label: 'Category',
                    value: _categoryFilter,
                    items: _categories,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _categoryFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status
              Expanded(
                flex: 2,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(7.0),
                  child: SearchableDropdownField(
                    label: 'Status',
                    value: _statusFilter,
                    items: _statusOptions,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _statusFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Expand/Collapse All Button
              FocusTraversalOrder(
                order: const NumericFocusOrder(7.5),
                child: OutlinedButton.icon(
                  icon: Icon(
                    allCatsExpanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 16,
                    color: BoutiqueColors.accent,
                  ),
                  label: Text(
                    allCatsExpanded ? 'Collapse All' : 'Expand All',
                    style: const TextStyle(
                      color: BoutiqueColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: BoutiqueColors.bgCard,
                    side: const BorderSide(color: BoutiqueColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() {
                      if (allCatsExpanded) {
                        _expandedProductCategories.clear();
                      } else {
                        _expandedProductCategories.addAll(sortedCategories);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Excel Export Button
              FocusTraversalOrder(
                order: const NumericFocusOrder(7.8),
                child: Tooltip(
                  message: 'Export Product Stock Report as formatted Excel',
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_view_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Excel Export',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7145), // Excel Green
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onPressed: _handleProductExcelDirect,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(8.0),
                child: Tooltip(
                  message: 'Refresh Stock Report (Alt+2)',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                    label: const Text('Refresh', style: TextStyle(color: BoutiqueColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: BoutiqueColors.bgCard,
                      side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _refresh,
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(9.0),
                child: IconButton(
                  icon: const Icon(Icons.print_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handlePrint,
                  tooltip: 'Print Report',
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(10.0),
                child: IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleDownload,
                  tooltip: 'Download PDF',
                ),
              ),
            ],
          ),
        ),

        // ── Summary Cards ────────────────────────────────────────────
        Container(
          color: BoutiqueColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(Icons.inventory_2_outlined, 'Total Products',
                    '${_filtered.length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.shopping_bag_outlined, 'Total Purchased',
                    '$_totalPurchasedQty', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.assignment_return_outlined, 'Total Issued',
                    '$_totalIssuedQty', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.point_of_sale_rounded, 'Total Sold',
                    '$_totalSoldQty', BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.numbers_rounded, 'Balance Stock',
                    '$_totalBalanceQty', BoutiqueColors.gold),
                const SizedBox(width: 14),
                _summaryCard(
                    Icons.currency_rupee_rounded,
                    'Stock Value',
                    '₹${_numFmt.format(_totalStockValue)}',
                    BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.warning_amber_rounded, 'Low Stock',
                    '$_lowStockCount', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.remove_shopping_cart_rounded, 'Out of Stock',
                    '$_outOfStockCount', BoutiqueColors.destructive),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: BoutiqueColors.border),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filtered.isEmpty
                  ? _emptyState('No products found matching the current filters.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        children: [
                          _prodCatTableHeader(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: sortedCategories.length,
                              separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: BoutiqueColors.borderLight),
                              itemBuilder: (ctx, i) {
                                final cat = sortedCategories[i];
                                final catProds = groupedByCategory[cat]!;
                                return _buildProductCategoryGroup(
                                    cat, catProds, i);
                              },
                            ),
                          ),
                          _productGrandTotalFooter(),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _prodCatTableHeader() {
    const cols = [
      'S.No',
      'Category Name',
      'Total Items (SKUs)',
      'Total Purchased',
      'Issued Qty',
      'Sold Qty',
      'Balance Qty',
      'Stock Value (₹)',
    ];
    const flexes = [1, 4, 2, 2, 2, 2, 2, 3];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: flexes[e.key],
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductCategoryGroup(
      String category, List<Map<String, dynamic>> products, int catIndex) {
    final isExpanded = _expandedProductCategories.contains(category);
    int catPurchased = 0;
    int catIssued = 0;
    int catSold = 0;
    int catBalance = 0;
    double catStockVal = 0.0;

    for (final p in products) {
      final pricingType = p['pricingType']?.toString() ?? 'Quantity-Based';
      final grossWeight = (p['grossWeight'] as num?)?.toDouble() ?? 0.0;
      final ratePerGram = (p['ratePerGram'] as num?)?.toDouble() ?? 0.0;
      final totalReceived = (p['totalReceived'] as num?)?.toInt() ?? 0;
      final issueQty = (p['issueQty'] as num?)?.toInt() ?? 0;
      final soldQty = (p['soldQty'] as num?)?.toInt() ?? 0;
      final balance = (p['balance'] as num?)?.toInt() ??
          (p['quantity'] as num?)?.toInt() ??
          0;
      final sp = (p['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      final sVal = pricingType == 'Weight-Based'
          ? (grossWeight * ratePerGram)
          : (balance * sp);

      catPurchased += totalReceived;
      catIssued += issueQty;
      catSold += soldQty;
      catBalance += balance;
      catStockVal += sVal;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedProductCategories.remove(category);
              } else {
                _expandedProductCategories.add(category);
              }
            });
          },
          child: Container(
            color: isExpanded
                ? BoutiqueColors.accentSoft.withValues(alpha: 0.25)
                : BoutiqueColors.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('${catIndex + 1}'),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: BoutiqueColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _cell(
                            category,
                            color: BoutiqueColors.accent,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('${products.length} Items', bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('$catPurchased',
                        color: BoutiqueColors.accent, bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$catIssued',
                      color: catIssued > 0
                          ? BoutiqueColors.warning
                          : BoutiqueColors.textSecondary,
                      bold: catIssued > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$catSold',
                      color: catSold > 0
                          ? BoutiqueColors.success
                          : BoutiqueColors.textSecondary,
                      bold: catSold > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$catBalance',
                      color: catBalance == 0
                          ? BoutiqueColors.destructive
                          : catBalance < 5
                              ? BoutiqueColors.warning
                              : BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '₹${_numFmt.format(catStockVal)}',
                      color: BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Expanded Nested Drill-Down Box for Products ──────────────
        if (isExpanded && products.isNotEmpty)
          Container(
            color: BoutiqueColors.bgMain.withValues(alpha: 0.6),
            padding: const EdgeInsets.only(left: 36, right: 16, top: 6, bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: BoutiqueColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BoutiqueColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: BoutiqueColors.bgSecondary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Tag ID',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 4,
                            child: Text('Product Name',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Purchased',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Issued',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sold',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Balance Qty',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 1,
                            child: Text('Unit',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sell Price (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Stock Value (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Status',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                      ],
                    ),
                  ),
                  ...products.asMap().entries.map((pe) {
                    final p = pe.value;
                    final pricingType = p['pricingType']?.toString() ?? 'Quantity-Based';
                    final grossWeight = (p['grossWeight'] as num?)?.toDouble() ?? 0.0;
                    final ratePerGram = (p['ratePerGram'] as num?)?.toDouble() ?? 0.0;
                    final weightUnit = p['weightUnit']?.toString() ?? 'g';
                    final totalReceived = (p['totalReceived'] as num?)?.toInt() ?? 0;
                    final issueQty = (p['issueQty'] as num?)?.toInt() ?? 0;
                    final soldQty = (p['soldQty'] as num?)?.toInt() ?? 0;
                    final bal = (p['balance'] as num?)?.toInt() ?? (p['quantity'] as num?)?.toInt() ?? 0;
                    final sp = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
                    final displaySp = pricingType == 'Weight-Based' ? ratePerGram : sp;
                    final sVal = pricingType == 'Weight-Based' ? (grossWeight * ratePerGram) : (bal * sp);
                    String balanceStr = bal.toString();
                    if (pricingType == 'Weight-Based' && grossWeight > 0) {
                      balanceStr = '${grossWeight.toStringAsFixed(2)}$weightUnit ($bal pc)';
                    }
                    final status = p['status']?.toString() ?? 'In Stock';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: BoutiqueColors.bgCard,
                        border: Border(
                          top: BorderSide(color: BoutiqueColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: _cell(p['tagId']?.toString() ?? '—',
                                  color: BoutiqueColors.accent, bold: true)),
                          Expanded(
                              flex: 4,
                              child: _cell(p['name']?.toString() ?? '—', bold: true)),
                          Expanded(
                              flex: 2,
                              child: _cell('$totalReceived',
                                  color: BoutiqueColors.accent, bold: true)),
                          Expanded(
                              flex: 2,
                              child: _cell('$issueQty',
                                  color: issueQty > 0 ? BoutiqueColors.warning : BoutiqueColors.textSecondary,
                                  bold: issueQty > 0)),
                          Expanded(
                              flex: 2,
                              child: _cell('$soldQty',
                                  color: soldQty > 0 ? BoutiqueColors.success : BoutiqueColors.textSecondary,
                                  bold: soldQty > 0)),
                          Expanded(
                              flex: 2,
                              child: _cell(balanceStr,
                                  color: bal == 0
                                      ? BoutiqueColors.destructive
                                      : bal < 5
                                          ? BoutiqueColors.warning
                                          : BoutiqueColors.textPrimary,
                                  bold: true)),
                          Expanded(
                              flex: 1,
                              child: _cell(p['unit']?.toString() ?? '—')),
                          Expanded(
                              flex: 2,
                              child: _cell('₹${_numFmt.format(displaySp)}')),
                          Expanded(
                              flex: 2,
                              child: _cell('₹${_numFmt.format(sVal)}', bold: true)),
                          Expanded(
                              flex: 2,
                              child: _buildStatusBadge(status)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _productGrandTotalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        border: Border(
          top: BorderSide(color: BoutiqueColors.border, width: 1.5),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SizedBox(),
          ),
          const Expanded(
            flex: 4,
            child: Text(
              'GRAND TOTAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: SizedBox(),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cell('$_totalPurchasedQty',
                  color: BoutiqueColors.accent, bold: true),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cell('$_totalIssuedQty',
                  color: BoutiqueColors.warning, bold: true),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cell('$_totalSoldQty',
                  color: BoutiqueColors.success, bold: true),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _cell('$_totalBalanceQty',
                  color: BoutiqueColors.accent, bold: true),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '₹${_numFmt.format(_totalStockValue)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: CATEGORY-WISE CLOSING STOCK REPORT VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryWiseClosingView() {
    return Column(
      children: [
        // ── Filter Bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
          ),
          child: Row(
            children: [
              // Search Category
              Expanded(
                flex: 4,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(3.0),
                  child: TextField(
                    focusNode: _catSearchFocusNode,
                    controller: _catSearchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search category name…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status Filter
              Expanded(
                flex: 2,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(4.0),
                  child: SearchableDropdownField(
                    label: 'Closing Status',
                    value: _catStatusFilter,
                    items: _catStatusOptions,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _catStatusFilter = v);
                        _applyCategoryFilters();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Expand/Collapse All button
              FocusTraversalOrder(
                order: const NumericFocusOrder(5.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_expandedCategories.length ==
                          _filteredCategoryRows.length) {
                        _expandedCategories.clear();
                      } else {
                        _expandedCategories.addAll(_filteredCategoryRows
                            .map((e) => e['category'].toString()));
                      }
                    });
                  },
                  icon: Icon(
                    _expandedCategories.length == _filteredCategoryRows.length &&
                            _filteredCategoryRows.isNotEmpty
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 16,
                    color: BoutiqueColors.accent,
                  ),
                  label: Text(
                    _expandedCategories.length == _filteredCategoryRows.length &&
                            _filteredCategoryRows.isNotEmpty
                        ? 'Collapse All'
                        : 'Expand Products',
                    style: const TextStyle(
                        fontSize: 12,
                        color: BoutiqueColors.accent,
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: BoutiqueColors.border),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Direct Excel Download Button
              FocusTraversalOrder(
                order: const NumericFocusOrder(5.5),
                child: Tooltip(
                  message: 'Export Closing Stock Report as formatted Excel',
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_view_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Excel Export',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7145), // Excel Green
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onPressed: _handleCatExcelDirect,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(6.0),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: BoutiqueColors.accent),
                  onPressed: _refresh,
                  tooltip: 'Refresh',
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(7.0),
                child: IconButton(
                  icon: const Icon(Icons.print_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleCatPrint,
                  tooltip: 'Print Closing Stock Report',
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(8.0),
                child: IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: BoutiqueColors.accent),
                  onPressed: _handleCatDownload,
                  tooltip: 'Download Closing Stock PDF',
                ),
              ),
            ],
          ),
        ),

        // ── Category Summary KPI Cards ───────────────────────────────
        Container(
          color: BoutiqueColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(Icons.category_outlined, 'Total Categories',
                    '${_filteredCategoryRows.length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.qr_code_2_rounded, 'Total SKUs',
                    '$_catTotalSkus', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.shopping_bag_outlined, 'Opening / Purchased',
                    '$_catTotalPurchased', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.assignment_return_outlined, 'Issued / Defect',
                    '$_catTotalIssued', BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.point_of_sale_rounded, 'Sold Qty',
                    '$_catTotalSold', BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.inventory_rounded, 'Closing Stock Qty',
                    '$_catTotalClosingQty', BoutiqueColors.gold),
                const SizedBox(width: 14),
                _summaryCard(
                    Icons.currency_rupee_rounded,
                    'Closing Stock Value',
                    '₹${_numFmt.format(_catTotalClosingValue)}',
                    BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.remove_shopping_cart_rounded,
                    'Zero-Stock Categories', '$_catZeroStockCount', BoutiqueColors.destructive),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: BoutiqueColors.border),

        // ── Category-Wise Table + Grand Total Footer ─────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filteredCategoryRows.isEmpty
                  ? _emptyState(
                      'No categories found matching the current filters.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        children: [
                          _catTableHeader(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filteredCategoryRows.length,
                              separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: BoutiqueColors.borderLight),
                              itemBuilder: (ctx, i) =>
                                  _catTableRow(_filteredCategoryRows[i], i),
                            ),
                          ),
                          _catGrandTotalFooter(),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _catTableHeader() {
    const cols = [
      'S.No',
      'Category Name',
      'Total Items (SKUs)',
      'Purchased Qty',
      'Issued Qty',
      'Sold Qty',
      'Closing Stock Qty',
      'Closing Value (₹)',
    ];
    const flexes = [1, 4, 2, 2, 2, 2, 2, 3];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: flexes[e.key],
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                e.value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _catTableRow(Map<String, dynamic> r, int i) {
    final category = r['category']?.toString() ?? 'Uncategorized';
    final skuCount = (r['skuCount'] as num?)?.toInt() ?? 0;
    final totalPurchased = (r['totalPurchased'] as num?)?.toInt() ?? 0;
    final totalIssued = (r['totalIssued'] as num?)?.toInt() ?? 0;
    final totalSold = (r['totalSold'] as num?)?.toInt() ?? 0;
    final closingQty = (r['closingQty'] as num?)?.toInt() ?? 0;
    final closingValue = (r['closingValue'] as num?)?.toDouble() ?? 0.0;
    final products =
        (r['products'] as List<Map<String, dynamic>>?) ?? const [];

    final isExpanded = _expandedCategories.contains(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category);
              } else {
                _expandedCategories.add(category);
              }
            });
          },
          child: Container(
            color: isExpanded
                ? BoutiqueColors.accentSoft.withValues(alpha: 0.25)
                : BoutiqueColors.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('${i + 1}'),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: BoutiqueColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _cell(
                            category,
                            color: BoutiqueColors.accent,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('$skuCount Items', bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell('$totalPurchased',
                        color: BoutiqueColors.accent, bold: true),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$totalIssued',
                      color: totalIssued > 0
                          ? BoutiqueColors.warning
                          : BoutiqueColors.textSecondary,
                      bold: totalIssued > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$totalSold',
                      color: totalSold > 0
                          ? BoutiqueColors.success
                          : BoutiqueColors.textSecondary,
                      bold: totalSold > 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '$closingQty',
                      color: closingQty == 0
                          ? BoutiqueColors.destructive
                          : closingQty < 5
                              ? BoutiqueColors.warning
                              : BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _cell(
                      '₹${_numFmt.format(closingValue)}',
                      color: BoutiqueColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Expanded Drill-Down Product Rows inside this Category ─────────
        if (isExpanded && products.isNotEmpty)
          Container(
            color: BoutiqueColors.bgMain.withValues(alpha: 0.6),
            padding:
                const EdgeInsets.only(left: 36, right: 16, top: 6, bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: BoutiqueColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BoutiqueColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: BoutiqueColors.bgSecondary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Tag ID',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 4,
                            child: Text('Product Name',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Purchased',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Issued',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sold',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Closing Qty',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 1,
                            child: Text('Unit',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Sell Price (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                        Expanded(
                            flex: 2,
                            child: Text('Closing Value (₹)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textSecondary))),
                      ],
                    ),
                  ),
                  ...products.asMap().entries.map((pe) {
                    final p = pe.value;
                    final bal = (p['balance'] as num?)?.toInt() ?? (p['quantity'] as num?)?.toInt() ?? 0;
                    final sp = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: BoutiqueColors.bgCard,
                        border: Border(
                          top: BorderSide(color: BoutiqueColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: _cell(p['tagId']?.toString() ?? '—',
                                  color: BoutiqueColors.accent, bold: true)),
                          Expanded(
                              flex: 4,
                              child: _cell(p['name']?.toString() ?? '—')),
                          Expanded(
                              flex: 2,
                              child: _cell('${p['totalReceived'] ?? 0}')),
                          Expanded(
                              flex: 2, child: _cell('${p['issueQty'] ?? 0}')),
                          Expanded(
                              flex: 2, child: _cell('${p['soldQty'] ?? 0}')),
                          Expanded(
                              flex: 2,
                              child: _cell('$bal',
                                  color: bal == 0
                                      ? BoutiqueColors.destructive
                                      : BoutiqueColors.textPrimary,
                                  bold: true)),
                          Expanded(
                              flex: 1,
                              child: _cell(p['unit']?.toString() ?? '—')),
                          Expanded(
                              flex: 2, child: _cell('₹${_numFmt.format(sp)}')),
                          Expanded(
                              flex: 2,
                              child: _cell(
                                  '₹${_numFmt.format((p['stockValue'] as num?)?.toDouble() ?? (bal * sp))}',
                                  bold: true)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _catGrandTotalFooter() {
    const flexes = [1, 4, 2, 2, 2, 2, 2, 3];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        border: Border(
          top: BorderSide(color: BoutiqueColors.border, width: 1.5),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(flex: flexes[0], child: const SizedBox()),
          Expanded(
            flex: flexes[1],
            child: const Text(
              'GRAND TOTAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            flex: flexes[2],
            child: _cell('$_catTotalSkus Items', bold: true),
          ),
          Expanded(
            flex: flexes[3],
            child: _cell('$_catTotalPurchased',
                color: BoutiqueColors.accent, bold: true),
          ),
          Expanded(
            flex: flexes[4],
            child: _cell('$_catTotalIssued',
                color: BoutiqueColors.warning, bold: true),
          ),
          Expanded(
            flex: flexes[5],
            child: _cell('$_catTotalSold',
                color: BoutiqueColors.success, bold: true),
          ),
          Expanded(
            flex: flexes[6],
            child: _cell('$_catTotalClosingQty',
                color: BoutiqueColors.accent, bold: true),
          ),
          Expanded(
            flex: flexes[7],
            child: Text(
              '₹${_numFmt.format(_catTotalClosingValue)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {Color color = BoutiqueColors.textPrimary, bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _summaryCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 52, color: BoutiqueColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: STOCK LEDGER VIEW (MATCHING ATTACHED EXCEL FORMAT)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStockLedgerView() {
    return Column(
      children: [
        // ── Filter Bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
          ),
          child: Row(
            children: [
              // Search Field
              Expanded(
                flex: 3,
                child: TextField(
                  focusNode: _ledgerSearchFocusNode,
                  controller: _ledgerSearchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(
                    hintText: 'Search product, category, or tag ID…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: BoutiqueColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date From
              ReportDatePill(
                label: 'From',
                dt: _ledgerDateFrom,
                order: 4.0,
                fmt: _fmt,
                onTap: () => _pickLedgerDate(isFrom: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→',
                    style: TextStyle(color: BoutiqueColors.textSecondary)),
              ),
              // Date To
              ReportDatePill(
                label: 'To',
                dt: _ledgerDateTo,
                order: 5.0,
                fmt: _fmt,
                onTap: () => _pickLedgerDate(isFrom: false),
              ),
              const SizedBox(width: 12),
              // Category Dropdown
              Expanded(
                flex: 2,
                child: SearchableDropdownField(
                  label: 'Category',
                  value: _ledgerCategoryFilter,
                  items: _categories,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _ledgerCategoryFilter = v);
                      _applyLedgerFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Status Dropdown
              Expanded(
                flex: 2,
                child: SearchableDropdownField(
                  label: 'Status',
                  value: _ledgerStatusFilter,
                  items: _statusOptions,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _ledgerStatusFilter = v);
                      _applyLedgerFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Direct Excel Download Button
              ElevatedButton.icon(
                icon: const Icon(Icons.table_view_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Excel Export',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7145),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 1,
                ),
                onPressed: _handleLedgerExcelDirect,
              ),
              const SizedBox(width: 8),
              // Refresh Button
              Tooltip(
                message: 'Refresh Stock Ledger',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                  label: const Text('Refresh', style: TextStyle(color: BoutiqueColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: BoutiqueColors.bgCard,
                    side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _refresh,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: BoutiqueColors.accent),
                onPressed: _handleLedgerPrint,
                tooltip: 'Print Ledger',
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined, color: BoutiqueColors.accent),
                onPressed: _handleLedgerDownload,
                tooltip: 'Export Options (PDF/Excel)',
              ),
            ],
          ),
        ),

        // ── Summary KPI Cards ─────────────────────────────────────────
        Container(
          color: BoutiqueColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(Icons.category_outlined, 'Categories',
                    '${_filteredLedgerRows.map((r) => r['category']).toSet().length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.format_list_numbered_rounded, 'Ledger Batches',
                    '${_filteredLedgerRows.length}', BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.input_rounded, 'Total Inward',
                    _ledgerTotalInward % 1 == 0 ? _ledgerTotalInward.toInt().toString() : _ledgerTotalInward.toStringAsFixed(2), BoutiqueColors.accent),
                const SizedBox(width: 14),
                _summaryCard(Icons.assignment_return_outlined, 'Total Issued',
                    _ledgerTotalIssue % 1 == 0 ? _ledgerTotalIssue.toInt().toString() : _ledgerTotalIssue.toStringAsFixed(2), BoutiqueColors.warning),
                const SizedBox(width: 14),
                _summaryCard(Icons.point_of_sale_rounded, 'Total Sold',
                    _ledgerTotalSales % 1 == 0 ? _ledgerTotalSales.toInt().toString() : _ledgerTotalSales.toStringAsFixed(2), BoutiqueColors.success),
                const SizedBox(width: 14),
                _summaryCard(Icons.account_balance_wallet_outlined, 'Closing Stock',
                    _ledgerTotalClosing % 1 == 0 ? _ledgerTotalClosing.toInt().toString() : _ledgerTotalClosing.toStringAsFixed(2), BoutiqueColors.gold),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: BoutiqueColors.border),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filteredLedgerRows.isEmpty
                  ? _emptyState('No stock ledger records found matching the current filters.')
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        children: [
                          _ledgerTableHeader(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filteredLedgerRows.length,
                              separatorBuilder: (_, _) => const Divider(
                                  height: 1, color: BoutiqueColors.borderLight),
                              itemBuilder: (ctx, i) {
                                final current = _filteredLedgerRows[i];
                                final prev = i > 0 ? _filteredLedgerRows[i - 1] : null;
                                final isFirstOfCat = prev == null ||
                                    (prev['category']?.toString().trim().toUpperCase() !=
                                        current['category']?.toString().trim().toUpperCase());
                                return _ledgerTableRow(current, isFirstOfCat, i);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _ledgerTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'CATEGORY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'PRODUCT NAME (Particulars)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'DATE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PRICE (₹)',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'TOTAL INWARD',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'ISSUE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'SALES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'CLOSING',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerTableRow(Map<String, dynamic> r, bool isFirstOfCat, int index) {
    final rawDate = r['date'];
    final date = rawDate is DateTime
        ? rawDate
        : (DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now());
    final dateStr = _fmt.format(date);
    final price = (r['price'] as num?)?.toDouble() ?? 0.0;
    final inwardQty = (r['inwardQty'] as num?)?.toDouble() ?? 0.0;
    final unit = r['unit']?.toString() ?? 'Nos';
    final isWeight = r['isWeight'] == true;
    final issueQty = (r['issueQty'] as num?)?.toDouble() ?? 0.0;
    final soldQty = (r['soldQty'] as num?)?.toDouble() ?? 0.0;
    final closingQty = (r['closingQty'] as num?)?.toDouble() ?? 0.0;
    final status = r['status']?.toString() ?? 'In Stock';
    final displayUnit = unit.isNotEmpty ? unit : (isWeight ? 'Gram' : 'Nos');

    String fmtQty(double val) {
      if (isWeight) {
        return val.toStringAsFixed(2);
      }
      return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
    }

    final rowWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: BoutiqueColors.bgCard,
      child: Row(
        children: [
          // Category
          Expanded(
            flex: 3,
            child: isFirstOfCat
                ? Text(
                    (r['category']?.toString() ?? '').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: BoutiqueColors.accent,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
          // Product Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: BoutiqueColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((r['tagId']?.toString().isNotEmpty ?? false))
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.accentSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r['tagId'].toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BoutiqueColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              dateStr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: BoutiqueColors.textSecondary,
              ),
            ),
          ),
          // Price
          Expanded(
            flex: 2,
            child: Text(
              price > 0 ? '₹${_numFmt.format(price)}' : '-',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: BoutiqueColors.textPrimary,
              ),
            ),
          ),
          // Total Inward
          Expanded(
            flex: 2,
            child: Text(
              '${fmtQty(inwardQty)} $displayUnit',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: BoutiqueColors.textPrimary,
              ),
            ),
          ),
          // Issue
          Expanded(
            flex: 1,
            child: Text(
              issueQty > 0 ? fmtQty(issueQty) : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: issueQty > 0 ? BoutiqueColors.warning : BoutiqueColors.textMuted,
              ),
            ),
          ),
          // Sales
          Expanded(
            flex: 1,
            child: Text(
              soldQty > 0 ? fmtQty(soldQty) : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: soldQty > 0 ? BoutiqueColors.success : BoutiqueColors.textMuted,
              ),
            ),
          ),
          // Closing
          Expanded(
            flex: 2,
            child: Text(
              fmtQty(closingQty),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: closingQty <= 0 ? BoutiqueColors.destructive : BoutiqueColors.accent,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Center(
              child: _buildStatusBadge(status),
            ),
          ),
        ],
      ),
    );

    return rowWidget;
  }


  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'In Stock':
        bg = BoutiqueColors.success.withValues(alpha: 0.12);
        fg = BoutiqueColors.success;
        break;
      case 'Low Stock':
        bg = BoutiqueColors.warning.withValues(alpha: 0.12);
        fg = BoutiqueColors.warning;
        break;
      case 'Out of Stock':
      default:
        bg = BoutiqueColors.destructive.withValues(alpha: 0.12);
        fg = BoutiqueColors.destructive;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

// ── Sub-Tab Button for Stock Report with Keyboard Traversal & Visible Highlight ──

class _StockSubTabButton extends StatefulWidget {
  final FocusNode focusNode;
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final double order;
  final VoidCallback onSelect;
  final VoidCallback? onArrowRight;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onShiftTab;

  const _StockSubTabButton({
    required this.focusNode,
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.order,
    required this.onSelect,
    this.onArrowRight,
    this.onArrowLeft,
    this.onShiftTab,
  });

  @override
  State<_StockSubTabButton> createState() => _StockSubTabButtonState();
}

class _StockSubTabButtonState extends State<_StockSubTabButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    const accent = BoutiqueColors.accent;

    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: true,
        onFocusChange: (focused) {
          if (mounted) setState(() => _isFocused = focused);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onSelect();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.tab &&
                HardwareKeyboard.instance.isShiftPressed) {
              if (widget.onShiftTab != null) {
                widget.onShiftTab!();
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                widget.onArrowRight != null) {
              widget.onArrowRight!();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                widget.onArrowLeft != null) {
              widget.onArrowLeft!();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: () {
            widget.focusNode.requestFocus();
            widget.onSelect();
          },
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _isFocused
                  ? accent.withAlpha(25)
                  : (isSelected
                      ? BoutiqueColors.accentSoft.withAlpha(60)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused ? accent : Colors.transparent,
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(60),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: isSelected ? accent : BoutiqueColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color:
                            isSelected ? accent : BoutiqueColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2.5,
                  width: isSelected ? 48 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
