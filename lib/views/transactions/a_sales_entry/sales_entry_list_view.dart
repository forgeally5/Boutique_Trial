import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../dialogs/bill_detail_dialog.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../utils/pdf_invoice_api.dart';
import '../../../state/admin_state.dart';
import 'sales_entry_view.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../../utils/share_helper.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

class SalesEntryListView extends StatefulWidget {
  final AdminState state;

  const SalesEntryListView({super.key, required this.state});

  @override
  State<SalesEntryListView> createState() => _SalesEntryListViewState();
}

class _SalesEntryListViewState extends State<SalesEntryListView> {
  final _fmt = DateFormat('dd/MM/yyyy');
  int? _selectedIndex;

  String _account = 'All';
  String _bookName = 'All';
  late DateTime _dateFrom;
  late DateTime _dateTo;

  String _vouType = 'All';
  String _prefix = 'All';

  List<Map<String, dynamic>> _entries = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Default: 1 Apr of current financial year → today
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    _dateFrom = fyStart;
    _dateTo = now;
    _loadBills();
    widget.state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStateChanged();
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  bool _isDialogOpen = false;

  void _onStateChanged() {
    if (mounted && !_isDialogOpen) {
      if (widget.state.pendingEstimationTags.isNotEmpty) {
        _openSalesEntryDialog();
      } else if (widget.state.autoOpenAddEntrySection == 'A Sales Entry') {
        widget.state.autoOpenAddEntrySection = null; // Clear immediately
        _openSalesEntryDialog();
      }
    }
  }

  Future<void> _loadBills() async {
    setState(() => _loading = true);
    try {
      // Query only by billType (no composite index needed)
      // Date filtering done client-side
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
        // Date filter
        final vd = e['voucherDate'];
        if (vd is Timestamp) {
          final dt = vd.toDate();
          if (dt.isBefore(fromDt) || dt.isAfter(toDt)) { return false; }
        }
        // Account filter
        if (_account != 'All' && e['accountName'] != _account &&
            e['acName'] != _account) { return false; }
        // Prefix filter
        if (_prefix != 'All' && e['voucherPrefix'] != _prefix) { return false; }
        return true;
      }).toList();

      // Sort by voucherDate descending
      results.sort((a, b) {
        final aTs = a['voucherDate'];
        final bTs = b['voucherDate'];
        final aDt = aTs is Timestamp ? aTs.toDate() : DateTime(2000);
        final bDt = bTs is Timestamp ? bTs.toDate() : DateTime(2000);
        return bDt.compareTo(aDt);
      });

      setState(() {
        _entries = results;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading sales bills: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _loadBills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Top Action & Filter Area ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters (Left)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildFilterRow('Account', _account,
                          (val) => setState(() => _account = val!),
                          isPrimary: true),
                      const SizedBox(height: 8),
                      _buildFilterRow('Book Name', _bookName,
                          (val) => setState(() => _bookName = val!)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTile(
                                'Date From', _fmt.format(_dateFrom),
                                onTap: () => _pickDate(isFrom: true)),
                          ),
                          const SizedBox(width: 8),
                          const Text('To',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _brown)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateTile(
                                '', _fmt.format(_dateTo),
                                onTap: () => _pickDate(isFrom: false)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildFilterRow(
                                  'Vou.Type', _vouType,
                                  (val) =>
                                      setState(() => _vouType = val!))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildFilterRow(
                                  'Prefix', _prefix,
                                  (val) => setState(() => _prefix = val!))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Action Buttons (Right)
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _printVoucher(_entries[_selectedIndex!]);
                        }
                      }),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openSalesEntryDialog()),
                      _buildActionButton(Icons.share, 'Share', iconColor: Colors.teal, onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _shareBill(_entries[_selectedIndex!]);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a bill from the list to share.')),
                          );
                        }
                      }),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openSalesEntryDialog(_entries[_selectedIndex!]);
                        }
                      }),
                      _buildActionButton(Icons.cancel_outlined, 'Delete', iconColor: Colors.deepOrange, onTap: () async {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Sales Voucher'),
                              content: Text('Are you sure you want to delete sales voucher ${entry['voucherNo']}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final docId = entry['_docId']?.toString();
                            if (docId != null) {
                              try {
                                await FirebaseFirestore.instance.collection('bills').doc(docId).delete();
                              } catch (_) {}
                            }
                            setState(() {
                              _entries.removeAt(_selectedIndex!);
                              _selectedIndex = null;
                            });
                          }
                        }
                      }),
                      _buildActionButton(Icons.pageview_outlined, 'View', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openSalesEntryDialog(_entries[_selectedIndex!], true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a bill from the list to view.')),
                          );
                        }
                      }),
                      _buildActionButton(Icons.refresh, 'Refresh', onTap: _loadBills),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Data Table Area ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group header hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E6F2).withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      border:
                          const Border(bottom: BorderSide(color: _border)),
                    ),
                    child: const Text(
                      'Drag a column header here to group by that column',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _brownLight),
                    ),
                  ),

                  // Table Headers
                  Container(
                    color: _headerBg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Voucher No',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Voucher Date',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 3,
                            child: Text('Account Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Voucher Type',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Total Voucher\nAmt.',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Book Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Reference',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Ref No',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Date',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Memo\nVoucher',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                        Expanded(
                            flex: 2,
                            child: Text('Narration',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _brown))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  // Table Body
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: _brown))
                        : _entries.isEmpty
                            ? const Center(
                                child: Text('No bills found for this date range.',
                                    style: TextStyle(
                                        color: _brownLight, fontSize: 13)))
                            : ListView.builder(
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  final entry = _entries[index];
                                  final isEven = index % 2 == 0;
                                  final isSelected = _selectedIndex == index;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedIndex = index),
                                    onDoubleTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => BillDetailDialog(docData: entry),
                                      );
                                    },
                                    child: Container(
                                      color: isSelected
                                          ? const Color(0xFFFDF6ED)
                                          : (isEven ? Colors.white : _headerBg),
                                      child: Row(
                                        children: [
                                          _buildRowCell(
                                              _formatVoucherNo(entry),
                                              flex: 2),
                                          _buildRowCell(
                                              _formatDate(entry['voucherDate']),
                                              flex: 2),
                                          _buildRowCell(
                                              entry['acName']?.toString() ??
                                                  entry['accountName']?.toString() ??
                                                  entry['partyName']?.toString() ??
                                                  '',
                                              flex: 3),
                                          _buildRowCell(
                                              entry['billType']?.toString() ??
                                                  entry['voucherType']?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              _formatAmt(entry['voucherAmt'] ??
                                                  entry['totalAmount']),
                                              flex: 2),
                                          _buildRowCell(
                                              entry['bookName']
                                                      ?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              entry['reference']
                                                      ?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              entry['refNo']?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              entry['date']?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              entry['memoVoucher']
                                                      ?.toString() ??
                                                  '',
                                              flex: 2),
                                          _buildRowCell(
                                              entry['narration']
                                                      ?.toString() ??
                                                  '',
                                              flex: 2),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Bottom Summary Row
                  const Divider(height: 1, color: _border, thickness: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: _headerBg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${_entries.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _brown)),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
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

  String _formatVoucherNo(Map<String, dynamic> e) {
    final prefix = e['voucherPrefix']?.toString() ?? '';
    final type = e['voucherType']?.toString() ?? '';
    final no = e['voucherNo']?.toString() ?? e['billNo']?.toString() ?? '';
    if (prefix.isNotEmpty && no.isNotEmpty) {
      if (no.toLowerCase().startsWith(prefix.toLowerCase())) {
        return no;
      }
      return '$prefix-$no';
    }
    if (no.isNotEmpty) return no;
    if (type.isNotEmpty) return type;
    return '';
  }

  String _formatAmt(dynamic val) {
    if (val == null) return '';
    final d = (val as num?)?.toDouble() ?? 0.0;
    return d.toStringAsFixed(2);
  }

  String _formatDate(dynamic val) {
    if (val == null) return '';
    if (val is Timestamp) return _fmt.format(val.toDate());
    return val.toString();
  }

  Widget _buildFilterRow(
      String label, String value, ValueChanged<String?> onChanged,
      {bool isPrimary = false}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _brownLight)),
        ),
        Expanded(
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.grey, size: 16),
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.normal),
                onChanged: onChanged,
                items: [
                  DropdownMenuItem(
                      value: 'All',
                      child: Text('All',
                          style: TextStyle(
                              color: isPrimary && value == 'All'
                                  ? Colors.white
                                  : Colors.black))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(String label, String value,
      {required VoidCallback onTap}) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _brownLight)),
          ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black)),
                  const Icon(Icons.calendar_today,
                      color: Colors.grey, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {Color? iconColor, VoidCallback? onTap}) {
    return Material(
      color: _btnBg,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor ?? _brown),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    color: _brown,
                    height: 1.1,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowCell(String text, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style:
                const TextStyle(fontSize: 11, color: Colors.black87)),
      ),
    );
  }

  Future<void> _openSalesEntryDialog([Map<String, dynamic>? initialData, bool isViewOnly = false]) async {
    _isDialogOpen = true;
    final dynamic newEntry = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: size.width * 0.95,
            height: size.height * 0.95,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SalesEntryView(
                state: widget.state,
                initialData: initialData,
                isViewOnly: isViewOnly,
                onBack: (val) => Navigator.pop(context, val),
              ),
            ),
          ),
        );
      },
    );
    _isDialogOpen = false;
    if (newEntry != null && newEntry is Map<String, dynamic>) {
      _loadBills();
    }
    if (widget.state.navigatedFromHomeShortcut) {
      widget.state.navigatedFromHomeShortcut = false;
      widget.state.requestNavigateToTab(5); // Index 5 is HomeView
    }
  }

  void _printVoucher(Map<String, dynamic> entry) {
    try {
      final customerData = entry['customerDetails'] as Map<String, dynamic>? ?? {};
      final rawItems = entry['items'] as List<dynamic>? ?? [];

      double totalDiaAmt = 0.0;
      double totalOtherChgAmt = 0.0;

      final List<InvoiceItem> invoiceItems = rawItems.map((item) {
        final itemMap = item as Map<String, dynamic>? ?? {};
        String name = itemMap['name']?.toString() ?? itemMap['itemName']?.toString() ?? '';
        final purity = itemMap['purity']?.toString() ?? itemMap['group']?.toString() ?? '';
        if (purity.isNotEmpty && !name.contains(purity)) {
          name += " ($purity)";
        }
        final pcs = (itemMap['pcs'] as num?)?.toInt() ?? 0;
        final gross = (itemMap['grossWeight'] as num?)?.toDouble() ?? (itemMap['grossWt'] as num?)?.toDouble() ?? 0.0;
        final net = (itemMap['netWeight'] as num?)?.toDouble() ?? (itemMap['netWt'] as num?)?.toDouble() ?? 0.0;
        final rate = (itemMap['rate'] as num?)?.toDouble() ?? 0.0;

        double diaAmt = 0.0;
        double otherChgAmt = 0.0;
        final bool otherWtChecked = itemMap['othWtChecked'] == true || itemMap['requireOtherWt'] == true;
        if (otherWtChecked) {
          final rawExtra = itemMap['extraCharges'] as List<dynamic>? ?? itemMap['subRows'] as List<dynamic>? ?? [];
          for (var sr in rawExtra) {
            final srMap = sr as Map<String, dynamic>? ?? {};
            final style = (srMap['styleName'] ?? srMap['style'] ?? '').toString().trim().toLowerCase();
            final amt = (srMap['metalAmt'] ?? srMap['amount'] ?? 0.0) as num;
            if (style == 'diamond') {
              diaAmt += amt.toDouble();
            } else {
              otherChgAmt += amt.toDouble();
            }
          }
        }
        totalDiaAmt += diaAmt;
        totalOtherChgAmt += otherChgAmt;

        final double totalMetalVal = (itemMap['metalAmt'] as num?)?.toDouble() ?? 0.0;
        final baseMetalAmt = totalMetalVal - diaAmt - otherChgAmt;
        final double labourVal = (itemMap['labourAmt'] as num?)?.toDouble() ?? 0.0;
        final double labourRate = (itemMap['labourRate'] as num?)?.toDouble() ?? 0.0;
        final String labourOn = itemMap['labourOn']?.toString() ?? 'Per Gram Net Wt';

        String labourRateStr = '';
        if (labourRate > 0) {
          if (labourOn.toLowerCase().contains('gram') || labourOn.toLowerCase().contains('g')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} /G';
          } else if (labourOn.toLowerCase().contains('percent') || labourOn.contains('%')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} %';
          } else {
            labourRateStr = '${labourRate.toStringAsFixed(2)} Fx';
          }
        }

        return InvoiceItem(
          description: name,
          pcs: pcs,
          purity: purity.isNotEmpty ? purity : 'S925',
          grossWt: gross,
          netWt: net,
          rate: rate,
          metalAmount: baseMetalAmt,
          diaAmount: diaAmt,
          labour: labourVal,
          colStAndOtChg: otherChgAmt,
          amount: totalMetalVal + labourVal,
          labourAmount: labourVal,
          labourRateStr: labourRateStr,
        );
      }).toList();

      final String dateStr = entry['voucherDate'] is Timestamp
          ? DateFormat('dd/MM/yyyy').format((entry['voucherDate'] as Timestamp).toDate())
          : entry['voucherDate']?.toString() ?? '';

      final double gross = (entry['voucherAmt'] as num?)?.toDouble() ??
          (entry['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final double discount = (entry['discountAmt'] as num?)?.toDouble() ?? 0.0;
      final double base = (entry['baseAmt'] as num?)?.toDouble() ?? 0.0;
      final double afterDiscount = (entry['afterDiscount'] as num?)?.toDouble() ?? 0.0;
      final double cgst = (entry['cgstAmt'] as num?)?.toDouble() ?? 0.0;
      final double sgst = (entry['sgstAmt'] as num?)?.toDouble() ?? 0.0;
      final double igst = (entry['igstAmt'] as num?)?.toDouble() ?? 0.0;
      final double roundOff = (entry['rndDiscount'] as num?)?.toDouble() ?? 0.0;
      final double payment = (entry['paymentAmt'] as num?)?.toDouble() ?? 0.0;
      final double card = (entry['cardAmt'] as num?)?.toDouble() ?? 0.0;

      final double cash = (entry['cashAmt'] as num?)?.toDouble() ?? 0.0;
      final double bank = (entry['bankAmt'] as num?)?.toDouble() ?? 0.0;
      final double upi = (entry['upiAmt'] as num?)?.toDouble() ?? 0.0;
      final double scheme = (entry['goldSchemeAmt'] as num?)?.toDouble() ?? 0.0;
      final double og = (entry['ogPurchaseAmt'] as num?)?.toDouble() ?? 0.0;
      final double sr = (entry['salesReturnAmt'] as num?)?.toDouble() ?? 0.0;
      final double ap = (entry['apAmt'] as num?)?.toDouble() ?? 0.0;
      final double rateApply = (entry['rateApplyAmt'] as num?)?.toDouble() ?? 0.0;
      final double dueAmt = (entry['dueAmt'] as num?)?.toDouble() ?? 0.0;

      final List<String> rParts = [];
      if (cash > 0) rParts.add('Cash: ${cash.toStringAsFixed(2)}');
      if (bank > 0) {
        String bStr = 'Bank: ${bank.toStringAsFixed(2)}';
        if (entry['bankCheque']?.toString().isNotEmpty ?? false) bStr += ' (Chq: ${entry['bankCheque']})';
        if (entry['bankRemarks']?.toString().isNotEmpty ?? false) bStr += ' (${entry['bankRemarks']})';
        rParts.add(bStr);
      }
      if (card > 0) {
        String cStr = 'Card: ${card.toStringAsFixed(2)}';
        if (entry['cardMachine']?.toString().isNotEmpty ?? false) cStr += ' (Mch: ${entry['cardMachine']})';
        if (entry['cardApproval']?.toString().isNotEmpty ?? false) cStr += ' (App: ${entry['cardApproval']})';
        rParts.add(cStr);
      }
      if (upi > 0) {
        String uStr = 'UPI: ${upi.toStringAsFixed(2)}';
        if (entry['upiRemarks']?.toString().isNotEmpty ?? false) uStr += ' (${entry['upiRemarks']})';
        if (entry['upiRemarks2']?.toString().isNotEmpty ?? false) uStr += ' (${entry['upiRemarks2']})';
        rParts.add(uStr);
      }
      if (scheme > 0) {
        String sStr = 'Scheme: ${scheme.toStringAsFixed(2)}';
        if (entry['schemeAcNo']?.toString().isNotEmpty ?? false) sStr += ' (A/c: ${entry['schemeAcNo']})';
        rParts.add(sStr);
      }
      if (og > 0) {
        String ogStr = 'Old Gold: ${og.toStringAsFixed(2)}';
        if (entry['ogGrossWt']?.toString().isNotEmpty ?? false) ogStr += ' (${entry['ogGrossWt']}g @ ${entry['ogRate']})';
        rParts.add(ogStr);
      }
      if (sr > 0) {
        String srStr = 'Sales Return: ${sr.toStringAsFixed(2)}';
        if (entry['srOriginalInv']?.toString().isNotEmpty ?? false) srStr += ' (Inv: ${entry['srOriginalInv']})';
        rParts.add(srStr);
      }
      if (ap > 0) rParts.add('Advance Pay: ${ap.toStringAsFixed(2)}');
      if (rateApply > 0) rParts.add('Rate Fix: ${rateApply.toStringAsFixed(2)}');
      final receiptDetailsText = rParts.isEmpty ? '0.00' : rParts.join('\n');
      final creditsText = dueAmt > 0 ? 'Credit Sale: ${dueAmt.toStringAsFixed(2)}' : '0.00';

      final String customerMobile = customerData['mobile']?.toString() ?? 
                                    customerData['mobileNo1']?.toString() ?? 
                                    customerData['mobileNo2']?.toString() ?? 
                                    customerData['phone']?.toString() ?? '';
      
      final String customerAddress = customerData['address']?.toString() ?? 
                                     customerData['street']?.toString() ?? 
                                     customerData['city']?.toString() ?? '';
      
      final String customerState = customerData['state']?.toString() ?? 
                                   customerData['customerState']?.toString() ?? '';
      
      final String customerPan = customerData['pan']?.toString() ?? 
                                 customerData['panNo']?.toString() ?? 
                                 customerData['panNumber']?.toString() ?? 
                                 entry['customerDetails']?['pan']?.toString() ?? '';

      final invoiceData = SalesInvoiceData(
        customerName: customerData['name']?.toString() ?? entry['acName']?.toString() ?? 'WALK-IN',
        customerMobile: customerMobile,
        customerAddress: customerAddress.isNotEmpty ? customerAddress : 'COIMBATORE, Tamil Nadu',
        customerState: customerState.isNotEmpty ? customerState : 'Tamil Nadu',
        invoiceNo: entry['voucherNo']?.toString() ?? '',
        date: dateStr,
        placeOfSupply: entry['placeOfSupply']?.toString() ?? 'Tamil Nadu',
        items: invoiceItems,
        totalPcs: invoiceItems.fold(0.0, (acc, r) => acc + r.pcs),
        totalGrossWt: invoiceItems.fold(0.0, (acc, r) => acc + r.grossWt),
        totalNetWt: invoiceItems.fold(0.0, (acc, r) => acc + r.netWt),
        totalMetalAmt: base - totalDiaAmt - totalOtherChgAmt,
        totalAmount: base,
        discountAmt: discount,
        taxableAmount: afterDiscount,
        cgstAmt: cgst,
        sgstAmt: sgst,
        igstAmt: igst,
        roundOff: roundOff > 0 ? -roundOff : 0.0,
        grossAmount: gross,
        receivedAmt: payment,
        amountInWords: PdfInvoiceApi.numberToWords(gross),
        cardDetails: card > 0 ? card.toStringAsFixed(2) : "0.00",
        customerPan: customerPan,
        narration: entry['narration']?.toString() ?? '',
        dueAmount: dueAmt,
        receiptDetails: receiptDetailsText,
        credits: creditsText,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 850,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF3E2723),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Invoice Print Preview - ${invoiceData.invoiceNo}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => PdfInvoiceApi.generate(invoiceData),
                    allowSharing: false,
                    allowPrinting: true,
                    actions: [
                      PdfPreviewAction(
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        onPressed: (context, buildPdf, pageFormat) async {
                          await shareInvoiceHelper(context: context, invoiceData: invoiceData);
                        },
                      ),
                    ],
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    dynamicLayout: false,
                    canDebug: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'Invoice_${invoiceData.invoiceNo}.pdf',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating preview: $e')),
      );
    }
  }

  void _shareBill(Map<String, dynamic> entry) async {
    final voucherNo = entry['voucherNo']?.toString() ?? '';
    final double totalAmount = (entry['voucherAmt'] as num?)?.toDouble() ?? 
                               (entry['grossAmount'] as num?)?.toDouble() ?? 
                               (entry['voucherAmount'] as num?)?.toDouble() ?? 0.0;
    
    final customerData = entry['customerDetails'] as Map<String, dynamic>? ?? {};
    final String customerName = entry['acName']?.toString() ?? customerData['name']?.toString() ?? "Customer";

    String customerMobile = customerData['mobileNo1']?.toString() ?? '';
    if (customerMobile.trim().isEmpty) customerMobile = customerData['mobileNo2']?.toString() ?? '';
    if (customerMobile.trim().isEmpty) customerMobile = customerData['phone']?.toString() ?? '';
    if (customerMobile.trim().isEmpty) customerMobile = customerData['mobile']?.toString() ?? '';

    String customerEmail = customerData['email1']?.toString() ?? '';
    if (customerEmail.trim().isEmpty) customerEmail = customerData['email2']?.toString() ?? '';
    if (customerEmail.trim().isEmpty) customerEmail = customerData['email']?.toString() ?? '';

    final rawDate = entry['voucherDate'];
    final String dateStr = rawDate is Timestamp
        ? DateFormat('dd/MM/yyyy').format(rawDate.toDate())
        : rawDate?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now());

    final String defaultMsg = "Dear $customerName, thank you for shopping with Trilok. Your invoice $voucherNo for Rs.${totalAmount.toStringAsFixed(2)} is ready. Date: $dateStr. Thank you!";
    final TextEditingController msgController = TextEditingController(text: defaultMsg);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFCFAF5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.share, color: Color(0xFF3E2723), size: 24),
              const SizedBox(width: 10),
              Text(
                'Share Invoice - $voucherNo',
                style: const TextStyle(
                  color: Color(0xFF3E2723),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Customize Share Message:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E2723)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: msgController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD7CCC8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8D6E63)),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // WhatsApp
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          String phone = customerMobile.replaceAll(RegExp(r'\D'), '');
                          if (phone.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No mobile number found in Customer details!')),
                              );
                            }
                            return;
                          }
                          final text = Uri.encodeComponent(msgController.text);
                          if (!phone.startsWith('91') && phone.length == 10) {
                            phone = '91$phone';
                          }
                          final url = 'https://api.whatsapp.com/send?phone=$phone&text=$text';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch WhatsApp')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Email
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD44638),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.email, size: 16),
                        label: const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          String targetEmail = customerEmail.trim();
                          if (targetEmail.isEmpty) {
                            final inputEmail = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final ctrl = TextEditingController();
                                return AlertDialog(
                                  title: const Text('Enter Recipient Email'),
                                  content: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. customer@gmail.com',
                                      labelText: 'Customer Email',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, null),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                      child: const Text('Send'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (inputEmail == null || inputEmail.isEmpty) return;
                            targetEmail = inputEmail;
                            if (!context.mounted) return;
                          }
                          
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );
                          
                          try {
                            await _sendInvoiceEmailViaSmtpForEntry(
                              entry: entry,
                              customerName: customerName,
                              recipientEmail: targetEmail,
                              messageText: msgController.text,
                              voucherNo: voucherNo,
                            );
                          } finally {
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendInvoiceEmailViaSmtpForEntry({
    required Map<String, dynamic> entry,
    required String customerName,
    required String recipientEmail,
    required String messageText,
    required String voucherNo,
  }) async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('email_config')
          .get();

      if (!configDoc.exists) {
        throw Exception(
          "Email SMTP config not found. Please configure it in Settings first."
        );
      }

      final data = configDoc.data()!;
      final username = data['username']?.toString() ?? '';
      final appPassword = data['appPassword']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? 'Trilok';

      if (username.isEmpty || appPassword.isEmpty) {
        throw Exception("SMTP username or appPassword is empty in configurations.");
      }

      final rawItems = entry['items'] as List<dynamic>? ?? [];
      final invoiceItems = rawItems.map((item) {
        final itemMap = item as Map<String, dynamic>? ?? {};
        final name = itemMap['name']?.toString() ?? 'SILVER ITEM';
        final pcs = (itemMap['pcs'] as num?)?.toInt() ?? 1;
        final gross = (itemMap['grossWeight'] as num?)?.toDouble() ?? 0.0;
        final net = (itemMap['netWeight'] as num?)?.toDouble() ?? 0.0;
        final rate = (itemMap['rate'] as num?)?.toDouble() ?? 0.0;
        final metalAmt = (itemMap['metalAmt'] as num?)?.toDouble() ?? 0.0;
        final labour = (itemMap['labourAmt'] as num?)?.toDouble() ?? 0.0;
        final double labourRate = (itemMap['labourRate'] as num?)?.toDouble() ?? 0.0;
        final String labourOn = itemMap['labourOn']?.toString() ?? 'Per Gram Net Wt';

        String labourRateStr = '';
        if (labourRate > 0) {
          if (labourOn.toLowerCase().contains('gram') || labourOn.toLowerCase().contains('g')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} /G';
          } else if (labourOn.toLowerCase().contains('percent') || labourOn.contains('%')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} %';
          } else {
            labourRateStr = '${labourRate.toStringAsFixed(2)} Fx';
          }
        }

        return InvoiceItem(
          description: name,
          pcs: pcs,
          purity: itemMap['purity']?.toString() ?? 'S925',
          grossWt: gross,
          netWt: net,
          rate: rate,
          metalAmount: metalAmt,
          diaAmount: 0.0,
          labour: labour,
          colStAndOtChg: 0.0,
          amount: metalAmt + labour,
          labourAmount: labour,
          labourRateStr: labourRateStr,
        );
      }).toList();

      final double grossAmt = (entry['voucherAmt'] as num?)?.toDouble() ?? 
                              (entry['grossAmount'] as num?)?.toDouble() ?? 0.0;

      final double cash = (entry['cashAmt'] as num?)?.toDouble() ?? 0.0;
      final double bank = (entry['bankAmt'] as num?)?.toDouble() ?? 0.0;
      final double card = (entry['cardAmt'] as num?)?.toDouble() ?? 0.0;
      final double upi = (entry['upiAmt'] as num?)?.toDouble() ?? 0.0;
      final double scheme = (entry['goldSchemeAmt'] as num?)?.toDouble() ?? 0.0;
      final double og = (entry['ogPurchaseAmt'] as num?)?.toDouble() ?? 0.0;
      final double sr = (entry['salesReturnAmt'] as num?)?.toDouble() ?? 0.0;
      final double ap = (entry['apAmt'] as num?)?.toDouble() ?? 0.0;
      final double rateApply = (entry['rateApplyAmt'] as num?)?.toDouble() ?? 0.0;
      final double dueAmt = (entry['dueAmt'] as num?)?.toDouble() ?? 0.0;

      final List<String> rParts = [];
      if (cash > 0) rParts.add('Cash: ${cash.toStringAsFixed(2)}');
      if (bank > 0) {
        String bStr = 'Bank: ${bank.toStringAsFixed(2)}';
        if (entry['bankCheque']?.toString().isNotEmpty ?? false) bStr += ' (Chq: ${entry['bankCheque']})';
        if (entry['bankRemarks']?.toString().isNotEmpty ?? false) bStr += ' (${entry['bankRemarks']})';
        rParts.add(bStr);
      }
      if (card > 0) {
        String cStr = 'Card: ${card.toStringAsFixed(2)}';
        if (entry['cardMachine']?.toString().isNotEmpty ?? false) cStr += ' (Mch: ${entry['cardMachine']})';
        if (entry['cardApproval']?.toString().isNotEmpty ?? false) cStr += ' (App: ${entry['cardApproval']})';
        rParts.add(cStr);
      }
      if (upi > 0) {
        String uStr = 'UPI: ${upi.toStringAsFixed(2)}';
        if (entry['upiRemarks']?.toString().isNotEmpty ?? false) uStr += ' (${entry['upiRemarks']})';
        if (entry['upiRemarks2']?.toString().isNotEmpty ?? false) uStr += ' (${entry['upiRemarks2']})';
        rParts.add(uStr);
      }
      if (scheme > 0) {
        String sStr = 'Scheme: ${scheme.toStringAsFixed(2)}';
        if (entry['schemeAcNo']?.toString().isNotEmpty ?? false) sStr += ' (A/c: ${entry['schemeAcNo']})';
        rParts.add(sStr);
      }
      if (og > 0) {
        String ogStr = 'Old Gold: ${og.toStringAsFixed(2)}';
        if (entry['ogGrossWt']?.toString().isNotEmpty ?? false) ogStr += ' (${entry['ogGrossWt']}g @ ${entry['ogRate']})';
        rParts.add(ogStr);
      }
      if (sr > 0) {
        String srStr = 'Sales Return: ${sr.toStringAsFixed(2)}';
        if (entry['srOriginalInv']?.toString().isNotEmpty ?? false) srStr += ' (Inv: ${entry['srOriginalInv']})';
        rParts.add(srStr);
      }
      if (ap > 0) rParts.add('Advance Pay: ${ap.toStringAsFixed(2)}');
      if (rateApply > 0) rParts.add('Rate Fix: ${rateApply.toStringAsFixed(2)}');
      final receiptDetailsText = rParts.isEmpty ? '0.00' : rParts.join('\n');
      final creditsText = dueAmt > 0 ? 'Credit Sale: ${dueAmt.toStringAsFixed(2)}' : '0.00';

      final customerMap = entry['customerDetails'] as Map? ?? {};
      final String customerMobile = customerMap['mobile']?.toString() ?? 
                                    customerMap['mobileNo1']?.toString() ?? 
                                    customerMap['mobileNo2']?.toString() ?? 
                                    customerMap['phone']?.toString() ?? '';
      
      final String customerAddress = customerMap['address']?.toString() ?? 
                                     customerMap['street']?.toString() ?? 
                                     customerMap['city']?.toString() ?? '';
      
      final String customerState = customerMap['state']?.toString() ?? 
                                   customerMap['customerState']?.toString() ?? 
                                   entry['placeOfSupply']?.toString() ?? 'Tamil Nadu';
      
      final String customerPan = customerMap['pan']?.toString() ?? 
                                 customerMap['panNo']?.toString() ?? 
                                 customerMap['panNumber']?.toString() ?? '';

      final invoiceData = SalesInvoiceData(
        customerName: customerName,
        customerMobile: customerMobile,
        customerAddress: customerAddress.isNotEmpty ? customerAddress : 'COIMBATORE, Tamil Nadu',
        customerState: customerState,
        invoiceNo: voucherNo,
        date: entry['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
        placeOfSupply: entry['placeOfSupply']?.toString() ?? 'Tamil Nadu',
        items: invoiceItems,
        totalPcs: invoiceItems.fold(0.0, (acc, r) => acc + r.pcs),
        totalGrossWt: invoiceItems.fold(0.0, (acc, r) => acc + r.grossWt),
        totalNetWt: invoiceItems.fold(0.0, (acc, r) => acc + r.netWt),
        totalMetalAmt: (entry['metalAmt'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (entry['baseAmt'] as num?)?.toDouble() ?? grossAmt,
        discountAmt: (entry['discountAmt'] as num?)?.toDouble() ?? 0.0,
        taxableAmount: (entry['afterDiscount'] as num?)?.toDouble() ?? grossAmt,
        cgstAmt: (entry['cgstAmt'] as num?)?.toDouble() ?? 0.0,
        sgstAmt: (entry['sgstAmt'] as num?)?.toDouble() ?? 0.0,
        igstAmt: (entry['igstAmt'] as num?)?.toDouble() ?? 0.0,
        roundOff: 0.0,
        grossAmount: grossAmt,
        receivedAmt: (entry['paymentAmt'] as num?)?.toDouble() ?? 0.0,
        amountInWords: PdfInvoiceApi.numberToWords(grossAmt),
        cardDetails: "0.00",
        customerPan: customerPan,
        narration: entry['narration']?.toString() ?? '',
        dueAmount: dueAmt,
        receiptDetails: receiptDetailsText,
        credits: creditsText,
      );

      final pdfBytes = await PdfInvoiceApi.generate(invoiceData);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/Invoice_${voucherNo.replaceAll('/', '_')}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      final smtpServer = gmail(username, appPassword);
      final message = Message()
        ..from = Address(username, senderName)
        ..recipients.add(recipientEmail.trim())
        ..subject = 'Tax Invoice $voucherNo - Trilok Jewellers'
        ..text = messageText
        ..attachments.add(FileAttachment(tempFile));

      await send(message, smtpServer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice email sent successfully with PDF attachment!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error sending invoice email: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
