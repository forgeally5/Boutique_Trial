import 'package:flutter/material.dart';
import '../../utils/boutique_pdf_generator.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../dialogs/vendor_issue_dialog.dart';
import '../../dialogs/customer_return_dialog.dart';
import '../../models/vendor_issue.dart';
import '../../utils/pdf_report_generator.dart';
import '../../state/admin_state.dart';
import '../../utils/boutique_theme.dart';
import '../../utils/excel_generator.dart';
import '../../widgets/report_export_dialog.dart';
import '../../widgets/searchable_dropdown.dart';

class IssueReportScreen extends StatefulWidget {
  const IssueReportScreen({super.key});

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  late DateTime _dateFrom;
  late DateTime _dateTo;
  final _searchCtrl = TextEditingController();

  /// 'All' | 'Customer Return' | 'Vendor Issue'
  String _typeFilter = 'All';
  final _typeOptions = ['All', 'Customer Return', 'Vendor Issue'];

  bool _loading = false;
  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];

  // ── Vendor-issue action options ────────────────────────────────────────────
  final _vendorActions = [
    'Pending',
    'Returned to Vendor',
    'Replacement Received',
    'Refund Received',
    'Discarded',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
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

  // ── Data Loading ───────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fromDt = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toDt =
          DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      final rows = <Map<String, dynamic>>[];

      // ── 1. Customer Returns (from bills via API) ─────────────────────
      final allBills = await ApiService().getBills();
      final billDocs = allBills.where((b) => b['billType'] == 'Return').toList();

      for (final data in billDocs) {
        final rawDate = data['billDate'] ?? data['voucherDate'] ?? data['createdAt'];
        DateTime? dt;
        if (rawDate is DateTime) {
          dt = rawDate;
        } else if (rawDate is String) {
          dt = DateTime.tryParse(rawDate);
        } else if (rawDate != null) {
          dt = DateTime.tryParse(rawDate.toString());
        }
        if (dt != null &&
            dt.isAfter(fromDt.subtract(const Duration(seconds: 1))) &&
            dt.isBefore(toDt.add(const Duration(seconds: 1)))) {
          final items = (data['items'] as List?) ?? [{}];
          for (final item in items) {
            final itemMap = (item is Map) ? Map<String, dynamic>.from(item) : <String, dynamic>{};
            final rawReason = (data['returnReason'] ??
                    data['reason'] ??
                    itemMap['returnReason'] ??
                    itemMap['reason'] ??
                    '')
                .toString()
                .trim();
            final condition = itemMap['condition']?.toString().trim() ?? '';
            final narration = data['narration']?.toString().trim() ?? '';
            String issueReason = rawReason;
            if (issueReason.isEmpty || issueReason == '—' || issueReason == '-') {
              if (condition.isNotEmpty && condition != '—' && condition != '-') {
                issueReason = condition == 'Good' ? 'Customer Return (Good)' : condition;
              } else if (narration.isNotEmpty) {
                issueReason = narration;
              } else {
                issueReason = 'Customer Return';
              }
            }

            rows.add({
              '_type': 'Customer Return',
              '_dt': dt,
              'date': _fmt.format(dt),
              'productName':
                  '${itemMap['tagId'] ?? itemMap['tag_id'] ?? ''} ${itemMap['name'] ?? itemMap['productName'] ?? ''}'.trim(),
              'counterpart': data['customerName'] ?? data['acName'] ?? 'Walk-in',
              'mobile': data['customerMobile'] ?? data['phone'] ?? '',
              'qty': itemMap['qty'] ?? itemMap['quantity'] ?? 1,
              'issueReason': issueReason,
              'refundAmount': (itemMap['lineAmount'] as num?)?.toDouble() ??
                  (itemMap['amount'] as num?)?.toDouble() ??
                  (data['totalPayable'] as num?)?.toDouble() ??
                  0.0,
              'status': data['returnStatus'] ?? 'Processed',
              'refundMode': data['paymentMode'] ?? '—',
              'billNo': data['billNo'] ?? data['voucherNo'] ?? '—',
              'originalBillNo': data['originalBillNo'] ?? '—',
              'id': '',
              'tagId': itemMap['tagId'] ?? itemMap['tag_id'] ?? '',
              'actionTaken': '',
              '_bill': data,
            });
          }
        }
      }

      // ── 2. Vendor / Purchase Issues ────────────────────────────────────
      final vendorDocs = await ApiService().getVendorIssues();

      for (final data in vendorDocs) {
        DateTime? dt;
        final dr = data['dateReported'];
        if (dr is String) {
          dt = DateTime.tryParse(dr);
        } else if (dr != null) {
          dt = DateTime.tryParse(dr.toString());
        }

        if (dt != null &&
            dt.isAfter(fromDt.subtract(const Duration(seconds: 1))) &&
            dt.isBefore(toDt.add(const Duration(seconds: 1)))) {
          rows.add({
            '_type': 'Vendor Issue',
            '_dt': dt,
            'date': _fmt.format(dt),
            'counterpart': data['vendor']?.toString() ?? '—',
            'productName': [
              data['tagId']?.toString() ?? '',
              data['productName']?.toString() ?? ''
            ].where((s) => s.isNotEmpty).join(' - ').trim().isEmpty
                ? (data['docId']?.toString() ?? 'Vendor Return')
                : [
                    data['tagId']?.toString() ?? '',
                    data['productName']?.toString() ?? ''
                  ].where((s) => s.isNotEmpty).join(' - '),
            'mobile': '',
            'qty': (data['quantity'] as num?)?.toInt() ?? 0,
            'issueReason': data['issueType']?.toString() ?? '—',
            'refundAmount':
                (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
            'status': data['actionTaken']?.toString() ?? 'Pending',
            'refundMode': '—',
            'billNo': '—',
            'originalBillNo': '—',
            // vendor-only fields
            'id': data['id'],
            'tagId': data['tagId']?.toString() ?? '',
            'actionTaken': data['actionTaken']?.toString() ?? 'Pending',
            'notes': data['notes']?.toString() ?? '',
          });
        }
      }

      // Sort newest first
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
      if (mounted) BoutiqueToast.showError(context, 'Error loading issues: $e');
    }
  }

  // ── Filtering ──────────────────────────────────────────────────────────────
  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allRows.where((r) {
        if (_typeFilter != 'All' && r['_type'] != _typeFilter) return false;
        if (q.isNotEmpty) {
          final prod = r['productName']?.toString().toLowerCase() ?? '';
          final cp = r['counterpart']?.toString().toLowerCase() ?? '';
          final mob = r['mobile']?.toString() ?? '';
          final bill = r['billNo']?.toString().toLowerCase() ?? '';
          if (!prod.contains(q) &&
              !cp.contains(q) &&
              !mob.contains(q) &&
              !bill.contains(q)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  // ── Date picker ────────────────────────────────────────────────────────────
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

  // ── Update Vendor Issue Action ─────────────────────────────────────────────
  Future<void> _updateVendorAction(
      String issueId, String tagId, String currentAction) async {
    String? selectedAction = currentAction;
    final newAction = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Action Taken'),
        content: StatefulBuilder(
          builder: (ctx2, setInner) => DropdownButtonFormField<String>(
            initialValue: selectedAction,
            items: _vendorActions
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) {
              setInner(() => selectedAction = v);
            },
            decoration:
                BoutiqueInputDecoration.field(labelText: 'Action', hintText: ''),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, selectedAction),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (newAction != null && newAction != currentAction && mounted) {
      final state = context.read<AdminState>();
      await state.updateVendorIssueAction(issueId, tagId, newAction);
      _load();
    }
  }

  // ── PDF Print / Download ───────────────────────────────────────────────────
  Future<void> _handlePrint() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to print.');
      return;
    }
    final bytes = await generateUnifiedIssueReportPdf(
      rows: _filtered,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _handleDownload() async {
    if (_filtered.isEmpty) {
      BoutiqueToast.showError(context, 'No data to download.');
      return;
    }
    await ReportExportDialog.show(
      context: context,
      title: 'Issue & Returns Register',
      onDownloadPdf: () async {
        final bytes = await generateUnifiedIssueReportPdf(
          rows: _filtered,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'issue_report_${_fmt.format(_dateFrom)}_${_fmt.format(_dateTo)}.pdf',
        );
      },
      onDownloadExcel: () async {
        await ExcelGenerator.downloadIssueReportExcel(
          rows: _filtered,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          filterType: _typeFilter,
        );
      },
    );
  }

  // ── Computed Totals ────────────────────────────────────────────────────────
  int get _totalIssues => _filtered.length;
  int get _totalQty =>
      _filtered.fold(0, (s, r) => s + ((r['qty'] as num?)?.toInt() ?? 0));
  double get _totalRefund => _filtered.fold(
      0.0, (s, r) => s + ((r['refundAmount'] as num?)?.toDouble() ?? 0));
  int get _customerCount =>
      _filtered.where((r) => r['_type'] == 'Customer Return').length;
  int get _vendorCount =>
      _filtered.where((r) => r['_type'] == 'Vendor Issue').length;

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter & Action Bar ────────────────────────────────────────────
        _buildFilterBar(),

        // ── Summary Banner ─────────────────────────────────────────────────
        _buildSummaryBanner(),

        // ── Table ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: BoutiqueColors.accent))
              : _filtered.isEmpty
                  ? _emptyState('No issues found', Icons.check_circle_outline)
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        children: [
                          _tableHeader(),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filtered.length,
                              separatorBuilder: (_, x) => const Divider(
                                  height: 1,
                                  color: BoutiqueColors.borderLight),
                              itemBuilder: (ctx, i) =>
                                  _tableRow(_filtered[i], i),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: BoutiqueInputDecoration.field(
                hintText: 'Search product, customer, vendor, bill no…',
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: BoutiqueColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date From
          _datePill('From', _dateFrom, () => _pickDate(isFrom: true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('→',
                style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
          _datePill('To', _dateTo, () => _pickDate(isFrom: false)),
          const SizedBox(width: 12),
          // Type filter
          Expanded(
            flex: 2,
            child: SearchableDropdownField(
              label: 'Issue Type',
              value: _typeFilter,
              items: _typeOptions,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _typeFilter = v);
                  _applyFilters();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // Add Issue / Return
          MenuAnchor(
            builder: (context, controller, child) {
              return ElevatedButton.icon(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BoutiqueColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.focused)) {
                        return Colors.white.withValues(alpha: 0.3); // High contrast focus
                      }
                      return null;
                    },
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log Issue / Return', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              );
            },
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.assignment_return_rounded, size: 18, color: BoutiqueColors.textPrimary),
                onPressed: () async {
                  final res = await showDialog(
                    context: context,
                    builder: (ctx) => CustomerReturnDialog(state: context.read<AdminState>()),
                  );
                  if (res == true) _load();
                },
                child: const Text('Log Customer Return'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.local_shipping_outlined, size: 18, color: BoutiqueColors.textPrimary),
                onPressed: () async {
                  final res = await showDialog(
                    context: context,
                    builder: (ctx) => VendorIssueDialog(state: context.read<AdminState>()),
                  );
                  if (res == true) _load();
                },
                child: const Text('Log Vendor Issue'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Refresh
          _iconBtn(
              Icons.refresh_rounded, BoutiqueColors.accent, _load, 'Refresh'),
          // Print
          _iconBtn(Icons.print_outlined, BoutiqueColors.accent, _handlePrint,
              'Print Report'),
          // Download PDF
          _iconBtn(Icons.download_outlined, BoutiqueColors.accent,
              _handleDownload, 'Download PDF'),
          // Download Excel
          _iconBtn(Icons.table_view_rounded, const Color(0xFF1E7E34), () async {
            if (_filtered.isEmpty) {
              BoutiqueToast.showError(context, 'No data to download.');
              return;
            }
            await ExcelGenerator.downloadIssueReportExcel(
              rows: _filtered,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              filterType: _typeFilter,
            );
            if (mounted) {
              BoutiqueToast.showSuccess(context, 'Issue Report (.xlsx) downloaded!');
            }
          }, 'Download Excel (.xlsx)'),
        ],
      ),
    );
  }

  // ── Summary Banner ─────────────────────────────────────────────────────────
  Widget _buildSummaryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      color: BoutiqueColors.accentSoft,
      child: Row(
        children: [
          _summaryChip(
              Icons.report_problem_rounded, 'Issues Logged', '$_totalIssues'),
          const SizedBox(width: 20),
          _summaryChip(Icons.assignment_return_rounded,
              'Customer Returns', '$_customerCount'),
          const SizedBox(width: 20),
          _summaryChip(Icons.local_shipping_outlined,
              'Vendor Issues', '$_vendorCount'),
          const SizedBox(width: 20),
          _summaryChip(
              Icons.inventory_2_rounded, 'Qty Affected', '$_totalQty'),
          const SizedBox(width: 20),
          _summaryChip(Icons.currency_rupee_rounded, 'Total Refund',
              '₹${_numFmt.format(_totalRefund)}'),
        ],
      ),
    );
  }

  // ── Table Header ───────────────────────────────────────────────────────────
  Widget _tableHeader() {
    const cols = [
      'Date', 'Party/Customer', 'Contact', 'Product',
      'Qty', 'Issue / Reason', 'Refund (₹)', 'Status', 'Actions'
    ];
    const flexes = [2, 3, 2, 4, 1, 3, 2, 2, 2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: BoutiqueColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: List.generate(cols.length, (i) {
          return Expanded(
            flex: flexes[i],
            child: Text(
              cols[i],
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: BoutiqueColors.textSecondary),
            ),
          );
        }),
      ),
    );
  }

  // ── Table Row ──────────────────────────────────────────────────────────────
  Widget _tableRow(Map<String, dynamic> r, int i) {
    final isAlt = i.isOdd;
    final isVendor = r['_type'] == 'Vendor Issue';
    final action = r['status']?.toString() ?? '—';

    // Status badge colours
    Color statusColor;
    Color statusBg;
    if (isVendor) {
      if (action == 'Replacement Received' || action == 'Refund Received') {
        statusColor = BoutiqueColors.success;
        statusBg = BoutiqueColors.successBg;
      } else if (action == 'Discarded') {
        statusColor = BoutiqueColors.destructive;
        statusBg = const Color(0xFFFFEBEE);
      } else {
        statusColor = BoutiqueColors.warning;
        statusBg = BoutiqueColors.warningBg;
      }
    } else {
      // Customer Return
      statusColor = action == 'Processed'
          ? BoutiqueColors.success
          : BoutiqueColors.warning;
      statusBg = action == 'Processed'
          ? BoutiqueColors.successBg
          : BoutiqueColors.warningBg;
    }

    return Container(
      color: isAlt ? BoutiqueColors.bgSubtle : BoutiqueColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Date
          Expanded(flex: 2, child: _cell(r['date']?.toString() ?? '—')),
          // Party/Customer
          Expanded(flex: 3, child: _cell(r['counterpart']?.toString() ?? '—', bold: true)),
          // Mobile
          Expanded(flex: 2, child: _cell(r['mobile']?.toString() ?? '—')),
          // Product
          Expanded(
              flex: 4,
              child: _cell(r['productName']?.toString() ?? '—', bold: true)),
          // Qty
          Expanded(
              flex: 1,
              child: _cell(r['qty']?.toString() ?? '0', bold: true)),
          // Issue / Reason
          Expanded(
              flex: 3,
              child: _cell(r['issueReason']?.toString() ?? '—')),
          // Refund
          Expanded(
            flex: 2,
            child: _cell(
                '₹${_numFmt.format((r['refundAmount'] as num?)?.toDouble() ?? 0)}',
                bold: true),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  action,
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // Action (download & edit)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVendor) ...[
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF1E7E34)),
                    tooltip: 'Download Issue Bill (.xlsx)',
                    onPressed: () async {
                      final issue = VendorIssue(
                        id: r['id'] ?? '',
                        tagId: r['tagId'] ?? '',
                        productName: r['productName'] ?? '',
                        vendor: r['counterpart'] ?? '',
                        quantity: (r['qty'] as num?)?.toInt() ?? 1,
                        issueType: r['issueReason'] ?? '',
                        actionTaken: r['actionTaken'] ?? 'Pending',
                        dateReported: r['_dt'] as DateTime? ?? DateTime.now(),
                        notes: '',
                        refundAmount: (r['refundAmount'] as num?)?.toDouble() ?? 0.0,
                      );
                      await ExcelGenerator.downloadVendorIssueBillExcel(issue: issue);
                      if (mounted) {
                        BoutiqueToast.showSuccess(context, 'Issue Bill (.xlsx) downloaded!');
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: BoutiqueColors.accent),
                    tooltip: 'Update action',
                    onPressed: () => _updateVendorAction(r['id'], r['tagId'], r['actionTaken']),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.print_rounded, size: 16, color: BoutiqueColors.accent),
                    tooltip: 'Print Return Bill',
                    onPressed: () async {
                       final bill = r['_bill'];
                       if (bill != null) {
                         try {
                            final bytes = await BoutiquePdfGenerator.generate(bill);
                            await Printing.layoutPdf(onLayout: (_) async => bytes);
                         } catch(e) {
                            if (mounted) BoutiqueToast.showError(context, 'Error generating PDF: $e');
                         }
                       } else {
                          BoutiqueToast.showError(context, 'Bill data missing');
                       }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _cell(String text,
      {Color color = BoutiqueColors.textPrimary, bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal),
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
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: BoutiqueColors.textSecondary)),
            Text(_fmt.format(dt),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return IconButton(
        icon: Icon(icon, color: color), onPressed: onTap, tooltip: tooltip);
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: BoutiqueColors.accent),
        const SizedBox(width: 5),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: BoutiqueColors.accent)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: BoutiqueColors.accent)),
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
          Text(message,
              style: const TextStyle(
                  color: BoutiqueColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
