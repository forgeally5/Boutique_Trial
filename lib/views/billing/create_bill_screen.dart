import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import 'bill_row_model.dart';

class CreateBillScreen extends StatefulWidget {
  final AdminState state;
  final Map<String, dynamic>? editData;
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

  List<String> _customerSuggestions = [];

  static const _paymentModes = ['Cash', 'UPI', 'Card', 'Split Payment'];
  static const _splitModes = ['Cash', 'UPI', 'Card'];

  @override
  void initState() {
    super.initState();
    _generateBillNo();
    _fetchCustomerSuggestions();
    _rows.add(BillRow());

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
      _billNoCtrl.text = 'FA-${now.millisecondsSinceEpoch.toString().substring(7)}';
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

  double get _subtotal => _rows.fold(0.0, (s, r) => s + r.lineAmount);

  double get _extraDiscountAmount {
    final v = double.tryParse(_extraDiscountCtrl.text) ?? 0;
    if (v <= 0) return 0;
    if (_extraDiscountType == '%') {
      return (_subtotal * v / 100).clamp(0, _subtotal);
    }
    return v.clamp(0, _subtotal);
  }

  double get _discountedSubtotal => (_subtotal - _extraDiscountAmount).clamp(0, double.infinity);

  double get _taxAmount {
    if (!_gstEnabled) return 0;
    final p = double.tryParse(_taxPercentCtrl.text) ?? 0;
    return _discountedSubtotal * p / 100;
  }

  double get _totalPayable => (_discountedSubtotal + _taxAmount).clamp(0, double.infinity);

  double get _amountReceived => double.tryParse(_amountReceivedCtrl.text) ?? 0;

  double get _balance => _amountReceived - _totalPayable;

  double get _split1Amt => double.tryParse(_split1AmtCtrl.text) ?? 0;
  double get _split2Amt => double.tryParse(_split2AmtCtrl.text) ?? 0;
  bool get _splitSumValid => (_split1Amt + _split2Amt - _totalPayable).abs() < 0.01;

  String? _mobileError() {
    final m = _customerMobileCtrl.text.trim();
    if (m.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(m)) return 'Must be 10 digits';
    return null;
  }

  bool get _hasValidRows => _rows.any((r) => r.isValid);

  bool get _canSave {
    if (!_hasValidRows) return false;
    if (_paymentMode == 'Split Payment' && !_splitSumValid) return false;
    if (_mobileError() != null) return false;
    return true;
  }

  Future<void> _saveBill() async {
    setState(() => _attemptedSave = true);
    if (!_canSave) {
      BoutiqueToast.showError(context, 'Please fill in all required fields correctly.');
      return;
    }

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
          final updated = p.copyWith(status: 'Sold Out');
          await widget.state.updateProduct(updated);
        }
      }

      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Invoice ${_billNoCtrl.text} created successfully!');
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Failed to save bill: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 950;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Customer details + item list
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 20),
                            _buildItemTable(),
                          ],
                        ),
                      ),
                    ),
                    // Right: Live Running Cart & Checkout Panel
                    Container(
                      width: 380,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: BoutiqueColors.bgCard,
                        border: Border(left: BorderSide(color: BoutiqueColors.border)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildSummaryPanel(),
                      ),
                    ),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 16),
                      _buildItemTable(),
                      const SizedBox(height: 16),
                      _buildSummaryPanel(),
                    ],
                  ),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoutiqueDecoration.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer & Invoice Details', style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
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
                        Text(_fmt.format(_billDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
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
              Expanded(
                child: TextField(
                  controller: _customerNameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(hintText: 'Walk-in Customer', labelText: 'Customer Name'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _customerMobileCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(hintText: '10-digit mobile', labelText: 'Mobile Number'),
                ),
              ),
            ],
          ),
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
              const Text('Select Products to Bill', style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
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
          const SizedBox(height: 16),

          ...List.generate(_rows.length, (i) => _buildItemRow(i)),
        ],
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final row = _rows[i];
    final products = widget.state.products;

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
          // Item Select Dropdown
          Expanded(
            flex: 4,
            child: _ItemSearchField(
              products: products,
              selected: row.product,
              onSelected: (p) {
                setState(() {
                  row.product = p;
                  row.price = p.finalPrice > 0 ? p.finalPrice : p.sellingPrice;
                  row.discountValue = p.discountValue;
                  row.discountType = p.discountType;
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          // Quantity Steppers (+/-)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoutiqueColors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 14, color: BoutiqueColors.textSecondary),
                  onPressed: () {
                    if (row.qty > 1) {
                      setState(() => row.qty -= 1);
                    }
                  },
                ),
                Text('${row.qty.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.add, size: 14, color: BoutiqueColors.accent),
                  onPressed: () {
                    setState(() => row.qty += 1);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Price & Total
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${row.lineAmount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                Text('@ ₹${row.price}', style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: BoutiqueColors.destructive, size: 20),
            onPressed: () {
              if (_rows.length > 1) {
                setState(() => _rows.removeAt(i));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Running Cart & Summary', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
        const Divider(height: 24, color: BoutiqueColors.border),

        _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 12),

        // Extra Discount Field
        Row(
          children: [
            const Text('Extra Discount', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
            const Spacer(),
            SizedBox(
              width: 80,
              height: 38,
              child: TextField(
                controller: _extraDiscountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: BoutiqueInputDecoration.field(hintText: '0'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // GST Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Apply GST Tax', style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
            Switch(
              value: _gstEnabled,
              activeColor: BoutiqueColors.accent,
              onChanged: (v) => setState(() => _gstEnabled = v),
            ),
          ],
        ),
        if (_gstEnabled) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Tax %', style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
              const Spacer(),
              SizedBox(
                width: 80,
                height: 38,
                child: TextField(
                  controller: _taxPercentCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(hintText: '5'),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 28, color: BoutiqueColors.border),

        // Total Payable Highlight
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL PAYABLE', style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
            Text('₹${_totalPayable.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
          ],
        ),
        const SizedBox(height: 24),

        // Segmented Payment Method Selector
        const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentModes.map((mode) {
            final isSelected = _paymentMode == mode;
            return ChoiceChip(
              label: Text(mode),
              selected: isSelected,
              selectedColor: BoutiqueColors.accent,
              labelStyle: TextStyle(color: isSelected ? Colors.white : BoutiqueColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              onSelected: (sel) {
                if (sel) setState(() => _paymentMode = mode);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Prominent Checkout Primary Button
        ElevatedButton(
          onPressed: _isSaving ? null : _saveBill,
          style: ElevatedButton.styleFrom(
            backgroundColor: BoutiqueColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('GENERATE BILL & CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  ],
                ),
        ),
      ],
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

class _ItemSearchField extends StatelessWidget {
  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onSelected;

  const _ItemSearchField({
    required this.products,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Product>(
      value: selected,
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
      decoration: BoutiqueInputDecoration.field(hintText: 'Select boutique product...'),
      items: products.map((p) {
        return DropdownMenuItem(
          value: p,
          child: Text('${p.tagId} - ${p.name} (₹${p.mrp})', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) onSelected(val);
      },
    );
  }
}
