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

  // Summary controllers — managed separately so only summary panel rebuilds
  final _extraDiscountCtrl = TextEditingController(text: '0');
  String _extraDiscountType = '₹';

  String _paymentMode = 'Cash';

  bool _isSaving = false;
  bool _attemptedSave = false;

  // Tracks row mutations (product select, qty change) so summary panel recalculates
  final ValueNotifier<int> _rowVersion = ValueNotifier(0);

  // Cached product list — read from state once, not on every rebuild
  List<Product> _cachedProducts = [];

  @override
  void initState() {
    super.initState();
    _cachedProducts = widget.state.products;
    _fetchNextBillNo();
    // Listen to AdminState for product list updates ONLY — no full-form rebuild
    widget.state.addListener(_onStateProductsUpdate);
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
    _extraDiscountCtrl.dispose();
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
      if (mounted) _billNoCtrl.text = 'FA-${nextNum.toString().padLeft(4, '0')}';
    } catch (_) {
      if (mounted) _billNoCtrl.text = 'FA-0001';
    }
  }

  // ── Calculation Helpers ───────────────────────────────────────────────────

  double get _subtotal => _rows.fold(0, (s, r) => s + r.lineAmount);
  double get _totalGst => _rows.fold(0, (s, r) => s + r.lineGstAmount);

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

  Future<void> _saveBill() async {
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
      final taxAmt = _totalGst;
      final total = (discounted + taxAmt).clamp(0.0, double.infinity);

      final billData = {
        'billNo': _billNoCtrl.text.trim(),
        'billType': 'Sale',
        'billDate': Timestamp.fromDate(_billDate),
        'customerName': _customerNameCtrl.text.trim(),
        'customerMobile': _customerMobileCtrl.text.trim(),
        'items': validRows.map((r) => r.toMap()).toList(),
        'subtotal': subtotal,
        'extraDiscountType': _extraDiscountType,
        'extraDiscountValue': double.tryParse(_extraDiscountCtrl.text) ?? 0,
        'extraDiscountAmount': discAmt,
        'taxAmount': taxAmt,
        'totalPayable': total,
        'paymentMode': _paymentMode,
        'amountReceived': total,
        'balanceReturned': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('bills').add(billData);

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

    final subtotal = _subtotal;
    final discAmt = _extraDiscountAmount(subtotal);
    final discounted = (subtotal - discAmt).clamp(0.0, double.infinity);
    final taxAmt = _totalGst;
    final total = (discounted + taxAmt).clamp(0.0, double.infinity);

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
                final itemName = r.product?.name ?? '';
                final nameText = r.gstRate > 0 ? '$itemName\n(GST: ${r.gstRate}%)' : itemName;
                return pw.TableRow(
                  children: [
                    _pdfCell(i.toString()),
                    _pdfCell(nameText, align: pw.Alignment.centerLeft),
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
                    _pdfTotalRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}', tColor),
                    if (discAmt > 0)
                      _pdfTotalRow('Extra Discount', '− ₹${discAmt.toStringAsFixed(2)}', tColor),
                    if (taxAmt > 0)
                      _pdfTotalRow('Total GST', '+ ₹${taxAmt.toStringAsFixed(2)}', tColor),
                    pw.Container(height: 1, color: tColor),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      color: tLight,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL PAYABLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: tColor)),
                          pw.Text('₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: tColor)),
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
                  isSaving: _isSaving,
                  hasValidRows: _hasValidRows,
                  onDiscountTypeChanged: (t) => setState(() => _extraDiscountType = t),
                  onSave: _saveBill,
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
          const Text('Customer & Invoice Details',
              style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
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
              // Customer name — no setState, TextField manages its own text
              Expanded(
                child: TextField(
                  controller: _customerNameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(
                      hintText: 'Walk-in Customer', labelText: 'Customer Name'),
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
          // Each row is its own StatefulWidget — changes in one row don't rebuild others
          for (int i = 0; i < _rows.length; i++)
            _BillRowWidget(
              key: ObjectKey(_rows[i]),
              row: _rows[i],
              products: _cachedProducts,
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
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _BillRowWidget({
    super.key,
    required this.row,
    required this.products,
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
              onSelected: (p) {
                if (p.sellableQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item is out of stock or damaged.'), backgroundColor: Colors.red),
                  );
                  return;
                }
                setState(() {
                  row.product = p;
                  if (row.qty > p.sellableQuantity) row.qty = p.sellableQuantity.toDouble();
                  row.price = p.finalPrice > 0 ? p.finalPrice : p.mrp;
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
                Text('Qty: ${row.qty.toInt()} ${row.unitLabel}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.add, size: 14, color: BoutiqueColors.accent),
                  onPressed: (row.product != null && row.qty < row.product!.sellableQuantity)
                      ? () {
                          setState(() => row.qty += 1);
                          widget.onChanged();
                        }
                      : null,
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
                Text('₹${row.lineAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                Text('@ ₹${row.price}',
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
}

// ── Product Autocomplete ──────────────────────────────────────────────────────
// Uses Flutter's Autocomplete widget — only renders the suggestions that match
// the search query, NOT all products as widget items simultaneously.

class _ProductAutocomplete extends StatelessWidget {
  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onSelected;

  const _ProductAutocomplete({
    required this.products,
    required this.selected,
    required this.onSelected,
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
                  return InkWell(
                    onTap: () => onSelected(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.tagId} - ${p.name}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹${p.mrp}  •  ${p.category}  •  Qty: ${p.sellableQuantity}',
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
  final bool isSaving;
  final bool hasValidRows;
  final ValueChanged<String> onDiscountTypeChanged;
  final VoidCallback onSave;
  final VoidCallback onDownload;

  const _BillSummaryPanel({
    required this.rows,
    required this.rowVersion,
    required this.extraDiscountCtrl,
    required this.extraDiscountType,
    required this.isSaving,
    required this.hasValidRows,
    required this.onDiscountTypeChanged,
    required this.onSave,
    required this.onDownload,
  });

  @override
  State<_BillSummaryPanel> createState() => _BillSummaryPanelState();
}

class _BillSummaryPanelState extends State<_BillSummaryPanel> {
  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder listens to discount/tax controllers AND rowVersion
    // so subtotal recalculates on product select, qty change, or discount/tax edits
    return AnimatedBuilder(
      animation: Listenable.merge([widget.extraDiscountCtrl, widget.rowVersion]),
      builder: (context, _) {
        final subtotal = widget.rows.fold<double>(0, (s, r) => s + r.lineAmount);
        final discV = double.tryParse(widget.extraDiscountCtrl.text) ?? 0;
        final discAmt = widget.extraDiscountType == '%'
            ? (subtotal * discV / 100).clamp(0, subtotal)
            : discV.clamp(0, subtotal);
        final discounted = (subtotal - discAmt).clamp(0.0, double.infinity);
        
        final taxAmt = widget.rows.fold<double>(0, (s, r) => s + r.lineGstAmount);
        final total = (discounted + taxAmt).clamp(0.0, double.infinity);

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
            if (discAmt > 0) ...[
              const SizedBox(height: 4),
              _summaryRow('Discount Applied', '− ₹${discAmt.toStringAsFixed(2)}'),
            ],
            if (taxAmt > 0) ...[
              const SizedBox(height: 12),
              _summaryRow('Total GST', '+ ₹${taxAmt.toStringAsFixed(2)}'),
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

            ElevatedButton.icon(
              onPressed: widget.isSaving ? null : widget.onSave,
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
