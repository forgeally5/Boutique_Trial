import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../../state/admin_state.dart';
import '../../../dialogs/journal_voucher_print_dialog.dart';
import '../../../dialogs/cheque_print_dialog.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

/// Model representing an individual line item row in a Journal Entry (OrnateStn style)
class JournalRow {
  String crDr; // 'DR' or 'CR'
  TextEditingController accountCtrl;
  TextEditingController tradingCtrl;
  TextEditingController metalCtrl;
  TextEditingController purityCtrl;
  TextEditingController weightCtrl;
  TextEditingController amountCtrl;
  TextEditingController refNoCtrl;
  String gstApplicable; // 'No' or 'Yes'
  TextEditingController hsnCodeCtrl;
  double gstRate; // e.g. 0, 3, 5, 12, 18, 28
  TextEditingController narrationCtrl;

  JournalRow({
    this.crDr = 'DR',
    String accountName = '',
    String tradingName = '',
    String metalName = '',
    String purity = '',
    String weight = '0.000',
    String amount = '0.00',
    String refNo = '',
    this.gstApplicable = 'No',
    String hsnCode = '',
    this.gstRate = 0.0,
    String narration = '',
  })  : accountCtrl = TextEditingController(text: accountName),
        tradingCtrl = TextEditingController(text: tradingName),
        metalCtrl = TextEditingController(text: metalName),
        purityCtrl = TextEditingController(text: purity),
        weightCtrl = TextEditingController(text: weight),
        amountCtrl = TextEditingController(text: amount),
        refNoCtrl = TextEditingController(text: refNo),
        hsnCodeCtrl = TextEditingController(text: hsnCode),
        narrationCtrl = TextEditingController(text: narration);

  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0.0;
  double get weight => double.tryParse(weightCtrl.text.trim()) ?? 0.0;

  double get sgstAmt => gstApplicable == 'Yes' ? (amount * (gstRate / 2) / 100) : 0.0;
  double get cgstAmt => gstApplicable == 'Yes' ? (amount * (gstRate / 2) / 100) : 0.0;
  double get igstAmt => gstApplicable == 'Yes' ? (amount * gstRate / 100) : 0.0;
  double get totalGstAmt => sgstAmt + cgstAmt;
  double get netAmount => amount + (gstApplicable == 'Yes' ? totalGstAmt : 0.0);

  void dispose() {
    accountCtrl.dispose();
    tradingCtrl.dispose();
    metalCtrl.dispose();
    purityCtrl.dispose();
    weightCtrl.dispose();
    amountCtrl.dispose();
    refNoCtrl.dispose();
    hsnCodeCtrl.dispose();
    narrationCtrl.dispose();
  }
}

/// Journal Entry View Component styled matching Cash Entry and Bank Entry
class JournalEntryView extends StatefulWidget {
  final AdminState state;

  const JournalEntryView({super.key, required this.state});

  @override
  State<JournalEntryView> createState() => _JournalEntryViewState();
}

class _JournalEntryViewState extends State<JournalEntryView> {
  String _account = 'All';
  String _bookName = 'All';
  final String _dateFrom = '23/10/2019';
  final String _dateTo = '23/10/2019';
  String _vouType = 'All';
  String _prefix = 'All';

  int? _selectedIndex;
  final List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;
  List<String> _bookNamesList = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchEntries();
    _loadBookNames();
  }

  Future<void> _loadBookNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final list = snap.docs.map((d) => d.data()['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _bookNamesList = ['All', ...list];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('journal_entries')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('journal_entries')
            .get();
      }
      if (mounted) {
        setState(() {
          _entries.clear();
          for (var doc in snap.docs) {
            final data = doc.data();
            data['docId'] = doc.id;
            _entries.add(data);
          }
        });
      }
    } catch (_) {
      // Firestore not available; show empty list
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _openPrintVoucher([Map<String, dynamic>? data]) {
    final entry = data ?? (_selectedIndex != null && _selectedIndex! < _entries.length ? _entries[_selectedIndex!] : null);
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an entry to print.')),
      );
      return;
    }

    final String vouNo = entry['voucherNo']?.toString() ?? entry['vouNo']?.toString() ?? 'JV / 1';
    final String dateStr = entry['voucherDate']?.toString() ?? entry['vouDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    final String vouType = entry['voucherType']?.toString() ?? entry['vouType']?.toString() ?? 'Journal';
    final String book = entry['bookName']?.toString() ?? 'JOURNAL BOOK';
    final String ref = entry['reference']?.toString() ?? '';
    final String pos = entry['placeOfSupply']?.toString() ?? '';
    final double dr = double.tryParse(entry['totalDr']?.toString() ?? '') ?? (entry['totalDr'] is num ? (entry['totalDr'] as num).toDouble() : 0.0);
    final double cr = double.tryParse(entry['totalCr']?.toString() ?? '') ?? (entry['totalCr'] is num ? (entry['totalCr'] as num).toDouble() : 0.0);
    final double drWt = double.tryParse(entry['totalDrWt']?.toString() ?? '') ?? (entry['totalDrWt'] is num ? (entry['totalDrWt'] as num).toDouble() : 0.0);
    final double crWt = double.tryParse(entry['totalCrWt']?.toString() ?? '') ?? (entry['totalCrWt'] is num ? (entry['totalCrWt'] as num).toDouble() : 0.0);
    final String masterNarr = entry['narration']?.toString() ?? '';
    final List<Map<String, dynamic>> rowData = (entry['rows'] as List<dynamic>?)?.map((r) => Map<String, dynamic>.from(r)).toList() ?? [];

    JournalVoucherPrintDialog.show(
      context,
      voucherNo: vouNo,
      date: dateStr,
      voucherType: vouType,
      bookName: book,
      reference: ref,
      placeOfSupply: pos,
      rows: rowData,
      totalDr: dr,
      totalCr: cr,
      totalDrWt: drWt,
      totalCrWt: crWt,
      masterNarration: masterNarr,
    );
  }

  void _openJournalEntryWindow({Map<String, dynamic>? initialData, bool isViewOnly = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _JournalVoucherEntryDialog(
        existingEntry: initialData,
        isViewOnly: isViewOnly,
        onSave: (newEntry) {
          setState(() {
            if (initialData != null && _selectedIndex != null) {
              _entries[_selectedIndex!] = newEntry;
            } else {
              _entries.insert(0, newEntry);
            }
          });
        },
      ),
    );
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
                      _buildFilterRow('Account', _account, ['All'], (val) => setState(() => _account = val!), isPrimary: true),
                      const SizedBox(height: 8),
                      _buildFilterRow('Book Name', _bookName, _bookNamesList, (val) => setState(() => _bookName = val!)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDateFilter('Date From', _dateFrom)),
                          const SizedBox(width: 8),
                          const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDateFilter('', _dateTo)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildFilterRow('Vou.Type', _vouType, ['All', 'Journal', 'Memorial'], (val) => setState(() => _vouType = val!))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildFilterRow('Prefix', _prefix, ['All', 'JV', 'MEMO'], (val) => setState(() => _prefix = val!))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Action Buttons (Right - 56x56 square action buttons like cash & bank entry)
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildActionButton(Icons.flash_on, 'Quick\nEntry', onTap: () => _openJournalEntryWindow()),
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () => _openPrintVoucher()),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openJournalEntryWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openJournalEntryWindow(initialData: _entries[_selectedIndex!]);
                        }
                      }),
                      _buildActionButton(Icons.cancel_outlined, 'Delete', iconColor: Colors.deepOrange, onTap: () async {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Voucher'),
                              content: Text('Are you sure you want to delete voucher ${entry['voucherNo']}?'),
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
                            final docId = entry['docId']?.toString();
                            if (docId != null) {
                              try {
                                if (entry['voucherNo']?.toString().contains('-OFF') == true) {
                                  LocalDbService().deleteUnsyncedEntryByDocId(docId);
                                } else {
                                  FirebaseFirestore.instance.collection('journal_entries').doc(docId).delete();
                                }
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
                          _openJournalEntryWindow(initialData: _entries[_selectedIndex!], isViewOnly: true);
                        }
                      }),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E6F2).withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      border: const Border(bottom: BorderSide(color: _border)),
                    ),
                    child: const Text(
                      'Drag a column header here to group by that column',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight),
                    ),
                  ),

                  // Table Headers
                  Container(
                    color: _headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Voucher No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Voucher Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 3, child: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Voucher Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Total Dr Amt.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Total Cr Amt.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Total Dr Wt (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Entry Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 3, child: Text('Narration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  // Table Body
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _entries.isEmpty
                            ? const Center(
                                child: Text(
                                  'No journal entries found.\nTap Add to create a new entry.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final isSelected = _selectedIndex == index;
                        final double drAmt = double.tryParse(entry['totalDr']?.toString() ?? '') ?? (entry['totalDr'] is num ? (entry['totalDr'] as num).toDouble() : 0.0);
                        final double crAmt = double.tryParse(entry['totalCr']?.toString() ?? '') ?? (entry['totalCr'] is num ? (entry['totalCr'] as num).toDouble() : 0.0);
                        final double drWt = double.tryParse(entry['totalDrWt']?.toString() ?? '') ?? (entry['totalDrWt'] is num ? (entry['totalDrWt'] as num).toDouble() : 0.0);

                        return InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          onDoubleTap: () => _openJournalEntryWindow(initialData: entry, isViewOnly: true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFDF6ED) : Colors.transparent,
                              border: const Border(bottom: BorderSide(color: _border)),
                            ),
                            child: Row(
                              children: [
                                _buildRowCell('${entry['prefix'] ?? 'JV'} / ${entry['vouNo'] ?? ''}', flex: 2, isBold: true),
                                _buildRowCell(entry['voucherDate']?.toString() ?? entry['vouDate']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['accountName']?.toString() ?? '', flex: 3),
                                _buildRowCell(entry['voucherType']?.toString() ?? entry['vouType']?.toString() ?? 'Journal', flex: 2),
                                _buildRowCell(drAmt.toStringAsFixed(2), flex: 2, isBold: true, textColor: Colors.blue.shade800),
                                _buildRowCell(crAmt.toStringAsFixed(2), flex: 2, isBold: true, textColor: Colors.green.shade800),
                                _buildRowCell(drWt.toStringAsFixed(3), flex: 2),
                                _buildRowCell(entry['voucherType']?.toString() ?? entry['vouType']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['reference']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['narration']?.toString() ?? '', flex: 3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: _headerBg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${_entries.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
                        ),
                        const SizedBox(width: 24),
                        Text('Total Debit: ₹${_calculateTotalDr().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade800)),
                        const SizedBox(width: 24),
                        Text('Total Credit: ₹${_calculateTotalCr().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800)),
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

  double _calculateTotalDr() {
    double total = 0.0;
    for (var e in _entries) {
      total += double.tryParse(e['totalDr']?.toString() ?? '') ?? (e['totalDr'] is num ? (e['totalDr'] as num).toDouble() : 0.0);
    }
    return total;
  }

  double _calculateTotalCr() {
    double total = 0.0;
    for (var e in _entries) {
      total += double.tryParse(e['totalCr']?.toString() ?? '') ?? (e['totalCr'] is num ? (e['totalCr'] as num).toDouble() : 0.0);
    }
    return total;
  }

  Widget _buildFilterRow(String label, String value, List<String> externalItems, ValueChanged<String?> onChanged, {bool isPrimary = false}) {
    final itemsMap = {
      'Account': ['All', 'OLD GOLD PURCHASE ACCOUNT', 'RAMESH JEWELLERS', 'MAKING CHARGES EXPENSE', 'KUMAR ARTISAN LABOUR'],
      'Vou.Type': ['All', 'Journal', 'Memorial'],
      'Prefix': ['All', 'JV', 'MEMO'],
    };
    final List<String> options = externalItems.isNotEmpty ? externalItems : (itemsMap[label] ?? ['All']);
    final String effectiveValue = options.contains(value) ? value : options.first;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
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
                value: effectiveValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
                ),
                onChanged: onChanged,
                items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilter(String label, String value) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 12, color: Colors.black)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
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
                style: const TextStyle(fontSize: 9, color: _brown, height: 1.1, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowCell(String text, {int flex = 2, bool isBold = false, Color? textColor}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// JOURNAL VOUCHER ENTRY DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _JournalVoucherEntryDialog extends StatefulWidget {
  final Map<String, dynamic>? existingEntry;
  final ValueChanged<Map<String, dynamic>> onSave;
  final bool isViewOnly;

  const _JournalVoucherEntryDialog({
    this.existingEntry,
    required this.onSave,
    this.isViewOnly = false,
  });

  @override
  State<_JournalVoucherEntryDialog> createState() => _JournalVoucherEntryDialogState();
}

class _JournalVoucherEntryDialogState extends State<_JournalVoucherEntryDialog> {
  String _prefix = 'JV';
  final TextEditingController _vouNoCtrl = TextEditingController(text: '1');
  final DateTime _vouDateVal = DateTime.now();
  String _vouType = 'General Journal';
  final List<String> _entryTypes = [
    'General Journal',
    'Stock Adjustment',
    'Old Gold Exchange',
    'Purity Correction',
    'Opening Balance',
    'Write-off',
    'Provision'
  ];
  final TextEditingController _referenceCtrl = TextEditingController();
  bool _reverseCharge = false;
  String _placeOfSupply = '33-Tamil Nadu';
  final TextEditingController _masterNarrationCtrl = TextEditingController();

  final List<JournalRow> _rows = [];

  final List<String> _accountOptions = [
    'OLD GOLD PURCHASE ACCOUNT',
    'RAMESH JEWELLERS (PARTY)',
    'MAKING CHARGES EXPENSE',
    'KUMAR ARTISAN LABOUR',
    'CASH ACCOUNT',
    'AXIS BANK ACCOUNT',
    'HDFC BANK ACCOUNT',
    'GOLD STOCK ACCOUNT',
    'SILVER STOCK ACCOUNT',
    'DISCOUNT ALLOWED',
    'ROUND OFF ACCOUNT',
  ];

  final List<String> _tradingOptions = [
    'GOLD ORNAMENTS',
    'SILVER ORNAMENTS',
    'DIAMOND JEWELLERY',
    'BULLION',
    'SERVICE / LABOUR',
    'GENERAL',
  ];

  final List<String> _metalOptions = [
    'GOLD 24K',
    'GOLD 22K',
    'GOLD 18K',
    'SILVER 999',
    'SILVER 925',
    'NONE',
  ];

  final List<String> _placeOptions = [
    '33-Tamil Nadu',
    '29-Karnataka',
    '32-Kerala',
    '27-Maharashtra',
    '36-Telangana',
    '07-Delhi',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _prefix = e['prefix'] ?? 'JV';
      _vouNoCtrl.text = e['vouNo'] ?? '1';
      _vouType = e['voucherType'] ?? e['vouType'] ?? 'General Journal';
      if (!_entryTypes.contains(_vouType)) _vouType = 'General Journal';
      _referenceCtrl.text = e['reference'] ?? '';
      _reverseCharge = e['reverseCharge'] ?? false;
      _placeOfSupply = e['placeOfSupply'] ?? '33-Tamil Nadu';
      _masterNarrationCtrl.text = e['narration'] ?? '';

      final rList = e['rows'] as List<dynamic>?;
      if (rList != null && rList.isNotEmpty) {
        for (var r in rList) {
          _rows.add(JournalRow(
            crDr: r['crDr'] ?? 'DR',
            accountName: r['account'] ?? '',
            tradingName: r['trading'] ?? '',
            metalName: r['metal'] ?? '',
            purity: r['purity'] ?? '',
            weight: (double.tryParse(r['weight']?.toString() ?? '') ?? (r['weight'] is num ? (r['weight'] as num).toDouble() : 0.0)).toStringAsFixed(3),
            amount: (double.tryParse(r['amount']?.toString() ?? '') ?? (r['amount'] is num ? (r['amount'] as num).toDouble() : 0.0)).toStringAsFixed(2),
            refNo: r['refNo'] ?? '',
            gstApplicable: r['gst'] ?? 'No',
            hsnCode: r['hsn'] ?? '',
            narration: r['narration'] ?? '',
          ));
        }
      }
    }

    if (_rows.isEmpty) {
      _addRow('DR');
      _addRow('CR');
    }
  }

  void _addRow([String defaultCrDr = 'DR']) {
    final row = JournalRow(crDr: defaultCrDr);
    row.amountCtrl.addListener(() => setState(() {}));
    row.weightCtrl.addListener(() => setState(() {}));
    setState(() {
      _rows.add(row);
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 rows (DR & CR) are required for a Journal Entry.')),
      );
      return;
    }
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  double _getTotalDr() {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.crDr == 'DR') sum += r.netAmount;
    }
    return sum;
  }

  double _getTotalCr() {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.crDr == 'CR') sum += r.netAmount;
    }
    return sum;
  }

  double _getTotalDrWt() {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.crDr == 'DR') sum += r.weight;
    }
    return sum;
  }

  double _getTotalCrWt() {
    double sum = 0.0;
    for (var r in _rows) {
      if (r.crDr == 'CR') sum += r.weight;
    }
    return sum;
  }

  @override
  void dispose() {
    _vouNoCtrl.dispose();
    _referenceCtrl.dispose();
    _masterNarrationCtrl.dispose();
    for (var r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    final drAmt = _getTotalDr();
    final crAmt = _getTotalCr();
    final diff = (drAmt - crAmt).abs();

    if (diff > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Total Debit and Total Credit amounts must match before saving!'),
        ),
      );
      return;
    }

    final String vouDateStr = DateFormat('dd/MM/yyyy').format(_vouDateVal);

    final String? existingDocId = widget.existingEntry?['docId'];

    final newEntry = {
      'docId': existingDocId,
      'prefix': _prefix,
      'vouNo': _vouNoCtrl.text.trim(),
      'voucherNo': '$_prefix / ${_vouNoCtrl.text.trim()}',
      'voucherDate': vouDateStr,
      'vouDate': '$vouDateStr ${DateFormat('EEE').format(_vouDateVal)}',
      'voucherType': _vouType,
      'vouType': _vouType,
      'reference': _referenceCtrl.text.trim(),
      'partyVouDate': vouDateStr,
      'reverseCharge': _reverseCharge,
      'placeOfSupply': _placeOfSupply,
      'accountName': _rows.isNotEmpty ? _rows.first.accountCtrl.text : '',
      'narration': _masterNarrationCtrl.text.trim(),
      'rows': _rows.map((r) => {
            'crDr': r.crDr,
            'account': r.accountCtrl.text,
            'trading': r.tradingCtrl.text,
            'metal': r.metalCtrl.text,
            'purity': r.purityCtrl.text,
            'weight': r.weight,
            'amount': r.amount,
            'refNo': r.refNoCtrl.text,
            'gst': r.gstApplicable,
            'hsn': r.hsnCodeCtrl.text,
            'narration': r.narrationCtrl.text,
          }).toList(),
      'totalDr': drAmt,
      'totalCr': crAmt,
      'totalDrWt': _getTotalDrWt(),
      'totalCrWt': _getTotalCrWt(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save to Firestore or Local Queue
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

    if (isOnline) {
      try {
        final firestoreData = Map<String, dynamic>.from(newEntry)..remove('docId');
        if (existingDocId != null) {
          FirebaseFirestore.instance.collection('journal_entries').doc(existingDocId).update(firestoreData);
        } else {
          final docRef = FirebaseFirestore.instance.collection('journal_entries').doc();
          newEntry['docId'] = docRef.id;
          docRef.set(firestoreData);
        }
      } catch (e) {
        debugPrint("Firebase update error: $e");
      }
    } else {
      if (!newEntry['vouNo'].toString().endsWith('-OFF')) {
        newEntry['vouNo'] = '${newEntry['vouNo']}-OFF';
        newEntry['voucherNo'] = '${newEntry['prefix']} / ${newEntry['vouNo']}';
      }
      await LocalDbService().insertEntry(
        'journal_entries',
        newEntry,
        operation: existingDocId != null ? 'UPDATE' : 'ADD',
        docId: existingDocId,
      );
      SyncService().syncNow();
      newEntry['docId'] = existingDocId ?? 'offline_dummy_id';
    }

    widget.onSave(newEntry);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double drAmt = _getTotalDr();
    final double crAmt = _getTotalCr();
    final double diff = drAmt - crAmt;
    final bool isBalanced = diff.abs() < 0.01;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Journal Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown)),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _brownLight),
                  )
                ],
              ),
            ),

            // ─── Master Form Controls ───
            IgnorePointer(
              ignoring: widget.isViewOnly,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  children: [
                  Row(
                    children: [
                      // Voucher No
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Voucher No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Container(
                              height: 26,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _prefix,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                                  onChanged: (v) => setState(() => _prefix = v!),
                                  items: const [
                                    DropdownMenuItem(value: 'JV', child: Text('JV')),
                                    DropdownMenuItem(value: 'MEMO', child: Text('MEMO')),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: SizedBox(
                                height: 26,
                                child: TextField(
                                  controller: _vouNoCtrl,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Date
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: InkWell(
                                onTap: null,
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd/MM/yyyy').format(_vouDateVal), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      const Icon(Icons.calendar_today, size: 14, color: _brownLight),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Entry Type
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Entry Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
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
                                    value: _entryTypes.contains(_vouType) ? _vouType : 'General Journal',
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    onChanged: (v) => setState(() => _vouType = v!),
                                    items: _entryTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Reference
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: SizedBox(
                                height: 26,
                                child: TextField(
                                  controller: _referenceCtrl,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Place of Supply
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Place of Supply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
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
                                    value: _placeOfSupply,
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    onChanged: (v) => setState(() => _placeOfSupply = v!),
                                    items: _placeOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Expanded(flex: 3, child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ),
            const Divider(height: 1, color: _border),

            // ─── Table Header & Controls Bar ───
            IgnorePointer(
              ignoring: widget.isViewOnly,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _headerBg,
              child: Row(
                children: [
                  const Text('Journal Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brown)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _addRow('DR'),
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: const Text('Add DR Row', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      minimumSize: const Size(100, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addRow('CR'),
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: const Text('Add CR Row', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size(100, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),

            // ─── Line Items Grid ───
            Expanded(
              child: IgnorePointer(
                ignoring: widget.isViewOnly,
                child: Container(
                  color: Colors.white,
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(60), // DR/CR
                      1: FlexColumnWidth(2.5), // Account
                      2: FlexColumnWidth(1.8), // Trading
                      3: FlexColumnWidth(1.5), // Metal
                      4: FlexColumnWidth(1.2), // Purity
                      5: FixedColumnWidth(80), // Weight
                      6: FixedColumnWidth(95), // Amount
                      7: FixedColumnWidth(80), // Ref No
                      8: FixedColumnWidth(60), // GST
                      9: FlexColumnWidth(2.0), // Narration
                      10: FixedColumnWidth(40), // Action
                    },
                    border: TableBorder.all(color: _border, width: 0.8),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: _btnBg),
                        children: [
                          _buildTh('Dr/Cr'),
                          _buildTh('Account Name'),
                          _buildTh('Trading Name'),
                          _buildTh('Metal Name'),
                          _buildTh('Purity'),
                          _buildTh('Weight (g)'),
                          _buildTh('Amount (₹)'),
                          _buildTh('Ref No'),
                          _buildTh('GST'),
                          _buildTh('Narration'),
                          _buildTh(''),
                        ],
                      ),
                      ..._rows.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;

                        return TableRow(
                          children: [
                            // DR/CR Dropdown
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: row.crDr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: row.crDr == 'DR' ? Colors.blue.shade800 : Colors.green.shade800,
                                    ),
                                    onChanged: (v) => setState(() => row.crDr = v!),
                                    items: const [
                                      DropdownMenuItem(value: 'DR', child: Text('DR')),
                                      DropdownMenuItem(value: 'CR', child: Text('CR')),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Account Name Dropdown / Text
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _accountOptions.contains(row.accountCtrl.text) ? row.accountCtrl.text : null,
                                    hint: const Text('Select Account', style: TextStyle(fontSize: 11)),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 11, color: Colors.black),
                                    onChanged: (v) => setState(() => row.accountCtrl.text = v ?? ''),
                                    items: _accountOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ),
                              ),
                            ),

                            // Trading Name
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _tradingOptions.contains(row.tradingCtrl.text) ? row.tradingCtrl.text : null,
                                    hint: const Text('Trading', style: TextStyle(fontSize: 11)),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 11, color: Colors.black),
                                    onChanged: (v) => setState(() => row.tradingCtrl.text = v ?? ''),
                                    items: _tradingOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ),
                              ),
                            ),

                            // Metal Name
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _metalOptions.contains(row.metalCtrl.text) ? row.metalCtrl.text : null,
                                    hint: const Text('Metal', style: TextStyle(fontSize: 11)),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 11, color: Colors.black),
                                    onChanged: (v) => setState(() => row.metalCtrl.text = v ?? ''),
                                    items: _metalOptions.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ),
                              ),
                            ),

                            // Purity (e.g. 22K, 24K, 916)
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: row.purityCtrl,
                                  style: const TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(bottom: 12),
                                    hintText: 'e.g. 22K',
                                    hintStyle: TextStyle(color: Colors.black38)
                                  ),
                                ),
                              ),
                            ),

                            // Weight
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: TextField(
                                  controller: row.weightCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),

                            // Amount
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: TextField(
                                  controller: row.amountCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),

                            // Ref No
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: TextField(
                                  controller: row.refNoCtrl,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),

                            // GST
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: row.gstApplicable,
                                    style: const TextStyle(fontSize: 11, color: Colors.black),
                                    onChanged: (v) => setState(() => row.gstApplicable = v!),
                                    items: const [
                                      DropdownMenuItem(value: 'No', child: Text('No')),
                                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Narration
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: TextField(
                                  controller: row.narrationCtrl,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),

                            // Delete button
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 16),
                                onPressed: () => _removeRow(idx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            ),

            // ─── Footer Controls & Status ───
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Master Narration
                      Expanded(
                        child: TextField(
                          controller: _masterNarrationCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Master Narration',
                            labelStyle: TextStyle(fontSize: 12, color: _brownLight),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Totals & Status Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isBalanced ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          border: Border.all(color: isBalanced ? Colors.green : Colors.red),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Debit: ₹${drAmt.toStringAsFixed(2)} | Wt: ${_getTotalDrWt().toStringAsFixed(3)}g',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                const SizedBox(height: 2),
                                Text('Total Credit: ₹${crAmt.toStringAsFixed(2)} | Wt: ${_getTotalCrWt().toStringAsFixed(3)}g',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isBalanced ? 'STATUS: BALANCED' : 'DIFF: ₹${diff.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                                Text(
                                  isBalanced ? ' Ready to Save' : ' Dr & Cr Must Match',
                                  style: TextStyle(fontSize: 10, color: isBalanced ? Colors.green.shade800 : Colors.red.shade800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              const SizedBox(height: 12),

                  // Buttons Bar (Image 1 style: Save, Print, Close)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!widget.isViewOnly) ...[
                        _buildBottomCardButton(Icons.save_outlined, 'Save', _handleSave),
                        const SizedBox(width: 12),
                      ],
                      _buildBottomCardButton(Icons.print_outlined, 'Print', _handlePrint),
                      const SizedBox(width: 12),
                      _buildBottomCardButton(Icons.exit_to_app, 'Close', () => Navigator.of(context).pop()),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  void _handlePrint() {
    final vouDateStr = DateFormat('dd/MM/yyyy').format(_vouDateVal);
    final rowList = _rows.map((r) => {
      'crDr': r.crDr,
      'account': r.accountCtrl.text,
      'trading': r.tradingCtrl.text,
      'metal': r.metalCtrl.text,
      'weight': r.weight,
      'amount': r.amount,
      'refNo': r.refNoCtrl.text,
      'gst': r.gstApplicable,
      'hsn': r.hsnCodeCtrl.text,
      'narration': r.narrationCtrl.text,
    }).toList();

    JournalVoucherPrintDialog.show(
      context,
      voucherNo: '$_prefix / ${_vouNoCtrl.text.trim()}',
      date: vouDateStr,
      voucherType: _vouType,
      bookName: '',
      reference: _referenceCtrl.text.trim(),
      placeOfSupply: _placeOfSupply,
      rows: rowList,
      totalDr: _getTotalDr(),
      totalCr: _getTotalCr(),
      totalDrWt: _getTotalDrWt(),
      totalCrWt: _getTotalCrWt(),
      masterNarration: _masterNarrationCtrl.text.trim(),
    );
  }

  Widget _buildBottomCardButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF7F3EB),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 70,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: _brown),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTh(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
      ),
    );
  }
}
