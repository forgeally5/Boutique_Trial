import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../state/admin_state.dart';
import '../models/product.dart';
import '../utils/boutique_theme.dart';

class BulkUploadDialog extends StatefulWidget {
  const BulkUploadDialog({super.key});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  bool _isUploading = false;
  String _status = '';
  int _successCount = 0;
  int _errorCount = 0;
  final List<String> _errorLog = [];

  Future<void> _downloadTemplate() async {
    final csvData = [
      ['Tag ID', 'Name', 'Category', 'Pricing Type (Quantity-Based/Weight-Based)', 'Quantity', 'MRP', 'Selling Price', 'Vendor', 'Material', 'Notes']
    ];
    String csvStr = csv.encode(csvData);
    final bytes = utf8.encode(csvStr);
    await Printing.sharePdf(bytes: bytes, filename: 'Product_Upload_Template.csv');
  }

  Future<void> _pickAndUploadFile() async {
    final adminState = context.read<AdminState>();

    setState(() {
      _status = 'Opening file picker...';
    });

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
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
    });

    try {
      final csvString = utf8.decode(bytes);
      final rows = csv.decode(csvString);

        if (rows.isEmpty || rows.length == 1) {
          setState(() {
            _status = 'File is empty or has no data rows.';
            _isUploading = false;
          });
          return;
        }

        final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
        
        bool hasRequired = true;
        for (var req in ['tag id', 'name', 'quantity']) {
          if (!headers.contains(req)) {
            hasRequired = false;
            break;
          }
        }

        if (!hasRequired) {
           setState(() {
            _status = 'Invalid CSV format. Missing required columns (Tag ID, Name, Quantity).';
            _isUploading = false;
          });
          return;
        }

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty || row.join('').trim().isEmpty) continue; // skip empty rows

          setState(() {
            _status = 'Uploading row $i of ${rows.length - 1}...';
          });

          final Map<String, dynamic> rowData = {};
          for (int j = 0; j < headers.length; j++) {
            if (j < row.length) {
              rowData[headers[j]] = row[j];
            }
          }

          final tagId = rowData['tag id']?.toString().trim() ?? '';
          final name = rowData['name']?.toString().trim() ?? '';
          
          if (tagId.isEmpty || name.isEmpty) {
            _errorCount++;
            _errorLog.add('Row ${i + 1}: Tag ID or Name is empty.');
            continue;
          }

          if (adminState.allTagIds.contains(tagId)) {
            _errorCount++;
            _errorLog.add('Row ${i + 1}: Tag ID "$tagId" already exists.');
            continue;
          }

          try {
            double parseDouble(dynamic val) {
              if (val == null) return 0.0;
              if (val is num) return val.toDouble();
              return double.tryParse(val.toString()) ?? 0.0;
            }

            int parseInt(dynamic val) {
              if (val == null) return 0;
              if (val is num) return val.toInt();
              return int.tryParse(val.toString()) ?? 0;
            }

            final pricingType = rowData['pricing type']?.toString().trim();
            final isWeight = pricingType != null && pricingType.toLowerCase().contains('weight');

            final productData = Product(
              tagId: tagId,
              name: name,
              category: rowData['category']?.toString().trim() ?? 'Uncategorized',
              pricingType: isWeight ? 'Weight-Based' : 'Quantity-Based',
              quantity: parseInt(rowData['quantity']),
              mrp: parseDouble(rowData['mrp']),
              sellingPrice: parseDouble(rowData['selling price']),
              vendor: rowData['vendor']?.toString().trim() ?? '',
              material: rowData['material']?.toString().trim() ?? '',
              notes: rowData['notes']?.toString().trim() ?? '',
              status: 'In Stock',
              addedDate: DateTime.now(),
              
              // defaults
              grossWeight: 0.0,
              netWeight: 0.0,
              ratePerGram: 0.0,
              makingCharges: 0.0,
              weightUnit: 'g',
              issueQuantity: 0,
              reservedQuantity: 0,
              finalPrice: parseDouble(rowData['selling price']),
              discountValue: 0.0,
              discountType: '%',
            );

            await adminState.addProduct(productData);
            _successCount++;

          } catch (e) {
            _errorCount++;
            _errorLog.add('Row ${i + 1}: Error adding product "$tagId" -> $e');
          }
        }

        setState(() {
          _isUploading = false;
          _status = 'Upload complete! $_successCount added, $_errorCount failed.';
        });

      } catch (e) {
        setState(() {
          _isUploading = false;
          _status = 'Error reading file: $e';
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      title: const Row(
        children: [
          Icon(Icons.upload_file_rounded, color: BoutiqueColors.accent),
          SizedBox(width: 12),
          Text('Bulk Upload (CSV)', style: TextStyle(fontFamily: 'serif', color: BoutiqueColors.textPrimary)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload a CSV file to add multiple products at once. Please download the template first to ensure the columns are in the correct format.',
              style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BoutiqueColors.accent,
                    side: const BorderSide(color: BoutiqueColors.border),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadFile,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Select CSV File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty) ...[
              const Divider(color: BoutiqueColors.border),
              const SizedBox(height: 8),
              Text(_status, style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isUploading ? BoutiqueColors.accent : (_errorCount > 0 ? BoutiqueColors.warning : BoutiqueColors.success),
              )),
              if (_isUploading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: BoutiqueColors.accent, backgroundColor: BoutiqueColors.accentSoft),
              ],
              if (_errorLog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _errorLog.length,
                    itemBuilder: (ctx, i) => Text('• ${_errorLog[i]}', style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ),
              ]
            ],
          ],
        ),
      ),
      actions: [
        if (!_isUploading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
      ],
    );
  }
}
