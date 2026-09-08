import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../state/admin_state.dart';
import '../../../utils/pdf_delivery_challan_api.dart';
import '../../../utils/connectivity_helper.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';

const Color _brownDark = Color(0xFF3E2723);
const Color _brownLight = Color(0xFF8D6E63);
const Color _bgCanvas = Color(0xFFFCFAF5);
const Color _borderColor = Color(0xFFD7CCC8);

class SummaryRowData {
  final TextEditingController dateController;
  final TextEditingController descriptionController;
  final TextEditingController consigneeController;
  final TextEditingController gstinController;
  final TextEditingController soldWtController;
  final TextEditingController invoiceNoController;
  final TextEditingController taxableValueController;
  final TextEditingController sgstController;
  final TextEditingController cgstController;
  final TextEditingController igstController;
  final TextEditingController totalController;

  SummaryRowData()
      : dateController = TextEditingController(),
        descriptionController = TextEditingController(),
        consigneeController = TextEditingController(),
        gstinController = TextEditingController(),
        soldWtController = TextEditingController(),
        invoiceNoController = TextEditingController(),
        taxableValueController = TextEditingController(),
        sgstController = TextEditingController(),
        cgstController = TextEditingController(),
        igstController = TextEditingController(),
        totalController = TextEditingController();

  void dispose() {
    dateController.dispose();
    descriptionController.dispose();
    consigneeController.dispose();
    gstinController.dispose();
    soldWtController.dispose();
    invoiceNoController.dispose();
    taxableValueController.dispose();
    sgstController.dispose();
    cgstController.dispose();
    igstController.dispose();
    totalController.dispose();
  }

  void clear() {
    dateController.clear();
    descriptionController.clear();
    consigneeController.clear();
    gstinController.clear();
    soldWtController.clear();
    invoiceNoController.clear();
    taxableValueController.clear();
    sgstController.clear();
    cgstController.clear();
    igstController.clear();
    totalController.clear();
  }
}

class DeliveryChallanView extends StatefulWidget {
  final AdminState? state;
  final VoidCallback? onBack;
  final Map<String, dynamic>? initialData;
  final bool isViewOnly;

  const DeliveryChallanView({super.key, this.state, this.onBack, this.initialData, this.isViewOnly = false});

  @override
  State<DeliveryChallanView> createState() => _DeliveryChallanViewState();
}

class _DeliveryChallanViewState extends State<DeliveryChallanView> {
  // Top Header Metadata
  late TextEditingController _challanNoController;
  late TextEditingController _dateController;

  // Consignee Section Controllers
  late TextEditingController _consigneeNameController;
  late TextEditingController _consigneeAddressController;
  late TextEditingController _consigneeGstinController;

  // Fixed Top Rows
  late TextEditingController _descGoodsHsnController;
  late TextEditingController _quantityGoodsController;
  late TextEditingController _valueGoodsController;
  late TextEditingController _purposeTransportController;
  late TextEditingController _personCarryingController;
  late TextEditingController _transportDetailsController;
  late TextEditingController _destinationDetailsController;

  // Bottom Section Controllers
  late TextEditingController _openingStockController;
  late TextEditingController _totalSaleController;

  // Summary Rows
  final List<SummaryRowData> _summaryRows = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _challanNoController = TextEditingController(text: data['challanNo']?.toString() ?? 'DC/2/2026-27');
      _dateController = TextEditingController(text: data['date']?.toString() ?? '10-07-2026');
      _consigneeNameController = TextEditingController(text: data['consigneeName']?.toString() ?? '');
      _consigneeAddressController = TextEditingController(text: data['consigneeAddress']?.toString() ?? '');
      _consigneeGstinController = TextEditingController(text: data['consigneeGstin']?.toString() ?? '');
      _descGoodsHsnController = TextEditingController(text: data['descGoodsHsn']?.toString() ?? '');
      _quantityGoodsController = TextEditingController(text: data['quantityGoods']?.toString() ?? '');
      _valueGoodsController = TextEditingController(text: data['valueGoods']?.toString() ?? '');
      _purposeTransportController = TextEditingController(text: data['purposeTransport']?.toString() ?? '');
      _personCarryingController = TextEditingController(text: data['personCarrying']?.toString() ?? '');
      _transportDetailsController = TextEditingController(text: data['transportDetails']?.toString() ?? '');
      _destinationDetailsController = TextEditingController(text: data['destinationDetails']?.toString() ?? '');
      _openingStockController = TextEditingController(text: data['openingStock']?.toString() ?? '');
      _totalSaleController = TextEditingController(text: data['totalSale']?.toString() ?? '');

      final List rawList = data['summaryItems'] as List? ?? [];
      for (final item in rawList) {
        if (item is Map) {
          final row = SummaryRowData();
          row.dateController.text = item['date']?.toString() ?? '';
          row.descriptionController.text = item['description']?.toString() ?? '';
          row.consigneeController.text = item['consigneeName']?.toString() ?? '';
          row.gstinController.text = item['gstin']?.toString() ?? '';
          row.soldWtController.text = item['soldWt']?.toString() ?? '';
          row.invoiceNoController.text = item['invoiceNo']?.toString() ?? '';
          row.taxableValueController.text = item['taxableValue']?.toString() ?? '';
          row.sgstController.text = item['sgst']?.toString() ?? '';
          row.cgstController.text = item['cgst']?.toString() ?? '';
          row.igstController.text = item['igst']?.toString() ?? '';
          row.totalController.text = item['total']?.toString() ?? '';
          _summaryRows.add(row);
        }
      }
    } else {
      _challanNoController = TextEditingController(text: 'DC/2/2026-27');
      _dateController = TextEditingController(text: '10-07-2026');
      _consigneeNameController = TextEditingController();
      _consigneeAddressController = TextEditingController();
      _consigneeGstinController = TextEditingController();
      _descGoodsHsnController = TextEditingController();
      _quantityGoodsController = TextEditingController();
      _valueGoodsController = TextEditingController();
      _purposeTransportController = TextEditingController();
      _personCarryingController = TextEditingController();
      _transportDetailsController = TextEditingController();
      _destinationDetailsController = TextEditingController();
      _openingStockController = TextEditingController();
      _totalSaleController = TextEditingController();
    }

    // Ensure we have at least 5 rows
    if (_summaryRows.length < 5) {
      final needed = 5 - _summaryRows.length;
      for (int i = 0; i < needed; i++) {
        _summaryRows.add(SummaryRowData());
      }
    }
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    _dateController.dispose();

    _consigneeNameController.dispose();
    _consigneeAddressController.dispose();
    _consigneeGstinController.dispose();

    _descGoodsHsnController.dispose();
    _quantityGoodsController.dispose();
    _valueGoodsController.dispose();
    _purposeTransportController.dispose();
    _personCarryingController.dispose();
    _transportDetailsController.dispose();
    _destinationDetailsController.dispose();

    _openingStockController.dispose();
    _totalSaleController.dispose();

    for (var row in _summaryRows) {
      row.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addSummaryRow() {
    setState(() {
      _summaryRows.add(SummaryRowData());
    });
  }

  void _removeSummaryRow(int index) {
    if (_summaryRows.length <= 1) return;
    setState(() {
      final removed = _summaryRows.removeAt(index);
      removed.dispose();
    });
  }

  void _clearAllFields() {
    setState(() {
      _challanNoController.clear();
      _dateController.clear();
      _consigneeNameController.clear();
      _consigneeAddressController.clear();
      _consigneeGstinController.clear();
      _descGoodsHsnController.clear();
      _quantityGoodsController.clear();
      _valueGoodsController.clear();
      _purposeTransportController.clear();
      _personCarryingController.clear();
      _transportDetailsController.clear();
      _destinationDetailsController.clear();
      _openingStockController.clear();
      _totalSaleController.clear();

      for (var row in _summaryRows) {
        row.clear();
      }
    });
  }

  Future<void> _saveChallan() async {
    try {
      final List<Map<String, dynamic>> summaryItemsList = [];
      for (final r in _summaryRows) {
        if (r.dateController.text.trim().isNotEmpty ||
            r.descriptionController.text.trim().isNotEmpty ||
            r.soldWtController.text.trim().isNotEmpty ||
            r.invoiceNoController.text.trim().isNotEmpty ||
            r.taxableValueController.text.trim().isNotEmpty ||
            r.totalController.text.trim().isNotEmpty) {
          summaryItemsList.add({
            'date': r.dateController.text.trim(),
            'description': r.descriptionController.text.trim(),
            'consigneeName': r.consigneeController.text.trim(),
            'gstin': r.gstinController.text.trim(),
            'soldWt': r.soldWtController.text.trim(),
            'invoiceNo': r.invoiceNoController.text.trim(),
            'taxableValue': r.taxableValueController.text.trim(),
            'sgst': r.sgstController.text.trim(),
            'cgst': r.cgstController.text.trim(),
            'igst': r.igstController.text.trim(),
            'total': r.totalController.text.trim(),
          });
        }
      }

      final challanData = {
        'challanNo': _challanNoController.text.trim(),
        'date': _dateController.text.trim(),
        'consigneeName': _consigneeNameController.text.trim(),
        'consigneeAddress': _consigneeAddressController.text.trim(),
        'consigneeGstin': _consigneeGstinController.text.trim(),
        'descGoodsHsn': _descGoodsHsnController.text.trim(),
        'quantityGoods': _quantityGoodsController.text.trim(),
        'valueGoods': _valueGoodsController.text.trim(),
        'purposeTransport': _purposeTransportController.text.trim(),
        'personCarrying': _personCarryingController.text.trim(),
        'transportDetails': _transportDetailsController.text.trim(),
        'destinationDetails': _destinationDetailsController.text.trim(),
        'openingStock': _openingStockController.text.trim(),
        'totalSale': _totalSaleController.text.trim(),
        'summaryItems': summaryItemsList,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final bool isOnline = await ConnectivityHelper.isOnline();

      if (isOnline) {
        if (widget.initialData != null && widget.initialData!['docId'] != null) {
          final docId = widget.initialData!['docId'] as String;
          await FirebaseFirestore.instance.collection('delivery_challans').doc(docId).update(challanData);
        } else {
          await FirebaseFirestore.instance.collection('delivery_challans').add(challanData);
        }
      } else {
        if (!_challanNoController.text.endsWith('-OFF')) {
          _challanNoController.text = '${_challanNoController.text}-OFF';
          challanData['challanNo'] = _challanNoController.text;
        }
        final docId = widget.initialData?['docId'] as String?;
        await LocalDbService().insertEntry(
          'delivery_challans', 
          challanData, 
          operation: docId != null ? 'UPDATE' : 'ADD',
          docId: docId,
        );
        SyncService().syncNow();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Challan saved successfully!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (widget.onBack != null) {
        if (!mounted) return;
        Navigator.pop(context, {
          'challanNo': _challanNoController.text.trim(),
          'date': _dateController.text.trim(),
          'consigneeName': _consigneeNameController.text.trim(),
          'consigneeGstin': _consigneeGstinController.text.trim(),
          'purposeTransport': _purposeTransportController.text.trim(),
          'quantityGoods': _quantityGoodsController.text.trim(),
          'valueGoods': _valueGoodsController.text.trim(),
        });
        return;
      }

      _clearAllFields();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save challan: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _printChallan() async {
    try {
      final printData = DeliveryChallanPrintData(
        challanNo: _challanNoController.text,
        date: _dateController.text,
        consigneeName: _consigneeNameController.text,
        consigneeAddress: _consigneeAddressController.text,
        consigneeGstin: _consigneeGstinController.text,
        descGoodsHsn: _descGoodsHsnController.text,
        quantityGoods: _quantityGoodsController.text,
        valueGoods: _valueGoodsController.text,
        purposeTransport: _purposeTransportController.text,
        personCarrying: _personCarryingController.text,
        transportDetails: _transportDetailsController.text,
        destinationDetails: _destinationDetailsController.text,
        openingStock: _openingStockController.text,
        totalSale: _totalSaleController.text,
        summaryItems: List.generate(_summaryRows.length, (index) {
          final r = _summaryRows[index];
          return DeliveryChallanSummaryItem(
            sNo: '${index + 1}',
            date: r.dateController.text,
            description: r.descriptionController.text,
            consigneeName: r.consigneeController.text,
            gstin: r.gstinController.text,
            soldWt: r.soldWtController.text,
            invoiceNo: r.invoiceNoController.text,
            taxableValue: r.taxableValueController.text,
            sgst: r.sgstController.text,
            cgst: r.cgstController.text,
            igst: r.igstController.text,
            total: r.totalController.text,
          );
        }),
      );

      await Printing.layoutPdf(
        onLayout: (format) => PdfDeliveryChallanApi.generate(printData, format: format),
        format: PdfPageFormat.a4.landscape,
        name: 'Delivery_Challan_${_challanNoController.text}',
      );
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugPrint("DELIVERY CHALLAN PRINT ERROR: $e\n$stackTrace");
    }
  }

  Widget _buildFormField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _brownDark,
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: maxLines > 1 ? null : 28,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            enabled: !widget.isViewOnly,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _brownDark),
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _brownDark,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildGridHeader(String title, int flex, {bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brownDark),
        ),
      ),
    );
  }

  Widget _buildGridTextFieldCell(TextEditingController controller, int flex, {bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          enabled: !widget.isViewOnly,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SUMMARY ITEMS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _brownDark,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.isViewOnly ? null : _addSummaryRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brownDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth > 1200 ? constraints.maxWidth : 1200;
              return Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: tableWidth,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: _borderColor),
                        bottom: BorderSide(color: _borderColor),
                      ),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table Header Row
                        Container(
                          color: const Color(0xFFEEEEEE),
                          child: Row(
                            children: [
                              _buildGridHeader('Date', 2),
                              _buildGridHeader('Description', 2),
                              _buildGridHeader('Sold Wt', 1),
                              _buildGridHeader('Invoice No', 2),
                              _buildGridHeader('Taxable Value', 2),
                              _buildGridHeader('SGST 1.5%', 1),
                              _buildGridHeader('CGST 1.5%', 1),
                              _buildGridHeader('IGST 3%', 1),
                              _buildGridHeader('Total', 2),
                              _buildGridHeader('', 1, isLast: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.grey, thickness: 1),
                        
                        // Table Body Rows
                        ...List.generate(_summaryRows.length, (idx) {
                          final row = _summaryRows[idx];
                          return Container(
                            color: const Color(0xFFF5F5F5),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildGridTextFieldCell(row.dateController, 2),
                                    _buildGridTextFieldCell(row.descriptionController, 2),
                                    _buildGridTextFieldCell(row.soldWtController, 1),
                                    _buildGridTextFieldCell(row.invoiceNoController, 2),
                                    _buildGridTextFieldCell(row.taxableValueController, 2),
                                    _buildGridTextFieldCell(row.sgstController, 1),
                                    _buildGridTextFieldCell(row.cgstController, 1),
                                    _buildGridTextFieldCell(row.igstController, 1),
                                    _buildGridTextFieldCell(row.totalController, 2),
                                    Expanded(
                                      flex: 1,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        onPressed: widget.isViewOnly ? null : () => _removeSummaryRow(idx),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1, color: Colors.grey, thickness: 1),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      body: Column(
        children: [
          // ── Action Toolbar Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: _borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: _brownDark, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Delivery Challan Entry',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _brownDark,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (!widget.isViewOnly) ...[
                  ElevatedButton.icon(
                    onPressed: _saveChallan,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brownDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: _printChallan,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2B3D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onBack ?? _clearAllFields,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brownDark,
                    side: const BorderSide(color: _brownLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Form Body ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: double.infinity),
                  child: Column(
                    children: [
                      // Section 1: General Details
                      _buildSectionCard('GENERAL DETAILS', [
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Challan No.', _challanNoController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Date', _dateController)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Section 2: Consignee Details
                      _buildSectionCard('CONSIGNEE DETAILS', [
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Name of the Consignee', _consigneeNameController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Consignee GSTIN', _consigneeGstinController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFormField('Consignee Address', _consigneeAddressController, maxLines: 2),
                      ]),
                      const SizedBox(height: 16),

                      // Section 3: Goods & Transport Details
                      _buildSectionCard('GOODS & TRANSPORT DETAILS', [
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Description of Goods & HSN Code', _descGoodsHsnController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Quantity of Goods', _quantityGoodsController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Value of Goods', _valueGoodsController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Purpose of Transport', _purposeTransportController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Person Carrying the Goods', _personCarryingController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Transport Details', _transportDetailsController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Destination Details & Intra/Inter State', _destinationDetailsController)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Section 4: Summary Items Table
                      _buildSummaryTable(),
                      const SizedBox(height: 16),

                      // Section 5: Stock Details
                      _buildSectionCard('STOCK DETAILS', [
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Opening Stock', _openingStockController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFormField('Total Sale', _totalSaleController)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
