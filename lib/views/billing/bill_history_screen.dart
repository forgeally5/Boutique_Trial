import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/pdf_invoice_api.dart';

class BillHistoryScreen extends StatefulWidget {
  final AdminState? state;
  const BillHistoryScreen({super.key, this.state});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  final _fmt = DateFormat('dd/MM/yyyy');
  late DateTime _dateFrom;
  late DateTime _dateTo;

  final _searchCtrl = TextEditingController();
  String _paymentModeFilter = 'All';
  bool _loading = false;

  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filtered = [];

  final List<String> _paymentModes = [
    'All',
    'Cash',
    'Card',
    'UPI',
    'Bank Transfer',
    'Cheque',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    _dateFrom = fyStart;
    _dateTo = now;
    _loadBills();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billType', isEqualTo: 'Sale')
          .get();

      final fromDt = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        data['_docId'] = doc.id;
        final ts = data['billDate'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (dt.isAfter(fromDt.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(toDt.add(const Duration(seconds: 1)))) {
            list.add(data);
          }
        }
      }
      list.sort((a, b) {
        final ta = a['billDate'] as Timestamp?;
        final tb = b['billDate'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _bills = list;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        BoutiqueToast.showError(context, 'Error loading bills: $e');
      }
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _bills.where((e) {
        if (q.isNotEmpty) {
          final billNo = (e['billNo'] ?? '').toString().toLowerCase();
          final customer = (e['customerName'] ?? '').toString().toLowerCase();
          final mobile = (e['customerMobile'] ?? '').toString();
          if (!billNo.contains(q) && !customer.contains(q) && !mobile.contains(q)) return false;
        }
        if (_paymentModeFilter != 'All' && e['paymentMode'] != _paymentModeFilter) return false;
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _loadBills();
    }
  }

  Future<void> _deleteBill(Map<String, dynamic> bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: BoutiqueColors.bgCard,
        title: const Text('Delete Bill?', style: TextStyle(fontFamily: 'serif', color: BoutiqueColors.textPrimary)),
        content: Text('Delete bill ${bill['billNo'] ?? ''}? This action cannot be undone.'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: BoutiqueColors.border)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('bills').doc(bill['_docId']).delete();
      _loadBills();
      if (mounted) BoutiqueToast.showSuccess(context, 'Bill deleted successfully');
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Error: $e');
    }
  }

  void _viewBill(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (ctx) => _BillDetailDialog(bill: bill),
    );
  }

  double get _totalSales => _filtered.fold(0.0, (s, e) => s + ((e['totalPayable'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BoutiqueColors.bgMain,
      child: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(
                      hintText: 'Search bill #, customer, mobile...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: BoutiqueColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentModeFilter,
                    style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                    decoration: BoutiqueInputDecoration.field(hintText: 'Payment Mode'),
                    items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _paymentModeFilter = v);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: BoutiqueColors.accent),
                  onPressed: _loadBills,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Total Sales Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            color: BoutiqueColors.accentSoft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Invoices: ${_filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.accent)),
                Text('Total Sales: ₹${_totalSales.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 16, color: BoutiqueColors.accent)),
              ],
            ),
          ),

          // Invoices Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(32),
              decoration: BoutiqueDecoration.card(),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
                  : _filtered.isEmpty
                      ? const Center(child: Text('No invoice records found.', style: TextStyle(color: BoutiqueColors.textSecondary)))
                      : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                          itemBuilder: (context, idx) {
                            final b = _filtered[idx];
                            return ListTile(
                              onTap: () => _viewBill(b),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: BoutiqueColors.accentSoft, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.receipt_long_rounded, color: BoutiqueColors.accent, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(b['billNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BoutiqueColors.accent)),
                                  const SizedBox(width: 12),
                                  Text(b['customerName'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BoutiqueColors.textPrimary)),
                                ],
                              ),
                              subtitle: Text(
                                'Date: ${_fmt.format((b['billDate'] as Timestamp).toDate())} • Mode: ${b['paymentMode']}',
                                style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${((b['totalPayable'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, color: BoutiqueColors.accent, size: 20),
                                    onPressed: () => _viewBill(b),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: BoutiqueColors.destructive, size: 20),
                                    onPressed: () => _deleteBill(b),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePill(String label, DateTime dt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: BoutiqueColors.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BoutiqueColors.border),
        ),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
            Text(_fmt.format(dt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Printable Invoice Receipt Dialog ──────────────────────────────────────────

class _BillDetailDialog extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BillDetailDialog({required this.bill});

  Future<void> _handlePrintPdf(BuildContext context) async {
    final invoiceData = SalesInvoiceData(
      customerName: bill['customerName']?.toString() ?? 'Customer',
      customerMobile: bill['customerMobile']?.toString() ?? '',
      customerAddress: '',
      customerState: '',
      invoiceNo: bill['billNo']?.toString() ?? 'FA-0001',
      date: bill['billDate'] != null ? DateFormat('dd/MM/yyyy').format((bill['billDate'] as Timestamp).toDate()) : '',
      placeOfSupply: '',
      items: [],
      totalPcs: 1,
      totalGrossWt: 0,
      totalNetWt: 0,
      totalMetalAmt: 0,
      totalAmount: (bill['totalPayable'] as num?)?.toDouble() ?? 0,
      discountAmt: (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0,
      taxableAmount: (bill['subtotal'] as num?)?.toDouble() ?? 0,
      cgstAmt: 0,
      sgstAmt: 0,
      igstAmt: 0,
      roundOff: 0,
      grossAmount: (bill['totalPayable'] as num?)?.toDouble() ?? 0,
      receivedAmt: (bill['amountReceived'] as num?)?.toDouble() ?? 0,
      amountInWords: PdfInvoiceApi.numberToWords((bill['totalPayable'] as num?)?.toDouble() ?? 0),
      cardDetails: bill['paymentMode']?.toString() ?? '',
      customerPan: '',
      narration: '',
      dueAmount: 0,
      receiptDetails: '',
      credits: '',
    );
    final bytes = await PdfInvoiceApi.generate(invoiceData);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final billDate = bill['billDate'] ?? bill['date'];
    final dateStr = billDate is Timestamp ? fmt.format(billDate.toDate()) : '—';
    final items = (bill['items'] as List?) ?? [];
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0;
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0;
    final extraDisc = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0;
    final tax = (bill['taxAmount'] as num?)?.toDouble() ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Toolbar (Above Receipt Area)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Invoice Preview', style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: BoutiqueColors.accent),
                      onPressed: () => _handlePrintPdf(context),
                      tooltip: 'Print Invoice / PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, color: BoutiqueColors.accent),
                      onPressed: () => _handlePrintPdf(context),
                      tooltip: 'Download PDF',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: BoutiqueColors.border),

            // Printable Receipt Content Box
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: BoutiqueColors.bgSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BoutiqueColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Boutique Header Logo & Address
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'FORGEALLY BOUTIQUE',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: BoutiqueColors.accent,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('High-End Fashion & Custom Couture', style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                        Text('GSTIN: 33AAAAA0000A1Z5 | Ph: +91 98765 43210', style: TextStyle(fontSize: 11, color: BoutiqueColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: BoutiqueColors.border),

                  // Bill & Customer Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoice No: ${bill['billNo'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary)),
                          Text('Date: $dateStr', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Customer: ${bill['customerName'] ?? 'Walk-in Customer'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary)),
                          Text('Payment: ${bill['paymentMode'] ?? 'Cash'}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Itemized Table
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: BoutiqueColors.border)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          color: BoutiqueColors.bgSubtle,
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text('Item Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary))),
                            ],
                          ),
                        ),
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(flex: 4, child: Text('${item['tagId'] ?? ''} - ${item['name'] ?? ''}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textPrimary))),
                                  Expanded(flex: 1, child: Text('${item['qty']}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textPrimary))),
                                  Expanded(flex: 2, child: Text('₹${(item['price'] as num?)?.toStringAsFixed(2) ?? '0'}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textPrimary))),
                                  Expanded(flex: 2, child: Text('₹${(item['lineAmount'] as num?)?.toStringAsFixed(2) ?? '0'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Totals Breakdown
                  _detailRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
                  if (extraDisc > 0) _detailRow('Discount', '− ₹${extraDisc.toStringAsFixed(2)}'),
                  if (tax > 0) _detailRow('GST Tax', '+ ₹${tax.toStringAsFixed(2)}'),
                  const Divider(color: BoutiqueColors.border),
                  _detailRow('TOTAL PAID', '₹${total.toStringAsFixed(2)}', large: true),

                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Thank you for shopping with ForgeAlly Boutique! ✨',
                      style: TextStyle(fontFamily: 'serif', fontSize: 13, fontStyle: FontStyle.italic, color: BoutiqueColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: large ? 15 : 13, fontWeight: large ? FontWeight.bold : FontWeight.normal, color: BoutiqueColors.textPrimary)),
          Text(value, style: TextStyle(fontFamily: 'serif', fontSize: large ? 20 : 13, fontWeight: FontWeight.bold, color: large ? BoutiqueColors.accent : BoutiqueColors.textPrimary)),
        ],
      ),
    );
  }
}
