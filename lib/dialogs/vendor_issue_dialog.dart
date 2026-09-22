import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/vendor_issue.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';

class VendorIssueDialog extends StatefulWidget {
  final AdminState state;

  const VendorIssueDialog({super.key, required this.state});

  @override
  State<VendorIssueDialog> createState() => _VendorIssueDialogState();
}

class _VendorIssueDialogState extends State<VendorIssueDialog> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _formKey = GlobalKey<FormState>();

  Product? _selectedProduct;
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();

  String? _issueType;
  DateTime _dateReported = DateTime.now();

  bool _isSaving = false;

  final List<String> _issueTypes = [
    'Damaged', 'Defective', 'Wrong Item Sent', 'Quality Issue', 'Broken in Transit', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_onQtyChanged);
  }

  void _onQtyChanged() {
    if (_selectedProduct != null) {
      final q = int.tryParse(_qtyCtrl.text) ?? 0;
      final unitPrice = _selectedProduct!.sellingPrice > 0 ? _selectedProduct!.sellingPrice : _selectedProduct!.mrp;
      final calcRefund = q * unitPrice;
      if (calcRefund > 0) {
        _refundCtrl.text = calcRefund.toStringAsFixed(2);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_onQtyChanged);
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReported,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateReported = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first'), backgroundColor: Colors.red),
      );
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0 || qty > _selectedProduct!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final issue = VendorIssue(
        id: '',
        tagId: _selectedProduct!.tagId,
        productName: _selectedProduct!.name,
        vendor: _selectedProduct!.vendor, // auto from product
        quantity: qty,
        issueType: _issueType!,
        actionTaken: 'Pending', // defaults to Pending; updatable from the table
        dateReported: _dateReported,
        notes: _notesCtrl.text.trim(),
        refundAmount: double.tryParse(_refundCtrl.text) ?? 0.0,
      );

      await widget.state.logVendorIssue(issue);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildProductSearch() {
    return Autocomplete<Product>(
      displayStringForOption: (p) => '${p.tagId} - ${p.name}',
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return const Iterable<Product>.empty();
        return widget.state.products.where((p) =>
            p.tagId.toLowerCase().contains(query) ||
            p.name.toLowerCase().contains(query));
      },
      onSelected: (p) {
        setState(() {
          _selectedProduct = p;
        });
        _onQtyChanged();
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onSubmit) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: BoutiqueInputDecoration.field(
            hintText: 'Search product...',
            labelText: 'Product',
          ),
          validator: (v) => _selectedProduct == null ? 'Select a product' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
         return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              height: 200,
              width: 300,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final p = options.elementAt(i);
                  final unitPrice = p.sellingPrice > 0 ? p.sellingPrice : p.mrp;
                  return ListTile(
                    title: Text('${p.tagId} - ${p.name}'),
                    subtitle: Text('Stock: ${p.quantity} | ₹${unitPrice.toStringAsFixed(2)} / pc'),
                    onTap: () => onSelected(p),
                  );
                }
              ),
            ),
          )
         );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final curQty = int.tryParse(_qtyCtrl.text) ?? 0;
    final curUnitPrice = _selectedProduct != null
        ? (_selectedProduct!.sellingPrice > 0 ? _selectedProduct!.sellingPrice : _selectedProduct!.mrp)
        : 0.0;
    final estRefund = curQty * curUnitPrice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Log Vendor Issue', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
              const SizedBox(height: 20),
              
              _buildProductSearch(),
              const SizedBox(height: 16),

              if (_selectedProduct != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: BoutiqueColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BoutiqueColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 16, color: BoutiqueColors.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Available Stock: ${_selectedProduct!.quantity} ${_selectedProduct!.unit}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.sell_outlined, size: 16, color: BoutiqueColors.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'Price / pc: ₹${NumberFormat('#,##,##0.00', 'en_IN').format(curUnitPrice)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (curQty > 0) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: BoutiqueColors.border),
                        const SizedBox(height: 6),
                        Text(
                          'Estimated Return: $curQty × ₹${NumberFormat('#,##,##0.00', 'en_IN').format(curUnitPrice)} = ₹${NumberFormat('#,##,##0.00', 'en_IN').format(estRefund)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Qty Affected (full width)
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: BoutiqueInputDecoration.field(labelText: 'Qty Affected', hintText: ''),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final q = int.tryParse(v) ?? 0;
                  if (q <= 0) return 'Must be > 0';
                  if (_selectedProduct != null && q > _selectedProduct!.quantity) return 'Exceeds total stock';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Issue Type (full width)
              DropdownButtonFormField<String>(
                decoration: BoutiqueInputDecoration.field(labelText: 'Issue Type', hintText: ''),
                initialValue: _issueType,
                isExpanded: true,
                items: _issueTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _issueType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: BoutiqueInputDecoration.field(labelText: 'Date Reported', hintText: ''),
                        child: Text(_fmt.format(_dateReported)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _refundCtrl,
                      keyboardType: TextInputType.number,
                      decoration: BoutiqueInputDecoration.field(labelText: 'Refund Amount (₹)', hintText: ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: BoutiqueInputDecoration.field(labelText: 'Notes (Optional)', hintText: ''),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent, foregroundColor: Colors.white),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Log Issue'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
