import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';

class CustomerReturnDialog extends StatefulWidget {
  final AdminState state;
  final Map<String, dynamic>? existingReturnBill;

  const CustomerReturnDialog({
    super.key,
    required this.state,
    this.existingReturnBill,
  });

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

  // List of items in bill with selection, qty, condition, error
  List<Map<String, dynamic>> _billItems = [];

  bool get _isEditing => widget.existingReturnBill != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final eb = widget.existingReturnBill!;
      String origBillNo = eb['originalBillNo']?.toString() ?? '';
      if (origBillNo.isEmpty || origBillNo == '—' || origBillNo == '-') {
        final narration = eb['narration']?.toString() ?? '';
        if (narration.startsWith('Return for ')) {
          origBillNo = narration.replaceAll('Return for ', '').trim();
        }
      }
      _billNoCtrl.text = origBillNo;
      _reasonCtrl.text = eb['returnReason']?.toString() ?? '';
      _refundModeCtrl.text = eb['paymentMode']?.toString() ?? 'Cash';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_billNoCtrl.text.isNotEmpty) {
          final itemsList = (eb['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _searchBill(existingReturnItems: itemsList);
        }
      });
    }
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _reasonCtrl.dispose();
    _refundModeCtrl.dispose();
    for (final item in _billItems) {
      final ctrl = item['qtyCtrl'] as TextEditingController?;
      ctrl?.dispose();
    }
    super.dispose();
  }

  Future<void> _searchBill({List<Map<String, dynamic>>? existingReturnItems}) async {
    final query = _billNoCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final bills = await ApiService().getBills();
      final matching = bills.where((b) => b['billNo']?.toString().toLowerCase() == query.toLowerCase()).toList();

      if (matching.isEmpty) {
        if (mounted) {
          BoutiqueToast.showError(context, 'Bill "$query" not found! Customer must have an existing purchase bill.');
        }
        setState(() {
          _foundBill = null;
          _billItems = [];
        });
      } else {
        final data = matching.first;
        final items = (data['items'] as List?) ?? [];

        // Calculate already returned items across all RETURN bills
        final returnedMap = <String, num>{};
        for (final b in bills) {
          if (b['billType']?.toString().toUpperCase() == 'RETURN') {
            // When editing, exclude the current return bill so its previous return quantities are available to re-edit
            if (_isEditing && b['billNo'] == widget.existingReturnBill!['billNo']) {
              continue;
            }
            String? orig = b['originalBillNo']?.toString();
            final rItems = b['items'];
            if (orig == null || orig.isEmpty) {
              if (rItems is List && rItems.isNotEmpty) {
                for (final item in rItems) {
                  if (item is Map && item['originalBillNo'] != null) {
                    orig = item['originalBillNo'].toString();
                    break;
                  }
                }
              }
            }
            if (orig == null || orig.isEmpty) {
              final narration = b['narration']?.toString() ?? '';
              if (narration.startsWith('Return for ')) {
                orig = narration.replaceAll('Return for ', '').trim();
              }
            }

            if (orig != null && orig.trim().toUpperCase() == query.toUpperCase()) {
              if (rItems is List) {
                for (final ri in rItems) {
                  if (ri is Map) {
                    final key = '${ri['tagId']}_${ri['name']}';
                    returnedMap[key] = (returnedMap[key] ?? 0) + ((ri['qty'] as num?) ?? 1);
                  }
                }
              }
            }
          }
        }

        // Clean previous controllers
        for (final item in _billItems) {
          final ctrl = item['qtyCtrl'] as TextEditingController?;
          ctrl?.dispose();
        }

        final billTotal = (data['totalPayable'] as num?)?.toDouble() ?? 0.0;
        final billSubtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
        final billRatio = (billSubtotal > 0 && billTotal > 0) ? (billTotal / billSubtotal) : 1.0;

        final availableItems = items.map((i) {
          final key = '${i['tagId']}_${i['name']}';
          final alreadyRet = returnedMap[key] ?? 0;
          final purchasedQty = (i['qty'] as num?) ?? 1;
          final availableToReturn = purchasedQty - alreadyRet;

          if (availableToReturn <= 0) return null;

          // Check if this item was in the existing return
          Map<String, dynamic>? prevItem;
          if (existingReturnItems != null) {
            for (final ex in existingReturnItems) {
              if (ex['tagId'] == i['tagId'] || ex['name'] == i['name']) {
                prevItem = ex;
                break;
              }
            }
          }

          final isSelected = prevItem != null;
          final initialReturnQty = prevItem != null
              ? ((prevItem['qty'] as num?)?.toInt() ?? availableToReturn.toInt()).clamp(1, availableToReturn.toInt())
              : availableToReturn.toInt();
          final condition = prevItem?['condition']?.toString() ?? 'Defective';

          final weight = (i['weight'] as num?)?.toDouble() ?? 0.0;
          final unit = (i['unit']?.toString().isNotEmpty == true) ? i['unit'].toString() : 'g';
          final pricingType = i['pricingType']?.toString() ?? 'Quantity-Based';
          final originalRate = (i['price'] as num?)?.toDouble() ?? 0.0;
          final lineAmt = (i['lineAmount'] as num?)?.toDouble() ?? 0.0;
          final itemTotal = lineAmt * billRatio;
          final unitPrice = (purchasedQty > 0 ? (itemTotal / purchasedQty) : itemTotal).toDouble();

          return {
            'tagId': i['tagId'],
            'name': i['name'],
            'category': i['category'] ?? '',
            'pricingType': pricingType,
            'weight': weight,
            'unit': unit,
            'originalRate': originalRate,
            'lineAmount': lineAmt,
            'purchasedQty': availableToReturn.toInt(),
            'unitPrice': unitPrice,
            'isSelected': isSelected,
            'returnQty': initialReturnQty,
            'condition': condition,
            'errorMsg': null as String?,
            'qtyCtrl': TextEditingController(text: initialReturnQty.toString()),
          };
        }).where((i) => i != null).cast<Map<String, dynamic>>().toList();

        if (availableItems.isEmpty) {
          if (mounted) BoutiqueToast.showError(context, 'All items in this bill have already been returned!');
          setState(() {
            _foundBill = null;
            _billItems = [];
          });
          return;
        }

        setState(() {
          _foundBill = data;
          _billItems = availableItems;
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
      if (i['isSelected'] == true && i['errorMsg'] == null) {
        total += ((i['returnQty'] as num?)?.toInt() ?? 0) * (i['unitPrice'] as num);
      }
    }
    return total;
  }

  void _showWarningAlert({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.of(ctx).pop(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.of(ctx).pop(),
          const SingleActivator(LogicalKeyboardKey.space): () => Navigator.of(ctx).pop(),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(),
        },
        child: FocusScope(
          autofocus: true,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFD97706)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14, color: BoutiqueColors.textPrimary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                autofocus: true,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK, Correct Quantity'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final selectedItems = _billItems.where((i) => i['isSelected'] == true).toList();
    if (selectedItems.isEmpty) {
      BoutiqueToast.showError(context, 'Please select at least one item to return');
      return;
    }

    // STRICT VALIDATION: Check that return quantity NEVER exceeds purchased quantity
    for (final i in selectedItems) {
      final qty = (i['returnQty'] as num?)?.toInt() ?? 0;
      final maxQty = (i['purchasedQty'] as num?)?.toInt() ?? 0;
      final name = i['name'] ?? i['tagId'] ?? 'Product';

      if (qty <= 0) {
        _showWarningAlert(
          title: 'Invalid Quantity',
          message: 'Quantity for "$name" must be at least 1.',
        );
        return;
      }

      if (qty > maxQty) {
        _showWarningAlert(
          title: 'Stock Purchase Limit Exceeded',
          message: 'Customer only purchased $maxQty unit(s) of "$name".\n\nYou cannot return $qty units!\n\nPlease enter $maxQty or less.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final itemsToReturn = selectedItems.map((i) => {
        'tagId': i['tagId'],
        'name': i['name'],
        'qty': (i['returnQty'] as num).toInt(),
        'weight': i['weight'],
        'unit': i['unit'],
        'pricingType': i['pricingType'],
        'unitPrice': i['unitPrice'],
        'lineAmount': (i['returnQty'] as num) * (i['unitPrice'] as num),
        'condition': i['condition'],
      }).toList();

      if (_isEditing) {
        final docId = widget.existingReturnBill!['docId']?.toString() ??
            widget.existingReturnBill!['doc_id']?.toString() ??
            widget.existingReturnBill!['id']?.toString() ??
            '';
        final oldItems = (widget.existingReturnBill!['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        await widget.state.updateCustomerReturn(
          docId: docId,
          returnBillNo: widget.existingReturnBill!['billNo'] ?? '',
          originalBillNo: _foundBill!['billNo'] ?? '',
          customerName: _foundBill!['customerName'] ?? 'Walk-in',
          customerMobile: _foundBill!['customerMobile'] ?? '',
          returnReason: _reasonCtrl.text.trim(),
          totalRefund: _totalRefund,
          paymentMode: _refundModeCtrl.text.trim(),
          oldItems: oldItems,
          newItems: itemsToReturn,
        );

        if (mounted) {
          BoutiqueToast.showSuccess(context, 'Customer return updated successfully');
          Navigator.pop(context, true);
        }
      } else {
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
          BoutiqueToast.showSuccess(context, 'Customer return processed successfully');
          Navigator.pop(context, true);
        }
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
        width: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isEditing ? Icons.edit_note_rounded : Icons.assignment_return_rounded, color: BoutiqueColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  _isEditing
                      ? 'Edit Customer Return (${widget.existingReturnBill?['billNo'] ?? ''})'
                      : 'Log Customer Return',
                  style: const TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _billNoCtrl,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.search,
                    decoration: BoutiqueInputDecoration.field(
                      labelText: 'Original Purchase Bill No',
                      hintText: 'e.g. SB-001',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    onFieldSubmitted: (_) => _searchBill(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _searchBill,
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Search Bill'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_foundBill != null) ...[
              () {
                final billTotal = (_foundBill!['totalPayable'] as num?)?.toDouble() ?? 0.0;
                final billReceived = (_foundBill!['amountReceived'] as num?)?.toDouble() ?? billTotal;
                final billDue = (_foundBill!['pendingBalance'] as num?)?.toDouble() ?? (billTotal - billReceived).clamp(0.0, double.infinity);
                final currencyFmt = NumberFormat('#,##,##0.00', 'en_IN');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BoutiqueColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BoutiqueColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, color: BoutiqueColors.textSecondary, size: 18),
                          const SizedBox(width: 6),
                          Text('${_foundBill!['customerName'] ?? 'Walk-in'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 16),
                          const Icon(Icons.phone_outlined, color: BoutiqueColors.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text('${_foundBill!['customerMobile'] ?? 'No phone'}', style: const TextStyle(color: BoutiqueColors.textSecondary, fontSize: 13)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: BoutiqueColors.accentSoft, borderRadius: BorderRadius.circular(4)),
                            child: Text('Bill: ${_foundBill!['billNo'] ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: BoutiqueColors.border),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bill Total: ₹${currencyFmt.format(billTotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BoutiqueColors.textPrimary)),
                          Text('Paid: ₹${currencyFmt.format(billReceived)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          Text('Due: ₹${currencyFmt.format(billDue)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: billDue > 0 ? const Color(0xFFDC2626) : BoutiqueColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                );
              }(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Purchased Products (Select to Return):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${_billItems.length} product(s) available', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _billItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _billItems[i];
                    final maxQty = (item['purchasedQty'] as num).toInt();
                    final hasError = item['errorMsg'] != null;

                    return Card(
                      elevation: 0,
                      color: hasError ? const Color(0xFFFFF5F5) : BoutiqueColors.bgCard,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: hasError ? Colors.red : BoutiqueColors.border, width: hasError ? 1.5 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: item['isSelected'],
                                  activeColor: BoutiqueColors.accent,
                                  onChanged: (v) => setState(() => item['isSelected'] = v),
                                ),
                                Expanded(
                                  child: () {
                                    final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
                                    final weightUnit = AdminState.resolveWeightUnit(item);
                                    final isWeight = item['pricingType'] == 'Weight-Based' || weight > 0;
                                    final weightStr = weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 2);
                                    final originalRate = (item['originalRate'] as num?)?.toDouble() ?? 0.0;
                                    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
                                    final numFmt = NumberFormat('#,##,##0.00', 'en_IN');

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['tagId']} - ${item['name']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isWeight
                                              ? 'Max Purchased: $maxQty unit(s) ($weightStr $weightUnit) • Rate: ₹${originalRate.toStringAsFixed(2)}/$weightUnit • Net Price: ₹${numFmt.format(unitPrice)}'
                                              : 'Max Purchased: $maxQty unit(s) • Net Price: ₹${numFmt.format(unitPrice)} / pc',
                                          style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
                                        ),
                                      ],
                                    );
                                  }(),
                                ),

                                // Return Qty
                                if (item['isSelected'] == true) ...[
                                  SizedBox(
                                    width: 95,
                                    child: TextFormField(
                                      controller: item['qtyCtrl'] as TextEditingController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Return Qty',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: const OutlineInputBorder(),
                                        errorStyle: const TextStyle(height: 0),
                                        errorText: hasError ? '' : null,
                                      ),
                                      onChanged: (v) {
                                        final q = int.tryParse(v);
                                        if (q == null || q <= 0) {
                                          setState(() {
                                            item['returnQty'] = 0;
                                            item['errorMsg'] = 'Min 1 qty required';
                                          });
                                        } else if (q > maxQty) {
                                          setState(() {
                                            item['returnQty'] = q;
                                            item['errorMsg'] = 'Exceeds purchase! (Max: $maxQty)';
                                          });
                                        } else {
                                          setState(() {
                                            item['returnQty'] = q;
                                            item['errorMsg'] = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Condition
                                  DropdownButton<String>(
                                    value: item['condition'],
                                    underline: const SizedBox(),
                                    items: ['Good', 'Defective']
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                                        .toList(),
                                    onChanged: (v) => setState(() => item['condition'] = v),
                                  ),
                                ]
                              ],
                            ),
                            if (hasError && item['isSelected'] == true) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 48, top: 2),
                                child: Text(
                                  '⚠️ ${item['errorMsg']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _reasonCtrl,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: BoutiqueInputDecoration.field(
                        labelText: 'Return Reason (Optional)',
                        hintText: 'e.g. Size didn\'t fit, Defective, Exchange...',
                      ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Refund: ₹${NumberFormat('#,##,##0.00', 'en_IN').format(_totalRefund)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                      ),
                      if (_foundBill != null &&
                          ((_foundBill!['pendingBalance'] as num?)?.toDouble() ?? 0.0) > 0)
                        Text(
                          'Note: Bill has ₹${((_foundBill!['pendingBalance'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} unpaid due',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent, foregroundColor: Colors.white),
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isEditing ? 'Update Return' : 'Process Return'),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (!_isLoading && _billNoCtrl.text.isNotEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Enter a valid purchase bill number to view customer stock.', style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
              ),
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
