import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';

class CustomerReturnDialog extends StatefulWidget {
  final AdminState state;
  const CustomerReturnDialog({super.key, required this.state});

  @override
  State<CustomerReturnDialog> createState() => _CustomerReturnDialogState();
}

class _CustomerReturnDialogState extends State<CustomerReturnDialog> {
  final _billNoCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _refundModeCtrl = TextEditingController(text: 'Cash');
  
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _foundBill;
  
  // List of {itemData, isSelected, returnQty, condition}
  List<Map<String, dynamic>> _billItems = [];

  Future<void> _searchBill() async {
    final query = _billNoCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billNo', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) BoutiqueToast.showError(context, 'Bill not found');
        setState(() {
          _foundBill = null;
          _billItems = [];
        });
      } else {
        final data = snap.docs.first.data();
        final items = (data['items'] as List?) ?? [];
        
        setState(() {
          _foundBill = data;
          _billItems = items.map((i) => {
            'tagId': i['tagId'],
            'name': i['name'],
            'purchasedQty': i['qty'],
            'unitPrice': (i['lineAmount'] ?? 0) / (i['qty'] ?? 1),
            
            'isSelected': false,
            'returnQty': i['qty'],
            'condition': 'Defective', // 'Good' or 'Defective'
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Error searching: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalRefund {
    double total = 0;
    for (var i in _billItems) {
      if (i['isSelected'] == true) {
        total += (i['returnQty'] as num) * (i['unitPrice'] as num);
      }
    }
    return total;
  }

  Future<void> _save() async {
    final selectedItems = _billItems.where((i) => i['isSelected'] == true).toList();
    if (selectedItems.isEmpty) {
      BoutiqueToast.showError(context, 'Please select at least one item to return');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      BoutiqueToast.showError(context, 'Please enter a return reason');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final itemsToReturn = selectedItems.map((i) => {
        'tagId': i['tagId'],
        'name': i['name'],
        'qty': i['returnQty'],
        'lineAmount': (i['returnQty'] as num) * (i['unitPrice'] as num),
        'condition': i['condition'],
      }).toList();

      await widget.state.processCustomerReturn(
        originalBillNo: _foundBill!['billNo'] ?? '',
        customerName: _foundBill!['customerName'] ?? 'Walk-in',
        customerMobile: _foundBill!['customerMobile'] ?? '',
        returnReason: _reasonCtrl.text.trim(),
        totalRefund: _totalRefund,
        paymentMode: _refundModeCtrl.text.trim(),
        items: itemsToReturn,
      );

      if (mounted) {
        BoutiqueToast.showSuccess(context, 'Return processed successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Error processing return: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Customer Return', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
            const SizedBox(height: 20),
            
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _billNoCtrl,
                    decoration: BoutiqueInputDecoration.field(labelText: 'Original Bill No', hintText: 'e.g. SB-001'),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    onFieldSubmitted: (_) => _searchBill(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                  onPressed: _isLoading ? null : _searchBill,
                  icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_foundBill != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BoutiqueColors.bgSecondary, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: BoutiqueColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text('${_foundBill!['customerName'] ?? 'Walk-in'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    const Icon(Icons.phone_outlined, color: BoutiqueColors.textSecondary, size: 18),
                    const SizedBox(width: 6),
                    Text('${_foundBill!['customerMobile'] ?? 'No phone'}', style: const TextStyle(color: BoutiqueColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _billItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _billItems[i];
                    return Card(
                      elevation: 0,
                      color: BoutiqueColors.bgCard,
                      shape: RoundedRectangleBorder(side: const BorderSide(color: BoutiqueColors.border), borderRadius: BorderRadius.circular(8)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: item['isSelected'],
                              activeColor: BoutiqueColors.accent,
                              onChanged: (v) => setState(() => item['isSelected'] = v),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['tagId']} - ${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Bought: ${item['purchasedQty']} @ ₹${item['unitPrice'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                                ],
                              ),
                            ),
                            
                            // Return Qty
                            if (item['isSelected'] == true) ...[
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: item['returnQty'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                                  onChanged: (v) {
                                    final q = int.tryParse(v) ?? 1;
                                    setState(() => item['returnQty'] = q.clamp(1, item['purchasedQty']));
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Condition
                              DropdownButton<String>(
                                value: item['condition'],
                                underline: const SizedBox(),
                                items: ['Good', 'Defective'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setState(() => item['condition'] = v),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _reasonCtrl,
                      decoration: BoutiqueInputDecoration.field(labelText: 'Return Reason (Required)', hintText: 'e.g. Size didn\'t fit, Defective...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      decoration: BoutiqueInputDecoration.field(labelText: 'Refund Mode', hintText: ''),
                      initialValue: _refundModeCtrl.text,
                      items: ['Cash', 'UPI', 'Card', 'Store Credit'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _refundModeCtrl.text = v ?? 'Cash'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Refund: ₹${NumberFormat('#,##,##0.00', 'en_IN').format(_totalRefund)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
                  Row(
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent, foregroundColor: Colors.white),
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Process Return'),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (!_isLoading && _billNoCtrl.text.isNotEmpty) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Enter a valid bill number to proceed.', style: TextStyle(color: BoutiqueColors.textSecondary)),
              )),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
              )
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
              )
            ],
          ],
        ),
      ),
    );
  }
}

/// Formats text input to uppercase automatically
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
