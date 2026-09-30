import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../auth/models/app_user_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/boutique_pdf_generator.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../services/api_service.dart';

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
  String _viewFilter = 'All Invoices'; // 'All Invoices' | 'Balance Due' | 'Advance Bills'
  bool _loading = false;

  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filtered = [];

  static const List<String> _viewOptions = [
    'All Invoices',
    'Balance Due',
    'Advance Bills',
  ];

  static const Map<String, IconData> _viewIcons = {
    'All Invoices': Icons.receipt_long_rounded,
    'Balance Due': Icons.hourglass_bottom_rounded,
    'Advance Bills': Icons.bookmark_added_rounded,
  };

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
          .where('billType', whereIn: ['Sale', 'Advance Payment'])
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

      // Also merge bills from Hostinger MySQL
      try {
        final hostingerBills = await ApiService().getBills();
        for (final hb in hostingerBills) {
          final docId = hb['doc_id'] ?? hb['docId'] ?? '';
          final bNo = hb['bill_no'] ?? hb['billNo'] ?? '';
          hb['_docId'] = docId;
          hb['billNo'] = bNo;
          final bDate = hb['bill_date'] ?? hb['billDate'];
          if (bDate is String) {
            final parsed = DateTime.tryParse(bDate);
            if (parsed != null) {
              hb['billDate'] = Timestamp.fromDate(parsed);
            }
          }
          if (!list.any((ex) => (ex['_docId'] != null && ex['_docId'] == docId) || (ex['billNo'] != null && ex['billNo'] == bNo))) {
            list.add(hb);
          }
        }
      } catch (e) {
        debugPrint('Hostinger getBills error: $e');
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
        // Search filter
        if (q.isNotEmpty) {
          final billNo = (e['billNo'] ?? '').toString().toLowerCase();
          final customer = (e['customerName'] ?? '').toString().toLowerCase();
          final mobile = (e['customerMobile'] ?? '').toString();
          if (!billNo.contains(q) && !customer.contains(q) && !mobile.contains(q)) return false;
        }
        // Payment mode filter
        if (_paymentModeFilter != 'All' && e['paymentMode'] != _paymentModeFilter) return false;
        // View filter
        if (_viewFilter == 'Balance Due') {
          final total = (e['totalPayable'] as num?)?.toDouble() ?? 0.0;
          final received = (e['amountReceived'] as num?)?.toDouble() ?? total;
          final pending = (e['pendingBalance'] as num?)?.toDouble() ?? (total - received).clamp(0.0, double.infinity);
          if (pending <= 0) return false;
        } else if (_viewFilter == 'Advance Bills') {
          if (e['billType'] != 'Advance Payment') return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await _showMonthYearDatePicker(context, initial);
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _loadBills();
    }
  }

  /// Custom date picker: first pick month+year, then pick the day.
  Future<DateTime?> _showMonthYearDatePicker(BuildContext ctx, DateTime initial) async {
    int selectedYear = initial.year;
    int selectedMonth = initial.month;

    // Step 1: Pick month + year
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final months = [
              'January','February','March','April','May','June',
              'July','August','September','October','November','December'
            ];
            final years = List.generate(12, (i) => 2020 + i);
            return AlertDialog(
              backgroundColor: BoutiqueColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Month & Year',
                style: TextStyle(fontFamily: 'serif', fontSize: 18, color: BoutiqueColors.textPrimary)),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year selector
                    Row(
                      children: [
                        const Text('Year:', style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            dropdownColor: BoutiqueColors.bgCard,
                            style: const TextStyle(color: BoutiqueColors.textPrimary, fontSize: 14),
                            items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                            onChanged: (y) => setDialogState(() => selectedYear = y!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Month grid
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      childAspectRatio: 2.2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: List.generate(12, (i) {
                        final isSelected = (i + 1) == selectedMonth;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedMonth = i + 1),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? BoutiqueColors.accent : BoutiqueColors.bgSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? BoutiqueColors.accent : BoutiqueColors.border,
                              ),
                            ),
                            child: Text(
                              months[i].substring(0, 3),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : BoutiqueColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Pick Day →', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !ctx.mounted) return null;

    // Step 2: Pick the day within the selected month
    final firstOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final lastOfMonth = DateTime(selectedYear, selectedMonth + 1, 0);
    final clampedInitial = initial.year == selectedYear && initial.month == selectedMonth
        ? initial
        : firstOfMonth;

    return showDatePicker(
      context: ctx,
      initialDate: clampedInitial,
      firstDate: firstOfMonth,
      lastDate: lastOfMonth,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][selectedMonth-1]} $selectedYear',
    );
  }

  Future<void> _deleteBill(Map<String, dynamic> bill) async {
    final perms = context.read<AuthViewModel>().appUser?.permissions ?? PermissionsModel.adminPreset();
    if (!perms.deleteTransactions) {
      BoutiqueToast.showError(context, 'You do not have permission to delete bills.');
      return;
    }
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
      builder: (ctx) => _BillDetailDialog(
        bill: bill,
        onUpdated: () => _loadBills(),
      ),
    );
  }

  void _openSettleDialog(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (ctx) => _SettleBalanceDialog(
        bill: bill,
        onPaymentUpdated: () => _loadBills(),
      ),
    );
  }

  double get _totalSales => _filtered.fold(0.0, (s, e) => s + ((e['totalPayable'] as num?)?.toDouble() ?? 0));

  List<Map<String, dynamic>> get _pendingBills => _filtered.where((b) {
    final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final received = (b['amountReceived'] as num?)?.toDouble() ?? total;
    final pending = (b['pendingBalance'] as num?)?.toDouble() ?? (total - received).clamp(0.0, double.infinity);
    return pending > 0;
  }).toList();

  double get _totalPendingBalance => _pendingBills.fold(0.0, (s, b) {
    final total = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final received = (b['amountReceived'] as num?)?.toDouble() ?? total;
    final pending = (b['pendingBalance'] as num?)?.toDouble() ?? (total - received).clamp(0.0, double.infinity);
    return s + pending;
  });


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
                // ── View Mode Dropdown ───────────────────────────────
                Expanded(
                  flex: 2,
                  child: _buildViewDropdown(),
                ),
                const SizedBox(width: 12),
                // ── Payment Mode Dropdown ────────────────────────────
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField(
                    label: 'Payment Mode',
                    value: _paymentModeFilter,
                    items: _paymentModes,
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

          // Sectioned Invoices
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: BoutiqueColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No invoice records found.', style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Section 1: Balance Due (only in All Invoices view) ──
                            if (_viewFilter == 'All Invoices' && _pendingBills.isNotEmpty) ...[
                              _sectionHeader(
                                icon: Icons.hourglass_bottom_rounded,
                                iconColor: const Color(0xFFB45309),
                                iconBg: const Color(0xFFFFF3E0),
                                label: 'Balance Due',
                                count: _pendingBills.length,
                                totalLabel: 'Total Pending',
                                totalValue: '₹${_totalPendingBalance.toStringAsFixed(2)}',
                                totalColor: const Color(0xFFD32F2F),
                                borderColor: const Color(0xFFFFCC80),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: BoutiqueColors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFCC80)),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFFFCC80).withAlpha(80), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _pendingBills.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFFFF3E0)),
                                    itemBuilder: (context, idx) => _buildBillTile(_pendingBills[idx]),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // ── Main Section ──────────────────────────────────────
                            _sectionHeader(
                              icon: _viewIcons[_viewFilter]!,
                              iconColor: _viewFilter == 'Balance Due'
                                  ? const Color(0xFFB45309)
                                  : _viewFilter == 'Advance Bills'
                                      ? const Color(0xFF1565C0)
                                      : BoutiqueColors.accent,
                              iconBg: _viewFilter == 'Balance Due'
                                  ? const Color(0xFFFFF3E0)
                                  : _viewFilter == 'Advance Bills'
                                      ? const Color(0xFFE3F2FD)
                                      : BoutiqueColors.accentSoft,
                              label: _viewFilter,
                              count: _filtered.length,
                              totalLabel: _viewFilter == 'Balance Due' ? 'Total Pending' : 'Total Sales',
                              totalValue: _viewFilter == 'Balance Due'
                                  ? '₹${_totalPendingBalance.toStringAsFixed(2)}'
                                  : '₹${_totalSales.toStringAsFixed(2)}',
                              totalColor: _viewFilter == 'Balance Due'
                                  ? const Color(0xFFD32F2F)
                                  : _viewFilter == 'Advance Bills'
                                      ? const Color(0xFF1565C0)
                                      : BoutiqueColors.accent,
                              borderColor: _viewFilter == 'Balance Due'
                                  ? const Color(0xFFFFCC80)
                                  : _viewFilter == 'Advance Bills'
                                      ? const Color(0xFF90CAF9)
                                      : BoutiqueColors.accentLightBorder,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: _viewFilter == 'Balance Due'
                                  ? BoxDecoration(
                                      color: BoutiqueColors.bgCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFCC80)),
                                      boxShadow: [BoxShadow(color: const Color(0xFFFFCC80).withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))],
                                    )
                                  : _viewFilter == 'Advance Bills'
                                      ? BoxDecoration(
                                          color: BoutiqueColors.bgCard,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF90CAF9)),
                                          boxShadow: [BoxShadow(color: const Color(0xFF90CAF9).withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))],
                                        )
                                      : BoutiqueDecoration.card(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                  itemBuilder: (context, idx) => _buildBillTile(_filtered[idx]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Section header widget ──────────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required int count,
    required String totalLabel,
    required String totalValue,
    required Color totalColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: iconColor)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
          ),
          const Spacer(),
          Text('$totalLabel: ', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
          Text(totalValue, style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: totalColor)),
        ],
      ),
    );
  }

  String _formatPaymentBreakdown(Map<String, dynamic> b) {
    final mode = b['paymentMode']?.toString() ?? 'Cash';
    final rawPayments = (b['payments'] as List<dynamic>?) ?? [];
    final valid = rawPayments
        .whereType<Map>()
        .where((p) => ((p['amount'] as num?)?.toDouble() ?? 0.0) > 0)
        .toList();
    if (valid.length > 1 || mode.toLowerCase().contains('split')) {
      final parts = valid
          .map((p) => '${p['mode'] ?? 'Cash'}: ₹${((p['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}')
          .join(', ');
      if (parts.isNotEmpty) return '$mode ($parts)';
    }
    return mode;
  }

  // ── Shared bill list tile ──────────────────────────────────────────────────
  Widget _buildBillTile(Map<String, dynamic> b) {
    final perms = context.watch<AuthViewModel>().appUser?.permissions ?? PermissionsModel.adminPreset();
    final isAdvance = b['billType'] == 'Advance Payment';
    final totalPayable = (b['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final amountReceived = (b['amountReceived'] as num?)?.toDouble() ?? totalPayable;
    final pendingBalance = (b['pendingBalance'] as num?)?.toDouble() ?? (totalPayable - amountReceived).clamp(0.0, double.infinity);
    final hasDue = pendingBalance > 0.01;
    final hadSettlements = ((b['paymentHistory'] as List?)?.length ?? 0) > 1;
    final isFullySettled = !hasDue && (isAdvance || hadSettlements);
    final customerName = (b['customerName']?.toString().trim().isNotEmpty ?? false)
        ? b['customerName'].toString().trim()
        : 'Walk-in Customer';

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () => _viewBill(b),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasDue
                ? const Color(0xFFFFF3E0)
                : isFullySettled
                    ? const Color(0xFFE8F5E9)
                    : BoutiqueColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            hasDue
              ? Icons.pending_actions_rounded
              : isFullySettled
                  ? Icons.verified_rounded
                  : Icons.receipt_long_rounded,
          color: hasDue
              ? const Color(0xFFD97706)
              : isFullySettled
                  ? const Color(0xFF2E7D32)
                  : BoutiqueColors.accent,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(b['billNo'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.accent)),
          const SizedBox(width: 8),
          if (hasDue || isFullySettled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isFullySettled ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isFullySettled ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082)),
              ),
              child: Text(
                isFullySettled ? 'PAID ✓' : 'DUE: ₹${pendingBalance.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isFullySettled ? const Color(0xFF2E7D32) : const Color(0xFFB45309)),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              customerName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.textPrimary),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          'Date: ${_fmt.format((b['billDate'] as Timestamp).toDate())} • Mode: ${_formatPaymentBreakdown(b)}${hasDue ? ' • Paid: ₹${amountReceived.toStringAsFixed(0)}' : ''}',
          style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${totalPayable.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
              ),
              if (hasDue)
                Text('Due: ₹${pendingBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)))
              else if (isFullySettled)
                const Text('Fully Paid ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
            ],
          ),
          const SizedBox(width: 8),
          if (perms.editTransactions)
            IconButton(
              icon: Icon(
                hasDue ? Icons.payments_rounded : Icons.edit_note_rounded,
                color: hasDue ? const Color(0xFF1E7E34) : BoutiqueColors.textSecondary,
                size: 20,
              ),
              tooltip: hasDue ? 'Settle Due Balance (₹${pendingBalance.toStringAsFixed(2)})' : 'Edit / View Payment',
              onPressed: () => _openSettleDialog(b),
            ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: BoutiqueColors.accent, size: 19),
            tooltip: 'View Invoice',
            onPressed: () => _viewBill(b),
          ),
          if (perms.deleteTransactions)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: BoutiqueColors.destructive, size: 19),
              tooltip: 'Delete Bill',
              onPressed: () => _deleteBill(b),
            ),
        ],
      ),
    ),
  );
}

// ── Professional View-mode dropdown ───────────────────────────────────────

  Widget _buildViewDropdown() {
    final accent = BoutiqueColors.accent;
    const Map<String, Color> colors = {
      'All Invoices': BoutiqueColors.accent,
      'Balance Due': Color(0xFFB45309),
      'Advance Bills': Color(0xFF1565C0),
    };
    return PopupMenuButton<String>(
      onSelected: (v) {
        setState(() => _viewFilter = v);
        _applyFilters();
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: BoutiqueColors.bgCard,
      itemBuilder: (_) => _viewOptions.map((opt) {
        final icon = _viewIcons[opt]!;
        final clr = colors[opt]!;
        final isSelected = _viewFilter == opt;
        return PopupMenuItem<String>(
          value: opt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: clr.withAlpha(isSelected ? 40 : 20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: clr),
              ),
              const SizedBox(width: 10),
              Text(
                opt,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? clr : BoutiqueColors.textPrimary,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check_rounded, size: 16, color: clr),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: BoutiqueColors.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _viewFilter == 'All Invoices' ? BoutiqueColors.border : (colors[_viewFilter] ?? accent).withAlpha(120),
            width: _viewFilter == 'All Invoices' ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _viewIcons[_viewFilter]!,
              size: 16,
              color: colors[_viewFilter] ?? accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _viewFilter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors[_viewFilter] ?? accent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: colors[_viewFilter] ?? accent),
          ],
        ),
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

class _BillDetailDialog extends StatefulWidget {
  final Map<String, dynamic> bill;
  final VoidCallback? onUpdated;
  const _BillDetailDialog({required this.bill, this.onUpdated});

  @override
  State<_BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends State<_BillDetailDialog> {
  Future<void> _handlePrintPdf(BuildContext context) async {
    try {
      final bytes = await BoutiquePdfGenerator.generate(widget.bill);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (context.mounted) BoutiqueToast.showError(context, 'Failed to print invoice: $e');
    }
  }

  Future<void> _handleSavePdf(BuildContext context) async {
    try {
      final bytes = await BoutiquePdfGenerator.generate(widget.bill);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Invoice_${widget.bill['billNo'] ?? 'Unknown'}.pdf',
      );
    } catch (e) {
      if (context.mounted) BoutiqueToast.showError(context, 'Failed to download invoice: $e');
    }
  }

  void _openSettleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SettleBalanceDialog(
        bill: widget.bill,
        onPaymentUpdated: () {
          setState(() {});
          widget.onUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final fmt = DateFormat('dd/MM/yyyy');
    final billDate = bill['billDate'] ?? bill['date'];
    final dateStr = billDate is Timestamp ? fmt.format(billDate.toDate()) : '—';
    final items = (bill['items'] as List?) ?? [];
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0.0;
    final extraDisc = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0;
    final tax = (bill['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final billType = bill['billType']?.toString() ?? 'Sale';
    final amountReceived = (bill['amountReceived'] as num?)?.toDouble() ?? total;
    final pendingBalance = (bill['pendingBalance'] as num?)?.toDouble() ?? (total - amountReceived).clamp(0.0, double.infinity);
    final hasDue = pendingBalance > 0.01;
    final paymentHistory = (bill['paymentHistory'] as List?) ?? [];
    final rawPayments = (bill['payments'] as List<dynamic>?) ?? [];
    final validPayments = rawPayments
        .whereType<Map>()
        .where((p) => ((p['amount'] as num?)?.toDouble() ?? 0.0) > 0)
        .toList();

    final customerName = (bill['customerName']?.toString().trim().isNotEmpty ?? false)
        ? bill['customerName'].toString().trim()
        : 'Walk-in Customer';
    final customerMobile = bill['customerMobile']?.toString().trim() ?? '';
    final customerAddress = bill['customerAddress']?.toString().trim() ?? '';
    final narration = bill['narration']?.toString().trim() ?? '';
    final paymentMode = bill['paymentMode']?.toString() ?? 'Cash';

    const bgCream = Color(0xFFF9F6F0);
    const maroon = Color(0xFF5A121A);
    const goldLine = Color(0xFFC7B492);
    const textDark = Color(0xFF333333);
    const textLight = Color(0xFF666666);

    Widget underlineBox(String text, {bool bold = false, Color color = textDark, Alignment alignment = Alignment.centerLeft}) {
      return Container(
        alignment: alignment,
        padding: const EdgeInsets.only(bottom: 3),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: goldLine, width: 0.8)),
        ),
        child: Text(
          text.isEmpty ? ' ' : text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      );
    }

    Widget tableCell(String text, {bool isHeader = false, Alignment align = Alignment.center, bool bold = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        alignment: align,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: (isHeader || bold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.white : textDark,
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 860),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Invoice Preview',
                      style: TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !hasDue ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: !hasDue ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082)),
                      ),
                      child: Text(
                        !hasDue ? 'FULLY PAID ✓' : 'DUE AMOUNT: ₹${pendingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: !hasDue ? const Color(0xFF2E7D32) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (hasDue)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E7E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 16),
                        label: Text('Pay Due (₹${pendingBalance.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openSettleDialog,
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BoutiqueColors.accent,
                          side: const BorderSide(color: BoutiqueColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Edit Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openSettleDialog,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: BoutiqueColors.accent),
                      onPressed: () => _handlePrintPdf(context),
                      tooltip: 'Print Invoice / PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, color: BoutiqueColors.accent),
                      onPressed: () => _handleSavePdf(context),
                      tooltip: 'Save PDF to device',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, color: BoutiqueColors.border),

            // ── Exact Bill / Invoice Replica Card ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    color: bgCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: goldLine, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP SECTION: RITUMITA BOUTIQUE | INVOICE
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/logo.png',
                                    height: 55,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Text(
                                      'RITUMITA BOUTIQUE',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        color: maroon,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(height: 1, color: goldLine, width: 150),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  billType == 'Advance Payment' ? 'ADVANCE' : 'INVOICE',
                                  style: const TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 24,
                                    color: maroon,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(height: 1, color: goldLine, width: double.infinity),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('INVOICE NO.', style: TextStyle(fontSize: 10, color: textLight, letterSpacing: 0.5)),
                                    underlineBox(bill['billNo']?.toString() ?? '—', bold: true, alignment: Alignment.centerRight),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('DATE', style: TextStyle(fontSize: 10, color: textLight, letterSpacing: 0.5)),
                                    underlineBox(dateStr, alignment: Alignment.centerRight),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 2. INVOICE TO
                      const Text(
                        'INVOICE TO',
                        style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: textDark, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: 220, child: underlineBox(customerName, bold: true)),
                      if (customerMobile.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(width: 220, child: underlineBox('Phone: $customerMobile')),
                      ],
                      if (customerAddress.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(width: 260, child: underlineBox(customerAddress)),
                      ],
                      const SizedBox(height: 24),

                      // 3. PRODUCT TABLE (Matches PDF Bill)
                      Table(
                        border: TableBorder.all(color: goldLine, width: 0.8),
                        columnWidths: const {
                          0: FlexColumnWidth(0.8),
                          1: FlexColumnWidth(3.2),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(0.8),
                          4: FlexColumnWidth(1.3),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: maroon),
                            children: [
                              tableCell('NO', isHeader: true),
                              tableCell('PRODUCT DESCRIPTION', isHeader: true, align: Alignment.centerLeft),
                              tableCell('PRICE', isHeader: true),
                              tableCell('QTY', isHeader: true),
                              tableCell('TOTAL', isHeader: true),
                            ],
                          ),
                          ...items.asMap().entries.map((e) {
                            final i = e.key + 1;
                            final r = e.value as Map<String, dynamic>;
                            final itemName = r['name']?.toString() ?? '';
                            final qty = (r['qty'] as num?)?.toDouble() ?? 1.0;
                            final price = (r['price'] as num?)?.toDouble() ?? 0.0;
                            final lineAmt = (r['lineAmount'] as num?)?.toDouble() ?? 0.0;
                            return TableRow(
                              children: [
                                tableCell('$i'),
                                tableCell(itemName, align: Alignment.centerLeft),
                                tableCell(price.toStringAsFixed(2)),
                                tableCell('${qty.toInt()}'),
                                tableCell(lineAmt.toStringAsFixed(2), bold: true),
                              ],
                            );
                          }),
                          if (items.length < 5)
                            ...List.generate(5 - items.length, (_) {
                              return TableRow(
                                children: [
                                  tableCell(' '),
                                  tableCell(' '),
                                  tableCell(' '),
                                  tableCell(' '),
                                  tableCell(' '),
                                ],
                              );
                            }),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. BOTTOM SECTION: PAYMENT DETAILS (Left) | TOTALS & DUE (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Payment Details + Split Breakdown
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAYMENT DETAILS',
                                  style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: textDark, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 65,
                                      child: Text('MODE', style: TextStyle(fontSize: 11, color: textLight)),
                                    ),
                                    Expanded(child: underlineBox(paymentMode, bold: true)),
                                  ],
                                ),
                                if (validPayments.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: goldLine.withValues(alpha: 0.6)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PAYMENT BREAKDOWN:',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: textLight, letterSpacing: 0.6),
                                        ),
                                        const SizedBox(height: 4),
                                        ...validPayments.map((p) {
                                          final m = p['mode']?.toString() ?? 'Cash';
                                          final a = (p['amount'] as num?)?.toDouble() ?? 0.0;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('• $m', style: const TextStyle(fontSize: 11, color: textDark)),
                                                Text('₹${a.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: maroon)),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 65,
                                      child: Text('REMARKS', style: TextStyle(fontSize: 11, color: textLight)),
                                    ),
                                    Expanded(child: underlineBox(narration)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Right: Totals, Received, Due Amount
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(left: BorderSide(color: goldLine, width: 1.2)),
                              ),
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('SUBTOTAL', style: TextStyle(fontSize: 11, color: textLight, letterSpacing: 1)),
                                      underlineBox(subtotal.toStringAsFixed(2), alignment: Alignment.centerRight),
                                    ],
                                  ),
                                  if (tax > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('TAX', style: TextStyle(fontSize: 11, color: textLight, letterSpacing: 1)),
                                        underlineBox(tax.toStringAsFixed(2), alignment: Alignment.centerRight),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('DISCOUNT', style: TextStyle(fontSize: 11, color: textLight, letterSpacing: 1)),
                                      underlineBox(extraDisc.toStringAsFixed(2), alignment: Alignment.centerRight),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(height: 1, color: goldLine, width: double.infinity),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('TOTAL', style: TextStyle(fontSize: 15, color: maroon, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                      underlineBox(total.toStringAsFixed(2), bold: true, color: maroon, alignment: Alignment.centerRight),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('RECEIVED', style: TextStyle(fontSize: 11.5, color: textLight, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      underlineBox(amountReceived.toStringAsFixed(2), bold: true, color: const Color(0xFF15803D), alignment: Alignment.centerRight),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'DUE AMOUNT',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: hasDue ? const Color(0xFFD32F2F) : textLight,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      underlineBox(
                                        pendingBalance.toStringAsFixed(2),
                                        bold: true,
                                        color: hasDue ? const Color(0xFFD32F2F) : textDark,
                                        alignment: Alignment.centerRight,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (hasDue) ...[
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: _openSettleDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFCC80)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payment_rounded, size: 16, color: Color(0xFFB45309)),
                                const SizedBox(width: 8),
                                Text(
                                  'Pending Due: ₹${pendingBalance.toStringAsFixed(2)} — Click here to Record / Split Due Payment →',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Payment History & Due Receipts Log
                      if (paymentHistory.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'DUE PAYMENT RECEIPTS (REF: #${widget.bill['billNo'] ?? '-'})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textLight,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: goldLine.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            children: paymentHistory.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final rec = entry.value;
                              final pDate = rec['date'];
                              final pDateStr = pDate is Timestamp
                                  ? fmt.format(pDate.toDate())
                                  : '—';
                              final pAmt =
                                  (rec['amount'] as num?)?.toDouble() ?? 0.0;
                              final pMode = rec['mode'] ?? 'Cash';
                              final pNotes =
                                  (rec['notes'] ?? rec['note'] ?? '').toString();
                              final rNo = (rec['receiptNo']?.toString() ?? '')
                                      .isNotEmpty
                                  ? rec['receiptNo'].toString()
                                  : 'DR-${(idx + 1).toString().padLeft(3, '0')}';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: maroon,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#$rNo',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$pDateStr • $pMode',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: textDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (pNotes.isNotEmpty)
                                            Text(
                                              '($pNotes)',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: textLight,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '+ ₹${pAmt.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () async {
                                            final receiptMap =
                                                Map<String, dynamic>.from(rec);
                                            receiptMap['receiptNo'] = rNo;
                                            receiptMap['refBillNo'] =
                                                widget.bill['billNo']
                                                    ?.toString() ??
                                                'SB';
                                            final bytes =
                                                await BoutiquePdfGenerator
                                                    .generateDueReceipt(
                                              bill: widget.bill,
                                              receipt: receiptMap,
                                            );
                                            await Printing.layoutPdf(
                                              onLayout: (_) async => bytes,
                                            );
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.print_outlined,
                                              size: 15,
                                              color: maroon,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // 5. FOOTER: Thank You & Address Block
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
                                  fontSize: 34,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  color: maroon,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'FOR YOUR TRUST & SUPPORT',
                                style: TextStyle(fontSize: 9, color: textLight, letterSpacing: 1.5),
                              ),
                            ],
                          ),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('RituMita', style: TextStyle(fontSize: 12, color: maroon, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('+91 98765 43210', style: TextStyle(fontSize: 11, color: textLight)),
                              Text('www.ritumita.com', style: TextStyle(fontSize: 11, color: textLight)),
                              Text('123 Fashion St., Chennai', style: TextStyle(fontSize: 11, color: textLight)),
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
    );
  }
}

// ── Settle Balance / Edit Payment Modal Dialog (Supports Single & Split) ──────

class _SettleBalanceDialog extends StatefulWidget {
  final Map<String, dynamic> bill;
  final VoidCallback onPaymentUpdated;
  const _SettleBalanceDialog({required this.bill, required this.onPaymentUpdated});

  @override
  State<_SettleBalanceDialog> createState() => _SettleBalanceDialogState();
}

class _SettleBalanceDialogState extends State<_SettleBalanceDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMode = 'Cash';
  bool _isSplit = false;
  final List<Map<String, dynamic>> _splitRows = [
    {'mode': 'Cash', 'ctrl': TextEditingController(text: '0')},
    {'mode': 'UPI', 'ctrl': TextEditingController(text: '0')},
  ];
  DateTime _paymentDate = DateTime.now();
  int _modeTab = 0; // 0: Pay Due Balance (Installment/Full), 1: Direct Total Override
  bool _saving = false;

  final List<String> _modes = ['Cash', 'UPI', 'GPay', 'Card', 'Bank Transfer', 'Cheque'];

  @override
  void initState() {
    super.initState();
    final total = (widget.bill['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final received = (widget.bill['amountReceived'] as num?)?.toDouble() ?? total;
    final pending = (widget.bill['pendingBalance'] as num?)?.toDouble() ?? (total - received).clamp(0.0, double.infinity);
    _amountCtrl.text = pending > 0 ? pending.toStringAsFixed(2) : received.toStringAsFixed(2);
    (_splitRows[0]['ctrl'] as TextEditingController).text =
        pending > 0 ? pending.toStringAsFixed(2) : '0';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _splitRows) {
      (r['ctrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  double get _splitTotal {
    double sum = 0;
    for (final r in _splitRows) {
      sum += double.tryParse((r['ctrl'] as TextEditingController).text.trim()) ?? 0.0;
    }
    return sum;
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    final total = (widget.bill['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final currReceived = (widget.bill['amountReceived'] as num?)?.toDouble() ?? 0.0;
    final currPending = (total - currReceived).clamp(0.0, double.infinity);

    final inputVal = (_modeTab == 0 && _isSplit)
        ? _splitTotal
        : (double.tryParse(_amountCtrl.text.trim()) ?? 0.0);

    double payNow = 0.0;
    double newAmountReceived = 0.0;
    double newPendingBalance = 0.0;

    if (_modeTab == 0) {
      if (inputVal <= 0) {
        BoutiqueToast.showError(context, 'Please enter a valid payment amount greater than 0');
        return;
      }
      payNow = inputVal;
      newAmountReceived = currReceived + payNow;
      newPendingBalance = (total - newAmountReceived).clamp(0.0, double.infinity);
    } else {
      if (inputVal < 0) {
        BoutiqueToast.showError(context, 'Amount cannot be negative');
        return;
      }
      newAmountReceived = inputVal;
      payNow = newAmountReceived - currReceived;
      newPendingBalance = (total - newAmountReceived).clamp(0.0, double.infinity);
    }

    setState(() => _saving = true);
    try {
      final docId = widget.bill['_docId'] ?? widget.bill['docId'];
      if (docId == null) throw 'Missing bill document reference';

      final existingPayments = List<Map<String, dynamic>>.from(
        ((widget.bill['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final historyList = List<Map<String, dynamic>>.from(
        ((widget.bill['paymentHistory'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final payTs = Timestamp.fromDate(_paymentDate);
      final refBillNo = widget.bill['billNo']?.toString() ?? 'SB';
      final nextDrIndex = historyList.length + 1;
      final receiptNo = 'DR-${nextDrIndex.toString().padLeft(3, '0')}';

      if (_modeTab == 0 && _isSplit) {
        final List<Map<String, dynamic>> splitBreakdown = [];
        for (final r in _splitRows) {
          final amt =
              double.tryParse((r['ctrl'] as TextEditingController).text.trim()) ??
              0.0;
          if (amt > 0) {
            final m = r['mode']?.toString() ?? 'Cash';
            existingPayments.add({
              'mode': m,
              'amount': amt,
              'date': payTs,
              'receiptNo': receiptNo,
            });
            splitBreakdown.add({'mode': m, 'amount': amt});
          }
        }
        historyList.add({
          'receiptNo': receiptNo,
          'refBillNo': refBillNo,
          'amount': payNow,
          'mode': splitBreakdown.length > 1
              ? 'Split'
              : (splitBreakdown.first['mode'] ?? 'Cash'),
          'breakdown': splitBreakdown,
          'previousDue': currPending,
          'remainingDue': newPendingBalance,
          'date': payTs,
          'note': _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : (newPendingBalance <= 0
                  ? 'Final Settlement'
                  : 'Installment Payment'),
          'notes': _notesCtrl.text.trim(),
          'recordedAt': Timestamp.now(),
          'type': 'Split Due Settlement',
        });
      } else {
        existingPayments.add({
          'mode': _paymentMode,
          'amount': payNow,
          'date': payTs,
          'receiptNo': receiptNo,
        });
        historyList.add({
          'receiptNo': receiptNo,
          'refBillNo': refBillNo,
          'amount': payNow,
          'mode': _paymentMode,
          'breakdown': [
            {'mode': _paymentMode, 'amount': payNow},
          ],
          'previousDue': currPending,
          'remainingDue': newPendingBalance,
          'date': payTs,
          'note': _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : (newPendingBalance <= 0
                  ? 'Final Settlement'
                  : 'Installment Payment'),
          'notes': _notesCtrl.text.trim(),
          'recordedAt': Timestamp.now(),
          'type': _modeTab == 0 ? 'Balance Settlement' : 'Amount Adjustment',
        });
      }

      final updatedMode = existingPayments.length > 1 ? 'Split Payment' : _paymentMode;

      await FirebaseFirestore.instance.collection('bills').doc(docId).update({
        'amountReceived': newAmountReceived,
        'pendingBalance': newPendingBalance,
        'paymentMode': updatedMode,
        'payments': existingPayments,
        'paymentHistory': historyList,
        'isFullyPaid': newPendingBalance <= 0,
        'paymentStatus': newPendingBalance <= 0 ? 'Paid' : 'Partial',
        'lastPaymentDate': payTs,
        'lastPaymentMode': (_modeTab == 0 && _isSplit) ? 'Split Payment' : _paymentMode,
      });

      widget.bill['amountReceived'] = newAmountReceived;
      widget.bill['pendingBalance'] = newPendingBalance;
      widget.bill['paymentMode'] = updatedMode;
      widget.bill['payments'] = existingPayments;
      widget.bill['paymentHistory'] = historyList;
      widget.bill['isFullyPaid'] = newPendingBalance <= 0;
      widget.bill['paymentStatus'] = newPendingBalance <= 0 ? 'Paid' : 'Partial';
      widget.bill['lastPaymentDate'] = payTs;

      widget.onPaymentUpdated();

      if (mounted) {
        Navigator.pop(context, true);
        BoutiqueToast.showSuccess(
          context,
          newPendingBalance <= 0
              ? 'Payment recorded! Bill is now FULLY PAID ✓'
              : 'Payment of ₹${payNow.toStringAsFixed(2)} recorded! Remaining due: ₹${newPendingBalance.toStringAsFixed(2)}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        BoutiqueToast.showError(context, 'Error updating payment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final total = (widget.bill['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final received = (widget.bill['amountReceived'] as num?)?.toDouble() ?? 0.0;
    final pending = (widget.bill['pendingBalance'] as num?)?.toDouble() ?? (total - received).clamp(0.0, double.infinity);

    final inputVal = (_modeTab == 0 && _isSplit)
        ? _splitTotal
        : (double.tryParse(_amountCtrl.text.trim()) ?? 0.0);
    final previewReceived = _modeTab == 0 ? (received + inputVal) : inputVal;
    final previewPending = (total - previewReceived).clamp(0.0, double.infinity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BoutiqueColors.bgCard,
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: BoutiqueColors.accentSoft, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.payments_rounded, color: BoutiqueColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Receive / Settle Due Payment', style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                          Text('Bill: ${widget.bill['billNo'] ?? '—'} • Customer: ${widget.bill['customerName'] ?? 'Walk-in'}', style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, color: BoutiqueColors.border),

              // Stat Summary Cards
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BoutiqueColors.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BoutiqueColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Bill', style: TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: BoutiqueColors.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Already Paid', style: TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('₹${received.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 32, color: BoutiqueColors.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Balance Due', style: TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${pending.toStringAsFixed(2)}', 
                              style: TextStyle(
                                fontFamily: 'serif', 
                                fontSize: 15, 
                                fontWeight: FontWeight.bold, 
                                color: pending > 0 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Selector: Pay Balance Due vs Direct Override
              Container(
                decoration: BoxDecoration(color: BoutiqueColors.bgSubtle, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _modeTab = 0;
                            _amountCtrl.text = pending > 0 ? pending.toStringAsFixed(2) : '0.00';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _modeTab == 0 ? BoutiqueColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pay Due (Part / Full / Split)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _modeTab == 0 ? Colors.white : BoutiqueColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _modeTab = 1;
                            _isSplit = false;
                            _amountCtrl.text = received.toStringAsFixed(2);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _modeTab == 1 ? BoutiqueColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Direct Total Override',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _modeTab == 1 ? Colors.white : BoutiqueColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_modeTab == 0) ...[
                Row(
                  children: [
                    const Text('Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Single Mode', style: TextStyle(fontSize: 12)),
                      selected: !_isSplit,
                      selectedColor: BoutiqueColors.accentSoft,
                      onSelected: (_) => setState(() => _isSplit = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Split Mode (Multiple)', style: TextStyle(fontSize: 12)),
                      selected: _isSplit,
                      selectedColor: BoutiqueColors.accentSoft,
                      onSelected: (_) => setState(() => _isSplit = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              if (!_isSplit) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _modeTab == 0 ? 'Amount Paying Now (₹)' : 'Total Received Amount (₹)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                    ),
                    if (_modeTab == 0 && pending > 0)
                      InkWell(
                        onTap: () {
                          setState(() => _amountCtrl.text = pending.toStringAsFixed(2));
                        },
                        child: Text(
                          'Pay Full Due (₹${pending.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: BoutiqueInputDecoration.field(
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18, color: BoutiqueColors.accent),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _paymentMode,
                            style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                            decoration: BoutiqueInputDecoration.field(hintText: 'Mode'),
                            items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _paymentMode = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickPaymentDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: BoutiqueColors.bgCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BoutiqueColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(fmt.format(_paymentDate), style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary)),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: BoutiqueColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Split Payment Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                const SizedBox(height: 8),
                ...List.generate(_splitRows.length, (idx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _splitRows[idx]['mode'] as String,
                            decoration: BoutiqueInputDecoration.field(hintText: 'Mode'),
                            items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _splitRows[idx]['mode'] = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _splitRows[idx]['ctrl'] as TextEditingController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: BoutiqueInputDecoration.field(
                              hintText: 'Amount',
                              prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 15, color: BoutiqueColors.accent),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_splitRows.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: BoutiqueColors.destructive, size: 20),
                            onPressed: () {
                              (_splitRows[idx]['ctrl'] as TextEditingController).dispose();
                              setState(() => _splitRows.removeAt(idx));
                            },
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _splitRows.add({'mode': 'Cash', 'ctrl': TextEditingController(text: '0')}));
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Add Another Payment Mode', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: BoutiqueColors.accent),
                ),
              ],

              const SizedBox(height: 12),

              // Remarks / Ref Notes
              const Text('Reference / Remarks (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: BoutiqueInputDecoration.field(
                  hintText: 'e.g. Installment 1, UPI Ref #, Cash received',
                ),
              ),
              const SizedBox(height: 16),

              // Calculation Preview Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: previewPending <= 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: previewPending <= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paying Now: ₹${inputVal.toStringAsFixed(2)} (Total Paid: ₹${previewReceived.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                    ),
                    Text(
                      previewPending <= 0 ? 'Remaining Due: ₹0.00 (Fully Paid ✓)' : 'Remaining Due: ₹${previewPending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: previewPending <= 0 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: BoutiqueColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: previewPending <= 0 ? const Color(0xFF1E7E34) : BoutiqueColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _submitPayment,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            previewPending <= 0 ? 'Save & Mark Fully Paid ✓' : 'Record Payment (₹${inputVal.toStringAsFixed(2)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
