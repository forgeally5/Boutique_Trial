import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../state/admin_state.dart';
import '../models/product.dart';
import '../utils/boutique_theme.dart';
import '../utils/file_downloader.dart';

enum DuplicateAction {
  addToStock,
  editName,
  skip,
}

class DuplicateConflictItem {
  final int rowIndex;
  final Product existingProduct;
  final String originalName;
  late final TextEditingController nameController;
  final String category;
  final String pricingType;
  final int importedQuantity;
  final double importedGrossWeight;
  final String importedWeightUnit;
  final double importedRatePerGram;
  final double importedMrp;
  final double importedSellingPrice;
  final double importedDiscountValue;
  final String importedDiscountType;
  final double importedFinalPrice;
  final String vendor;
  final String material;
  final String notes;

  DuplicateAction action;
  bool updatePriceToImported;

  DuplicateConflictItem({
    required this.rowIndex,
    required this.existingProduct,
    required this.originalName,
    required String newName,
    required this.category,
    required this.pricingType,
    required this.importedQuantity,
    this.importedGrossWeight = 0.0,
    this.importedWeightUnit = 'g',
    this.importedRatePerGram = 0.0,
    required this.importedMrp,
    required this.importedSellingPrice,
    required this.importedDiscountValue,
    required this.importedDiscountType,
    required this.importedFinalPrice,
    required this.vendor,
    required this.material,
    required this.notes,
    this.action = DuplicateAction.addToStock,
    this.updatePriceToImported = false,
  }) {
    nameController = TextEditingController(text: newName);
  }

  void dispose() {
    nameController.dispose();
  }
}

class BulkUploadDialog extends StatefulWidget {
  const BulkUploadDialog({super.key});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  bool _isUploading = false;
  bool _isResolvingConflicts = false;
  String _status = '';
  int _successCount = 0;
  int _errorCount = 0;
  final List<String> _errorLog = [];

  List<DuplicateConflictItem> _conflicts = [];

  static const List<String> _templateHeaders = [
    'Name',
    'Category',
    'Pricing Type (Quantity-Based/Weight-Based)',
    'Quantity',
    'Gross Weight',
    'Weight Unit (g/kg/carat)',
    'Rate per Unit (₹)',
    'MRP',
    'Selling Price',
    'Discount',
    'Discount Type (% or ₹)',
    'Vendor',
    'Material',
    'Notes'
  ];

  static const List<List<dynamic>> _sampleRows = [
    [
      'Temple Choker Set',
      'Necklaces',
      'Quantity-Based',
      10,
      0,
      'g',
      0,
      2500,
      2100,
      0,
      '%',
      'Kalyan Suppliers',
      'Brass',
      'Sample quantity product'
    ],
    [
      'Silver Kuthu Vilakku',
      'Silver/Brass Items',
      'Weight-Based',
      1,
      450.5,
      'g',
      85.0,
      0,
      0,
      0,
      '%',
      'Madurai Silvers',
      'Silver',
      'Sample weight product'
    ]
  ];

  @override
  void dispose() {
    for (final c in _conflicts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _downloadCsvTemplate() async {
    try {
      final csvData = [
        _templateHeaders,
        ..._sampleRows.map((r) => r.map((e) => e.toString()).toList()),
      ];
      final csvStr = csv.encode(csvData);
      final bytes = utf8.encode(csvStr);
      await downloadFile(
        bytes,
        'Product_Upload_Template.csv',
        'text/csv;charset=utf-8',
      );
      if (mounted) {
        BoutiqueToast.showSuccess(context, 'CSV Template downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Failed to download CSV template: $e');
      }
    }
  }

  Future<void> _downloadExcelTemplate() async {
    try {
      final xls.Workbook workbook = xls.Workbook();
      final xls.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Products Template';

      for (int col = 0; col < _templateHeaders.length; col++) {
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(_templateHeaders[col]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#8B263E';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.fontSize = 11;
      }

      for (int rowIdx = 0; rowIdx < _sampleRows.length; rowIdx++) {
        final row = _sampleRows[rowIdx];
        for (int col = 0; col < row.length; col++) {
          final cell = sheet.getRangeByIndex(rowIdx + 2, col + 1);
          final val = row[col];
          if (val is num) {
            cell.setNumber(val.toDouble());
          } else {
            cell.setText(val.toString());
          }
        }
      }

      for (int col = 1; col <= _templateHeaders.length; col++) {
        sheet.autoFitColumn(col);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      await downloadFile(
        bytes,
        'Product_Upload_Template.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Excel Template downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Failed to download Excel template: $e');
      }
    }
  }

  int _calculateMaxTagNumber(List<String> existingTags) {
    int maxVal = 0;
    for (final tag in existingTags) {
      final match = RegExp(r'\d+').firstMatch(tag);
      if (match != null) {
        final val = int.tryParse(match.group(0)!) ?? 0;
        if (val > maxVal) maxVal = val;
      }
    }
    return maxVal;
  }

  List<List<dynamic>> _parseXlsxBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final List<String> sharedStrings = [];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(sharedStringsFile.content as List<int>));
      for (final si in xmlDoc.findAllElements('si')) {
        final textBuffers = <String>[];
        for (final t in si.findAllElements('t')) {
          textBuffers.add(t.innerText);
        }
        sharedStrings.add(textBuffers.join());
      }
    }

    ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) {
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }
    }

    if (sheetFile == null) {
      throw Exception('No worksheet found in Excel file.');
    }

    final sheetDoc = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
    final rowsElements = sheetDoc.findAllElements('row');
    final List<List<dynamic>> resultRows = [];

    for (final rowElem in rowsElements) {
      final Map<int, dynamic> rowMap = {};
      int maxColIdx = 0;

      for (final cellElem in rowElem.findAllElements('c')) {
        final cellRef = cellElem.getAttribute('r') ?? '';
        final colLetters = RegExp(r'^[A-Z]+').firstMatch(cellRef)?.group(0) ?? '';
        int colIndex = 0;
        for (int i = 0; i < colLetters.length; i++) {
          colIndex = colIndex * 26 + (colLetters.codeUnitAt(i) - 64);
        }
        final colIdx0 = (colIndex > 0 ? colIndex - 1 : 0);
        if (colIdx0 > maxColIdx) maxColIdx = colIdx0;

        final cellType = cellElem.getAttribute('t');
        final valElem = cellElem.findElements('v').firstOrNull;
        final inlineStrElem = cellElem.findElements('is').firstOrNull;

        dynamic value = '';
        if (cellType == 's') {
          if (valElem != null) {
            final sIndex = int.tryParse(valElem.innerText) ?? -1;
            if (sIndex >= 0 && sIndex < sharedStrings.length) {
              value = sharedStrings[sIndex];
            }
          }
        } else if (cellType == 'inlineStr' && inlineStrElem != null) {
          value = inlineStrElem.findAllElements('t').map((e) => e.innerText).join();
        } else if (valElem != null) {
          final rawVal = valElem.innerText;
          final numVal = num.tryParse(rawVal);
          value = numVal ?? rawVal;
        }

        rowMap[colIdx0] = value;
      }

      if (rowMap.isNotEmpty) {
        final List<dynamic> fullRow = List.filled(maxColIdx + 1, '');
        rowMap.forEach((idx, val) {
          fullRow[idx] = val;
        });
        resultRows.add(fullRow);
      }
    }

    return resultRows;
  }

  Future<void> _pickAndUploadFile({required bool isExcel}) async {
    final adminState = context.read<AdminState>();

    setState(() {
      _status = 'Opening file picker...';
    });

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: isExcel ? ['xlsx', 'xls'] : ['csv'],
    );

    if (files.isEmpty) {
      setState(() {
        _status = '';
      });
      return;
    }

    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      setState(() {
        _status = 'Selected file is empty or could not be read.';
        _errorCount = 1;
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _status = 'Parsing file...';
      _successCount = 0;
      _errorCount = 0;
      _errorLog.clear();
      _conflicts.clear();
    });

    try {
      List<List<dynamic>> rows;
      if (isExcel) {
        rows = _parseXlsxBytes(bytes);
      } else {
        final csvString = utf8.decode(bytes);
        rows = csv.decode(csvString);
      }

      if (rows.isEmpty || rows.length <= 1) {
        setState(() {
          _status = 'File is empty or has no data rows.';
          _isUploading = false;
        });
        return;
      }

      final rawHeaders = rows.first;
      final headers = rawHeaders.map((e) => e.toString().trim().toLowerCase()).toList();

      if (!headers.contains('name')) {
        setState(() {
          _status = 'Invalid file format. Missing required "Name" column.';
          _isUploading = false;
        });
        return;
      }

      int currentMaxTagVal = _calculateMaxTagNumber(adminState.allTagIds);

      double parseDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString().replaceAll(',', '').trim()) ?? 0.0;
      }

      int parseInt(dynamic val) {
        if (val == null) return 1;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString().replaceAll(',', '').trim()) ?? 1;
      }

      final List<Product> directUploadList = [];
      final List<DuplicateConflictItem> detectedConflicts = [];
      final Set<String> processedNamesInBatch = {};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.map((e) => e.toString().trim()).join('').isEmpty) {
          continue;
        }

        final Map<String, dynamic> rowData = {};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            rowData[headers[j]] = row[j];
          }
        }

        final name = rowData['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          _errorCount++;
          _errorLog.add('Row ${i + 1}: Name is empty.');
          continue;
        }

        final normalizedName = name.toLowerCase();

        final pricingType = rowData['pricing type (quantity-based/weight-based)']?.toString().trim() ??
            rowData['pricing type']?.toString().trim() ??
            'Quantity-Based';
        final isWeight = pricingType.toLowerCase().contains('weight');

        final rawQty = rowData['quantity'];
        final qty = rawQty != null && rawQty.toString().trim().isNotEmpty ? parseInt(rawQty) : 1;

        final grossWeight = parseDouble(rowData['gross weight'] ?? rowData['weight'] ?? rowData['stock weight'] ?? 0);
        final rawWeightUnit = rowData['weight unit (g/kg/carat)'] ?? rowData['weight unit'] ?? rowData['weight_unit'] ?? 'g';
        final weightUnit = rawWeightUnit.toString().trim().isNotEmpty ? rawWeightUnit.toString().trim() : 'g';
        final ratePerGram = parseDouble(rowData['rate per unit (₹)'] ?? rowData['rate per gram/unit (₹)'] ?? rowData['rate per gram'] ?? rowData['rate per unit'] ?? rowData['rate'] ?? 0);

        final rawSellingPrice = parseDouble(rowData['selling price'] ?? rowData['price'] ?? 0);
        final rawMrp = parseDouble(rowData['mrp'] ?? 0);
        final rawDiscount = parseDouble(rowData['discount'] ?? rowData['discount %'] ?? rowData['discount value'] ?? rowData['discount amount'] ?? 0);

        final rawDiscountType = rowData['discount type (% or ₹)'] ?? rowData['discount type'] ?? rowData['discount_type'] ?? '%';
        String discountType = '%';
        if (rawDiscountType.toString().contains('₹') ||
            rawDiscountType.toString().toLowerCase().contains('rs') ||
            rawDiscountType.toString().toLowerCase().contains('rupee') ||
            rawDiscountType.toString().toLowerCase().contains('flat')) {
          discountType = '₹';
        } else {
          discountType = '%';
        }

        double mrp = rawMrp;
        double sellingPrice = rawSellingPrice;
        double discountValue = rawDiscount;
        double finalPrice = 0.0;

        if (isWeight && sellingPrice == 0 && ratePerGram > 0) {
          sellingPrice = (grossWeight > 0 ? grossWeight * ratePerGram : ratePerGram);
          mrp = sellingPrice;
          finalPrice = sellingPrice;
        } else if (discountValue > 0) {
          if (sellingPrice == 0 && mrp > 0) sellingPrice = mrp;
          if (mrp == 0 && sellingPrice > 0) mrp = sellingPrice;

          if (discountType == '%') {
            finalPrice = (sellingPrice - (sellingPrice * discountValue / 100)).clamp(0.0, double.infinity);
          } else {
            finalPrice = (sellingPrice - discountValue).clamp(0.0, double.infinity);
          }
        } else {
          if (mrp > 0 && sellingPrice > 0 && sellingPrice < mrp) {
            // e.g. MRP 2500 and Selling Price 2100 (auto calculate 16% discount)
            finalPrice = sellingPrice; // 2100
            sellingPrice = mrp;        // 2500 base price
            final pct = ((mrp - finalPrice) / mrp * 100);
            discountValue = double.parse(pct.toStringAsFixed(2));
            if (discountValue == discountValue.toInt()) discountValue = discountValue.toInt().toDouble();
            discountType = '%';
          } else if (sellingPrice > 0) {
            if (mrp == 0) mrp = sellingPrice;
            finalPrice = sellingPrice;
          } else if (mrp > 0) {
            sellingPrice = mrp;
            finalPrice = mrp;
          }
        }

        final category = rowData['category']?.toString().trim().isNotEmpty == true
            ? rowData['category'].toString().trim()
            : 'Uncategorized';
        final vendor = rowData['vendor']?.toString().trim() ?? '';
        final material = rowData['material']?.toString().trim() ?? '';
        final notes = rowData['notes']?.toString().trim() ?? '';

        // Check if name already exists in catalog OR duplicate inside this same file
        Product? existingProduct;
        try {
          existingProduct = adminState.allProducts.firstWhere(
            (p) => p.name.trim().toLowerCase() == normalizedName,
          );
        } catch (_) {
          existingProduct = null;
        }

        if (existingProduct == null && processedNamesInBatch.contains(normalizedName)) {
          try {
            existingProduct = directUploadList.firstWhere(
              (p) => p.name.trim().toLowerCase() == normalizedName,
            );
          } catch (_) {}
        }

        if (existingProduct != null) {
          detectedConflicts.add(DuplicateConflictItem(
            rowIndex: i + 1,
            existingProduct: existingProduct,
            originalName: name,
            newName: '$name (Copy)',
            category: category,
            pricingType: isWeight ? 'Weight-Based' : 'Quantity-Based',
            importedQuantity: qty,
            importedGrossWeight: isWeight ? grossWeight : 0.0,
            importedWeightUnit: isWeight ? weightUnit : 'g',
            importedRatePerGram: isWeight ? ratePerGram : 0.0,
            importedMrp: mrp > 0 ? mrp : sellingPrice,
            importedSellingPrice: sellingPrice,
            importedDiscountValue: discountValue,
            importedDiscountType: discountType,
            importedFinalPrice: finalPrice,
            vendor: vendor,
            material: material,
            notes: notes,
          ));
        } else {
          processedNamesInBatch.add(normalizedName);
          currentMaxTagVal++;
          final generatedTagId = 'RM-${currentMaxTagVal.toString().padLeft(3, '0')}';

          final productData = Product(
            tagId: generatedTagId,
            name: name,
            category: category,
            pricingType: isWeight ? 'Weight-Based' : 'Quantity-Based',
            quantity: qty,
            mrp: mrp > 0 ? mrp : sellingPrice,
            sellingPrice: sellingPrice,
            vendor: vendor,
            material: material,
            notes: notes,
            status: 'In Stock',
            addedDate: DateTime.now(),
            grossWeight: isWeight ? grossWeight : 0.0,
            netWeight: 0.0,
            ratePerGram: isWeight ? ratePerGram : 0.0,
            makingCharges: 0.0,
            weightUnit: isWeight ? weightUnit : 'g',
            issueQuantity: 0,
            reservedQuantity: 0,
            finalPrice: finalPrice,
            discountValue: discountValue,
            discountType: discountType,
          );
          directUploadList.add(productData);
        }
      }

      // Upload all non-conflicting products immediately
      for (int i = 0; i < directUploadList.length; i++) {
        final prod = directUploadList[i];
        setState(() {
          _status = 'Importing new product ${i + 1} of ${directUploadList.length} (${prod.name})...';
        });
        try {
          await adminState.addProduct(prod);
          _successCount++;
        } catch (e) {
          _errorCount++;
          _errorLog.add('Error adding ${prod.name}: $e');
        }
      }

      if (detectedConflicts.isNotEmpty) {
        setState(() {
          _isUploading = false;
          _conflicts = detectedConflicts;
          _isResolvingConflicts = true;
          _status = '$_successCount new products added. ${detectedConflicts.length} duplicate items need your resolution below:';
        });
      } else {
        setState(() {
          _isUploading = false;
          _status = 'Import complete! $_successCount products added, $_errorCount failed.';
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _status = 'Error reading file: $e';
      });
    }
  }

  Future<void> _applyConflictResolutions() async {
    final adminState = context.read<AdminState>();

    setState(() {
      _isUploading = true;
      _status = 'Applying duplicate resolutions...';
    });

    int currentMaxTagVal = _calculateMaxTagNumber(adminState.allTagIds);
    int resolvedCount = 0;

    for (int i = 0; i < _conflicts.length; i++) {
      final conflict = _conflicts[i];
      if (conflict.action == DuplicateAction.skip) {
        continue;
      }

      if (conflict.action == DuplicateAction.addToStock) {
        try {
          final existing = conflict.existingProduct;
          final updatedQty = existing.quantity + conflict.importedQuantity;
          final updatedPrice = conflict.updatePriceToImported && conflict.importedSellingPrice > 0
              ? conflict.importedSellingPrice
              : existing.sellingPrice;
          final updatedMrp = conflict.updatePriceToImported && conflict.importedMrp > 0
              ? conflict.importedMrp
              : existing.mrp;
          final updatedDiscount = conflict.updatePriceToImported
              ? conflict.importedDiscountValue
              : existing.discountValue;
          final updatedDiscountType = conflict.updatePriceToImported
              ? conflict.importedDiscountType
              : existing.discountType;
          final updatedFinalPrice = conflict.updatePriceToImported
              ? conflict.importedFinalPrice
              : existing.finalPrice;

          final updatedGrossWeight = existing.pricingType == 'Weight-Based'
              ? (existing.grossWeight + conflict.importedGrossWeight)
              : existing.grossWeight;
          final updatedRatePerGram = conflict.updatePriceToImported && conflict.importedRatePerGram > 0
              ? conflict.importedRatePerGram
              : existing.ratePerGram;

          final updatedProduct = existing.copyWith(
            quantity: updatedQty,
            grossWeight: updatedGrossWeight,
            ratePerGram: updatedRatePerGram,
            sellingPrice: updatedPrice,
            mrp: updatedMrp,
            discountValue: updatedDiscount,
            discountType: updatedDiscountType,
            finalPrice: updatedFinalPrice,
          );

          await adminState.updateProduct(updatedProduct);
          _successCount++;
          resolvedCount++;
        } catch (e) {
          _errorCount++;
          _errorLog.add('Error updating stock for "${conflict.originalName}": $e');
        }
      } else if (conflict.action == DuplicateAction.editName) {
        final newName = conflict.nameController.text.trim();
        if (newName.isEmpty) {
          _errorCount++;
          _errorLog.add('Row ${conflict.rowIndex}: New name cannot be empty.');
          continue;
        }

        currentMaxTagVal++;
        final generatedTagId = 'RM-${currentMaxTagVal.toString().padLeft(3, '0')}';

        try {
          final productData = Product(
            tagId: generatedTagId,
            name: newName,
            category: conflict.category,
            pricingType: conflict.pricingType,
            quantity: conflict.importedQuantity,
            mrp: conflict.importedMrp,
            sellingPrice: conflict.importedSellingPrice,
            discountValue: conflict.importedDiscountValue,
            discountType: conflict.importedDiscountType,
            finalPrice: conflict.importedFinalPrice,
            vendor: conflict.vendor,
            material: conflict.material,
            notes: conflict.notes,
            status: 'In Stock',
            addedDate: DateTime.now(),
            grossWeight: conflict.importedGrossWeight,
            netWeight: 0.0,
            ratePerGram: conflict.importedRatePerGram,
            makingCharges: 0.0,
            weightUnit: conflict.importedWeightUnit,
            issueQuantity: 0,
            reservedQuantity: 0,
          );

          await adminState.addProduct(productData);
          _successCount++;
          resolvedCount++;
        } catch (e) {
          _errorCount++;
          _errorLog.add('Error adding renamed product "$newName": $e');
        }
      }
    }

    setState(() {
      _isUploading = false;
      _isResolvingConflicts = false;
      _conflicts.clear();
      _status = 'All resolutions saved! $resolvedCount duplicate items processed successfully.';
    });

    if (mounted) {
      BoutiqueToast.showSuccess(context, 'Duplicates resolved and inventory updated successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      title: Row(
        children: [
          Icon(
            _isResolvingConflicts ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
            color: _isResolvingConflicts ? const Color(0xFFE65100) : BoutiqueColors.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            _isResolvingConflicts
                ? 'Resolve Duplicate Products (${_conflicts.length})'
                : 'Bulk Import Products',
            style: const TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: BoutiqueColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: _isResolvingConflicts
            ? _buildConflictResolutionView()
            : _buildStandardUploadView(),
      ),
      actions: [
        if (!_isUploading) ...[
          if (_isResolvingConflicts) ...[
            TextButton(
              onPressed: () => setState(() {
                _isResolvingConflicts = false;
                _conflicts.clear();
              }),
              child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: _applyConflictResolutions,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: Text('Apply & Save (${_conflicts.length} Items)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BoutiqueColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: BoutiqueColors.textSecondary)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStandardUploadView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BoutiqueColors.accentSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BoutiqueColors.accentLightBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: BoutiqueColors.accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tag IDs are auto-generated. Duplicate product names will be detected and you can choose to merge stock or rename them.',
                    style: TextStyle(color: BoutiqueColors.textPrimary, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 4 OPTIONS SECTION ──────────────────────────────────────────
          const Text(
            '1. Download Templates',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _downloadCsvTemplate,
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('CSV Template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BoutiqueColors.accent,
                    side: const BorderSide(color: BoutiqueColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _downloadExcelTemplate,
                  icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF2E7D32)),
                  label: const Text('Excel Template (.xlsx)', style: TextStyle(color: Color(0xFF2E7D32))),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFFC8E6C9)),
                    backgroundColor: const Color(0xFFF1F8E9),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            '2. Upload & Import Products',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _pickAndUploadFile(isExcel: false),
                  icon: const Icon(Icons.upload_file_rounded, size: 17),
                  label: const Text('Import CSV File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _pickAndUploadFile(isExcel: true),
                  icon: const Icon(Icons.file_present_rounded, size: 17),
                  label: const Text('Import Excel (.xlsx)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          // ─── STATUS & ERROR LOG ─────────────────────────────────────────
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Divider(color: BoutiqueColors.border),
            const SizedBox(height: 10),
            Text(
              _status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _isUploading
                    ? BoutiqueColors.accent
                    : (_errorCount > 0 ? BoutiqueColors.warning : BoutiqueColors.success),
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: BoutiqueColors.accent,
                backgroundColor: BoutiqueColors.accentSoft,
              ),
            ],
            if (_errorLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _errorLog.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${_errorLog[i]}',
                      style: const TextStyle(color: Colors.red, fontSize: 11.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildConflictResolutionView() {
    final adminState = context.watch<AdminState>();

    return SizedBox(
      height: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFE65100)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Found ${_conflicts.length} duplicate product name(s). Choose whether to add to existing stock, edit the name, or skip for each item:',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFBF360C), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView.builder(
              itemCount: _conflicts.length,
              itemBuilder: (context, idx) {
                final conflict = _conflicts[idx];
                final existing = conflict.existingProduct;
                final priceDiffers = existing.sellingPrice != conflict.importedSellingPrice;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoutiqueColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: BoutiqueColors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Row ${conflict.rowIndex}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BoutiqueColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conflict.originalName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: BoutiqueColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Existing vs Imported Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: BoutiqueColors.bgSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: BoutiqueColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ALREADY IN CATALOG',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tag: ${existing.tagId}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                                  ),
                                  Text(
                                    'Current Stock: ${existing.quantity} pcs',
                                    style: const TextStyle(fontSize: 12, color: BoutiqueColors.textPrimary),
                                  ),
                                  Text(
                                    'Current Price: ₹${existing.sellingPrice}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BoutiqueColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC8E6C9)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'IMPORTED FROM FILE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quantity: +${conflict.importedQuantity} pcs',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                  ),
                                  Text(
                                    'Imported Price: ₹${conflict.importedSellingPrice}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: priceDiffers ? const Color(0xFFE65100) : BoutiqueColors.textPrimary,
                                    ),
                                  ),
                                  if (priceDiffers)
                                    const Text(
                                      '(Price differs from existing)',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Selection
                      const Text(
                        'Select Action:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 15),
                                const SizedBox(width: 4),
                                Text('Add to Stock (${existing.quantity + conflict.importedQuantity} pcs)'),
                              ],
                            ),
                            selected: conflict.action == DuplicateAction.addToStock,
                            selectedColor: BoutiqueColors.accentSoft,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => conflict.action = DuplicateAction.addToStock);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 15),
                                SizedBox(width: 4),
                                Text('Edit Name (New Product)'),
                              ],
                            ),
                            selected: conflict.action == DuplicateAction.editName,
                            selectedColor: const Color(0xFFE3F2FD),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => conflict.action = DuplicateAction.editName);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close_rounded, size: 15),
                                SizedBox(width: 4),
                                Text('Skip Item'),
                              ],
                            ),
                            selected: conflict.action == DuplicateAction.skip,
                            selectedColor: Colors.grey.shade200,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => conflict.action = DuplicateAction.skip);
                              }
                            },
                          ),
                        ],
                      ),

                      // Sub-option for Add to Stock when Price differs
                      if (conflict.action == DuplicateAction.addToStock && priceDiffers) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              const Text(
                                'Price Conflict: ',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
                              ),
                              InkWell(
                                onTap: () => setState(() => conflict.updatePriceToImported = false),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        !conflict.updatePriceToImported ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 16,
                                        color: !conflict.updatePriceToImported ? BoutiqueColors.accent : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Keep Old Price (₹${existing.sellingPrice})', style: const TextStyle(fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => conflict.updatePriceToImported = true),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        conflict.updatePriceToImported ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 16,
                                        color: conflict.updatePriceToImported ? BoutiqueColors.accent : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Update to New Price (₹${conflict.importedSellingPrice})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Sub-option for Edit Name
                      if (conflict.action == DuplicateAction.editName) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BoutiqueColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enter Unique Product Name:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: conflict.nameController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'e.g. ${conflict.originalName} - Variation B',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: BoutiqueColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: BoutiqueColors.accent, width: 1.5),
                                  ),
                                ),
                              ),
                              if (adminState.allProducts.any((p) => p.name.trim().toLowerCase() == conflict.nameController.text.trim().toLowerCase())) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  '⚠️ This name also already exists. Please choose a different name.',
                                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
