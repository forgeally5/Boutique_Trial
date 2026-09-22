import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import '../../dialogs/vendor_issue_dialog.dart';

class VendorIssueTab extends StatefulWidget {
  const VendorIssueTab({super.key});

  @override
  State<VendorIssueTab> createState() => _VendorIssueTabState();
}

class _VendorIssueTabState extends State<VendorIssueTab> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();
  
  String _issueTypeFilter = 'All';
  String _actionFilter = 'All';
  
  bool _loading = false;
  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];

  final _issueTypes = ['All', 'Damaged', 'Defective', 'Wrong Item Sent', 'Quality Issue', 'Broken in Transit', 'Other'];
  final _actions = ['All', 'Pending', 'Returned to Vendor', 'Replacement Received', 'Refund Received', 'Discarded'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
    _dateFrom = fyStart;
    _dateTo = now;
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('vendor_issues').get();

      final fromDt = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        
        DateTime? dt;
        final dr = data['dateReported'];
        if (dr is Timestamp) {
          dt = dr.toDate();
        } else if (dr is String) {
          dt = DateTime.tryParse(dr);
        }

        if (dt != null) {
          if (dt.isAfter(fromDt.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(toDt.add(const Duration(seconds: 1)))) {
            data['_dt'] = dt;
            rows.add(data);
          }
        }
      }

      rows.sort((a, b) {
        final ta = a['_dt'] as DateTime?;
        final tb = b['_dt'] as DateTime?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _allRows = rows;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) BoutiqueToast.showError(context, 'Error loading vendor issues: $e');
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allRows.where((r) {
        if (q.isNotEmpty) {
          final prod = r['productName']?.toString().toLowerCase() ?? '';
          final tag = r['tagId']?.toString().toLowerCase() ?? '';
          final vend = r['vendor']?.toString().toLowerCase() ?? '';
          if (!prod.contains(q) && !tag.contains(q) && !vend.contains(q)) return false;
        }
        if (_issueTypeFilter != 'All' && r['issueType'] != _issueTypeFilter) return false;
        if (_actionFilter != 'All' && r['actionTaken'] != _actionFilter) return false;
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _load();
    }
  }

  Future<void> _updateAction(String issueId, String tagId, String currentAction) async {
    String? selectedAction = currentAction;
    final newAction = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Action Taken'),
        content: DropdownButtonFormField<String>(
          initialValue: selectedAction,
          items: _actions.where((a) => a != 'All').map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => selectedAction = v,
          decoration: BoutiqueInputDecoration.field(labelText: 'Action', hintText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, selectedAction);
            },
            child: const Text('Update'),
          )
        ],
      )
    );
    if (newAction != null && newAction != currentAction && mounted) {
      final state = context.read<AdminState>();
      await state.updateVendorIssueAction(issueId, tagId, newAction);
      _load();
    }
  }

  int get _totalIssues => _filtered.length;
  int get _totalQty => _filtered.fold(0, (s, r) => s + ((r['quantity'] as num?)?.toInt() ?? 0));
  double get _totalRefund => _filtered.fold(0.0, (s, r) => s + ((r['refundAmount'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter & Action Bar ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: BoutiqueInputDecoration.field(
                    hintText: 'Search product, vendor, tag...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: BoutiqueColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date From
              _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→', style: TextStyle(color: BoutiqueColors.textSecondary)),
              ),
              _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
              const SizedBox(width: 12),
              // Type filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _issueTypeFilter,
                  style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                  decoration: BoutiqueInputDecoration.field(hintText: 'Issue Type'),
                  items: _issueTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _issueTypeFilter = v);
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Action filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _actionFilter,
                  style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                  decoration: BoutiqueInputDecoration.field(hintText: 'Action'),
                  items: _actions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _actionFilter = v);
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.accent, foregroundColor: Colors.white),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Issue'),
                onPressed: () async {
                  final res = await showDialog(
                    context: context, 
                    builder: (ctx) => VendorIssueDialog(state: context.read<AdminState>())
                  );
                  if (res == true) _load();
                },
              ),
              const SizedBox(width: 12),
              _iconBtn(Icons.refresh_rounded, BoutiqueColors.accent, _load, 'Refresh'),
            ],
          ),
        ),

        // ── Summary Banner ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          color: BoutiqueColors.accentSoft,
          child: Row(
            children: [
              _summaryChip(Icons.report_problem_rounded, 'Issues Logged', '$_totalIssues'),
              const SizedBox(width: 24),
              _summaryChip(Icons.inventory_2_rounded, 'Qty Affected', '$_totalQty'),
              const SizedBox(width: 24),
              _summaryChip(Icons.currency_rupee_rounded, 'Total Refund', '₹${_numFmt.format(_totalRefund)}'),
            ],
          ),
        ),

        // ── Table ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filtered.isEmpty
                  ? _emptyState('No vendor issues found', Icons.check_circle_outline)
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        children: [
                          _tableHeader([
                            'Date', 'Product', 'Vendor', 'Qty', 'Issue Type', 'Refund', 'Action', 'Update'
                          ]),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                              itemBuilder: (ctx, i) => _tableRow(_filtered[i], i),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _tableHeader(List<String> cols) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols.asMap().entries.map((e) {
          final flex = [2, 4, 3, 1, 2, 2, 2, 1][e.key];
          return Expanded(
            flex: flex,
            child: Text(
              e.value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> r, int i) {
    final isAlt = i.isOdd;
    final action = r['actionTaken']?.toString() ?? 'Pending';
    Color statusColor = BoutiqueColors.warning;
    Color statusBg = BoutiqueColors.warningBg;
    
    if (action == 'Replacement Received' || action == 'Refund Received') {
      statusColor = BoutiqueColors.success;
      statusBg = BoutiqueColors.successBg;
    } else if (action == 'Discarded') {
      statusColor = BoutiqueColors.destructive;
      statusBg = const Color(0xFFFFEBEE);
    }

    final dt = r['_dt'] as DateTime?;

    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: _cell(dt != null ? _fmt.format(dt) : '—')),
          Expanded(flex: 4, child: _cell('${r['tagId']} - ${r['productName']}', bold: true)),
          Expanded(flex: 3, child: _cell(r['vendor']?.toString() ?? '—')),
          Expanded(flex: 1, child: _cell(r['quantity']?.toString() ?? '0', bold: true)),
          Expanded(flex: 2, child: _cell(r['issueType']?.toString() ?? '—')),
          Expanded(flex: 2, child: _cell('₹${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}')),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(action, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 16, color: BoutiqueColors.accent),
              onPressed: () => _updateAction(r['id'], r['tagId'], action),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {Color color = BoutiqueColors.textPrimary, bool bold = false}) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      overflow: TextOverflow.ellipsis,
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

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return IconButton(icon: Icon(icon, color: color), onPressed: onTap, tooltip: tooltip);
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: BoutiqueColors.accent),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: BoutiqueColors.accent)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
      ],
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: BoutiqueColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
