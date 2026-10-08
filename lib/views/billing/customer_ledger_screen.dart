import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/boutique_pdf_generator.dart';
import '../../services/api_service.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final AdminState state;
  const CustomerLedgerScreen({super.key, required this.state});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allBills = [];
  List<Map<String, dynamic>> _allPendingBills = [];
  final Map<String, List<Map<String, dynamic>>> _customerGroups = {};

  String? _selectedCustomerKey;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPendingBills();
  }

  double _getPendingAmount(Map<String, dynamic> b) {
    final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final received = (b['amountReceived'] as num?)?.toDouble() ?? total;
    final rawPending = (b['pendingBalance'] as num?)?.toDouble();
    final computed = rawPending ?? (total - received);
    return computed > 0.01 ? computed : 0.0;
  }

  /// Safely parse a date field that may be a String, DateTime, or legacy map.
  static DateTime _parseBillDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    // Handle map-style {seconds:..., nanoseconds:...} from old Firestore data
    if (v is Map) {
      final s = v['seconds'] ?? v['_seconds'];
      if (s != null) return DateTime.fromMillisecondsSinceEpoch((s as num).toInt() * 1000);
    }
    return DateTime.now();
  }

  /// Generates the next sequential Due Receipt number (DR-001, DR-002, ...)
  /// independent of the SB-xxx invoice series.
  int _getMaxDueReceiptNumber() {
    int maxNum = 0;
    for (final b in _allBills) {
      final history = List<Map<String, dynamic>>.from(
        b['paymentHistory'] ?? [],
      );
      for (final h in history) {
        final type = (h['type']?.toString() ?? '').toLowerCase();
        final note = (h['note']?.toString() ?? h['notes']?.toString() ?? '').toLowerCase();
        if (type == 'initial payment' || note == 'initial payment' || note == 'initial bill payment') {
          continue;
        }
        final rNo = h['receiptNo']?.toString() ?? '';
        if (rNo.startsWith('DR-')) {
          final match = RegExp(r'\d+').firstMatch(rNo);
          if (match != null) {
            final n = int.tryParse(match.group(0)!) ?? 0;
            if (n > maxNum) maxNum = n;
          }
        }
      }
    }
    return maxNum;
  }

  /// Returns all due/installment receipts for a bill, assigning fallback DR-xxx
  /// numbers to any legacy installment entries that were saved before receiptNo existed.
  List<Map<String, dynamic>> _getBillDueReceipts(Map<String, dynamic> b) {
    final billNo = b['billNo']?.toString() ?? 'SB';
    final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final currentPending = _getPendingAmount(b);
    final history = List<Map<String, dynamic>>.from(b['paymentHistory'] ?? []);

    final List<Map<String, dynamic>> receipts = [];
    int fallbackIdx = 1;

    for (final h in history) {
      final type = (h['type']?.toString() ?? '').toLowerCase();
      final note = (h['note']?.toString() ?? h['notes']?.toString() ?? '').toLowerCase();
      // Skip initial bill creation entry if marked as 'initial payment' or 'initial bill payment'
      if (type == 'initial payment' || note == 'initial payment' || note == 'initial bill payment') {
        continue;
      }

      final amt = (h['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0) continue;

      final existingReceiptNo = h['receiptNo']?.toString() ?? '';
      final receiptNo = existingReceiptNo.isNotEmpty
          ? existingReceiptNo
          : 'DR-${fallbackIdx.toString().padLeft(3, '0')}';
      fallbackIdx++;

      final rawBreakdown = h['breakdown'] as List<dynamic>?;
      final breakdown = (rawBreakdown != null && rawBreakdown.isNotEmpty)
          ? rawBreakdown.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [
              {'mode': h['mode']?.toString() ?? 'Cash', 'amount': amt},
            ];

      receipts.add({
        'receiptNo': receiptNo,
        'refBillNo': h['refBillNo']?.toString() ?? billNo,
        'date': h['date'] ?? b['billDate'] ?? DateTime.now().toIso8601String(),
        'amount': amt,
        'mode': h['mode']?.toString() ?? 'Cash',
        'breakdown': breakdown,
        'previousDue': (h['previousDue'] as num?)?.toDouble() ??
            (currentPending + amt).clamp(0.0, total),
        'remainingDue':
            (h['remainingDue'] as num?)?.toDouble() ?? currentPending,
        'note': h['note']?.toString() ?? 'Installment Payment',
      });
    }
    return receipts;
  }

  Future<void> _fetchPendingBills() async {
    setState(() => _isLoading = true);
    try {
      final hostingerBills = await ApiService().getBills();
      final allDocs = <Map<String, dynamic>>[];
      for (final hb in hostingerBills) {
        final docId = hb['doc_id'] ?? hb['docId'] ?? hb['id'] ?? '';
        final bNo = hb['bill_no'] ?? hb['billNo'] ?? hb['voucherNo'] ?? '';
        final copy = Map<String, dynamic>.from(hb);
        copy['docId'] = docId;
        copy['billNo'] = bNo;
        allDocs.add(copy);
      }

      _allBills = allDocs;

      final bills = allDocs
          .where((b) => _getPendingAmount(b) > 0.01)
          .toList();

      // Sort oldest first for FIFO bulk payment application
      bills.sort((a, b) {
        final t1 = _parseBillDate(a['billDate']);
        final t2 = _parseBillDate(b['billDate']);
        return t1.compareTo(t2);
      });

      _allPendingBills = bills;
      _groupBills();

      if (_selectedCustomerKey != null &&
          !_customerGroups.containsKey(_selectedCustomerKey)) {
        _selectedCustomerKey =
            _customerGroups.keys.isNotEmpty ? _customerGroups.keys.first : null;
      } else if (_selectedCustomerKey == null &&
          _customerGroups.keys.isNotEmpty) {
        _selectedCustomerKey = _customerGroups.keys.first;
      }
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

      String key;
      if (mobile.isNotEmpty) {
        key = mobile;
      } else if (name.isNotEmpty) {
        key = name;
      } else {
        key = 'Walk-in Customer (${bill['billNo'] ?? 'Bill'})';
      }

      if (!_customerGroups.containsKey(key)) {
        _customerGroups[key] = [];
      }
      _customerGroups[key]!.add(bill);
    }
  }

  List<String> get _filteredCustomerKeys {
    final q = _searchQuery.toLowerCase().trim();
    final keys = _customerGroups.keys.toList();
    if (q.isEmpty) return keys;

    return keys.where((k) {
      final bills = _customerGroups[k]!;
      for (final b in bills) {
        final name = (b['customerName']?.toString() ?? 'Walk-in Customer')
            .toLowerCase();
        final mobile = (b['customerMobile']?.toString() ?? '').toLowerCase();
        final billNo = (b['billNo']?.toString() ?? '').toLowerCase();
        if (name.contains(q) || mobile.contains(q) || billNo.contains(q)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: BoutiqueColors.accent),
      );
    }

    final keys = _filteredCustomerKeys;

    return Row(
      children: [
        // LEFT: Customer / Bill Group List
        Container(
          width: 360,
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgSubtle,
            border: Border(
              right: BorderSide(color: BoutiqueColors.borderLight),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: BoutiqueInputDecoration.field(
                          hintText: 'Search customer, mobile or bill #...',
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: BoutiqueColors.textSecondary,
                          ),
                        ),
                        onChanged: (v) => setState(() {
                          _searchQuery = v;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _fetchPendingBills,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: BoutiqueColors.accent,
                      ),
                      tooltip: 'Refresh Ledger',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: BoutiqueColors.borderLight),
              Expanded(
                child: keys.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending due balances found.',
                          style: TextStyle(color: BoutiqueColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: keys.length,
                        itemBuilder: (ctx, i) {
                          final k = keys[i];
                          final bills = _customerGroups[k]!;
                          final rawName =
                              (bills.first['customerName']?.toString() ?? '')
                                  .trim();
                          final rawMobile =
                              (bills.first['customerMobile']?.toString() ?? '')
                                  .trim();
                          final displayName = rawName.isNotEmpty
                              ? rawName
                              : 'Walk-in Customer';
                          final billNos = bills
                              .map((b) => b['billNo']?.toString() ?? '')
                              .where((s) => s.isNotEmpty)
                              .join(', ');
                          final totalPending = bills.fold(
                            0.0,
                            (acc, b) => acc + _getPendingAmount(b),
                          );
                          final isSelected = _selectedCustomerKey == k;

                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedCustomerKey = k),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border(
                                  bottom: const BorderSide(
                                    color: BoutiqueColors.borderLight,
                                  ),
                                  left: BorderSide(
                                    color: isSelected
                                        ? BoutiqueColors.accent
                                        : Colors.transparent,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected
                                                ? BoutiqueColors.accent
                                                : BoutiqueColors.textPrimary,
                                          ),
                                        ),
                                        if (rawMobile.isNotEmpty)
                                          Text(
                                            rawMobile,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  BoutiqueColors.textSecondary,
                                            ),
                                          ),
                                        if (billNos.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'Bill: $billNos',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: BoutiqueColors.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${NumberFormat('#,##,##0.00').format(totalPending)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                      Text(
                                        '${bills.length} ${bills.length == 1 ? 'bill' : 'bills'} due',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: BoutiqueColors.textSecondary,
                                        ),
                                      ),
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

        // RIGHT: Customer Details & Split / Installment Due Payments
        Expanded(
          child:
              _selectedCustomerKey == null ||
                  !_customerGroups.containsKey(_selectedCustomerKey)
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: BoutiqueColors.border,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Select a customer or bill to view & settle due balance',
                        style: TextStyle(
                          color: BoutiqueColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildCustomerDetailPanel(
                  _customerGroups[_selectedCustomerKey!]!,
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerDetailPanel(List<Map<String, dynamic>> bills) {
    final rawName = (bills.first['customerName']?.toString() ?? '').trim();
    final rawMobile = (bills.first['customerMobile']?.toString() ?? '').trim();
    final displayName = rawName.isNotEmpty ? rawName : 'Walk-in Customer';
    final totalPending = bills.fold(
      0.0,
      (acc, b) => acc + _getPendingAmount(b),
    );
    final totalBilled = bills.fold(
      0.0,
      (acc, b) => acc + ((b['totalPayable'] as num?)?.toDouble() ?? 0.0),
    );
    final totalReceived = bills.fold(
      0.0,
      (acc, b) =>
          acc +
          ((b['amountReceived'] as num?)?.toDouble() ??
              ((b['totalPayable'] as num?)?.toDouble() ?? 0.0) -
                  _getPendingAmount(b)),
    );

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
              border: Border(
                bottom: BorderSide(color: BoutiqueColors.borderLight),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: BoutiqueColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rawMobile.isNotEmpty
                          ? '+91 $rawMobile'
                          : 'Walk-in / No Phone Number',
                      style: const TextStyle(
                        fontSize: 14,
                        color: BoutiqueColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _summaryStatBox(
                      label: 'Total Bill Value',
                      amount: totalBilled,
                      bgColor: Colors.white,
                      borderColor: BoutiqueColors.border,
                      textColor: BoutiqueColors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    _summaryStatBox(
                      label: 'Total Paid',
                      amount: totalReceived,
                      bgColor: const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFFBBF7D0),
                      textColor: const Color(0xFF15803D),
                    ),
                    const SizedBox(width: 12),
                    _summaryStatBox(
                      label: 'Total Due Amount',
                      amount: totalPending,
                      bgColor: const Color(0xFFFEF2F2),
                      borderColor: const Color(0xFFFECACA),
                      textColor: const Color(0xFFB91C1C),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Bills & Installment Ledger',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BoutiqueColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pay due amounts in parts (installments) or split across Cash / UPI / Card. Each due payment generates an independent DR-xxx Receipt.',
                      style: TextStyle(
                        fontSize: 12,
                        color: BoutiqueColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (bills.length > 1)
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(
                      title: 'Receive Bulk Due Payment',
                      subtitle:
                          'Applies payment across oldest pending bills first and generates DR-xxx Due Receipts.',
                      maxDue: totalPending,
                      onConfirm: (paidNow, splitList) async {
                        await _processBulkPayment(bills, paidNow, splitList);
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text(
                      'Bulk Pay All Bills',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Bill List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final b = bills[i];
                final date = _parseBillDate(b['billDate']);
                final pending = _getPendingAmount(b);
                final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
                final received =
                    (b['amountReceived'] as num?)?.toDouble() ??
                    (total - pending);

                final payments = List<Map<String, dynamic>>.from(
                  b['payments'] ?? [],
                );
                final dueReceipts = _getBillDueReceipts(b);
                final items = List<Map<String, dynamic>>.from(b['items'] ?? []);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BoutiqueColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Invoice #${b['billNo'] ?? '-'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: BoutiqueColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: BoutiqueColors.accentSoft,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      b['billType'] ?? 'Sale',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: BoutiqueColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BoutiqueColors.textSecondary,
                                ),
                              ),
                              if (items.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  items
                                      .map((it) {
                                        final itemName =
                                            (it['name'] ??
                                                    it['productName'] ??
                                                    'Product')
                                                .toString();
                                        final qty = it['qty'] ?? 1;
                                        return '$itemName (x$qty)';
                                      })
                                      .join(', '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: BoutiqueColors.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _printBillInvoice(b),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BoutiqueColors.accent,
                                  side: const BorderSide(
                                    color: BoutiqueColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Invoice PDF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showPaymentDialog(
                                  title:
                                      'Pay Due — Invoice #${b['billNo'] ?? ''}',
                                  subtitle:
                                      'Generates a separate Due Receipt (DR-xxx) with Ref Invoice #${b['billNo'] ?? ''}.',
                                  maxDue: pending,
                                  onConfirm: (paidNow, splitList) async {
                                    final createdReceipt =
                                        await _processSingleBillPayment(
                                          b,
                                          paidNow,
                                          splitList,
                                        );
                                    if (mounted) {
                                      _showDueReceiptPreviewDialog(
                                        b,
                                        createdReceipt,
                                      );
                                    }
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Pay Due (Split / Part)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        height: 1,
                        color: BoutiqueColors.borderLight,
                      ),
                      const SizedBox(height: 12),

                      // Bill Amounts & Payment Mode Breakdown Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Payment Modes Breakdown & Due Receipts List
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAYMENT BREAKDOWN (BY MODE)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                    color: BoutiqueColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (payments.isEmpty)
                                  Text(
                                    received > 0
                                        ? '• ${b['paymentMode'] ?? 'Cash'}: ₹${received.toStringAsFixed(2)}'
                                        : 'No payments received yet.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: BoutiqueColors.textPrimary,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: payments.map((p) {
                                      final m = p['mode']?.toString() ?? 'Cash';
                                      final a =
                                          (p['amount'] as num?)?.toDouble() ??
                                          0.0;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: BoutiqueColors.bgSubtle,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: BoutiqueColors.border,
                                          ),
                                        ),
                                        child: Text(
                                          '$m: ₹${a.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: BoutiqueColors.textPrimary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 14),
                                Text(
                                  'DUE PAYMENT RECEIPTS (REF: #${b['billNo'] ?? '-'})',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                    color: BoutiqueColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (dueReceipts.isEmpty)
                                  const Text(
                                    'No due installment receipts generated yet for this invoice.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: BoutiqueColors.textMuted,
                                    ),
                                  )
                                else
                                  ...dueReceipts.map((r) {
                                    final rNo =
                                        r['receiptNo']?.toString() ?? 'DR-001';
                                    final refNo =
                                        r['refBillNo']?.toString() ??
                                        b['billNo']?.toString() ??
                                        '-';
                                    final rAmt =
                                        (r['amount'] as num?)?.toDouble() ??
                                        0.0;
                                    final rDate =
                                        _parseBillDate(r['date']);
                                    final rBreakdown =
                                        List<Map<String, dynamic>>.from(
                                          r['breakdown'] ?? [],
                                        );
                                    final modeDetails = rBreakdown.isNotEmpty
                                        ? rBreakdown
                                              .map(
                                                (e) =>
                                                    '${e['mode']}: ₹${((e['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                              )
                                              .join(' + ')
                                        : (r['mode']?.toString() ?? 'Cash');

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDFBF7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE5DEC9),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        BoutiqueColors.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Receipt #$rNo',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: BoutiqueColors
                                                        .accentSoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Ref: #$refNo',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          BoutiqueColors.accent,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '₹${rAmt.toStringAsFixed(2)} ($modeDetails)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF15803D),
                                                  ),
                                                ),
                                                Text(
                                                  '• ${DateFormat('dd/MM/yyyy hh:mm a').format(rDate)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: BoutiqueColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _showDueReceiptPreviewDialog(
                                                      b,
                                                      r,
                                                    ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      BoutiqueColors.accent,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                ),
                                                icon: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 15,
                                                ),
                                                label: const Text(
                                                  'Receipt Preview',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    'Print / Download Receipt #$rNo',
                                                onPressed: () =>
                                                    _printDueReceipt(b, r),
                                                icon: const Icon(
                                                  Icons.print_outlined,
                                                  size: 16,
                                                  color: BoutiqueColors.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Right: Bill Total, Received, Due
                          Container(
                            width: 240,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BoutiqueColors.bgSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: BoutiqueColors.borderLight,
                              ),
                            ),
                            child: Column(
                              children: [
                                _billMiniRow(
                                  'Bill Total',
                                  '₹${NumberFormat('#,##,##0.00').format(total)}',
                                  BoutiqueColors.textPrimary,
                                  false,
                                ),
                                const SizedBox(height: 6),
                                _billMiniRow(
                                  'Received',
                                  '₹${NumberFormat('#,##,##0.00').format(received)}',
                                  const Color(0xFF15803D),
                                  true,
                                ),
                                const Divider(height: 14),
                                _billMiniRow(
                                  'DUE AMOUNT',
                                  '₹${NumberFormat('#,##,##0.00').format(pending)}',
                                  const Color(0xFFB91C1C),
                                  true,
                                ),
                              ],
                            ),
                          ),
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

  Widget _summaryStatBox({
    required String label,
    required double amount,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: textColor)),
          const SizedBox(height: 2),
          Text(
            '₹${NumberFormat('#,##,##0.00').format(amount)}',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _billMiniRow(String label, String val, Color color, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _printBillInvoice(Map<String, dynamic> b) async {
    try {
      final bytes = await BoutiquePdfGenerator.generate(b);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Failed to generate invoice PDF: $e');
      }
    }
  }

  Future<void> _printDueReceipt(
    Map<String, dynamic> b,
    Map<String, dynamic> receipt,
  ) async {
    try {
      final bytes = await BoutiquePdfGenerator.generateDueReceipt(
        bill: b,
        receipt: receipt,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Failed to print due receipt: $e');
      }
    }
  }

  Future<void> _downloadDueReceipt(
    Map<String, dynamic> b,
    Map<String, dynamic> receipt,
  ) async {
    try {
      final bytes = await BoutiquePdfGenerator.generateDueReceipt(
        bill: b,
        receipt: receipt,
      );
      final rNo = receipt['receiptNo']?.toString() ?? 'DR-001';
      await Printing.sharePdf(bytes: bytes, filename: 'DueReceipt_$rNo.pdf');
    } catch (e) {
      if (mounted) {
        BoutiqueToast.showError(context, 'Failed to download due receipt: $e');
      }
    }
  }

  /// Shows a boutique-styled Due Receipt Preview modal matching the PDF receipt.
  void _showDueReceiptPreviewDialog(
    Map<String, dynamic> bill,
    Map<String, dynamic> receipt,
  ) {
    const bgColor = Color(0xFFF9F6F0);
    const maroon = Color(0xFF5A121A);
    const goldLine = Color(0xFFC7B492);
    const textDark = Color(0xFF333333);
    const textLight = Color(0xFF666666);

    final fmt = DateFormat('dd/MM/yyyy');
    final receiptNo = receipt['receiptNo']?.toString() ?? 'DR-001';
    final refBillNo =
        receipt['refBillNo']?.toString() ?? bill['billNo']?.toString() ?? '-';
    final rawDate = receipt['date'];
    final receiptDate = rawDate is DateTime
        ? rawDate
        : (rawDate is String ? DateTime.tryParse(rawDate) : null) ??
            DateTime.now();
    final rawBillDate = bill['billDate'] ?? bill['voucherDate'];
    final billDate = rawBillDate is DateTime
        ? rawBillDate
        : (rawBillDate is String ? DateTime.tryParse(rawBillDate) : null) ??
            DateTime.now();

    final customerName = bill['customerName']?.toString().trim() ?? '';
    final customerMobile = bill['customerMobile']?.toString().trim() ?? '';
    final billTotal = (bill['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final paidNow = (receipt['amount'] as num?)?.toDouble() ?? 0.0;
    final previousDue =
        (receipt['previousDue'] as num?)?.toDouble() ?? paidNow;
    final remainingDue = (receipt['remainingDue'] as num?)?.toDouble() ??
        (previousDue - paidNow).clamp(0.0, double.infinity);
    final modeStr = receipt['mode']?.toString() ?? 'Cash';
    final noteStr = receipt['note']?.toString() ?? 'Installment Payment';
    final breakdown = List<Map<String, dynamic>>.from(
      receipt['breakdown'] ?? [],
    );

    Widget underlineVal(
      String text, {
      bool bold = false,
      Color color = textDark,
    }) {
      return Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: goldLine, width: 0.8)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 760),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Top Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Due Payment Receipt — #$receiptNo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: BoutiqueColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Print Receipt',
                        onPressed: () => _printDueReceipt(bill, receipt),
                        icon: const Icon(Icons.print_outlined, color: maroon),
                      ),
                      IconButton(
                        tooltip: 'Download PDF',
                        onPressed: () => _downloadDueReceipt(bill, receipt),
                        icon: const Icon(
                          Icons.download_outlined,
                          color: maroon,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: goldLine, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/logo.png',
                                    height: 50,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Text(
                                      'RITUMITA BOUTIQUE',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: maroon,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 1,
                                    width: 140,
                                    color: goldLine,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DUE RECEIPT',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: maroon,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(height: 1, color: goldLine),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'RECEIPT NO.',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textLight,
                                        ),
                                      ),
                                      underlineVal(receiptNo, bold: true),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'REF INVOICE NO.',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: maroon,
                                        ),
                                      ),
                                      underlineVal(
                                        refBillNo,
                                        bold: true,
                                        color: maroon,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'DATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textLight,
                                        ),
                                      ),
                                      underlineVal(fmt.format(receiptDate)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // RECEIVED FROM
                        const Text(
                          'RECEIVED FROM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        underlineVal(
                          customerName.isEmpty
                              ? 'Walk-in Customer'
                              : customerName,
                        ),
                        if (customerMobile.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          underlineVal('Phone: $customerMobile'),
                        ],
                        const SizedBox(height: 20),

                        // Table
                        Table(
                          border: TableBorder.all(color: goldLine, width: 0.8),
                          columnWidths: const {
                            0: FlexColumnWidth(0.7),
                            1: FlexColumnWidth(2.8),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.2),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: maroon),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'NO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'DESCRIPTION',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'REF BILL',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'PREV DUE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'PAID NOW',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    '1',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Due Amount Payment towards Invoice #$refBillNo (${fmt.format(billDate)})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    refBillNo,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: maroon,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    previousDue.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    paidNow.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Bottom Split: Payment Details & Summary
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PAYMENT DETAILS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'MODE   ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textLight,
                                        ),
                                      ),
                                      Expanded(child: underlineVal(modeStr)),
                                    ],
                                  ),
                                  if (breakdown.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    ...breakdown.map((p) {
                                      final m =
                                          p['mode']?.toString() ?? 'Cash';
                                      final a =
                                          (p['amount'] as num?)?.toDouble() ??
                                          0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '• $m',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: textLight,
                                              ),
                                            ),
                                            Text(
                                              '₹${a.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text(
                                        'REMARKS ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textLight,
                                        ),
                                      ),
                                      Expanded(child: underlineVal(noteStr)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.only(left: 14),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: goldLine,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'BILL TOTAL ($refBillNo)',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: textLight,
                                          ),
                                        ),
                                        underlineVal(
                                          billTotal.toStringAsFixed(2),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'PREVIOUS DUE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textLight,
                                          ),
                                        ),
                                        underlineVal(
                                          previousDue.toStringAsFixed(2),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(height: 1, color: goldLine),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'PAID NOW',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                        underlineVal(
                                          paidNow.toStringAsFixed(2),
                                          bold: true,
                                          color: const Color(0xFF15803D),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'BALANCE DUE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: maroon,
                                          ),
                                        ),
                                        underlineVal(
                                          remainingDue.toStringAsFixed(2),
                                          bold: true,
                                          color: maroon,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thank You',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 26,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                    color: maroon,
                                  ),
                                ),
                                Text(
                                  'FOR YOUR TRUST & SUPPORT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    color: textLight,
                                  ),
                                ),
                              ],
                            ),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'RituMita',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: maroon,
                                  ),
                                ),
                                Text(
                                  'www.ritumitasrentaljewels.com',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textLight,
                                  ),
                                ),
                                Text(
                                  '33, 7th Street, Tatabad, 100 Feet Road,',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textLight,
                                  ),
                                ),
                                Text(
                                  'Coimbatore - 641012',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog({
    required String title,
    required String subtitle,
    required double maxDue,
    required Future<void> Function(
      double totalPaidNow,
      List<Map<String, dynamic>> splitBreakdown,
    )
    onConfirm,
  }) {
    bool isSplitMode = false;
    String singleMode = 'Cash';
    final singleAmountCtrl = TextEditingController(
      text: maxDue.toStringAsFixed(2),
    );
    final List<Map<String, dynamic>> splitRows = [
      {'mode': 'Cash', 'ctrl': TextEditingController(text: '')},
      {'mode': 'UPI', 'ctrl': TextEditingController(text: '')},
    ];
    bool isSaving = false;
    final nextDrPreview =
        'DR-${(_getMaxDueReceiptNumber() + 1).toString().padLeft(3, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          double currentPaidNow = 0.0;
          if (!isSplitMode) {
            currentPaidNow = double.tryParse(singleAmountCtrl.text) ?? 0.0;
          } else {
            for (final r in splitRows) {
              currentPaidNow +=
                  double.tryParse(
                    (r['ctrl'] as TextEditingController).text,
                  ) ??
                  0.0;
            }
          }
          final remainingAfterThis =
              (maxDue - currentPaidNow).clamp(0.0, double.infinity);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: BoutiqueColors.bgCard,
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BoutiqueColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: BoutiqueColors.accentSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BoutiqueColors.accent),
                          ),
                          child: Text(
                            'Receipt #$nextDrPreview',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: BoutiqueColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BoutiqueColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Pending Due:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              Text(
                                '₹${maxDue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Paying Now:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹${currentPaidNow.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Remaining Due After Payment:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                              Text(
                                '₹${remainingAfterThis.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle Single vs Split Mode
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => isSplitMode = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: !isSplitMode
                                    ? BoutiqueColors.accentSoft
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !isSplitMode
                                      ? BoutiqueColors.accent
                                      : BoutiqueColors.border,
                                  width: !isSplitMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !isSplitMode
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: !isSplitMode
                                        ? BoutiqueColors.accent
                                        : BoutiqueColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Single Mode',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => isSplitMode = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSplitMode
                                    ? BoutiqueColors.accentSoft
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSplitMode
                                      ? BoutiqueColors.accent
                                      : BoutiqueColors.border,
                                  width: isSplitMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSplitMode
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: isSplitMode
                                        ? BoutiqueColors.accent
                                        : BoutiqueColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Split Modes (Cash+UPI)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!isSplitMode) ...[
                      TextField(
                        controller: singleAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: BoutiqueInputDecoration.field(
                          labelText: 'Amount Paying Now (₹)',
                          hintText: 'Enter partial or full due amount',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: singleMode,
                        decoration: BoutiqueInputDecoration.field(
                          labelText: 'Payment Mode',
                          hintText: '',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'Card', child: Text('Card')),
                          DropdownMenuItem(
                            value: 'Bank Transfer',
                            child: Text('Bank Transfer'),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() => singleMode = v!),
                      ),
                    ] else ...[
                      ...splitRows.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        final ctrl = row['ctrl'] as TextEditingController;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  initialValue: row['mode'] as String,
                                  decoration: BoutiqueInputDecoration.field(
                                    labelText: 'Mode ${idx + 1}',
                                    hintText: '',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Cash',
                                      child: Text('Cash'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'UPI',
                                      child: Text('UPI'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Card',
                                      child: Text('Card'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Bank Transfer',
                                      child: Text('Bank Transfer'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setDialogState(() => row['mode'] = v!),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: BoutiqueInputDecoration.field(
                                    labelText: 'Amount (₹)',
                                    hintText: '0.00',
                                  ),
                                ),
                              ),
                              if (splitRows.length > 1)
                                IconButton(
                                  onPressed: () => setDialogState(
                                    () => splitRows.removeAt(idx),
                                  ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Color(0xFFB91C1C),
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setDialogState(() {
                            splitRows.add({
                              'mode': 'Cash',
                              'ctrl': TextEditingController(text: ''),
                            });
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Another Payment Mode'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: BoutiqueColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  List<Map<String, dynamic>> breakdown = [];
                                  double totalPaidNow = 0.0;

                                  if (!isSplitMode) {
                                    final amt =
                                        double.tryParse(
                                          singleAmountCtrl.text,
                                        ) ??
                                        0.0;
                                    totalPaidNow = amt;
                                    if (amt > 0) {
                                      breakdown.add({
                                        'mode': singleMode,
                                        'amount': amt,
                                      });
                                    }
                                  } else {
                                    for (final r in splitRows) {
                                      final amt =
                                          double.tryParse(
                                            (r['ctrl'] as TextEditingController)
                                                .text,
                                          ) ??
                                          0.0;
                                      if (amt > 0) {
                                        totalPaidNow += amt;
                                        breakdown.add({
                                          'mode': r['mode'],
                                          'amount': amt,
                                        });
                                      }
                                    }
                                  }

                                  if (totalPaidNow <= 0 ||
                                      totalPaidNow > maxDue + 0.01) {
                                    BoutiqueToast.showError(
                                      ctx,
                                      'Enter a valid amount up to ₹${maxDue.toStringAsFixed(2)}',
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  Navigator.pop(ctx);
                                  await onConfirm(totalPaidNow, breakdown);
                                  if (mounted) {
                                    BoutiqueToast.showSuccess(
                                      context,
                                      'Due Receipt generated & payment recorded!',
                                    );
                                    _fetchPendingBills();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirm & Generate Receipt',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _processSingleBillPayment(
    Map<String, dynamic> b,
    double paidNow,
    List<Map<String, dynamic>> splitBreakdown,
  ) async {
    final docId = b['docId'] as String;
    final refBillNo = b['billNo']?.toString() ?? 'SB';
    final currentPending = _getPendingAmount(b);
    final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final currentReceived =
        (b['amountReceived'] as num?)?.toDouble() ?? (total - currentPending);

    final newPending =
        (currentPending - paidNow).clamp(0.0, double.infinity);
    final newReceived = currentReceived + paidNow;
    final isNowFullyPaid = newPending <= 0.01;

    final nextReceiptNum = _getMaxDueReceiptNumber() + 1;
    final receiptNo = 'DR-${nextReceiptNum.toString().padLeft(3, '0')}';

    final existingPayments = List<Map<String, dynamic>>.from(
      b['payments'] ?? [],
    );
    final existingHistory = List<Map<String, dynamic>>.from(
      b['paymentHistory'] ?? [],
    );

    final nowTs = DateTime.now().toIso8601String();
    for (final entry in splitBreakdown) {
      existingPayments.add({
        'mode': entry['mode'],
        'amount': entry['amount'],
        'date': nowTs,
        'receiptNo': receiptNo,
      });
    }

    final receiptModeLabel = splitBreakdown.length > 1
        ? 'Split'
        : (splitBreakdown.first['mode']?.toString() ?? 'Cash');

    final newReceiptRecord = <String, dynamic>{
      'receiptNo': receiptNo,
      'refBillNo': refBillNo,
      'mode': receiptModeLabel,
      'amount': paidNow,
      'breakdown': splitBreakdown,
      'previousDue': currentPending,
      'remainingDue': newPending,
      'date': nowTs,
      'note': isNowFullyPaid ? 'Final Settlement' : 'Installment Payment',
    };

    existingHistory.add(newReceiptRecord);

    String updatedModeLabel = b['paymentMode']?.toString() ?? 'Cash';
    if (existingPayments.length > 1) {
      updatedModeLabel = 'Split';
    } else if (existingPayments.length == 1) {
      updatedModeLabel = existingPayments.first['mode']?.toString() ?? 'Cash';
    }

    await ApiService().updateBill(docId, {
      'pendingBalance': newPending,
      'amountReceived': newReceived,
      'isFullyPaid': isNowFullyPaid,
      'paymentStatus': isNowFullyPaid ? 'Paid' : 'Partial / Due',
      'paymentMode': updatedModeLabel,
      'payments': existingPayments,
      'paymentHistory': existingHistory,
    });

    return newReceiptRecord;
  }

  Future<void> _processBulkPayment(
    List<Map<String, dynamic>> bills,
    double amountToApply,
    List<Map<String, dynamic>> splitBreakdown,
  ) async {
        final nowTs = DateTime.now().toIso8601String();
    int runningDrNum = _getMaxDueReceiptNumber();

    final chunks = splitBreakdown
        .map(
          (e) => {
            'mode': e['mode']?.toString() ?? 'Cash',
            'remaining': (e['amount'] as num?)?.toDouble() ?? 0.0,
          },
        )
        .toList();

    for (var b in bills) {
      final totalRemainingToApply = chunks.fold(
        0.0,
        (acc, c) => acc + (c['remaining'] as double),
      );
      if (totalRemainingToApply <= 0.001) break;

      final docId = (b['id'] ?? b['docId'] ?? b['doc_id'] ?? b['billNo'] ?? b['bill_no'] ?? '').toString();
      final refBillNo = b['billNo']?.toString() ?? 'SB';
      final currentPending = _getPendingAmount(b);
      final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
      final currentAmountReceived =
          (b['amountReceived'] as num?)?.toDouble() ?? (total - currentPending);

      if (currentPending <= 0.001) continue;

      double neededForThisBill = currentPending;
      double appliedToThisBill = 0.0;

      final existingPayments = List<Map<String, dynamic>>.from(
        b['payments'] ?? [],
      );
      final existingHistory = List<Map<String, dynamic>>.from(
        b['paymentHistory'] ?? [],
      );
      final List<Map<String, dynamic>> billBreakdown = [];

      runningDrNum++;
      final receiptNo = 'DR-${runningDrNum.toString().padLeft(3, '0')}';

      for (var chunk in chunks) {
        if (neededForThisBill <= 0.001) break;
        final avail = chunk['remaining'] as double;
        if (avail <= 0.001) continue;

        final take = avail >= neededForThisBill ? neededForThisBill : avail;
        chunk['remaining'] = avail - take;
        neededForThisBill -= take;
        appliedToThisBill += take;

        existingPayments.add({
          'mode': chunk['mode'],
          'amount': take,
          'date': nowTs,
          'receiptNo': receiptNo,
        });
        billBreakdown.add({'mode': chunk['mode'], 'amount': take});
      }

      if (appliedToThisBill > 0) {
        final newPending =
            (currentPending - appliedToThisBill).clamp(0.0, double.infinity);
        final newAmountReceived = currentAmountReceived + appliedToThisBill;
        final isNowFullyPaid = newPending <= 0.01;

        final receiptModeLabel = billBreakdown.length > 1
            ? 'Split'
            : (billBreakdown.first['mode']?.toString() ?? 'Cash');

        existingHistory.add({
          'receiptNo': receiptNo,
          'refBillNo': refBillNo,
          'mode': receiptModeLabel,
          'amount': appliedToThisBill,
          'breakdown': billBreakdown,
          'previousDue': currentPending,
          'remainingDue': newPending,
          'date': nowTs,
          'note': isNowFullyPaid ? 'Final Settlement' : 'Bulk Ledger Payment',
        });

        String updatedModeLabel = b['paymentMode']?.toString() ?? 'Cash';
        if (existingPayments.length > 1) {
          updatedModeLabel = 'Split';
        } else if (existingPayments.length == 1) {
          updatedModeLabel =
              existingPayments.first['mode']?.toString() ?? 'Cash';
        }

        
        await ApiService().updateBill(docId, {
          'pendingBalance': newPending,
          'amountReceived': newAmountReceived,
          'isFullyPaid': isNowFullyPaid,
          'paymentStatus': isNowFullyPaid ? 'Paid' : 'Partial / Due',
          'paymentMode': updatedModeLabel,
          'payments': existingPayments,
          'paymentHistory': existingHistory,
        });
      }
    }

    
  }
}

