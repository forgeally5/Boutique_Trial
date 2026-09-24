import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final AdminState state;
  const CustomerLedgerScreen({super.key, required this.state});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPendingBills = [];
  Map<String, List<Map<String, dynamic>>> _customerGroups = {};
  
  String? _selectedCustomerKey; // Key is typically mobile number
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPendingBills();
  }

  Future<void> _fetchPendingBills() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('pendingBalance', isGreaterThan: 0)
          .orderBy('pendingBalance') // Requires composite index if we sort by date too, but let's fetch all and sort locally.
          .get();

      final bills = snap.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      // Sort by date locally
      bills.sort((a, b) {
        final t1 = (a['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final t2 = (b['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return t1.compareTo(t2); // Oldest first
      });

      _allPendingBills = bills;
      _groupBills();
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load pending bills.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _groupBills() {
    _customerGroups.clear();
    for (var bill in _allPendingBills) {
      final mobile = (bill['customerMobile']?.toString() ?? '').trim();
      final name = (bill['customerName']?.toString() ?? '').trim();
      
      if (mobile.isEmpty && name.isEmpty) continue; // Skip anonymous bills

      final key = mobile.isNotEmpty ? mobile : name; // Group by mobile ideally
      if (!_customerGroups.containsKey(key)) {
        _customerGroups[key] = [];
      }
      _customerGroups[key]!.add(bill);
    }
  }

  List<String> get _filteredCustomerKeys {
    final q = _searchQuery.toLowerCase();
    final keys = _customerGroups.keys.toList();
    if (q.isEmpty) return keys;

    return keys.where((k) {
      final bills = _customerGroups[k]!;
      final firstBill = bills.first;
      final name = (firstBill['customerName']?.toString() ?? '').toLowerCase();
      final mobile = (firstBill['customerMobile']?.toString() ?? '').toLowerCase();
      return name.contains(q) || mobile.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent));
    }

    final keys = _filteredCustomerKeys;

    return Row(
      children: [
        // LEFT: Customer List
        Container(
          width: 350,
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgSubtle,
            border: Border(right: BorderSide(color: BoutiqueColors.borderLight)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: BoutiqueInputDecoration.field(
                    hintText: 'Search customer name or mobile...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: BoutiqueColors.textSecondary),
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _selectedCustomerKey = null;
                  }),
                ),
              ),
              const Divider(height: 1, color: BoutiqueColors.borderLight),
              Expanded(
                child: keys.isEmpty
                    ? const Center(child: Text('No pending balances found.', style: TextStyle(color: BoutiqueColors.textSecondary)))
                    : ListView.builder(
                        itemCount: keys.length,
                        itemBuilder: (ctx, i) {
                          final k = keys[i];
                          final bills = _customerGroups[k]!;
                          final name = bills.first['customerName']?.toString() ?? '';
                          final mobile = bills.first['customerMobile']?.toString() ?? '';
                          final totalPending = bills.fold(0.0, (sum, b) => sum + ((b['pendingBalance'] as num?)?.toDouble() ?? 0.0));
                          final isSelected = _selectedCustomerKey == k;

                          return InkWell(
                            onTap: () => setState(() => _selectedCustomerKey = k),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                border: Border(
                                  bottom: const BorderSide(color: BoutiqueColors.borderLight),
                                  left: BorderSide(color: isSelected ? BoutiqueColors.accent : Colors.transparent, width: 4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name.isNotEmpty ? name : 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? BoutiqueColors.accent : BoutiqueColors.textPrimary)),
                                        if (mobile.isNotEmpty)
                                          Text(mobile, style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₹${NumberFormat('#,##,##0.00').format(totalPending)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB45309))),
                                      Text('${bills.length} bills', style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // RIGHT: Customer Details & Payment
        Expanded(
          child: _selectedCustomerKey == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: BoutiqueColors.border),
                      SizedBox(height: 16),
                      Text('Select a customer to view ledger', style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : _buildCustomerDetailPanel(_customerGroups[_selectedCustomerKey!]!),
        ),
      ],
    );
  }

  Widget _buildCustomerDetailPanel(List<Map<String, dynamic>> bills) {
    final name = bills.first['customerName']?.toString() ?? '';
    final mobile = bills.first['customerMobile']?.toString() ?? '';
    final totalPending = bills.fold(0.0, (sum, b) => sum + ((b['pendingBalance'] as num?)?.toDouble() ?? 0.0));

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgSubtle,
              border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isNotEmpty ? name : 'Unknown Customer', style: const TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(mobile.isNotEmpty ? '+91 $mobile' : 'No Phone Number', style: const TextStyle(fontSize: 14, color: BoutiqueColors.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Outstanding', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                      Text('₹${NumberFormat('#,##,##0.00').format(totalPending)}', style: const TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pending Bills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                ElevatedButton.icon(
                  onPressed: () => _showBulkPaymentDialog(bills, totalPending),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Receive Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Bill List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: bills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final b = bills[i];
                final date = (b['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                final pending = (b['pendingBalance'] as num?)?.toDouble() ?? 0.0;
                final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoutiqueColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bill #${b['billNo']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd MMM yyyy, hh:mm a').format(date), style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BoutiqueColors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(b['billType'] ?? 'Sale', style: const TextStyle(fontSize: 10, color: BoutiqueColors.accent)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Pending: ₹${NumberFormat('#,##,##0.00').format(pending)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB45309))),
                          const SizedBox(height: 4),
                          Text('Bill Total: ₹${NumberFormat('#,##,##0.00').format(total)}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkPaymentDialog(List<Map<String, dynamic>> bills, double totalPending) {
    final amountCtrl = TextEditingController(text: totalPending.toStringAsFixed(2));
    String mode = 'Cash';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: BoutiqueColors.bgCard,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receive Bulk Payment', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Payment will be applied to the oldest pending bills first.', style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoutiqueInputDecoration.field(
                      labelText: 'Amount Received (₹)',
                      hintText: 'e.g. 5000',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: BoutiqueInputDecoration.field(labelText: 'Payment Mode', hintText: ''),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                    ],
                    onChanged: (v) => setDialogState(() => mode = v!),
                  ),
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          final amt = double.tryParse(amountCtrl.text);
                          if (amt == null || amt <= 0 || amt > totalPending + 0.01) { // 0.01 margin for float errors
                            BoutiqueToast.showError(ctx, 'Invalid amount entered.');
                            return;
                          }
                          
                          setDialogState(() => isSaving = true);
                          await _processBulkPayment(bills, amt, mode);
                          
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            BoutiqueToast.showSuccess(context, 'Payment applied successfully!');
                            _fetchPendingBills(); // refresh ledger
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
                        child: isSaving 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Apply Payment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _processBulkPayment(List<Map<String, dynamic>> bills, double amountToApply, String mode) async {
    final batch = FirebaseFirestore.instance.batch();
    
    double remainingAmount = amountToApply;
    
    for (var b in bills) {
      if (remainingAmount <= 0) break;
      
      final docId = b['docId'] as String;
      final currentPending = (b['pendingBalance'] as num?)?.toDouble() ?? 0.0;
      final currentAmountReceived = (b['amountReceived'] as num?)?.toDouble() ?? 0.0;
      
      if (currentPending <= 0) continue;
      
      final appliedToThisBill = (remainingAmount >= currentPending) ? currentPending : remainingAmount;
      
      final newPending = currentPending - appliedToThisBill;
      final newAmountReceived = currentAmountReceived + appliedToThisBill;
      
      // We also need to update the `payments` array if it exists.
      final existingPayments = List<Map<String, dynamic>>.from(b['payments'] ?? []);
      existingPayments.add({
        'mode': mode,
        'amount': appliedToThisBill,
        'date': Timestamp.now(), // Track when this portion was paid
      });
      
      final ref = FirebaseFirestore.instance.collection('bills').doc(docId);
      batch.update(ref, {
        'pendingBalance': newPending,
        'amountReceived': newAmountReceived,
        'payments': existingPayments,
      });
      
      remainingAmount -= appliedToThisBill;
    }
    
    await batch.commit();
  }
}
