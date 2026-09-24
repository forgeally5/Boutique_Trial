import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../state/admin_state.dart';
import '../../models/product.dart';
import 'bill_row_model.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/boutique_pdf_generator.dart';

class CreateBillScreen extends StatefulWidget {
  final AdminState state;
  final VoidCallback? onSaved;
  const CreateBillScreen({super.key, required this.state, this.onSaved});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _fmt = DateFormat('dd/MM/yyyy');

  final _billNoCtrl = TextEditingController();
  DateTime _billDate = DateTime.now();
  final _customerNameCtrl = TextEditingController();
  final _customerMobileCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  bool _showExtraCustomerDetails = false;
  final List<Map<String, TextEditingController>> _customFields = [];

  final List<BillRow> _rows = [BillRow()];

  // Summary controllers — managed separately so only summary panel rebuilds
  final _extraDiscountCtrl = TextEditingController(text: '0');
  String _extraDiscountType = '₹';

  final _gstCtrl = TextEditingController(text: '0');
  String _gstType = 'No GST';

  final _adjustmentCtrl = TextEditingController(text: '');

  String _paymentMode = 'Cash';

  bool _isSaving = false;
  bool _attemptedSave = false;

  String _billType = 'Sale';
  final _narrationCtrl = TextEditingController();
  final _amountReceivedCtrl = TextEditingController();

  // Tracks row mutations (product select, qty change) so summary panel recalculates
  final ValueNotifier<int> _rowVersion = ValueNotifier(0);

  // Cached product list — read from state once, not on every rebuild
  List<Product> _cachedProducts = [];

  List<String> _knownCustomers = [];

  @override
  void initState() {
    super.initState();
    _cachedProducts = widget.state.products;
    _fetchNextBillNo();
    _fetchCustomerNames();
    // Listen to AdminState for product list updates ONLY — no full-form rebuild
    widget.state.addListener(_onStateProductsUpdate);
    _gstCtrl.addListener(_onGstChanged);
  }

  Future<void> _fetchCustomerNames() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .orderBy('billDate', descending: true)
          .limit(200)
          .get();
      final names = <String>{};
      for (final doc in snap.docs) {
        final name = doc.data()['customerName']?.toString().trim();
        if (name != null && name.isNotEmpty && name.toLowerCase() != 'walk-in' && name.toLowerCase() != 'walk-in customer') {
          names.add(name);
        }
      }
      if (mounted) setState(() => _knownCustomers = names.toList()..sort());
    } catch (_) {}
  }

  void _onGstChanged() {
    final val = _gstCtrl.text.trim();
    String expectedType = 'Custom';
    if (val == '0' || val.isEmpty) expectedType = 'No GST';
    else if (val == '5' || val == '5.0') expectedType = '5%';
    else if (val == '12' || val == '12.0') expectedType = '12%';
    else if (val == '18' || val == '18.0') expectedType = '18%';
    else if (val == '28' || val == '28.0') expectedType = '28%';

    if (_gstType != expectedType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _gstType = expectedType);
      });
    }
  }

  void _onStateProductsUpdate() {
    // Only update products cache — does NOT rebuild the whole form
    final fresh = widget.state.products;
    if (fresh != _cachedProducts) {
      setState(() => _cachedProducts = fresh);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateProductsUpdate);
    _rowVersion.dispose();
    _billNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    _customerAddressCtrl.dispose();
    for (var f in _customFields) {
      f['key']?.dispose();
      f['value']?.dispose();
    }
    _extraDiscountCtrl.dispose();
    _gstCtrl.dispose();
    _narrationCtrl.dispose();
    _amountReceivedCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNextBillNo() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      int nextNum = 1;
      if (snap.docs.isNotEmpty) {
        final lastNo = snap.docs.first.data()['billNo'] as String? ?? '';
        final match = RegExp(r'\d+').firstMatch(lastNo);
        if (match != null) {
          nextNum = (int.tryParse(match.group(0)!) ?? 0) + 1;
        }
      }
      if (mounted) _billNoCtrl.text = 'SB-${nextNum.toString().padLeft(3, '0')}';
    } catch (_) {
      if (mounted) _billNoCtrl.text = 'SB-001';
    }
  }

  // ── Calculation Helpers ───────────────────────────────────────────────────

  double get _subtotal => _rows.fold(0, (s, r) => s + r.lineAmount);

  double _extraDiscountAmount(double subtotal) {
    final v = double.tryParse(_extraDiscountCtrl.text) ?? 0;
    if (_extraDiscountType == '%') return (subtotal * v / 100).clamp(0, subtotal);
    return v.clamp(0, subtotal);
  }


  String? _mobileError() {
    if (!_attemptedSave) return null; // show only after first save attempt
    final m = _customerMobileCtrl.text.trim();
    if (m.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(m)) return 'Must be 10 digits';
    return null;
  }

  bool get _hasValidRows => _rows.any((r) => r.isValid);

  bool get _canSave {
    if (!_hasValidRows) return false;
    final m = _customerMobileCtrl.text.trim();
    if (m.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(m)) return false;
    return true;
  }

  Future<void> _saveBill(bool isSplit, String singleMode, List<Map<String, dynamic>> splitPayments) async {
    setState(() => _attemptedSave = true);
    if (!_canSave) {
      BoutiqueToast.showError(context, 'Please fill in all required fields correctly.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final validRows = _rows.where((r) => r.isValid).toList();
      final subtotal = _subtotal;
      final discAmt = _extraDiscountAmount(subtotal);
      final discounted = (subtotal - discAmt).clamp(0.0, double.infinity);
      final gstPercent = double.tryParse(_gstCtrl.text) ?? 0.0;
      final taxAmt = (subtotal * (gstPercent / 100)).clamp(0.0, double.infinity);
      final computedTotal = (discounted + taxAmt).clamp(0.0, double.infinity);
      final manualTotal = double.tryParse(_adjustmentCtrl.text);
      final adjustment = manualTotal != null ? manualTotal - computedTotal : 0.0;
      final totalPayable = (computedTotal + adjustment).clamp(0.0, double.infinity);
      final amountReceived = _billType == 'Advance Payment'
          ? (double.tryParse(_amountReceivedCtrl.text) ?? totalPayable)
          : totalPayable;
      final pendingBalance = (totalPayable - amountReceived).clamp(0.0, double.infinity);

      final billData = {
        'billNo': _billNoCtrl.text.trim(),
        'billType': _billType,
        'narration': _narrationCtrl.text.trim(),
        'billDate': Timestamp.fromDate(_billDate),
        'customerName': _customerNameCtrl.text.trim(),
        'customerMobile': _customerMobileCtrl.text.trim(),
        'customerAddress': _customerAddressCtrl.text.trim(),
        'customCustomerDetails': {
          for (var field in _customFields)
            if (field['key']!.text.trim().isNotEmpty)
              field['key']!.text.trim(): field['value']!.text.trim()
        },
        'items': validRows.map((r) => r.toMap()).toList(),
        'subtotal': subtotal,
        'extraDiscountType': _extraDiscountType,
        'extraDiscountValue': double.tryParse(_extraDiscountCtrl.text) ?? 0,
        'extraDiscountAmount': discAmt,
        'gstPercent': gstPercent,
        'taxAmount': taxAmt,
        'adjustmentAmount': adjustment,
        'totalPayable': totalPayable,
        'paymentMode': isSplit ? 'Split Payment' : singleMode,
        'payments': isSplit ? splitPayments : [{'mode': singleMode, 'amount': amountReceived}],
        'amountReceived': amountReceived,
        'pendingBalance': pendingBalance,
        'balanceReturned': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('bills').add(billData);

      // Aggregate quantities for stock deduction
      final Map<String, double> deductionMap = {};
      final Map<String, double> reservedDeductionMap = {};
      final Map<String, Product> productMap = {};
      for (final row in validRows) {
        final p = row.product!;
        if (row.isFromReserve) {
          reservedDeductionMap[p.tagId] = (reservedDeductionMap[p.tagId] ?? 0) + row.qty;
        } else {
          deductionMap[p.tagId] = (deductionMap[p.tagId] ?? 0) + row.qty;
        }
        productMap[p.tagId] = p;
      }

      for (final tagId in productMap.keys) {
        final p = productMap[tagId]!;
        final regularDeducted = (deductionMap[tagId] ?? 0).toInt();
        final reservedDeducted = (reservedDeductionMap[tagId] ?? 0).toInt();
        final totalDeducted = regularDeducted + reservedDeducted;
        
        final newQty = (p.quantity - totalDeducted).clamp(0, 999999);
        final newReservedQty = (p.reservedQuantity - reservedDeducted).clamp(0, 999999);
        
        final updated = p.copyWith(
          quantity: newQty,
          reservedQuantity: newReservedQty,
          isReserved: newReservedQty > 0 ? p.isReserved : false,
          reservedFor: newReservedQty > 0 ? p.reservedFor : '',
          status: newQty == 0 ? 'Sold Out' : p.status,
        );
        await widget.state.updateProduct(updated);
      }

      if (mounted) {
        final billNo = _billNoCtrl.text.trim();
        _resetForm();
        widget.onSaved?.call();
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: BoutiqueColors.bgCard,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF81C784), width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 42),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bill Saved!',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: BoutiqueColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bill #$billNo has been saved\nsuccessfully.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: BoutiqueColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BoutiqueColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Error saving bill: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _fetchNextBillNo();
    setState(() {
      _billDate = DateTime.now();
      _customerNameCtrl.clear();
      _customerMobileCtrl.clear();
      _rows.clear();
      _rows.add(BillRow());
      _extraDiscountCtrl.text = '0';
      _gstCtrl.text = '0';
      _gstType = 'No GST';
      _adjustmentCtrl.text = '';
      _billType = 'Sale';
      _narrationCtrl.clear();
      _amountReceivedCtrl.clear();
      _attemptedSave = false;
    });
  }

  Future<void> _downloadInvoice() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    final subtotal = _subtotal;
    final discAmt = _extraDiscountAmount(subtotal);
    final discounted = (subtotal - discAmt).clamp(0.0, double.infinity);
    final gstPercent = double.tryParse(_gstCtrl.text) ?? 0.0;
    final taxAmt = (subtotal * (gstPercent / 100)).clamp(0.0, double.infinity);
    final computedTotal = (discounted + taxAmt).clamp(0.0, double.infinity);
    final manualTotal = double.tryParse(_adjustmentCtrl.text);
    final adjustment = manualTotal != null ? manualTotal - computedTotal : 0.0;
    final totalPayable = (computedTotal + adjustment).clamp(0.0, double.infinity);
    final amountReceived = _billType == 'Advance Payment'
        ? (double.tryParse(_amountReceivedCtrl.text) ?? totalPayable)
        : totalPayable;
    final pendingBalance = (totalPayable - amountReceived).clamp(0.0, double.infinity);

    final billData = {
      'billNo': _billNoCtrl.text.trim(),
      'billType': _billType,
      'narration': _narrationCtrl.text.trim(),
      'billDate': Timestamp.fromDate(_billDate),
      'customerName': _customerNameCtrl.text.trim(),
      'customerMobile': _customerMobileCtrl.text.trim(),
      'items': validRows.map((r) => r.toMap()).toList(),
      'subtotal': subtotal,
      'extraDiscountAmount': discAmt,
      'taxAmount': taxAmt,
      'adjustmentAmount': adjustment,
      'totalPayable': totalPayable,
      'amountReceived': amountReceived,
      'pendingBalance': pendingBalance,
    };

    final bytes = await BoutiquePdfGenerator.generate(billData);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 9,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: isHeader ? PdfColors.white : null,
        ),
      ),
    );
  }

  static pw.Widget _pdfTotalRow(String label, String value, PdfColor tColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // NOTE: No ListenableBuilder(widget.state) here — we track products via
  // _onStateProductsUpdate() listener which only updates _cachedProducts.
  // This prevents AdminState Firestore events from rebuilding the whole form.

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Customer Info + Item Table
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  _buildCustomerSection(),
                  const SizedBox(height: 24),
                  _buildItemTable(),
                ],
              ),
            ),
          ),

          // Right: Summary Panel — isolated widget that manages its own rebuilds
          Expanded(
            flex: 5,
            child: Container(
              height: double.infinity,
              color: BoutiqueColors.bgCard,
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: _BillSummaryPanel(
                  rows: _rows,
                  rowVersion: _rowVersion,
                  extraDiscountCtrl: _extraDiscountCtrl,
                  extraDiscountType: _extraDiscountType,
                  gstCtrl: _gstCtrl,
                  gstType: _gstType,
                  adjustmentCtrl: _adjustmentCtrl,
                  billType: _billType,
                  amountReceivedCtrl: _amountReceivedCtrl,
                  isSaving: _isSaving,
                  hasValidRows: _hasValidRows,
                  onDiscountTypeChanged: (t) => setState(() => _extraDiscountType = t),
                  onGstTypeChanged: (t) {
                    setState(() {
                      _gstType = t;
                      if (t == 'No GST') _gstCtrl.text = '0';
                      else if (t == '5%') _gstCtrl.text = '5';
                      else if (t == '12%') _gstCtrl.text = '12';
                      else if (t == '18%') _gstCtrl.text = '18';
                      else if (t == '28%') _gstCtrl.text = '28';
                    });
                  },
                  onSave: (isSplit, singleMode, splitPayments) => _saveBill(isSplit, singleMode, splitPayments),
                  onDownload: _downloadInvoice,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoutiqueDecoration.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer & Invoice Details',
                  style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
              TextButton.icon(
                onPressed: () => setState(() => _showExtraCustomerDetails = !_showExtraCustomerDetails),
                icon: Icon(_showExtraCustomerDetails ? Icons.expand_less : Icons.add, size: 18, color: BoutiqueColors.accent),
                label: Text(_showExtraCustomerDetails ? 'Hide Extra Details' : 'Add Customer Details', style: const TextStyle(color: BoutiqueColors.accent, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _billNoCtrl,
                  readOnly: true,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                  decoration: BoutiqueInputDecoration.field(hintText: 'Bill No', labelText: 'Invoice #'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _billType,
                  style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                  decoration: BoutiqueInputDecoration.field(hintText: 'Bill Type', labelText: 'Bill Type'),
                  items: const [
                    DropdownMenuItem(value: 'Sale', child: Text('Sale')),
                    DropdownMenuItem(value: 'Advance Payment', child: Text('Advance Payment')),
                  ],
                  onChanged: (v) => setState(() => _billType = v ?? 'Sale'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: BoutiqueColors.bgSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BoutiqueColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: BoutiqueColors.accent),
                        const SizedBox(width: 10),
                        Text(_fmt.format(_billDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Customer name autocomplete
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: _customerNameCtrl,
                  focusNode: FocusNode(),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    final query = textEditingValue.text.toLowerCase();
                    return _knownCustomers.where((name) =>
                        name.toLowerCase().contains(query));
                  },
                  fieldViewBuilder: (BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: const TextStyle(fontSize: 13),
                      decoration: BoutiqueInputDecoration.field(
                          hintText: 'Walk-in Customer', labelText: 'Customer Name'),
                      onSubmitted: (String value) {
                        onFieldSubmitted();
                      },
                    );
                  },
                  optionsViewBuilder: (BuildContext context,
                      AutocompleteOnSelected<String> onSelected,
                      Iterable<String> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(option, style: const TextStyle(fontSize: 13)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Mobile field — error shown only after save attempt, not on every keystroke
              Expanded(
                child: TextField(
                  controller: _customerMobileCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(
                    hintText: '10-digit mobile',
                    labelText: 'Mobile Number',
                    errorText: _mobileError(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _narrationCtrl,
            style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
            decoration: BoutiqueInputDecoration.field(hintText: 'Narration / Remarks', labelText: 'Narration'),
          ),
          if (_showExtraCustomerDetails) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customerAddressCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: BoutiqueInputDecoration.field(
                hintText: 'Full Address',
                labelText: 'Address',
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < _customFields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _customFields[i]['key'],
                        style: const TextStyle(fontSize: 13),
                        decoration: BoutiqueInputDecoration.field(
                          hintText: 'Field Name (e.g. Email)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _customFields[i]['value'],
                        style: const TextStyle(fontSize: 13),
                        decoration: BoutiqueInputDecoration.field(
                          hintText: 'Value',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: BoutiqueColors.destructive),
                      onPressed: () {
                        final removed = _customFields.removeAt(i);
                        removed['key']?.dispose();
                        removed['value']?.dispose();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _customFields.add({
                    'key': TextEditingController(),
                    'value': TextEditingController(),
                  });
                }),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Custom Field'),
                style: TextButton.styleFrom(
                  foregroundColor: BoutiqueColors.accent,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoutiqueDecoration.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Products to Bill',
                  style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showReservedItemsList,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB45309),
                      side: const BorderSide(color: Color(0xFFFFCC80)),
                      backgroundColor: const Color(0xFFFFF3E0),
                    ),
                    icon: const Icon(Icons.bookmark_added_rounded, size: 16),
                    label: const Text('Reserved List'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _rows.add(BillRow())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accentSoft,
                      foregroundColor: BoutiqueColors.accent,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Row'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Each row is its own StatefulWidget — changes in one row don't rebuild others
          for (int i = 0; i < _rows.length; i++)
            _BillRowWidget(
              key: ObjectKey(_rows[i]),
              row: _rows[i],
              products: _cachedProducts,
              getAvailableStock: _getAvailableStock,
              onChanged: () {
                _rowVersion.value++; // notify summary panel
                setState(() {});    // refresh row display (qty, line amount)
              },
              onDelete: _rows.length > 1
                  ? () {
                      _rowVersion.value++;
                      setState(() => _rows.removeAt(i));
                    }
                  : null,
            ),
        ],
      ),
    );
  }

  int _getAvailableStock(Product p, [BillRow? currentRow]) {
    double usedInOtherRows = 0;
    bool isReserveCheck = currentRow?.isFromReserve ?? false;
    
    for (final r in _rows) {
      if (r != currentRow && r.product != null) {
        if (r.product!.tagId.trim().toLowerCase() == p.tagId.trim().toLowerCase()) {
          // If we are checking available reserve stock, only count other rows that ALSO use reserve stock.
          if (isReserveCheck) {
            if (r.isFromReserve) usedInOtherRows += r.qty;
          } else {
            // Normal stock check: count other rows that use normal stock
            if (!r.isFromReserve) usedInOtherRows += r.qty;
          }
        }
      }
    }
    
    final int baseStock = isReserveCheck ? p.reservedQuantity : p.sellableQuantity;
    final remaining = baseStock - usedInOtherRows.toInt();
    return remaining < 0 ? 0 : remaining;
  }
  void _showReservedItemsList() {
    final reservedItems = _cachedProducts.where((p) => p.isReserved && p.reservedQuantity > 0).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: BoutiqueColors.bgCard,
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFFFCC80))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added_rounded, color: Color(0xFFB45309)),
                    const SizedBox(width: 12),
                    const Text('Reserved Items', style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFFB45309)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: reservedItems.isEmpty
                    ? const Center(
                        child: Text('No reserved items found.', style: TextStyle(color: BoutiqueColors.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: reservedItems.length,
                        separatorBuilder: (_, __) => const Divider(color: BoutiqueColors.borderLight),
                        itemBuilder: (context, idx) {
                          final p = reservedItems[idx];
                          final availableReserve = _getAvailableStock(p, BillRow(isFromReserve: true));
                          return ListTile(
                            title: Text('${p.tagId} - ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reserved For: ${p.reservedFor.isNotEmpty ? p.reservedFor : 'Unknown'}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('Qty Reserved: ${p.reservedQuantity} (Available: $availableReserve)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: availableReserve > 0 ? BoutiqueColors.accent : Colors.red)),
                                ],
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: availableReserve > 0
                                  ? () {
                                      setState(() {
                                        final row = BillRow(isFromReserve: true);
                                        row.product = p;
                                        row.qty = 1;
                                        if (p.pricingType == 'Weight-Based') {
                                          row.price = p.ratePerGram > 0 ? p.ratePerGram : 0.0;
                                        } else {
                                          row.price = p.finalPrice > 0 ? p.finalPrice : p.mrp;
                                        }
                                        row.discountValue = p.discountValue;
                                        row.discountType = p.discountType;
                                        
                                        // Auto-fill customer details from reserved details if bill is empty
                                        if (_customerNameCtrl.text.isEmpty && _customerMobileCtrl.text.isEmpty && p.reservedFor.isNotEmpty) {
                                          final parts = p.reservedFor.split('-');
                                          if (parts.isNotEmpty) _customerNameCtrl.text = parts[0].trim();
                                          if (parts.length > 1) {
                                            final num = parts[1].trim().replaceAll(RegExp(r'[^0-9]'), '');
                                            if (num.length >= 10) _customerMobileCtrl.text = num;
                                          }
                                        }
                                        _rows.add(row);
                                        _rowVersion.value++;
                                      });
                                      Navigator.pop(ctx);
                                      BoutiqueToast.showSuccess(context, 'Reserved item added to bill');
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309), foregroundColor: Colors.white),
                              child: const Text('Add to Bill'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _billDate = picked);
  }
}

// ── Bill Row Widget ───────────────────────────────────────────────────────────
// Isolated StatefulWidget: qty stepper and product selection manage their own
// state internally; parent only notified via onChanged when values actually change.

class _BillRowWidget extends StatefulWidget {
  final BillRow row;
  final List<Product> products;
  final int Function(Product p, [BillRow? currentRow]) getAvailableStock;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _BillRowWidget({
    super.key,
    required this.row,
    required this.products,
    required this.getAvailableStock,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_BillRowWidget> createState() => _BillRowWidgetState();
}

class _BillRowWidgetState extends State<_BillRowWidget> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final availableStock = row.product != null ? widget.getAvailableStock(row.product!, row) : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BoutiqueColors.bgSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BoutiqueColors.border),
      ),
      child: Row(
        children: [
          // Product search — Autocomplete so only visible suggestions are built
          Expanded(
            flex: 4,
            child: _ProductAutocomplete(
              products: widget.products,
              selected: row.product,
              getAvailableStock: (p) => widget.getAvailableStock(p, row),
              onSelected: (p) {
                final available = widget.getAvailableStock(p, row);
                if (available <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item is out of stock (already selected in other rows).'), backgroundColor: Colors.red),
                  );
                  return;
                }
                setState(() {
                  row.product = p;
                  if (row.qty > available) row.qty = available.toDouble();
                  if (p.pricingType == 'Weight-Based') {
                    row.price = p.ratePerGram > 0 ? p.ratePerGram : 0.0;
                  } else {
                    row.price = p.finalPrice > 0 ? p.finalPrice : p.mrp;
                  }
                  row.discountValue = p.discountValue;
                  row.discountType = p.discountType;
                });
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 12),

          // Qty stepper — only rebuilds this widget, not parent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoutiqueColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 14, color: BoutiqueColors.textSecondary),
                  onPressed: row.qty > 1
                      ? () {
                          setState(() => row.qty -= 1);
                          widget.onChanged();
                        }
                      : null,
                ),
                InkWell(
                  onTap: () => _editQuantityDialog(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text('Qty: ${row.qty == row.qty.toInt() ? row.qty.toInt() : row.qty.toStringAsFixed(2)} ${row.unitLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 14, color: BoutiqueColors.accent),
                  onPressed: (row.product != null && row.qty < availableStock)
                      ? () {
                          setState(() => row.qty += 1);
                          widget.onChanged();
                        }
                      : null,
                ),
              ],
            ),
          ),
          if (row.product?.pricingType == 'Weight-Based') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6E8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BoutiqueColors.accentLightBorder),
              ),
              child: InkWell(
                onTap: () => _editWeightDialog(),
                child: Text(
                  '${row.weight > 0 ? row.weight.toStringAsFixed(2) : 'Enter'} ${row.product?.weightUnit ?? 'g'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.accent, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),

          // Price & Total
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${row.lineAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                Text(row.product?.pricingType == 'Weight-Based' ? '@ ₹${row.price}/${row.product?.weightUnit ?? 'g'}' : '@ ₹${row.price}',
                    style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: BoutiqueColors.destructive, size: 20),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _editQuantityDialog() async {
    final ctrl = TextEditingController(text: widget.row.qty == widget.row.qty.toInt() ? widget.row.qty.toInt().toString() : widget.row.qty.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Quantity', style: TextStyle(fontFamily: 'serif', color: BoutiqueColors.accent)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Quantity'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent),
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)), 
            child: const Text('Save', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      final available = widget.row.product != null
          ? widget.getAvailableStock(widget.row.product!, widget.row)
          : 0;
      if (widget.row.product != null && result > available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot exceed available stock ($available available)'), backgroundColor: Colors.red),
        );
      } else {
        setState(() => widget.row.qty = result);
        widget.onChanged();
      }
    }
  }

  Future<void> _editWeightDialog() async {
    final ctrl = TextEditingController(text: widget.row.weight > 0 ? widget.row.weight.toString() : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter Weight (${widget.row.product?.weightUnit ?? 'g'})', style: const TextStyle(fontFamily: 'serif', color: BoutiqueColors.accent)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Grams'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent),
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)), 
            child: const Text('Save', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => widget.row.weight = result);
      widget.onChanged();
    }
  }
}

// ── Product Autocomplete ──────────────────────────────────────────────────────
// Uses Flutter's Autocomplete widget — only renders the suggestions that match
// the search query, NOT all products as widget items simultaneously.

class _ProductAutocomplete extends StatelessWidget {
  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onSelected;
  final int Function(Product) getAvailableStock;

  const _ProductAutocomplete({
    required this.products,
    required this.selected,
    required this.onSelected,
    required this.getAvailableStock,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      initialValue: selected != null
          ? TextEditingValue(text: '${selected!.tagId} - ${selected!.name}')
          : TextEditingValue.empty,
      displayStringForOption: (p) => '${p.tagId} - ${p.name}',
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return products.take(30); // show first 30 when empty
        return products.where(
          (p) =>
              p.tagId.toLowerCase().contains(query) ||
              p.name.toLowerCase().contains(query),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final p = options.elementAt(index);
                  final stock = getAvailableStock(p);
                  return InkWell(
                    onTap: () => onSelected(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${p.tagId} - ${p.name}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: stock > 0 ? BoutiqueColors.accent.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Stock: $stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: stock > 0 ? BoutiqueColors.accent : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.pricingType == 'Weight-Based'
                              ? '₹${p.ratePerGram == p.ratePerGram.toInt() ? p.ratePerGram.toInt() : p.ratePerGram.toStringAsFixed(2)}/${p.weightUnit}  •  ${p.category}'
                              : '₹${p.mrp == p.mrp.toInt() ? p.mrp.toInt() : p.mrp.toStringAsFixed(2)}  •  ${p.category}',
                            style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onSubmit) {
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13),
          decoration: BoutiqueInputDecoration.field(
            hintText: 'Search product name or tag ID...',
            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: BoutiqueColors.textSecondary),
          ),
        );
      },
      onSelected: onSelected,
    );
  }
}

// ── Summary Panel ─────────────────────────────────────────────────────────────
// Isolated StatefulWidget that listens to its OWN controllers via AnimatedBuilder.
// Typing in discount / tax fields ONLY rebuilds this panel, not the item table.

class _BillSummaryPanel extends StatefulWidget {
  final List<BillRow> rows;
  final ValueNotifier<int> rowVersion;
  final TextEditingController extraDiscountCtrl;
  final String extraDiscountType;
  final TextEditingController gstCtrl;
  final String gstType;
  final TextEditingController adjustmentCtrl;
  final String billType;
  final TextEditingController amountReceivedCtrl;
  final bool isSaving;
  final bool hasValidRows;
  final ValueChanged<String> onDiscountTypeChanged;
  final ValueChanged<String> onGstTypeChanged;
  final void Function(bool isSplit, String singleMode, List<Map<String, dynamic>> splitPayments) onSave;
  final VoidCallback onDownload;

  const _BillSummaryPanel({
    required this.rows,
    required this.rowVersion,
    required this.extraDiscountCtrl,
    required this.extraDiscountType,
    required this.gstCtrl,
    required this.gstType,
    required this.adjustmentCtrl,
    required this.billType,
    required this.amountReceivedCtrl,
    required this.isSaving,
    required this.hasValidRows,
    required this.onDiscountTypeChanged,
    required this.onGstTypeChanged,
    required this.onSave,
    required this.onDownload,
  });

  @override
  State<_BillSummaryPanel> createState() => _BillSummaryPanelState();
}

class _BillSummaryPanelState extends State<_BillSummaryPanel> {
  bool _isSplitPayment = false;
  String _singlePaymentMode = 'Cash';
  final List<Map<String, dynamic>> _splitPayments = [{'mode': 'Cash', 'amountCtrl': TextEditingController(text: '0')}];
  final List<String> _paymentModes = ['Cash', 'GPay', 'Bank Transfer', 'Card', 'UPI', 'Other'];

  @override
  void dispose() {
    for (var p in _splitPayments) {
      (p['amountCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder listens to discount/tax/adjustment controllers AND rowVersion
    // so subtotal recalculates on product select, qty change, or discount/tax edits
    return AnimatedBuilder(
      animation: Listenable.merge([widget.extraDiscountCtrl, widget.gstCtrl, widget.adjustmentCtrl, widget.amountReceivedCtrl, widget.rowVersion]),
      builder: (context, _) {
        final subtotal = widget.rows.fold<double>(0, (s, r) => s + r.lineAmount);
        final discV = double.tryParse(widget.extraDiscountCtrl.text) ?? 0;
        final discAmt = widget.extraDiscountType == '%'
            ? (subtotal * discV / 100).clamp(0, subtotal)
            : discV.clamp(0, subtotal);
        final discounted = (subtotal - discAmt).clamp(0.0, double.infinity);
        
        final gstPercent = double.tryParse(widget.gstCtrl.text) ?? 0.0;
        final taxAmt = (subtotal * (gstPercent / 100)).clamp(0.0, double.infinity);
        final computedTotal = (discounted + taxAmt).clamp(0.0, double.infinity);
        final manualTotal = double.tryParse(widget.adjustmentCtrl.text);
        final adjustment = manualTotal != null ? manualTotal - computedTotal : 0.0;
        final total = (computedTotal + adjustment).clamp(0.0, double.infinity);

        final targetAmount = widget.billType == 'Advance Payment'
            ? (double.tryParse(widget.amountReceivedCtrl.text) ?? total)
            : total;

        double allocated = 0;
        if (_isSplitPayment) {
          for (var p in _splitPayments) {
            allocated += double.tryParse((p['amountCtrl'] as TextEditingController).text) ?? 0;
          }
        }
        double remaining = targetAmount - allocated;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Running Cart & Summary',
                style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
            const Divider(height: 24, color: BoutiqueColors.border),

            _summaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),

            // Extra Discount
            Row(
              children: [
                const Text('Extra Discount', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.extraDiscountType,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: '₹', child: Text('₹')),
                    DropdownMenuItem(value: '%', child: Text('%')),
                  ],
                  onChanged: (v) { if (v != null) widget.onDiscountTypeChanged(v); },
                ),
                const Spacer(),
                SizedBox(
                  width: 90,
                  height: 38,
                  child: TextField(
                    controller: widget.extraDiscountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(hintText: '0'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // GST
            Row(
              children: [
                const Text('GST', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.gstType,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'No GST', child: Text('No GST')),
                    DropdownMenuItem(value: '5%', child: Text('5%')),
                    DropdownMenuItem(value: '12%', child: Text('12%')),
                    DropdownMenuItem(value: '18%', child: Text('18%')),
                    DropdownMenuItem(value: '28%', child: Text('28%')),
                    DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                  ],
                  onChanged: (v) { if (v != null) widget.onGstTypeChanged(v); },
                ),
                const Spacer(),
                SizedBox(
                  width: 90,
                  height: 38,
                  child: TextField(
                    controller: widget.gstCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(hintText: '0'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Adjustment Override
            Row(
              children: [
                const Text('Override Total', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
                const Spacer(),
                SizedBox(
                  width: 90,
                  height: 38,
                  child: TextField(
                    controller: widget.adjustmentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(hintText: 'e.g. 100'),
                  ),
                ),
              ],
            ),
            if (discAmt > 0) ...[
              const SizedBox(height: 12),
              _summaryRow('Discount Applied', '− ₹${discAmt.toStringAsFixed(2)}'),
            ],
            if (taxAmt > 0) ...[
              const SizedBox(height: 12),
              _summaryRow('Total GST', '+ ₹${taxAmt.toStringAsFixed(2)}'),
            ],
            if (adjustment != 0) ...[
              const SizedBox(height: 12),
              _summaryRow('Adjustment', '${adjustment >= 0 ? '+' : ''} ₹${adjustment.toStringAsFixed(2)}'),
            ],
            const Divider(height: 28, color: BoutiqueColors.border),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL PAYABLE',
                    style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
              ],
            ),
            const SizedBox(height: 24),
            
            if (widget.billType == 'Advance Payment') ...[
              Row(
                children: [
                  const Text('Advance Received', style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                  const Spacer(),
                  SizedBox(
                    width: 110,
                    height: 38,
                    child: TextField(
                      controller: widget.amountReceivedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                      decoration: BoutiqueInputDecoration.field(hintText: 'e.g. 500'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            const Text('Payment Details',
                style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    groupValue: _isSplitPayment,
                    title: const Text('Single', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (v) => setState(() => _isSplitPayment = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    groupValue: _isSplitPayment,
                    title: const Text('Split', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (v) => setState(() => _isSplitPayment = v!),
                  ),
                ),
              ],
            ),
            if (!_isSplitPayment) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: BoutiqueColors.bgSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BoutiqueColors.border),
                ),
                child: DropdownButton<String>(
                  value: _singlePaymentMode,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    for (final m in _paymentModes)
                      DropdownMenuItem<String>(value: m, child: Text(m))
                  ],
                  onChanged: (v) { if (v != null) setState(() => _singlePaymentMode = v); },
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              for (int idx = 0; idx < _splitPayments.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: BoutiqueColors.bgSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BoutiqueColors.border),
                          ),
                          child: DropdownButton<String>(
                            value: _splitPayments[idx]['mode'],
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: [
                              for (final m in _paymentModes)
                                DropdownMenuItem<String>(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))
                            ],
                            onChanged: (v) { if (v != null) setState(() => _splitPayments[idx]['mode'] = v); },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _splitPayments[idx]['amountCtrl'],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: BoutiqueInputDecoration.field(hintText: 'Amount'),
                          ),
                        ),
                      ),
                      if (_splitPayments.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: BoutiqueColors.destructive, size: 20),
                          onPressed: () {
                            (_splitPayments[idx]['amountCtrl'] as TextEditingController).dispose();
                            setState(() => _splitPayments.removeAt(idx));
                          },
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _splitPayments.add({'mode': 'Cash', 'amountCtrl': TextEditingController(text: '0')}));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Payment Mode', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: BoutiqueColors.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining:', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
                  Text('₹${remaining.toStringAsFixed(2)}', 
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold, 
                      color: remaining.abs() < 0.01 ? Colors.green : BoutiqueColors.destructive
                    )
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: widget.isSaving ? null : () {
                if (_isSplitPayment && remaining.abs() >= 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please allocate the exact remaining amount (₹${remaining.toStringAsFixed(2)})'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                final List<Map<String, dynamic>> parsedSplitPayments = [
                  for (final e in _splitPayments)
                    {
                      'mode': e['mode'],
                      'amount': double.tryParse((e['amountCtrl'] as TextEditingController).text) ?? 0.0
                    }
                ];
                
                widget.onSave(_isSplitPayment, _singlePaymentMode, parsedSplitPayments);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BoutiqueColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: widget.isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('SAVE & CHECKOUT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: widget.hasValidRows ? widget.onDownload : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('PRINT / DOWNLOAD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
      ],
    );
  }
}
