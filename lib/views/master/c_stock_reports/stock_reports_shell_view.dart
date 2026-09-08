import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/pdf_stock_report_api.dart';
import 'stock_reports_dummy_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/report_header.dart';
import 'closing_stock_report_view.dart';
import 'item_wise_stock_balance_view.dart';
import 'tag_wise_stock_report_view.dart';
import 'counter_stock_report_view.dart';
import 'supplier_stock_report_view.dart';

class StockReportsShellView extends StatefulWidget {
  final int initialReportIndex;

  const StockReportsShellView({
    super.key,
    this.initialReportIndex = 0,
  });

  @override
  State<StockReportsShellView> createState() => _StockReportsShellViewState();
}

class _StockReportsShellViewState extends State<StockReportsShellView> {
  late int _activeReportIndex;
  String _selectedFinancialYear = '2025 - 2026';
  DateTime _startDate = DateTime(2025, 4, 1);
  DateTime _endDate = DateTime(2026, 3, 31);

  bool _isLoading = true;
  List<StockSummaryItem> _stockSummaryList = [];
  List<ItemWiseStockItem> _itemWiseList = [];
  List<TagWiseStockItem> _tagWiseList = [];
  List<CounterStockItem> _counterStockList = [];
  List<SupplierStockItem> _supplierStockList = [];

  final List<String> _reportTitles = [
    'Closing Stock Report',
    'Item Wise Stock Balance',
    'Tag Wise Stock Report',
    'Counter Stock Report',
    'Supplier Stock',
  ];

  @override
  void initState() {
    super.initState();
    _activeReportIndex = widget.initialReportIndex;
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final inventorySnap = await FirebaseFirestore.instance.collection('jewelry_inventory').get();
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();

      final List<Map<String, dynamic>> allInvDocs = inventorySnap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      final List<Map<String, dynamic>> allBills = [];
      final Set<String> soldTagIds = {};

      for (final doc in billsSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        
        final dateStr = d['date']?.toString() ?? '';
        DateTime? billDate;
        try {
          if (dateStr.isNotEmpty) {
            final parts = dateStr.split(' ')[0].split('/');
            if (parts.length == 3) {
              final day = int.tryParse(parts[0]) ?? 1;
              final month = int.tryParse(parts[1]) ?? 1;
              final year = int.tryParse(parts[2]) ?? 2026;
              billDate = DateTime(year, month, day);
            }
          }
        } catch (_) {}
        
        if (billDate != null) {
          if (billDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              billDate.isBefore(_endDate.add(const Duration(days: 1)))) {
            allBills.add(d);
          }
        }

        // Track sold tag IDs from all Sale invoices
        final isSale = d['billType'] == 'Sale' || 
                       d['type'] == 'Sale' || 
                       (d['voucherNo']?.toString().startsWith('SL') ?? false) || 
                       d['category']?.toString().toLowerCase() == 'customer';
        if (isSale) {
          final items = d['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tId = item['tagId']?.toString().trim() ?? '';
                if (tId.isNotEmpty) {
                  soldTagIds.add(tId);
                }
              }
            }
          }
        }
      }

      // Merge inventory items and Purchase bills (pseudo-inventory documents)
      final Map<String, Map<String, dynamic>> tagMap = {};
      for (final doc in allInvDocs) {
        final tagId = doc['id']?.toString().trim() ?? '';
        if (tagId.isNotEmpty) {
          tagMap[tagId] = doc;
        }
      }

      for (final bill in allBills) {
        final isPurchase = bill['billType'] == 'Purchase' || 
                           bill['type'] == 'Purchase' || 
                           (bill['voucherNo']?.toString().startsWith('PR') ?? false) || 
                           bill['category']?.toString().toLowerCase() == 'supplier';
        if (isPurchase) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                if (tagId.isNotEmpty && !tagMap.containsKey(tagId)) {
                  tagMap[tagId] = {
                    'id': tagId,
                    'tagId': tagId,
                    'barcode': tagId,
                    'name': item['name'] ?? item['productName'] ?? '',
                    'category': item['category'] ?? item['group'] ?? 'Uncategorized',
                    'grossWeight': (item['grossWeight'] as num?)?.toDouble() ?? 0.0,
                    'netWeight': (item['netWeight'] as num?)?.toDouble() ?? 0.0,
                    'purity': item['purity'] ?? '22K',
                    'productStatus': 'Available',
                    'pcs': (item['pcs'] as num?)?.toInt() ?? 1,
                    'pieces': (item['pcs'] as num?)?.toInt() ?? 1,
                    'quantity': (item['pcs'] as num?)?.toInt() ?? 1,
                    'metalRate': (item['rate'] as num?)?.toDouble() ?? 0.0,
                  };
                }
              }
            }
          }
        }
      }

      String getGroupHead(String purity) {
        final p = purity.toUpperCase();
        if (p.contains('22') || p.contains('916')) return 'Precious Gold';
        if (p.contains('18') || p.contains('750')) return 'Precious Gold';
        if (p.contains('925') || p.contains('SILVER')) return 'Silverware & Articles';
        if (p.contains('PLATINUM') || p.contains('950')) return 'Platinum Luxury';
        if (p.contains('DIAMOND') || p.contains('18D') || p.contains('22D')) return 'Diamond Collections';
        return 'Antique Craft';
      }

      String getMetalType(String purity) {
        final p = purity.toUpperCase();
        if (p.contains('22') || p.contains('916')) return 'Gold 22K (916)';
        if (p.contains('18') || p.contains('750')) return 'Gold 18K (750)';
        if (p.contains('925') || p.contains('SILVER')) return 'Silver 925';
        if (p.contains('PLATINUM') || p.contains('950')) return 'Platinum 950';
        if (p.contains('DIAMOND') || p.contains('18D') || p.contains('22D')) return 'Diamond';
        return 'Gold 22K (916)';
      }

      // REPORT 3: TAG WISE STOCK REPORT
      final List<TagWiseStockItem> tagWise = [];
      tagMap.forEach((tagId, doc) {
        final barcode = doc['barcode']?.toString() ?? doc['tagId']?.toString() ?? tagId;
        final name = doc['name']?.toString() ?? doc['productName']?.toString() ?? '';
        final category = doc['category']?.toString() ?? doc['groupName']?.toString() ?? doc['metalId']?.toString() ?? 'Uncategorized';
        final grossWt = (doc['grossWeight'] ?? doc['grossWt'] ?? 0.0).toDouble();
        final netWt = (doc['netWeight'] ?? doc['netWt'] ?? 0.0).toDouble();
        final purity = doc['purity']?.toString() ?? doc['metalId']?.toString() ?? '22K';
        
        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final isYetToAdd = doc['yetToAdd'] == true || doc['isYetToAdd'] == true || rawStatus == 'Yet to add';
        
        final currentPcs = (doc['pcs'] as num?)?.toInt() ?? 
                           (doc['pieces'] as num?)?.toInt() ?? 
                           (doc['quantity'] as num?)?.toInt() ?? 1;

        final isSold = currentPcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock';

        final status = isSold ? 'Sold' : (isYetToAdd ? 'Reserved' : 'Available');
        final counter = doc['counterNo']?.toString() ?? doc['counter']?.toString() ?? doc['counterName']?.toString() ?? 'Main Display Safe';

        tagWise.add(TagWiseStockItem(
          tagNumber: tagId,
          barcode: barcode,
          itemName: name,
          category: category,
          grossWeight: grossWt,
          netWeight: netWt,
          purity: purity,
          status: status,
          counter: counter,
        ));
      });

      // REPORT 2: ITEM WISE STOCK BALANCE
      final Map<String, List<Map<String, dynamic>>> itemWiseGroups = {};
      tagMap.forEach((tagId, doc) {
        final key = doc['tagId']?.toString().trim().toLowerCase() ?? doc['id']?.toString().trim().toLowerCase() ?? tagId.toLowerCase().trim();
        
        itemWiseGroups.putIfAbsent(key, () => []).add(doc);
      });

      // Include sold items from Sale bills
      for (final bill in allBills) {
        final isSale = bill['billType'] == 'Sale' || 
                       bill['type'] == 'Sale' || 
                       (bill['voucherNo']?.toString().startsWith('SL') ?? false) || 
                       bill['category']?.toString().toLowerCase() == 'customer';
        if (isSale) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                final doc = {
                  'id': tagId.isNotEmpty ? tagId : 'sold_non_tagged',
                  'tagId': tagId,
                  'barcode': tagId,
                  'name': item['name'] ?? item['productName'] ?? '',
                  'category': item['category'] ?? item['group'] ?? 'Uncategorized',
                  'grossWeight': (item['grossWeight'] as num?)?.toDouble() ?? 0.0,
                  'netWeight': (item['netWeight'] as num?)?.toDouble() ?? 0.0,
                  'purity': item['purity'] ?? '22K',
                  'productStatus': 'Sold',
                  'isFromBill': true,
                  'pcs': (item['pcs'] as num?)?.toInt() ?? 1,
                  'pieces': (item['pcs'] as num?)?.toInt() ?? 1,
                  'quantity': (item['pcs'] as num?)?.toInt() ?? 1,
                };
                final key = tagId.isNotEmpty ? tagId.toLowerCase().trim() : '${doc['name'].toString().toLowerCase()}_${doc['purity'].toString().toLowerCase()}';
                itemWiseGroups.putIfAbsent(key, () => []).add(doc);
              }
            }
          }
        }
      }

      final List<ItemWiseStockItem> itemWise = [];
      itemWiseGroups.forEach((key, docs) {
        final first = docs.first;
        final name = first['name']?.toString() ?? first['productName']?.toString() ?? '';
        final category = first['category']?.toString() ?? first['groupName']?.toString() ?? first['metalId']?.toString() ?? 'Uncategorized';
        final purity = first['purity']?.toString() ?? first['metalId']?.toString() ?? '22K';
        final branch = first['branch']?.toString() ?? 'Main Branch (Coimbatore)';
        
        int availableQty = 0;
        int soldQty = 0;
        double gross = 0.0;
        double net = 0.0;
        double totalVal = 0.0;
        
        for (final d in docs) {
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? (d['quantity'] as num?)?.toInt() ?? 1;
          final g = (d['grossWeight'] ?? d['grossWt'] ?? 0.0).toDouble();
          final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
          final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

          final dIsSold = rawStatus.toLowerCase() == 'sold' || 
                          rawStatus.toLowerCase() == 'out of stock' ||
                          p <= 0;

          if (dIsSold || d['isFromBill'] == true) {
            if (d['isFromBill'] == true) {
              final soldPcs = p > 0 ? p : 1;
              soldQty += soldPcs;
            }
          } else {
            availableQty += p;
            gross += g * p;
            net += n * p;
            totalVal += (n * p) * rate;
          }
        }

        final int totalQty = availableQty + soldQty;
        final double soldPct = totalQty > 0 ? (soldQty / totalQty * 100) : 0.0;

        // Determine correct product status from available documents first
        Map<String, dynamic>? firstDoc;
        for (final d in docs) {
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? (d['quantity'] as num?)?.toInt() ?? 1;

          final dIsSold = rawStatus.toLowerCase() == 'sold' || 
                          rawStatus.toLowerCase() == 'out of stock' ||
                          p <= 0;
          if (!dIsSold && d['isFromBill'] != true) {
            firstDoc = d;
            break;
          }
        }
        firstDoc ??= first;

        final rawStatus = (firstDoc['productStatus'] ?? firstDoc['status'] ?? '').toString().trim();
        final rawStatusLower = rawStatus.toLowerCase();

        String prodStatus = 'Shop product';
        if (rawStatusLower == 'yet to add' || firstDoc['yetToAdd'] == true || firstDoc['isYetToAdd'] == true) {
          prodStatus = 'Yet to add';
        } else if (rawStatusLower == 'web product') {
          prodStatus = 'Web Product';
        } else if (rawStatusLower == 'website product') {
          prodStatus = 'Website product';
        } else if (rawStatusLower == 'shop product') {
          prodStatus = 'Shop product';
        } else {
          final isWeb = firstDoc['inWebsite'] == true || 
                        firstDoc['uploadInWebsite'] == true || 
                        firstDoc['isWebsiteVisible'] == true || 
                        firstDoc['visibleInWebsite'] == true;
          if (isWeb) {
            prodStatus = 'Website product';
          } else {
            prodStatus = 'Shop product';
          }
        }

        itemWise.add(ItemWiseStockItem(
          itemCode: firstDoc['id']?.toString() ?? '',
          itemName: name,
          category: category,
          purity: purity,
          branch: branch,
          quantity: availableQty,
          grossWeight: gross,
          netWeight: net,
          value: totalVal,
          availableQuantity: availableQty,
          soldQuantity: soldQty,
          totalQuantity: totalQty,
          soldPercentage: soldPct,
          productStatus: prodStatus,
        ));
      });

      // REPORT 1: STOCK SUMMARY REPORT
      final Map<String, List<Map<String, dynamic>>> summaryGroups = {};
      tagMap.forEach((tagId, doc) {
        final category = doc['category']?.toString() ?? doc['groupName']?.toString() ?? doc['metalId']?.toString() ?? 'Uncategorized';
        final purity = doc['purity']?.toString() ?? doc['metalId']?.toString() ?? '22K';
        final key = '${category.toLowerCase()}_${purity.toLowerCase()}';
        summaryGroups.putIfAbsent(key, () => []).add(doc);
      });

      final Map<String, int> stockOutMap = {};
      final Map<String, int> stockInMap = {};

      for (final bill in allBills) {
        final items = bill['items'] as List?;
        final isSale = bill['billType'] == 'Sale' || bill['type'] == 'Sale';
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final category = item['category']?.toString() ?? item['group']?.toString() ?? 'Uncategorized';
              final purity = item['purity']?.toString() ?? item['group']?.toString() ?? '22K';
              final key = '${category.toLowerCase()}_${purity.toLowerCase()}';
              final pcs = (item['pcs'] as num?)?.toInt() ?? 1;
              if (isSale) {
                stockOutMap[key] = (stockOutMap[key] ?? 0) + pcs;
              } else {
                stockInMap[key] = (stockInMap[key] ?? 0) + pcs;
              }
            }
          }
        }
      }

      final List<StockSummaryItem> stockSummary = [];
      summaryGroups.forEach((key, docs) {
        final first = docs.first;
        final category = first['category']?.toString() ?? first['groupName']?.toString() ?? first['metalId']?.toString() ?? 'Uncategorized';
        final purity = first['purity']?.toString() ?? first['metalId']?.toString() ?? '22K';
        
        final groupHead = getGroupHead(purity);
        final metalType = getMetalType(purity);
        final branch = first['branch']?.toString() ?? 'Main Branch (Coimbatore)';

        int activeQty = 0;
        double totalWt = 0.0;
        double totalVal = 0.0;

        for (final d in docs) {
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final currentPcs = (d['pcs'] as num?)?.toInt() ?? 
                             (d['pieces'] as num?)?.toInt() ?? 
                             (d['quantity'] as num?)?.toInt() ?? 1;

          final isSold = currentPcs <= 0 || 
                         rawStatus.toLowerCase() == 'sold' || 
                         rawStatus.toLowerCase() == 'out of stock';
          if (isSold) continue;

          final p = currentPcs;
          final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
          final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

          activeQty += p;
          totalWt += n * p;
          totalVal += n * p * rate;
        }

        final inQty = stockInMap[key] ?? 0;
        final outQty = stockOutMap[key] ?? 0;
        final opening = activeQty - inQty + outQty;

        stockSummary.add(StockSummaryItem(
          groupHead: groupHead,
          category: category,
          metalType: metalType,
          branch: branch,
          itemCount: docs.length,
          openingQty: opening >= 0 ? opening : 0,
          stockIn: inQty,
          stockOut: outQty,
          closingQty: activeQty,
          weight: totalWt,
          value: totalVal,
        ));
      });

      // REPORT 4: COUNTER STOCK REPORT
      final Map<String, List<Map<String, dynamic>>> counterGroups = {};
      tagMap.forEach((tagId, doc) {
        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final currentPcs = (doc['pcs'] as num?)?.toInt() ?? 
                           (doc['pieces'] as num?)?.toInt() ?? 
                           (doc['quantity'] as num?)?.toInt() ?? 1;

        final isSold = currentPcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock';
        if (isSold) return;

        final counter = doc['counterNo']?.toString() ?? doc['counter']?.toString() ?? doc['counterName']?.toString() ?? 'Main Display Safe';
        counterGroups.putIfAbsent(counter, () => []).add(doc);
      });

      final List<CounterStockItem> counterStock = [];
      counterGroups.forEach((counter, docs) {
        final Map<String, List<Map<String, dynamic>>> catGroups = {};
        for (final d in docs) {
          final category = d['category']?.toString() ?? d['groupName']?.toString() ?? 'Uncategorized';
          catGroups.putIfAbsent(category, () => []).add(d);
        }

        catGroups.forEach((category, catDocs) {
          int qty = 0;
          double wt = 0.0;
          double val = 0.0;
          for (final d in catDocs) {
            final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? 1;
            final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
            final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

            qty += p;
            wt += n * p;
            val += n * p * rate;
          }

          counterStock.add(CounterStockItem(
            counterName: counter,
            staff: 'Staff Assigned',
            category: category,
            itemCount: catDocs.length,
            quantity: qty,
            weight: wt,
            value: val,
          ));
        });
      });

      // REPORT 5: SUPPLIER STOCK REPORT
      final suppliersSnap = await FirebaseFirestore.instance.collection('suppliers').get();
      final Map<String, String> supplierNameMap = {};
      for (final doc in suppliersSnap.docs) {
        final d = doc.data();
        final code = d['supplierCode']?.toString().trim() ?? doc.id;
        final name = d['companyName']?.toString().trim() ?? d['contactName']?.toString().trim() ?? doc.id;
        if (code.isNotEmpty) {
          supplierNameMap[code] = name;
        }
      }

      String getPrefixFromTag(String tagId) {
        final clean = tagId.trim();
        final match = RegExp(r'^[A-Za-z]+').firstMatch(clean);
        if (match != null) {
          return match.group(0)!.toUpperCase();
        }
        return '—';
      }

      final Map<String, int> purPcsMap = {};
      final Map<String, double> purGrossMap = {};
      final Map<String, double> purNetMap = {};
      final Map<String, double> purDiaMap = {};
      final Map<String, double> purStnMap = {};

      final Map<String, int> tagPcsMap = {};
      final Map<String, double> tagGrossMap = {};
      final Map<String, double> tagNetMap = {};
      final Map<String, double> tagDiaMap = {};
      final Map<String, double> tagStnMap = {};

      final Map<String, int> actPcsMap = {};
      final Map<String, double> actGrossMap = {};
      final Map<String, double> actNetMap = {};
      final Map<String, double> actDiaMap = {};
      final Map<String, double> actStnMap = {};

      final Map<String, Map<String, String>> keyDetailsMap = {};

      for (final bill in allBills) {
        final isPurchase = bill['billType'] == 'Purchase' || 
                           bill['type'] == 'Purchase' || 
                           (bill['voucherNo']?.toString().startsWith('PR') ?? false) || 
                           bill['category']?.toString().toLowerCase() == 'supplier';
        if (isPurchase) {
          final supCode = (bill['supplierDetails']?['supplierCode'] ?? bill['supplierDetails']?['id'] ?? bill['supplierCode'] ?? '').toString().trim();
          if (supCode.isEmpty) continue;

          if (!supplierNameMap.containsKey(supCode)) {
            final name = (bill['supplierDetails']?['name'] ?? bill['acName'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              supplierNameMap[supCode] = name;
            }
          }

          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final pcs = (item['pcs'] as num?)?.toInt() ?? 1;
                final gross = (item['grossWeight'] as num?)?.toDouble() ?? 0.0;
                final net = (item['netWeight'] as num?)?.toDouble() ?? 0.0;

                double diaWt = 0.0;
                double stnWt = 0.0;
                final extra = item['extraCharges'] as List?;
                if (extra != null) {
                  for (final ex in extra) {
                    if (ex is Map) {
                      final style = ex['styleName']?.toString().toLowerCase() ?? '';
                      final wt = (ex['weight'] as num?)?.toDouble() ?? 0.0;
                      if (style.contains('diamond') || style.contains('dm')) {
                        diaWt += wt;
                      } else if (style.contains('stone') || style.contains('st')) {
                        stnWt += wt;
                      }
                    }
                  }
                }

                final prefix = getPrefixFromTag(item['tagId']?.toString() ?? '');
                final group = (item['group'] ?? item['category'] ?? item['purity'] ?? 'Uncategorized').toString().trim();
                final key = '${supCode}_${prefix}_$group';

                keyDetailsMap[key] = {
                  'supCode': supCode,
                  'prefix': prefix,
                  'group': group,
                };

                purPcsMap[key] = (purPcsMap[key] ?? 0) + pcs;
                purGrossMap[key] = (purGrossMap[key] ?? 0.0) + gross;
                purNetMap[key] = (purNetMap[key] ?? 0.0) + net;
                purDiaMap[key] = (purDiaMap[key] ?? 0.0) + diaWt;
                purStnMap[key] = (purStnMap[key] ?? 0.0) + stnWt;
              }
            }
          }
        }
      }

      for (final doc in allInvDocs) {
        final supCode = doc['supplierCode']?.toString().trim() ?? '';
        if (supCode.isEmpty) continue;

        final pcs = (doc['pcs'] as num?)?.toInt() ?? 
                    (doc['pieces'] as num?)?.toInt() ?? 
                    (doc['quantity'] as num?)?.toInt() ?? 1;
        final gross = (doc['grossWt'] ?? doc['grossWeight'] ?? 0.0).toDouble();
        final net = (doc['netWt'] ?? doc['netWeight'] ?? 0.0).toDouble();
        final dia = (doc['diamondWt'] ?? 0.0).toDouble();
        final stn = (doc['extraStoneWt'] ?? 0.0).toDouble();

        final prefix = getPrefixFromTag(doc['tagId']?.toString() ?? doc['barcode']?.toString() ?? '');
        final group = (doc['metalGroupName'] ?? doc['groupName'] ?? doc['category'] ?? 'Uncategorized').toString().trim();
        final key = '${supCode}_${prefix}_$group';

        keyDetailsMap[key] = {
          'supCode': supCode,
          'prefix': prefix,
          'group': group,
        };

        tagPcsMap[key] = (tagPcsMap[key] ?? 0) + pcs;
        tagGrossMap[key] = (tagGrossMap[key] ?? 0.0) + gross * pcs;
        tagNetMap[key] = (tagNetMap[key] ?? 0.0) + net * pcs;
        tagDiaMap[key] = (tagDiaMap[key] ?? 0.0) + dia;
        tagStnMap[key] = (tagStnMap[key] ?? 0.0) + stn;

        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final isSold = pcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock';
        if (!isSold) {
          actPcsMap[key] = (actPcsMap[key] ?? 0) + pcs;
          actGrossMap[key] = (actGrossMap[key] ?? 0.0) + gross * pcs;
          actNetMap[key] = (actNetMap[key] ?? 0.0) + net * pcs;
          actDiaMap[key] = (actDiaMap[key] ?? 0.0) + dia;
          actStnMap[key] = (actStnMap[key] ?? 0.0) + stn;
        }
      }

      final List<SupplierStockItem> supplierStock = [];
      for (final key in keyDetailsMap.keys) {
        final details = keyDetailsMap[key]!;
        final code = details['supCode']!;
        final prefix = details['prefix']!;
        final group = details['group']!;
        final name = supplierNameMap[code] ?? code;

        supplierStock.add(SupplierStockItem(
          supplierCode: code,
          supplierName: name,
          tagPrefix: prefix,
          groupName: group,
          purchasedPcs: purPcsMap[key] ?? 0,
          purchasedGrossWt: purGrossMap[key] ?? 0.0,
          purchasedNetWt: purNetMap[key] ?? 0.0,
          purchasedDiamondWt: purDiaMap[key] ?? 0.0,
          purchasedStoneWt: purStnMap[key] ?? 0.0,
          taggedPcs: tagPcsMap[key] ?? 0,
          taggedGrossWt: tagGrossMap[key] ?? 0.0,
          taggedNetWt: tagNetMap[key] ?? 0.0,
          taggedDiamondWt: tagDiaMap[key] ?? 0.0,
          taggedStoneWt: tagStnMap[key] ?? 0.0,
          activePcs: actPcsMap[key] ?? 0,
          activeGrossWt: actGrossMap[key] ?? 0.0,
          activeNetWt: actNetMap[key] ?? 0.0,
          activeDiamondWt: actDiaMap[key] ?? 0.0,
          activeStoneWt: actStnMap[key] ?? 0.0,
        ));
      }

      if (mounted) {
        setState(() {
          _stockSummaryList = stockSummary;
          _itemWiseList = itemWise;
          _tagWiseList = tagWise;
          _counterStockList = counterStock;
          _supplierStockList = supplierStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stock report data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _dateRangeStr {
    final format = DateFormat('dd MMM yyyy');
    return '${format.format(_startDate)} - ${format.format(_endDate)}';
  }

  // PDF Export & Print Handlers
  Future<void> _handleExportPdf({bool isPrintMode = false}) async {
    final title = _reportTitles[_activeReportIndex];
    final fy = _selectedFinancialYear;
    final dr = _dateRangeStr;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(isPrintMode ? 'Preparing $title for printing...' : 'Generating $title PDF...'),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final Uint8List pdfBytes;
      switch (_activeReportIndex) {
        case 0:
          pdfBytes = await PdfStockReportApi.generateStockSummaryPdf(
            items: _stockSummaryList,
            financialYear: fy,
            dateRange: dr,
          );
          break;
        case 1:
          pdfBytes = await PdfStockReportApi.generateItemWisePdf(
            items: _itemWiseList,
            financialYear: fy,
            dateRange: dr,
          );
          break;
        case 2:
          pdfBytes = await PdfStockReportApi.generateTagWisePdf(
            items: _tagWiseList,
            financialYear: fy,
            dateRange: dr,
          );
          break;
        case 3:
          pdfBytes = await PdfStockReportApi.generateCounterStockPdf(
            items: _counterStockList,
            financialYear: fy,
            dateRange: dr,
          );
          break;
        default:
          pdfBytes = await PdfStockReportApi.generateStockSummaryPdf(
            items: _stockSummaryList,
            financialYear: fy,
            dateRange: dr,
          );
          break;
      }

      await PdfStockReportApi.printPdf(pdfBytes, title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Excel CSV Export Handler
  void _handleExportExcel() {
    final title = _reportTitles[_activeReportIndex];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Text('$title successfully exported to Excel / CSV format!'),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF5),
      body: Column(
        children: [
          // ── Common Report Header ──────────────────────────────────────────
          ReportHeader(
            title: _reportTitles[_activeReportIndex],
            selectedFinancialYear: _selectedFinancialYear,
            onFinancialYearChanged: (fy) {
              setState(() => _selectedFinancialYear = fy);
              _loadReportData();
            },
            startDate: _startDate,
            endDate: _endDate,
            onDateRangeChanged: (range) {
              setState(() {
                _startDate = range.start;
                _endDate = range.end;
              });
              _loadReportData();
            },
            onExportPdf: () => _handleExportPdf(isPrintMode: false),
            onExportExcel: _handleExportExcel,
            onPrint: () => _handleExportPdf(isPrintMode: true),
          ),

          // ── Sub Navigation Tabs Bar ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5DDD0), width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_reportTitles.length, (index) {
                  final isSelected = index == _activeReportIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ChoiceChip(
                      label: Text(_reportTitles[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _activeReportIndex = index);
                        }
                      },
                      selectedColor: const Color(0xFF3E2723),
                      backgroundColor: const Color(0xFFFCFAF5),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF5D4037),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF3E2723) : const Color(0xFFE5DDD0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Report View Body ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3E2723)),
                    ),
                  )
                : IndexedStack(
                    index: _activeReportIndex,
                    children: [
                      ClosingStockReportView(items: _stockSummaryList),
                      ItemWiseStockBalanceView(items: _itemWiseList),
                      TagWiseStockReportView(items: _tagWiseList),
                      CounterStockReportView(items: _counterStockList),
                      SupplierStockReportView(items: _supplierStockList),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
