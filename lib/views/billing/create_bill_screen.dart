import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../state/admin_state.dart';
import '../../models/product.dart';
import 'bill_row_model.dart';
import '../../utils/boutique_theme.dart';

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

  final List<BillRow> _rows = [BillRow()];

  final _extraDiscountCtrl = TextEditingController(text: '0');
  String _extraDiscountType = '₹';

  bool _gstEnabled = false;
  final _taxPercentCtrl = TextEditingController(text: '5');

  String _paymentMode = 'Cash';
  final List<String> _paymentModes = ['Cash', 'Card', 'UPI', 'Bank Transfer', 'Cheque'];

  bool _isSaving = false;
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    _fetchNextBillNo();
    _extraDiscountCtrl.addListener(() => setState(() {}));
    _taxPercentCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    _extraDiscountCtrl.dispose();
    _taxPercentCtrl.dispose();
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
      _billNoCtrl.text = 'FA-${nextNum.toString().padLeft(4, '0')}';
    } catch (_) {
      _billNoCtrl.text = 'FA-0001';
    }
  }

  // ── Calculation Helpers ────────────────────────────────────────────────────────

  double get _subtotal => _rows.fold(0, (sum, r) => sum + r.lineAmount);

  double get _extraDiscountAmount {
    final v = double.tryParse(_extraDiscountCtrl.text) ?? 0;
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

  String? _mobileError() {
    final m = _customerMobileCtrl.text.trim();
    if (m.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(m)) return 'Must be 10 digits';
    return null;
  }

  bool get _hasValidRows => _rows.any((r) => r.isValid);

  bool get _canSave {
    if (!_hasValidRows) return false;
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
        'amountReceived': _totalPayable,
        'balanceReturned': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('bills').add(billData);

      // Deduct stock
      for (final row in validRows) {
        final p = row.product!;
        final newQty = (p.quantity - row.qty.toInt()).clamp(0, 999999);
        final updated = p.copyWith(
          quantity: newQty,
          status: newQty == 0 ? 'Sold Out' : p.status,
        );
        await widget.state.updateProduct(updated);
      }

      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Bill saved successfully!');
        _resetForm();
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Error saving bill: $e');
      }
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
      _gstEnabled = false;
      _paymentMode = 'Cash';
      _attemptedSave = false;
    });
  }

  Future<void> _downloadInvoice() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    final fmt = DateFormat('dd/MM/yyyy');
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    const tColor = PdfColor.fromInt(0xFF5E1729);
    const tLight = PdfColor.fromInt(0xFFF9F6F0);
    const greenColor = PdfColor.fromInt(0xFF2E7D32);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('FORGEALLY BOUTIQUE - TAX INVOICE',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: tColor)),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.5, color: tColor),
              pw.SizedBox(height: 10),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: tColor)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _customerNameCtrl.text.trim().isEmpty ? 'Walk-in Customer' : _customerNameCtrl.text.trim(),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    if (_customerMobileCtrl.text.trim().isNotEmpty)
                      pw.Text(_customerMobileCtrl.text.trim(), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Invoice No: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.TextSpan(text: _billNoCtrl.text.trim(), style: const pw.TextStyle(fontSize: 9)),
                  ])),
                  pw.SizedBox(height: 3),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.TextSpan(text: fmt.format(_billDate), style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: tColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tColor),
                children: [
                  _pdfCell('#', bold: true, isHeader: true),
                  _pdfCell('Item', bold: true, isHeader: true, align: pw.Alignment.centerLeft),
                  _pdfCell('Qty', bold: true, isHeader: true),
                  _pdfCell('Price (₹)', bold: true, isHeader: true),
                  _pdfCell('Discount', bold: true, isHeader: true),
                  _pdfCell('Amount (₹)', bold: true, isHeader: true),
                ],
              ),
              ...validRows.asMap().entries.map((e) {
                final i = e.key + 1;
                final r = e.value;
                final discStr = r.discountValue > 0 ? '${r.discountValue.toStringAsFixed(2)} ${r.discountType}' : '—';
                final qtyStr = '${r.qty.toInt()} ${r.unitLabel}';
                return pw.TableRow(
                  children: [
                    _pdfCell(i.toString()),
                    _pdfCell(r.product?.name ?? '', align: pw.Alignment.centerLeft),
                    _pdfCell(qtyStr),
                    _pdfCell('₹${r.price.toStringAsFixed(2)}'),
                    _pdfCell(discStr),
                    _pdfCell('₹${r.lineAmount.toStringAsFixed(2)}'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    _pdfTotalRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}', tColor),
                    if (_extraDiscountAmount > 0)
                      _pdfTotalRow('Extra Discount', '− ₹${_extraDiscountAmount.toStringAsFixed(2)}', tColor),
                    if (_taxAmount > 0)
                      _pdfTotalRow('Tax (${_taxPercentCtrl.text}%)', '+ ₹${_taxAmount.toStringAsFixed(2)}', tColor),
                    pw.Container(height: 1, color: tColor),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      color: tLight,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL PAYABLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: tColor)),
                          pw.Text('₹${_totalPayable.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: tColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(height: 0.5, color: tColor),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Thank you for shopping with ForgeAlly Boutique!', style: pw.TextStyle(fontSize: 9, color: greenColor, fontWeight: pw.FontWeight.bold)),
              pw.Text('This is a computer generated invoice.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return Container(
          color: BoutiqueColors.bgMain,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Two-Panel Checkout Area (Customer Info & Items)
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

              // Right Running Cart & Billing Summary Panel
              Expanded(
                flex: 5,
                child: Container(
                  height: double.infinity,
                  color: BoutiqueColors.bgCard,
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
                    child: _buildSummaryPanel(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerSection() {
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
                  decoration: BoutiqueInputDecoration.field(
                    hintText: '10-digit mobile',
                    labelText: 'Mobile Number',
                    errorText: _mobileError(),
                  ),
                  onChanged: (_) => setState(() {}),
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
          Expanded(
            flex: 4,
            child: _ItemSearchField(
              products: products,
              selected: row.product,
              onSelected: (p) {
                setState(() {
                  row.product = p;
                  row.price = p.finalPrice > 0 ? p.finalPrice : p.mrp;
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
            width: 110,
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
              width: 90,
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
                width: 90,
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

        // Prominent Checkout & PDF Download Buttons
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveBill,
          style: ElevatedButton.styleFrom(
            backgroundColor: BoutiqueColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('GENERATE BILL & CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _hasValidRows ? _downloadInvoice : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text('DOWNLOAD INVOICE PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
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
