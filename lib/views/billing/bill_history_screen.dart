import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../state/admin_state.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF8D6E63);
const _bg = Color(0xFFFCFAF5);
const _border = Color(0xFFE5DDD0);
const _green = Color(0xFF2E7D32);
const _errorColor = Color(0xFFB71C1C);

class BillHistoryScreen extends StatefulWidget {
  final AdminState state;

  const BillHistoryScreen({super.key, required this.state});

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

  static const _paymentModes = ['All', 'Cash', 'UPI', 'Card', 'Split Payment'];

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

      final results = snap.docs.map((d) {
        final data = d.data();
        data['_docId'] = d.id;
        return data;
      }).where((e) {
        final bd = e['billDate'] ?? e['date'];
        if (bd is Timestamp) {
          final dt = bd.toDate();
          if (dt.isBefore(fromDt) || dt.isAfter(toDt)) return false;
        }
        return true;
      }).toList();

      results.sort((a, b) {
        final aTs = a['billDate'] ?? a['date'];
        final bTs = b['billDate'] ?? b['date'];
        final aDt = aTs is Timestamp ? aTs.toDate() : DateTime(2000);
        final bDt = bTs is Timestamp ? bTs.toDate() : DateTime(2000);
        return bDt.compareTo(aDt);
      });

      setState(() {
        _bills = results;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _errorColor),
        );
      }
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _bills.where((e) {
        // Bill No / Customer search
        if (q.isNotEmpty) {
          final billNo = (e['billNo'] ?? '').toString().toLowerCase();
          final customer = (e['customerName'] ?? '').toString().toLowerCase();
          final mobile = (e['customerMobile'] ?? '').toString();
          if (!billNo.contains(q) && !customer.contains(q) && !mobile.contains(q)) return false;
        }
        // Payment mode filter
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _brown)),
        child: child!,
      ),
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
        backgroundColor: Colors.white,
        title: const Text('Delete Bill?'),
        content: Text('Delete bill ${bill['billNo'] ?? ''}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('bills').doc(bill['_docId']).delete();
      _loadBills();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _viewBill(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (ctx) => _BillDetailDialog(bill: bill),
    );
  }

  // ── Summary totals ────────────────────────────────────────────────────────────

  double get _totalSales =>
      _filtered.fold(0.0, (s, e) => s + ((e['totalPayable'] as num?)?.toDouble() ?? 0));

  double get _totalDiscount =>
      _filtered.fold(0.0, (s, e) {
        final ed = (e['extraDiscountAmount'] as num?)?.toDouble() ?? 0;
        final items = (e['items'] as List?)?.fold<double>(
          0, (si, i) => si + ((i['itemDiscountAmount'] as num?)?.toDouble() ?? 0)) ?? 0;
        return s + ed + items;
      });

  int get _totalItems =>
      _filtered.fold(0, (s, e) => s + ((e['items'] as List?)?.length ?? 0));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(color: _brown),
        child: Row(children: [
          const Icon(Icons.history_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Bill History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _loadBills,
          ),
        ]),
      ),

      // Filter bar
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search
            SizedBox(
              width: 240,
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13, color: _brown),
                decoration: InputDecoration(
                  hintText: 'Bill No, Customer, Mobile…',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBCAAA4)),
                  prefixIcon: const Icon(Icons.search, size: 16, color: _brownLight),
                  filled: true, fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                ),
              ),
            ),
            // Date from
            _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
            const Text('→', style: TextStyle(color: _brownLight)),
            _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
            // Payment mode
            SizedBox(
              width: 160,
              height: 40,
              child: DropdownButtonFormField<String>(
                value: _paymentModeFilter,
                decoration: InputDecoration(
                  filled: true, fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                ),
                items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) { setState(() => _paymentModeFilter = v!); _applyFilters(); },
                style: const TextStyle(color: _brown, fontSize: 13),
              ),
            ),
          ],
        ),
      ),

      // Table
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _brown))
          : _filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: _border),
                  const SizedBox(height: 12),
                  const Text('No bills found', style: TextStyle(color: _brownLight)),
                ]))
              : Column(children: [
                  // Column headers
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFFF9F6F0),
                    child: Row(children: [
                      _th('Bill No', flex: 2),
                      _th('Date', flex: 2),
                      _th('Customer', flex: 3),
                      _th('Items', flex: 1),
                      _th('Subtotal', flex: 2),
                      _th('Discount', flex: 2),
                      _th('Total', flex: 2),
                      _th('Mode', flex: 2),
                      _th('', flex: 2),
                    ]),
                  ),
                  Expanded(child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final bill = _filtered[i];
                      final isEven = i % 2 == 0;
                      return _BillRow(
                        bill: bill,
                        isEven: isEven,
                        fmt: _fmt,
                        onView: () => _viewBill(bill),
                        onDelete: () => _deleteBill(bill),
                      );
                    },
                  )),
                ]),
      ),

      // Summary bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: _brown,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          _statChip('Bills', '${_filtered.length}'),
          const SizedBox(width: 24),
          _statChip('Items Sold', '$_totalItems'),
          const Spacer(),
          _statChip('Total Discount', '₹${_totalDiscount.toStringAsFixed(2)}'),
          const SizedBox(width: 24),
          _statChip('Total Sales', '₹${_totalSales.toStringAsFixed(2)}', highlight: true),
        ]),
      ),
    ]);
  }

  Widget _datePill(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: _brownLight)),
          Text(_fmt.format(dt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brown)),
          const SizedBox(width: 4),
          const Icon(Icons.calendar_today_rounded, size: 13, color: _brownLight),
        ]),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              letterSpacing: 0.8, color: _brownLight)),
    );
  }

  Widget _statChip(String label, String value, {bool highlight = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
      Text(value, style: TextStyle(fontSize: highlight ? 18 : 14,
          fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
  }
}

// ── Bill Row Widget ───────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final Map<String, dynamic> bill;
  final bool isEven;
  final DateFormat fmt;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _BillRow({
    required this.bill,
    required this.isEven,
    required this.fmt,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final billDate = bill['billDate'] ?? bill['date'];
    final dateStr = billDate is Timestamp ? fmt.format(billDate.toDate()) : '—';
    final itemCount = (bill['items'] as List?)?.length ?? 0;
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0;
    final extraDisc = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0;
    final itemDisc = (bill['items'] as List?)?.fold<double>(
            0, (s, i) => s + ((i['itemDiscountAmount'] as num?)?.toDouble() ?? 0)) ?? 0;
    final totalDisc = extraDisc + itemDisc;
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0;
    final mode = bill['paymentMode'] as String? ?? '—';
    final customer = bill['customerName'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isEven ? Colors.white : const Color(0xFFFAF8F5),
      child: Row(children: [
        Expanded(flex: 2, child: Text(
          bill['billNo'] as String? ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _brown),
        )),
        Expanded(flex: 2, child: Text(dateStr, style: const TextStyle(fontSize: 12, color: _brownLight))),
        Expanded(flex: 3, child: Text(
          customer.isEmpty ? '—' : customer,
          style: const TextStyle(fontSize: 12, color: _brown),
          overflow: TextOverflow.ellipsis,
        )),
        Expanded(flex: 1, child: Text('$itemCount', style: const TextStyle(fontSize: 12, color: _brownLight))),
        Expanded(flex: 2, child: Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: _brownLight))),
        Expanded(flex: 2, child: Text(
          totalDisc > 0 ? '₹${totalDisc.toStringAsFixed(2)}' : '—',
          style: TextStyle(fontSize: 12, color: totalDisc > 0 ? Colors.orange[700] : _brownLight),
        )),
        Expanded(flex: 2, child: Text(
          '₹${total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _green),
        )),
        Expanded(flex: 2, child: _modePill(mode)),
        Expanded(flex: 2, child: Row(children: [
          _actionBtn(Icons.visibility_outlined, 'View', Colors.blueGrey, onView),
          const SizedBox(width: 4),
          _actionBtn(Icons.delete_outline, 'Delete', _errorColor, onDelete),
        ])),
      ]),
    );
  }

  Widget _modePill(String mode) {
    Color c = Colors.grey;
    if (mode == 'Cash') c = _green;
    if (mode == 'UPI') c = Colors.indigo;
    if (mode == 'Card') c = Colors.blueAccent;
    if (mode == 'Split Payment') c = Colors.deepOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(mode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
    );
  }

  Widget _actionBtn(IconData icon, String tip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ── Bill Detail Dialog ────────────────────────────────────────────────────────

class _BillDetailDialog extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BillDetailDialog({required this.bill});

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long_rounded, color: _brown),
              const SizedBox(width: 8),
              Text(bill['billNo'] ?? 'Bill', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _brown)),
              const Spacer(),
              Text(dateStr, style: const TextStyle(color: _brownLight)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(),
            if ((bill['customerName'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Customer: ${bill['customerName']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            // Items
            Container(
              decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(children: [
                    Expanded(flex: 3, child: Text('Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                    Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                    Expanded(flex: 2, child: Text('Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                    Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                  ]),
                ),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('${item['tagId']} – ${item['name']}', style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 1, child: Text('${item['qty']} ${item['unit'] ?? ''}', style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 2, child: Text('₹${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 2, child: Text('₹${(item['lineAmount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            _detailRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            if (extraDisc > 0) _detailRow('Extra Discount', '− ₹${extraDisc.toStringAsFixed(2)}', color: Colors.orange),
            if (tax > 0) _detailRow('Tax', '+ ₹${tax.toStringAsFixed(2)}', color: Colors.indigo),
            const Divider(),
            _detailRow('TOTAL PAYABLE', '₹${total.toStringAsFixed(2)}', large: true),
            _detailRow('Payment Mode', bill['paymentMode'] ?? '—'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: TextStyle(color: color ?? _brownLight, fontSize: large ? 14 : 13, fontWeight: large ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(value, style: TextStyle(color: color ?? _brown, fontSize: large ? 18 : 13, fontWeight: large ? FontWeight.bold : FontWeight.w600)),
      ]),
    );
  }
}
