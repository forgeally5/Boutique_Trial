import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../state/admin_state.dart';
import 'bill_row_model.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF8D6E63);
const _bg = Color(0xFFFCFAF5);
const _border = Color(0xFFE5DDD0);
const _errorColor = Color(0xFFB71C1C);
const _green = Color(0xFF2E7D32);

class CreateBillScreen extends StatefulWidget {
  final AdminState state;
  final Map<String, dynamic>? editData; // for editing existing bill
  final VoidCallback? onSaved;

  const CreateBillScreen({
    super.key,
    required this.state,
    this.editData,
    this.onSaved,
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _fmt = DateFormat('dd/MM/yyyy');

  // Header
  final _billNoCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerMobileCtrl = TextEditingController();
  DateTime _billDate = DateTime.now();

  // Items
  final List<BillRow> _rows = [];

  // Summary
  String _extraDiscountType = '%';
  final _extraDiscountCtrl = TextEditingController(text: '0');
  bool _gstEnabled = false;
  final _taxPercentCtrl = TextEditingController(text: '0');

  // Payment
  String _paymentMode = 'Cash';
  final _amountReceivedCtrl = TextEditingController();
  // Split
  final _split1AmtCtrl = TextEditingController();
  String _split1Mode = 'Cash';
  final _split2AmtCtrl = TextEditingController();
  String _split2Mode = 'UPI';

  bool _isSaving = false;
  bool _attemptedSave = false;

  // Customer autocomplete
  List<String> _customerSuggestions = [];

  static const _paymentModes = ['Cash', 'UPI', 'Card', 'Split Payment'];
  static const _splitModes = ['Cash', 'UPI', 'Card'];

  @override
  void initState() {
    super.initState();
    _generateBillNo();
    _fetchCustomerSuggestions();
    _rows.add(BillRow()); // start with one empty row

    // listen for recalc
    _extraDiscountCtrl.addListener(_recalc);
    _taxPercentCtrl.addListener(_recalc);
    _amountReceivedCtrl.addListener(_recalc);
    _split1AmtCtrl.addListener(_recalc);
    _split2AmtCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    _extraDiscountCtrl.dispose();
    _taxPercentCtrl.dispose();
    _amountReceivedCtrl.dispose();
    _split1AmtCtrl.dispose();
    _split2AmtCtrl.dispose();
    super.dispose();
  }

  void _recalc() => setState(() {});

  // ── Bill No ─────────────────────────────────────────────────────────────────

  Future<void> _generateBillNo() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billType', isEqualTo: 'Sale')
          .orderBy('billNo', descending: true)
          .limit(1)
          .get();

      int next = 1;
      if (snap.docs.isNotEmpty) {
        final lastNo = snap.docs.first.data()['billNo'] as String? ?? '';
        final match = RegExp(r'FA-(\d+)').firstMatch(lastNo);
        if (match != null) {
          next = int.parse(match.group(1)!) + 1;
        }
      }
      if (mounted) {
        _billNoCtrl.text = 'FA-${next.toString().padLeft(4, '0')}';
      }
    } catch (_) {
      final now = DateTime.now();
      _billNoCtrl.text =
          'FA-${now.millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  Future<void> _fetchCustomerSuggestions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billType', isEqualTo: 'Sale')
          .get();
      final names = snap.docs
          .map((d) => d.data()['customerName'] as String? ?? '')
          .where((n) => n.trim().isNotEmpty)
          .toSet()
          .toList();
      if (mounted) setState(() => _customerSuggestions = names);
    } catch (_) {}
  }

  // ── Calculations ─────────────────────────────────────────────────────────────

  double get _subtotal =>
      _rows.fold(0.0, (s, r) => s + r.lineAmount);

  double get _extraDiscountAmount {
    final v = double.tryParse(_extraDiscountCtrl.text) ?? 0;
    if (v <= 0) return 0;
    if (_extraDiscountType == '%') {
      return (_subtotal * v / 100).clamp(0, _subtotal);
    }
    return v.clamp(0, _subtotal);
  }

  double get _discountedSubtotal =>
      (_subtotal - _extraDiscountAmount).clamp(0, double.infinity);

  double get _taxAmount {
    if (!_gstEnabled) return 0;
    final p = double.tryParse(_taxPercentCtrl.text) ?? 0;
    return _discountedSubtotal * p / 100;
  }

  double get _totalPayable =>
      (_discountedSubtotal + _taxAmount).clamp(0, double.infinity);

  double get _amountReceived =>
      double.tryParse(_amountReceivedCtrl.text) ?? 0;

  double get _balance => _amountReceived - _totalPayable;

  double get _split1Amt => double.tryParse(_split1AmtCtrl.text) ?? 0;
  double get _split2Amt => double.tryParse(_split2AmtCtrl.text) ?? 0;
  bool get _splitSumValid =>
      (_split1Amt + _split2Amt - _totalPayable).abs() < 0.01;

  // ── Validation ────────────────────────────────────────────────────────────────

  String? _mobileError() {
    final m = _customerMobileCtrl.text.trim();
    if (m.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(m)) return 'Must be 10 digits';
    return null;
  }

  bool get _hasValidRows =>
      _rows.any((r) => r.isValid);

  bool get _canSave {
    if (!_hasValidRows) return false;
    if (_paymentMode == 'Split Payment' && !_splitSumValid) return false;
    if (_mobileError() != null) return false;
    return true;
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  Future<void> _saveBill({bool print = false}) async {
    setState(() => _attemptedSave = true);
    if (!_canSave) return;

    setState(() => _isSaving = true);
    try {
      final validRows = _rows.where((r) => r.isValid).toList();

      final billData = {
        'billNo': _billNoCtrl.text.trim(),
        'billType': 'Sale',
        'billDate': Timestamp.fromDate(_billDate),
        'customerName': _customerNameCtrl.text.trim(),
        'customerMobile': _customerMobileCtrl.text.trim(),
        'items': validRows.map((r) => r.toMap()).toList(),
        'subtotal': _subtotal,
        'extraDiscountType': _extraDiscountType,
        'extraDiscountValue': double.tryParse(_extraDiscountCtrl.text) ?? 0,
        'extraDiscountAmount': _extraDiscountAmount,
        'gstEnabled': _gstEnabled,
        'taxPercent': _gstEnabled ? (double.tryParse(_taxPercentCtrl.text) ?? 0) : 0,
        'taxAmount': _taxAmount,
        'totalPayable': _totalPayable,
        'paymentMode': _paymentMode,
        'amountReceived': _paymentMode == 'Cash' ? _amountReceived : _totalPayable,
        'balanceReturned': _paymentMode == 'Cash' ? _balance : 0,
        'split1Amount': _paymentMode == 'Split Payment' ? _split1Amt : 0,
        'split1Mode': _paymentMode == 'Split Payment' ? _split1Mode : '',
        'split2Amount': _paymentMode == 'Split Payment' ? _split2Amt : 0,
        'split2Mode': _paymentMode == 'Split Payment' ? _split2Mode : '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('bills').add(billData);

      // Deduct stock
      for (final row in validRows) {
        final p = row.product!;
        if (p.pricingType == 'Quantity-Based') {
          final newQty = (p.quantity - row.qty.toInt()).clamp(0, 999999);
          final updated = p.copyWith(
            quantity: newQty,
            status: newQty == 0 ? 'Sold Out' : p.status,
          );
          await widget.state.updateProduct(updated);
        } else {
          // Weight-based: mark as Sold Out (single piece logic)
          final updated = p.copyWith(status: 'Sold Out');
          await widget.state.updateProduct(updated);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bill ${_billNoCtrl.text} saved! Stock updated.'),
            ]),
            backgroundColor: _green,
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e'), backgroundColor: _errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Date Picker ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _brown),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Header bar
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: header + items
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          _buildHeaderSection(),
                          const SizedBox(height: 20),
                          _buildItemTable(),
                        ]),
                      ),
                    ),
                    // Right: sticky summary
                    SizedBox(
                      width: 340,
                      child: _buildSummaryPanel(),
                    ),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 16),
                    _buildItemTable(),
                    const SizedBox(height: 16),
                    _buildSummaryPanel(),
                  ]),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: _brown,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        const Text(
          'Create Bill',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Spacer(),
        if (_isSaving) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      ]),
    );
  }

  // ── Header Section ────────────────────────────────────────────────────────────

  Widget _buildHeaderSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Bill Details', Icons.info_outline),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _labeledField(
              'Bill No',
              _billNoCtrl,
              hint: 'FA-0001',
            )),
            const SizedBox(width: 16),
            Expanded(child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight)),
                  const SizedBox(height: 5),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: _brownLight),
                      const SizedBox(width: 8),
                      Text(_fmt.format(_billDate), style: const TextStyle(color: _brown, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
            )),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue val) {
                if (val.text.isEmpty) return const [];
                return _customerSuggestions.where(
                    (s) => s.toLowerCase().contains(val.text.toLowerCase()));
              },
              onSelected: (s) => _customerNameCtrl.text = s,
              fieldViewBuilder: (ctx, ctrl, focus, _) {
                _customerNameCtrl.addListener(() {
                  if (ctrl.text != _customerNameCtrl.text) ctrl.text = _customerNameCtrl.text;
                });
                return _labeledField('Customer Name (optional)', ctrl, hint: 'Walk-in customer');
              },
            )),
            const SizedBox(width: 16),
            Expanded(child: _labeledField(
              'Mobile No (optional)',
              _customerMobileCtrl,
              hint: '10-digit mobile',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              error: _mobileError(),
              onChanged: (_) => setState(() {}),
            )),
          ]),
        ],
      ),
    );
  }

  // ── Item Table ────────────────────────────────────────────────────────────────

  Widget _buildItemTable() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Items', Icons.shopping_bag_outlined),
          const SizedBox(height: 12),

          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: _brown.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              const SizedBox(width: 8),
              Expanded(flex: 4, child: _colHeader('Item')),
              Expanded(flex: 2, child: _colHeader('Qty / Weight')),
              Expanded(flex: 2, child: _colHeader('Price (₹)')),
              Expanded(flex: 3, child: _colHeader('Item Discount')),
              Expanded(flex: 2, child: _colHeader('Amount (₹)')),
              const SizedBox(width: 40),
            ]),
          ),

          // Rows
          ...List.generate(_rows.length, (i) => _buildItemRow(i)),

          const SizedBox(height: 12),
          // + Add Row button
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(BillRow())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Row'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brown,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),

          // Validation hint
          if (_attemptedSave && !_hasValidRows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.error_outline, color: _errorColor, size: 16),
                const SizedBox(width: 4),
                const Text('Add at least one valid item row.',
                    style: TextStyle(color: _errorColor, fontSize: 12)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final row = _rows[i];
    final products = widget.state.products;

    // Stock warning
    bool stockWarning = false;
    if (row.product != null && row.product!.pricingType == 'Quantity-Based') {
      if (row.qty > row.product!.quantity) stockWarning = true;
    }

    final hasError = _attemptedSave && !row.isValid;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFFF8F8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasError ? _errorColor.withValues(alpha: 0.4) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 4),
            // Item search dropdown
            Expanded(flex: 4, child: _ItemSearchField(
              products: products,
              selected: row.product,
              onSelected: (p) {
                setState(() {
                  row.product = p;
                  // Auto-fill price from finalPrice (post-default-discount)
                  row.price = p.finalPrice > 0 ? p.finalPrice : p.sellingPrice;
                  row.discountValue = p.discountValue;
                  row.discountType = p.discountType;
                });
              },
            )),
            const SizedBox(width: 8),
            // Qty / Weight
            Expanded(flex: 2, child: _numField(
              hint: row.isWeightBased ? 'g' : 'qty',
              value: row.qty == 0 ? '' : (row.isWeightBased ? row.qty.toString() : row.qty.toInt().toString()),
              isDecimal: row.isWeightBased,
              onChanged: (v) => setState(() => row.qty = double.tryParse(v) ?? 0),
              hasError: hasError && row.qty <= 0,
            )),
            const SizedBox(width: 8),
            // Price
            Expanded(flex: 2, child: _numField(
              hint: '0.00',
              value: row.price == 0 ? '' : row.price.toString(),
              isDecimal: true,
              onChanged: (v) => setState(() => row.price = double.tryParse(v) ?? 0),
              hasError: hasError && row.price <= 0,
            )),
            const SizedBox(width: 8),
            // Discount
            Expanded(flex: 3, child: _discountField(
              valueCtrl: row.discountValue,
              type: row.discountType,
              onValueChanged: (v) => setState(() => row.discountValue = v),
              onTypeChanged: (t) => setState(() => row.discountType = t),
            )),
            const SizedBox(width: 8),
            // Line amount (read-only)
            Expanded(flex: 2, child: Container(
              height: 42,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFC5E1A5)),
              ),
              child: Text(
                '₹${row.lineAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _green, fontSize: 13),
              ),
            )),
            // Remove
            SizedBox(width: 40,
              child: IconButton(
                onPressed: () => setState(() => _rows.removeAt(i)),
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                tooltip: 'Remove row',
              ),
            ),
          ]),
          // Stock warning
          if (stockWarning)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Only ${row.product!.quantity} in stock',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Summary Panel ─────────────────────────────────────────────────────────────

  Widget _buildSummaryPanel() {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: _border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Bill Summary', Icons.summarize_outlined),
            const SizedBox(height: 16),

            // Subtotal
            _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),

            // Extra Discount
            const Text('Extra Discount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _numFieldRaw(
                ctrl: _extraDiscountCtrl,
                hint: '0',
                isDecimal: true,
              )),
              const SizedBox(width: 8),
              _toggleBtn(_extraDiscountType, '%', () => setState(() => _extraDiscountType = '%')),
              _toggleBtn(_extraDiscountType, '₹', () => setState(() => _extraDiscountType = '₹')),
            ]),
            if (_extraDiscountAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('− ₹${_extraDiscountAmount.toStringAsFixed(2)} off',
                    style: const TextStyle(fontSize: 11, color: _green)),
              ),

            const SizedBox(height: 12),

            // GST toggle
            Row(children: [
              const Text('GST / Tax', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight)),
              const Spacer(),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _gstEnabled,
                  activeColor: _brown,
                  onChanged: (v) => setState(() => _gstEnabled = v),
                ),
              ),
            ]),
            if (_gstEnabled) ...[
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _numFieldRaw(ctrl: _taxPercentCtrl, hint: '0', isDecimal: true)),
                const SizedBox(width: 8),
                const Text('%', style: TextStyle(fontWeight: FontWeight.bold, color: _brownLight)),
              ]),
              if (_taxAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ₹${_taxAmount.toStringAsFixed(2)} tax',
                      style: const TextStyle(fontSize: 11, color: Colors.orange)),
                ),
            ],

            const SizedBox(height: 16),
            const Divider(color: _border),

            // Total Payable
            Row(children: [
              const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brown)),
              const Spacer(),
              Text(
                '₹${_totalPayable.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _brown),
              ),
            ]),

            const SizedBox(height: 16),
            const Divider(color: _border),

            // Payment Mode
            const Text('Payment Mode *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: InputDecoration(
                filled: true, fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
              ),
              items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMode = v!),
              style: const TextStyle(color: _brown),
            ),

            // Cash fields
            if (_paymentMode == 'Cash') ...[
              const SizedBox(height: 12),
              _labeledField('Amount Received (₹)', _amountReceivedCtrl, hint: '0.00',
                  keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _balance >= 0 ? const Color(0xFFF1F8E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _balance >= 0 ? const Color(0xFFA5D6A7) : Colors.red.shade200),
                ),
                child: Row(children: [
                  Text(
                    _balance >= 0 ? 'Balance to return' : 'Amount short',
                    style: TextStyle(fontSize: 12, color: _balance >= 0 ? _green : _errorColor),
                  ),
                  const Spacer(),
                  Text(
                    '₹${_balance.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16,
                        color: _balance >= 0 ? _green : _errorColor),
                  ),
                ]),
              ),
            ],

            // Split Payment
            if (_paymentMode == 'Split Payment') ...[
              const SizedBox(height: 12),
              _buildSplitPayment(),
              if (_attemptedSave && !_splitSumValid)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Split amounts must equal Total Payable',
                      style: TextStyle(color: _errorColor, fontSize: 11)),
                ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveBill(),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brown,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brown.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _confirmCancel(),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _brownLight,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitPayment() {
    return Column(children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _split1Mode,
          decoration: _compactDeco('Mode 1'),
          items: _splitModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _split1Mode = v!),
          style: const TextStyle(color: _brown, fontSize: 13),
        )),
        const SizedBox(width: 8),
        Expanded(child: _numFieldRaw(ctrl: _split1AmtCtrl, hint: '0.00', isDecimal: true, labelText: 'Amount 1')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _split2Mode,
          decoration: _compactDeco('Mode 2'),
          items: _splitModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _split2Mode = v!),
          style: const TextStyle(color: _brown, fontSize: 13),
        )),
        const SizedBox(width: 8),
        Expanded(child: _numFieldRaw(ctrl: _split2AmtCtrl, hint: '0.00', isDecimal: true, labelText: 'Amount 2')),
      ]),
      const SizedBox(height: 6),
      Text(
        'Total: ₹${(_split1Amt + _split2Amt).toStringAsFixed(2)} / ₹${_totalPayable.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          color: _splitSumValid ? _green : _errorColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }

  Future<void> _confirmCancel() async {
    if (_rows.any((r) => r.product != null)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Cancel Bill?'),
          content: const Text('Items have been added. Are you sure you want to cancel?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _errorColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    widget.onSaved?.call();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: _brownLight),
      const SizedBox(width: 6),
      Text(title.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: _brownLight)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: _border)),
    ]);
  }

  Widget _colHeader(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight));

  Widget _summaryRow(String label, String value) {
    return Row(children: [
      Text(label, style: const TextStyle(color: _brownLight, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: _brown, fontSize: 14)),
    ]);
  }

  Widget _toggleBtn(String current, String val, VoidCallback onTap) {
    final sel = current == val;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _brown : Colors.white,
          border: Border.all(color: _border),
          borderRadius: val == '%'
              ? const BorderRadius.horizontal(left: Radius.circular(6))
              : const BorderRadius.horizontal(right: Radius.circular(6)),
        ),
        child: Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : _brownLight, fontSize: 13)),
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? error,
    void Function(String)? onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(color: _brown, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBCAAA4)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: error != null ? _errorColor : _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: error != null ? _errorColor : _brown, width: 1.5)),
        ),
      ),
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(error, style: const TextStyle(color: _errorColor, fontSize: 11))),
    ]);
  }

  Widget _numField({
    required String hint,
    required String value,
    required bool isDecimal,
    required void Function(String) onChanged,
    bool hasError = false,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          isDecimal
              ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: _brown),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBCAAA4)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: hasError ? _errorColor : _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _brown, width: 1.5)),
        ),
      ),
    );
  }

  Widget _numFieldRaw({
    required TextEditingController ctrl,
    required String hint,
    required bool isDecimal,
    String? labelText,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (labelText != null) ...[
        Text(labelText, style: const TextStyle(fontSize: 11, color: _brownLight)),
        const SizedBox(height: 4),
      ],
      SizedBox(height: 42, child: TextField(
        controller: ctrl,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          isDecimal
              ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontSize: 13, color: _brown),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBCAAA4)),
          filled: true, fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _brown, width: 1.5)),
        ),
      )),
    ]);
  }

  Widget _discountField({
    required double valueCtrl,
    required String type,
    required void Function(double) onValueChanged,
    required void Function(String) onTypeChanged,
  }) {
    return Row(children: [
      Expanded(child: _numField(
        hint: '0',
        value: valueCtrl == 0 ? '' : valueCtrl.toString(),
        isDecimal: true,
        onChanged: (v) => onValueChanged(double.tryParse(v) ?? 0),
      )),
      const SizedBox(width: 4),
      _toggleBtn(type, '%', () => onTypeChanged('%')),
      _toggleBtn(type, '₹', () => onTypeChanged('₹')),
    ]);
  }

  InputDecoration _compactDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11, color: _brownLight),
    filled: true, fillColor: _bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
  );
}

// ── Item Search Field ─────────────────────────────────────────────────────────

class _ItemSearchField extends StatefulWidget {
  final List<Product> products;
  final Product? selected;
  final void Function(Product) onSelected;

  const _ItemSearchField({
    required this.products,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_ItemSearchField> createState() => _ItemSearchFieldState();
}

class _ItemSearchFieldState extends State<_ItemSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Product> _suggestions = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _ctrl.text = '${widget.selected!.tagId} – ${widget.selected!.name}';
    }
    _focus.addListener(() {
      if (!_focus.hasFocus) setState(() => _showDropdown = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _suggestions = widget.products.where((p) =>
        p.tagId.toLowerCase().contains(lower) ||
        p.name.toLowerCase().contains(lower) ||
        p.category.toLowerCase().contains(lower)
      ).take(8).toList();
      _showDropdown = _suggestions.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 42,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 13, color: Color(0xFF3E2723)),
          decoration: InputDecoration(
            hintText: 'Search item…',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBCAAA4)),
            filled: true, fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF8D6E63)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF3E2723), width: 1.5)),
          ),
        ),
      ),
      if (_showDropdown)
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5DDD0)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (ctx, i) {
                final p = _suggestions[i];
                final isOos = p.status == 'Sold Out';
                return ListTile(
                  dense: true,
                  enabled: !isOos,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F6F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      p.pricingType == 'Weight-Based' ? Icons.scale_outlined : Icons.inventory_2_outlined,
                      size: 14, color: const Color(0xFF8D6E63),
                    ),
                  ),
                  title: Text('${p.tagId} – ${p.name}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${p.category} • ₹${p.finalPrice > 0 ? p.finalPrice.toStringAsFixed(2) : p.sellingPrice.toStringAsFixed(2)} ${isOos ? '• OUT OF STOCK' : ''}',
                    style: TextStyle(fontSize: 11, color: isOos ? Colors.red : Colors.grey),
                  ),
                  onTap: isOos ? null : () {
                    _ctrl.text = '${p.tagId} – ${p.name}';
                    setState(() => _showDropdown = false);
                    _focus.unfocus();
                    widget.onSelected(p);
                  },
                );
              },
            ),
          ),
        ),
    ]);
  }
}
