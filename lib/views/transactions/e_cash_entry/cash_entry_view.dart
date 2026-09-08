import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../../state/admin_state.dart';
import '../../../dialogs/cash_voucher_print_dialog.dart';
import '../../../dialogs/cheque_print_dialog.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

class CashVoucherRow {
  String crDr; // 'DR' or 'CR'
  TextEditingController accountNameCtrl;
  TextEditingController refNoCtrl;
  DateTime date;
  TextEditingController amountCtrl;
  TextEditingController tdsAmountCtrl;
  String gstApplicable; // 'No' or 'Yes'
  TextEditingController narrationCtrl;

  CashVoucherRow({
    this.crDr = 'DR',
    String accountName = '',
    String refNo = '',
    DateTime? date,
    String amount = '0.00',
    String tdsAmount = '0.00',
    this.gstApplicable = 'No',
    String narration = '',
  })  : accountNameCtrl = TextEditingController(text: accountName),
        refNoCtrl = TextEditingController(text: refNo),
        date = date ?? DateTime.now(),
        amountCtrl = TextEditingController(text: amount),
        tdsAmountCtrl = TextEditingController(text: tdsAmount),
        narrationCtrl = TextEditingController(text: narration);

  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0.0;
  double get tdsAmount => double.tryParse(tdsAmountCtrl.text.trim()) ?? 0.0;
  double get gstAmount => gstApplicable == 'Yes' ? amount * 0.03 : 0.0;
  double get netAmount => amount - tdsAmount + gstAmount;
}

class CashEntryView extends StatefulWidget {
  final AdminState state;

  const CashEntryView({super.key, required this.state});

  @override
  State<CashEntryView> createState() => _CashEntryViewState();
}

class _CashEntryViewState extends State<CashEntryView> {
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
            .collection('cash_entries')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('cash_entries')
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
      // Firestore not available; use local list
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    return _entries.where((entry) {
      if (_account != 'All' && entry['accountName'] != _account && entry['acName'] != _account) {
        return false;
      }
      if (_bookName != 'All' && entry['bookName'] != _bookName) {
        return false;
      }
      if (_vouType != 'All' && entry['voucherType'] != _vouType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
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
                          Expanded(child: _buildFilterRow('Vou.Type', _vouType, ['All', 'Payment', 'Receipt'], (val) => setState(() => _vouType = val!))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildFilterRow('Prefix', _prefix, ['All'], (val) => setState(() => _prefix = val!))),
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
                      _buildActionButton(Icons.flash_on, 'Quick\nEntry', onTap: () => _openCashEntryWindow()),
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () => _openPrintVoucher()),
                      _buildActionButton(Icons.receipt_long, 'Cheque\nPrint', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final double amtVal = double.tryParse(entry['amount']?.toString() ?? '') ??
                              (entry['amount'] is num ? (entry['amount'] as num).toDouble() : 0.0);
                          ChequePrintDialog.show(
                            context,
                            payee: entry['accountName']?.toString() ?? entry['acName']?.toString() ?? 'WALK-IN',
                            amount: amtVal,
                            date: entry['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          );
                        }
                      }),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openCashEntryWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openCashEntryWindow(initialData: _entries[_selectedIndex!]);
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
                                  FirebaseFirestore.instance.collection('cash_entries').doc(docId).delete();
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
                          _openCashEntryWindow(initialData: _entries[_selectedIndex!], isViewOnly: true);
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
                        Expanded(flex: 2, child: Text('Total Voucher\nAmt.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Book Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Ref No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Memo\nVoucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Narration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No cash entries found.\nTap Quick Entry or Add to create one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final isSelected = _selectedIndex == index;
                        return InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          onDoubleTap: () => _openCashEntryWindow(initialData: entry, isViewOnly: true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFDF6ED) : Colors.transparent,
                              border: const Border(bottom: BorderSide(color: _border)),
                            ),
                            child: Row(
                              children: [
                                _buildRowCell(entry['voucherNo']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['voucherDate']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['accountName']?.toString() ?? entry['acName']?.toString() ?? '', flex: 3),
                                _buildRowCell(entry['voucherType']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['amount']?.toString() ?? entry['totalAmount']?.toString() ?? '0.00', flex: 2),
                                _buildRowCell(entry['bookName']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['reference']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['refNo']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['date']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['memoVoucher']?.toString() ?? '', flex: 2),
                                _buildRowCell(entry['narration']?.toString() ?? '', flex: 2),
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
                          child: Text('${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
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

   void _openCashEntryWindow({Map<String, dynamic>? initialData, bool isViewOnly = false}) async {
    String nextVoucherSuffix = '1';
    if (initialData == null) {
      int maxSuffix = 0;
      for (var entry in _entries) {
        final vn = entry['voucherNo']?.toString() ?? '';
        if (vn.startsWith('C-')) {
          final suffixStr = vn.substring(2).replaceAll('-OFF', '');
          final suffixInt = int.tryParse(suffixStr);
          if (suffixInt != null && suffixInt > maxSuffix) {
            maxSuffix = suffixInt;
          }
        }
      }
      nextVoucherSuffix = (maxSuffix + 1).toString();
    }

    final dynamic newEntry = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CashEntryFormWindowDialog(
        initialData: initialData, 
        isViewOnly: isViewOnly,
        nextVoucherSuffix: nextVoucherSuffix,
      ),
    );
    if (newEntry != null && newEntry is Map<String, dynamic>) {
      setState(() {
        if (initialData != null) {
          final index = _entries.indexOf(initialData);
          if (index != -1) {
            _entries[index] = {...newEntry, 'docId': initialData['docId']};
          }
        } else {
          _entries.insert(0, newEntry);
        }
      });
    }
  }

  void _openPrintVoucher([Map<String, dynamic>? data]) {
    final entry = data ?? (_selectedIndex != null && _selectedIndex! < _entries.length ? _entries[_selectedIndex!] : null);
    CashVoucherPrintDialog.show(
      context,
      voucherNo: entry?['voucherNo']?.toString() ?? 'C / 1',
      date: entry?['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
      accountName: entry?['accountName']?.toString() ?? entry?['acName']?.toString() ?? 'ELECTRICITY BILL',
      amount: (entry?['amount'] as double?) ?? double.tryParse(entry?['amount']?.toString() ?? '') ?? 4700.00,
      narration: entry?['narration']?.toString() ?? 'ADMIN EXPENSE',
      voucherType: entry?['voucherType']?.toString() ?? 'Cash Payment',
      placeOfSupply: entry?['placeOfSupply']?.toString() ?? 'Gujarat',
    );
  }

  Widget _buildFilterRow(String label, String value, List<String> items, ValueChanged<String?> onChanged, {bool isPrimary = false}) {
    final List<String> dropdownItems = items.contains(value) ? items : [value, ...items];
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
                value: value,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal),
                onChanged: onChanged,
                items: dropdownItems.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
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

  Widget _buildRowCell(String text, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ),
    );
  }
}

class _CashEntryFormWindowDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isViewOnly;
  final String? nextVoucherSuffix;
  const _CashEntryFormWindowDialog({this.initialData, this.isViewOnly = false, this.nextVoucherSuffix});

  @override
  State<_CashEntryFormWindowDialog> createState() => _CashEntryFormWindowDialogState();
}

class _CashEntryFormWindowDialogState extends State<_CashEntryFormWindowDialog> {
  String? _editingDocId;
  String _voucherPrefix = 'C';
  final TextEditingController _voucherSuffixCtrl = TextEditingController(text: '1');
  DateTime _voucherDate = DateTime.now();
  final TextEditingController _referenceCtrl = TextEditingController();

  String _voucherType = 'Payment';
  String _formBookName = '';
  List<String> _bookNames = [];
  bool _reverseChargeApply = false;
  String _placeOfSupply = 'Tamil Nadu';

  final TextEditingController _formNarrationCtrl = TextEditingController();
  final List<CashVoucherRow> _formRows = [];

  List<Map<String, dynamic>> _partiesList = [];
  final Map<String, List<Map<String, dynamic>>> _partyBillsDetails = {};
  final Map<String, Map<String, dynamic>> _billDetailsMap = {};

  @override
  void initState() {
    super.initState();
    _initData();
    _fetchBookNames();
    _loadParties();
  }

  String _standardizeState(String? st) {
    if (st == null || st.trim().isEmpty) return 'Tamil Nadu';
    final lower = st.toLowerCase().trim();
    if (lower.contains('kerala')) return 'Kerala';
    if (lower.contains('karnataka')) return 'Karnataka';
    if (lower.contains('andhra')) return 'Andhra Pradesh';
    return 'Tamil Nadu';
  }

  Future<void> _loadParties() async {
    try {
      final custSnap = await FirebaseFirestore.instance.collection('customers').get();
      final suppSnap = await FirebaseFirestore.instance.collection('suppliers').get();

      final List<Map<String, dynamic>> combined = [];

      for (var d in custSnap.docs) {
        final data = d.data();
        data['docId'] = d.id;
        data['partyType'] = 'Customer';
        final name = (data['name'] ?? data['companyName'] ?? '').toString().trim();
        data['name'] = name;
        data['displayName'] = name.isNotEmpty ? '$name (Customer)' : '';
        if (name.isNotEmpty) combined.add(data);
      }

      for (var d in suppSnap.docs) {
        final data = d.data();
        data['docId'] = d.id;
        data['partyType'] = 'Supplier';
        final name = (data['companyName'] ?? data['name'] ?? '').toString().trim();
        data['name'] = name;
        data['displayName'] = name.isNotEmpty ? '$name (Supplier)' : '';
        if (name.isNotEmpty) combined.add(data);
      }

      if (mounted) {
        setState(() {
          _partiesList = combined;
        });
      }
    } catch (e) {
      debugPrint("Error loading parties: $e");
    }
  }

  Future<void> _loadPendingBillsForParty(String partyName) async {
    if (partyName.trim().isEmpty) return;
    try {
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final List<Map<String, dynamic>> partyBills = [];

      for (var doc in billsSnap.docs) {
        final d = doc.data();
        final docId = doc.id;
        final ac = (d['acName'] ??
                d['accountName'] ??
                (d['customerDetails'] as Map?)?['name'] ??
                (d['supplierDetails'] as Map?)?['name'] ??
                '')
            .toString()
            .trim();

        if (ac.toLowerCase() == partyName.toLowerCase()) {
          final billNo = (d['voucherNo'] ?? d['billNo'] ?? d['invoiceNo'] ?? docId)
              .toString()
              .replaceAll('/', '-');

          final double totalAmt = double.tryParse(d['voucherAmt']?.toString() ?? d['grandTotal']?.toString() ?? d['amount']?.toString() ?? '') ?? 0.0;
          final double paidAmt = double.tryParse(d['paidAmount']?.toString() ?? '') ??
              (double.tryParse(d['cashAmt']?.toString() ?? '0') ?? 0.0) +
              (double.tryParse(d['bankAmt']?.toString() ?? '0') ?? 0.0) +
              (double.tryParse(d['cardAmt']?.toString() ?? '0') ?? 0.0);
          final double dueAmt = double.tryParse(d['dueAmount']?.toString() ?? '') ?? (totalAmt - paidAmt);

          final billType = d['billType']?.toString() ?? d['voucherType']?.toString() ?? '';

          final detail = {
            'docId': docId,
            'billNo': billNo,
            'partyName': ac,
            'totalAmt': totalAmt,
            'paidAmt': paidAmt,
            'dueAmt': dueAmt > 0 ? dueAmt : 0.0,
            'billType': billType,
          };

          _billDetailsMap[billNo] = detail;
          partyBills.add(detail);
        }
      }

      if (mounted) {
        setState(() {
          _partyBillsDetails[partyName] = partyBills;
        });
      }
    } catch (e) {
      debugPrint("Error loading bills for $partyName: $e");
    }
  }

  Future<void> _fetchBookNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final list = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _bookNames = list;
          if (_bookNames.isNotEmpty) {
            if (_formBookName.isEmpty || !_bookNames.contains(_formBookName)) {
              _formBookName = _bookNames.first;
            }
          }
        });
      }
    } catch (_) {}
  }

  void _initData() {
    final data = widget.initialData;
    if (data != null) {
      _editingDocId = data['docId'];
      final vNo = data['voucherNo']?.toString() ?? 'C-1';
      if (vNo.contains('-')) {
        final parts = vNo.split('-');
        _voucherPrefix = parts.first;
        _voucherSuffixCtrl.text = parts.last;
      } else {
        _voucherSuffixCtrl.text = vNo;
      }
      DateTime parsedVouDate = DateTime.now();
      final rawVouDate = data['voucherDate'];
      if (rawVouDate is DateTime) {
        parsedVouDate = rawVouDate;
      } else if (rawVouDate is Timestamp) {
        parsedVouDate = rawVouDate.toDate();
      } else if (rawVouDate != null) {
        final str = rawVouDate.toString();
        try {
          parsedVouDate = DateFormat('dd/MM/yyyy EEE').parse(str);
        } catch (_) {
          try {
            parsedVouDate = DateFormat('dd/MM/yyyy').parse(str.split(' ').first);
          } catch (_) {}
        }
      }
      _voucherDate = parsedVouDate;
      _referenceCtrl.text = data['reference']?.toString() ?? '';
      _voucherType = data['voucherType']?.toString().contains('Receipt') == true ? 'Receipt' : 'Payment';
      _formBookName = data['bookName']?.toString() ?? '';
      _formNarrationCtrl.text = data['narration']?.toString() ?? '';
      _reverseChargeApply = data['isReverseCharge'] == true || data['reverseCharge'] == true;

      final double amtVal = double.tryParse(data['amount']?.toString() ?? '') ??
          (data['amount'] is num ? (data['amount'] as num).toDouble() : 0.0);

      _formRows.clear();
      _formRows.add(CashVoucherRow(
        crDr: 'DR',
        accountName: data['acName']?.toString() ?? '',
        date: _voucherDate,
        amount: amtVal.toStringAsFixed(2),
        narration: data['narration']?.toString() ?? '',
      ));
    } else {
      _editingDocId = null;
      _voucherPrefix = 'C';
      _voucherSuffixCtrl.text = widget.nextVoucherSuffix ?? '1';
      _voucherDate = DateTime.now();
      _referenceCtrl.clear();
      _voucherType = 'Payment';
      _formBookName = '';
      _reverseChargeApply = false;
      _placeOfSupply = 'Tamil Nadu';
      _formNarrationCtrl.clear();

      _formRows.clear();
      _formRows.add(CashVoucherRow(
        crDr: 'DR',
        accountName: '',
        date: _voucherDate,
        amount: '0.00',
      ));
    }
  }

  void _addFormRow() {
    setState(() {
      _formRows.add(CashVoucherRow(
        crDr: 'DR',
        date: _voucherDate,
      ));
    });
  }

  void _removeFormRow(int index) {
    if (_formRows.length <= 1) return;
    setState(() {
      _formRows.removeAt(index);
    });
  }

  double get _totalCr {
    double sum = 0.0;
    for (final r in _formRows) {
      if (r.crDr == 'CR') sum += r.netAmount;
    }
    return sum;
  }

  double get _totalDr {
    double sum = 0.0;
    for (final r in _formRows) {
      if (r.crDr == 'DR') sum += r.netAmount;
    }
    return sum;
  }

  String get _balanceStr {
    final diff = _totalDr - _totalCr;
    if (diff > 0) return '${diff.toStringAsFixed(2)} Dr.';
    if (diff < 0) return '${(-diff).toStringAsFixed(2)} Cr.';
    return '0.00 Cr.';
  }

  Future<void> _saveVoucher() async {
    try {
      final String fullVoucherNo = '$_voucherPrefix-${_voucherSuffixCtrl.text.trim()}';
      final String activeVoucherType = _totalDr >= _totalCr ? 'Payment' : 'Receipt';
      final double primaryAmt = activeVoucherType == 'Payment' ? (_totalDr - _totalCr) : (_totalCr - _totalDr);
      final String mainParty = _formRows.isNotEmpty ? _formRows.first.accountNameCtrl.text.trim() : 'Party Account';

      double totalTaxable = 0.0;
      double totalCgst = 0.0;
      double totalSgst = 0.0;
      double totalIgst = 0.0;

      for (var r in _formRows) {
        if (r.gstApplicable == 'Yes') {
          totalTaxable += r.amount;
          if (_placeOfSupply == 'Tamil Nadu') {
            totalCgst += r.amount * 0.015;
            totalSgst += r.amount * 0.015;
          } else {
            totalIgst += r.amount * 0.03;
          }
        }
      }

      final List<Map<String, dynamic>> rowData = _formRows.map((r) => {
        'crDr': r.crDr,
        'acName': r.accountNameCtrl.text.trim(),
        'mode': 'Cash',
        'refNo': r.refNoCtrl.text.trim(),
        'amount': r.amount,
        'tdsAmount': r.tdsAmount,
        'gstApplicable': r.gstApplicable,
        'narration': r.narrationCtrl.text.trim(),
      }).toList();

      final entryData = {
        'docId': _editingDocId,
        'voucherNo': fullVoucherNo,
        'voucherDate': DateFormat('dd/MM/yyyy EEE').format(_voucherDate),
        'acName': mainParty,
        'accountName': mainParty,
        'bookName': _formBookName,
        'voucherType': 'Cash $activeVoucherType',
        'amount': primaryAmt,
        'totalAmount': primaryAmt.toStringAsFixed(2),
        'taxableAmt': totalTaxable,
        'reference': _referenceCtrl.text.trim(),
        'refNo': _formRows.isNotEmpty ? _formRows.first.refNoCtrl.text.trim() : '',
        'narration': _formNarrationCtrl.text.trim(),
        'isReverseCharge': _reverseChargeApply,
        'reverseCharge': _reverseChargeApply,
        'reverseChargeAmt': totalCgst + totalSgst + totalIgst,
        'cgstAmt': totalCgst,
        'sgstAmt': totalSgst,
        'igstAmt': totalIgst,
        'placeOfSupply': _placeOfSupply,
        'rows': rowData,
      };

      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        // Update target Bill & Party Master balances
        for (var r in _formRows) {
          final ref = r.refNoCtrl.text.trim();
          final partyName = r.accountNameCtrl.text.trim();
          final rowAmt = r.netAmount;

          if (ref.isNotEmpty && _billDetailsMap.containsKey(ref)) {
            final billInfo = _billDetailsMap[ref]!;
            final docId = billInfo['docId']?.toString();
            if (docId != null && docId.isNotEmpty) {
              try {
                final double currentPaid = (billInfo['paidAmt'] as double? ?? 0.0);
                final double currentTotal = (billInfo['totalAmt'] as double? ?? 0.0);
                final double newPaid = currentPaid + rowAmt;
                final double newDue = (currentTotal - newPaid).clamp(0.0, double.infinity);
                final String newStatus = newDue <= 0 ? 'PAID' : 'PARTIAL';

                FirebaseFirestore.instance.collection('bills').doc(docId).update({
                  'paidAmount': newPaid,
                  'dueAmount': newDue,
                  'status': newStatus,
                  'lastPaymentDate': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                debugPrint("Error updating bill $docId balance: $e");
              }
            }
          }

          if (partyName.isNotEmpty) {
            try {
              final custSnap = await FirebaseFirestore.instance
                  .collection('customers')
                  .where('name', isEqualTo: partyName)
                  .get();

              if (custSnap.docs.isNotEmpty) {
                final doc = custSnap.docs.first;
                final currentBal = double.tryParse(doc.data()['dueAmount']?.toString() ?? doc.data()['pendingBalance']?.toString() ?? '0') ?? 0.0;
                final newBal = r.crDr == 'DR'
                    ? currentBal + rowAmt
                    : (currentBal - rowAmt).clamp(0.0, double.infinity);
                FirebaseFirestore.instance.collection('customers').doc(doc.id).update({
                  'dueAmount': newBal,
                  'pendingBalance': newBal,
                });
              } else {
                final suppSnap = await FirebaseFirestore.instance
                    .collection('suppliers')
                    .where('companyName', isEqualTo: partyName)
                    .get();

                if (suppSnap.docs.isNotEmpty) {
                  final doc = suppSnap.docs.first;
                  final currentBal = double.tryParse(doc.data()['dueAmount']?.toString() ?? doc.data()['pendingBalance']?.toString() ?? '0') ?? 0.0;
                  final newBal = r.crDr == 'CR'
                      ? currentBal + rowAmt
                      : (currentBal - rowAmt).clamp(0.0, double.infinity);
                  FirebaseFirestore.instance.collection('suppliers').doc(doc.id).update({
                    'dueAmount': newBal,
                    'pendingBalance': newBal,
                  });
                }
              }
            } catch (e) {
              debugPrint("Error updating party master balance: $e");
            }
          }
        }

        try {
          if (_editingDocId != null) {
            FirebaseFirestore.instance.collection('cash_entries').doc(_editingDocId).update(entryData);
          } else {
            final docRef = FirebaseFirestore.instance.collection('cash_entries').doc();
            entryData['docId'] = docRef.id;
            final firestoreData = Map<String, dynamic>.from(entryData)
              ..['createdAt'] = FieldValue.serverTimestamp();
            docRef.set(firestoreData);
          }
        } catch (e) {
          debugPrint("Firebase update error: $e");
        }
      } else {
        if (!fullVoucherNo.endsWith('-OFF')) {
          entryData['voucherNo'] = '$fullVoucherNo-OFF';
        }
        await LocalDbService().insertEntry(
          'cash_entries',
          entryData,
          operation: _editingDocId != null ? 'UPDATE' : 'ADD',
          docId: _editingDocId,
        );
        SyncService().syncNow();
        entryData['docId'] = _editingDocId ?? 'offline_dummy_id';
      }

      if (mounted) {
        Navigator.pop(context, entryData);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Save Error: $e\n$stackTrace');
    }
  }

  Widget _buildRightSideBillPanel() {
    double totalDr = 0.0;
    double totalCr = 0.0;
    double totalTds = 0.0;
    double totalTaxable = 0.0;
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalIgst = 0.0;

    for (var r in _formRows) {
      if (r.crDr == 'DR') totalDr += r.netAmount;
      if (r.crDr == 'CR') totalCr += r.netAmount;
      totalTds += r.tdsAmount;

      if (r.gstApplicable == 'Yes') {
        totalTaxable += r.amount;
        if (_placeOfSupply == 'Tamil Nadu') {
          totalCgst += r.amount * 0.015;
          totalSgst += r.amount * 0.015;
        } else {
          totalIgst += r.amount * 0.03;
        }
      }
    }

    final double netPayable = totalDr - totalCr;

    Map<String, dynamic>? selectedBillInfo;
    for (var r in _formRows) {
      final ref = r.refNoCtrl.text.trim();
      if (ref.isNotEmpty && _billDetailsMap.containsKey(ref)) {
        selectedBillInfo = _billDetailsMap[ref];
        break;
      }
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.only(left: 8, top: 12, bottom: 12, right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: _brown, size: 18),
              SizedBox(width: 6),
              Text(
                'Bill Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brown),
              ),
            ],
          ),
          const Divider(height: 16, color: _border),
          _buildBillRow('Total Dr Amount', '₹ ${totalDr.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildBillRow('Total Cr Amount', '₹ ${totalCr.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildBillRow('TDS Amount', '₹ ${totalTds.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildBillRow('Taxable Amount', '₹ ${totalTaxable.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          if (_placeOfSupply == 'Tamil Nadu') ...[
            _buildBillRow('CGST (1.5%)', '₹ ${totalCgst.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            _buildBillRow('SGST (1.5%)', '₹ ${totalSgst.toStringAsFixed(2)}'),
          ] else ...[
            _buildBillRow('IGST (3.0%)', '₹ ${totalIgst.toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _reverseChargeApply ? Colors.amber.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _reverseChargeApply ? Colors.amber.shade700 : Colors.grey.shade400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RCM Applicable:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                Text(_reverseChargeApply ? 'YES' : 'NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _reverseChargeApply ? Colors.deepOrange.shade800 : Colors.grey.shade700)),
              ],
            ),
          ),
          if (selectedBillInfo != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_added, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Ref: ${selectedBillInfo['billNo']}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildBillRow('Original Amt', '₹ ${(selectedBillInfo['totalAmt'] as double).toStringAsFixed(2)}'),
                  const SizedBox(height: 2),
                  _buildBillRow('Paid So Far', '₹ ${(selectedBillInfo['paidAmt'] as double).toStringAsFixed(2)}'),
                  const SizedBox(height: 2),
                  _buildBillRow('Current Due', '₹ ${(selectedBillInfo['dueAmt'] as double).toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  const Divider(height: 6, color: _border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('After Pay Due:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brown)),
                      Text(
                        '₹ ${((selectedBillInfo['dueAmt'] as double) - totalDr).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          const Divider(height: 16, color: _border),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _brown,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                const Text('NET PAYABLE AMOUNT', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '₹ ${netPayable.abs().toStringAsFixed(2)} ${netPayable >= 0 ? 'Dr' : 'Cr'}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _brownLight)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildAccountNameAutocompleteCell(CashVoucherRow row, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 26,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (option) => option['name']?.toString() ?? '',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (_partiesList.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
            final q = textEditingValue.text.toLowerCase().trim();
            if (q.isEmpty) return _partiesList.take(20);
            return _partiesList.where((party) {
              final name = (party['name'] ?? party['companyName'] ?? '').toString().toLowerCase();
              return name.contains(q);
            });
          },
          onSelected: (Map<String, dynamic> selection) {
            setState(() {
              final name = selection['name']?.toString() ?? '';
              row.accountNameCtrl.text = name;
              final st = (selection['state'] ?? selection['placeOfSupply'] ?? '').toString();
              if (st.isNotEmpty) {
                _placeOfSupply = _standardizeState(st);
              }
              _loadPendingBillsForParty(name);
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text != row.accountNameCtrl.text && row.accountNameCtrl.text.isNotEmpty) {
              controller.text = row.accountNameCtrl.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                row.accountNameCtrl.text = val;
                if (val.isNotEmpty) _loadPendingBillsForParty(val);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRefNoDropdownCell(CashVoucherRow row, int flex) {
    final partyName = row.accountNameCtrl.text.trim();
    final allBills = _partyBillsDetails[partyName] ?? [];

    String partyType = 'Customer';
    final matchedParty = _partiesList.firstWhere(
      (p) => (p['name'] ?? p['companyName'] ?? '').toString().trim().toLowerCase() == partyName.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (matchedParty.isNotEmpty) {
      partyType = matchedParty['partyType']?.toString() ?? 'Customer';
    }

    final filteredBills = allBills.where((b) {
      final bType = (b['billType'] as String? ?? '').toLowerCase();
      final bNo = (b['billNo'] as String? ?? '').toLowerCase();
      final due = (b['dueAmt'] as double? ?? 0.0);
      if (due <= 0) return false;

      final isSalesBill = bType.contains('sale') || bType.contains('invoice') || bNo.startsWith('sl') || bNo.startsWith('s-');
      final isPurchaseBill = bType.contains('purchase') || bNo.startsWith('pur') || bNo.startsWith('p-');

      if (partyType == 'Customer') {
        if (row.crDr == 'CR') {
          // CR for Customer = Payment Received -> Show Sales Bills
          return isSalesBill || (!isPurchaseBill && !bType.contains('credit'));
        } else {
          // DR for Customer = Refund / Debit Note -> Show non-sales
          return !isSalesBill;
        }
      } else {
        // Supplier
        if (row.crDr == 'DR') {
          // DR for Supplier = Payment Made -> Show Purchase Bills
          return isPurchaseBill || (!isSalesBill && !bType.contains('debit'));
        } else {
          // CR for Supplier = Credit Note -> Show non-purchase
          return !isPurchaseBill;
        }
      }
    }).toList();

    final List<String> items = ['', ...filteredBills.map((b) => b['billNo'].toString())];

    return Expanded(
      flex: flex,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(row.refNoCtrl.text) ? row.refNoCtrl.text : '',
            isDense: true,
            style: const TextStyle(fontSize: 11, color: _brown),
            items: items.map((b) => DropdownMenuItem(value: b, child: Text(b.isEmpty ? 'Select Bill' : b))).toList(),
            onChanged: (v) {
              setState(() {
                row.refNoCtrl.text = v ?? '';
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('dd/MM/yyyy EEE').format(_voucherDate);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: screenWidth * 0.95,
        height: screenHeight * 0.9,
        child: Column(
          children: [
            // ── Clean Title Header ───────────────────────────────────────────
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
                  Text(
                    _editingDocId != null ? 'Edit Cash Entry' : 'Cash Entry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _brownLight),
                  ),
                ],
              ),
            ),

            // ── Main Dialog Content Split (Left: Form & Table Grid | Right: Bill Summary Panel) ─────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side (Form & Table)
                  Expanded(
                    child: Column(
                      children: [
                        // Top Form Fields Card
                        IgnorePointer(
                          ignoring: widget.isViewOnly,
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                // Row 1: Voucher No / Vou. Date / Reference
                                Row(
                                  children: [
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
                                                value: ['B', 'C', 'CS', 'CP', 'CE'].contains(_voucherPrefix) ? _voucherPrefix : 'C',
                                                dropdownColor: Colors.white,
                                                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                                                style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                                                onChanged: null,
                                                items: ['B', 'C', 'CS', 'CP', 'CE'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.black)))).toList(),
                                              ),
                                            ),
                                          ),
                                          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('/', style: TextStyle(color: _brownLight))),
                                          SizedBox(width: 50, height: 26, child: _buildTextField(_voucherSuffixCtrl, readOnly: true)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 70, child: Text('Vou. Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                                          Expanded(
                                            child: Container(
                                              height: 26,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                                              alignment: Alignment.centerLeft,
                                              child: Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 80, child: Text('Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                                          Expanded(child: SizedBox(height: 26, child: _buildTextField(_referenceCtrl))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),



                                // Row 3: Reverse Charge Apply / Place Of Supply
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _reverseChargeApply,
                                        onChanged: (v) => setState(() => _reverseChargeApply = v ?? false),
                                        activeColor: _brown,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('Reverse Charge Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                                    const SizedBox(width: 32),
                                    const Text('Place Of Supply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 200,
                                      child: _buildDropdown(_placeOfSupply, ['Tamil Nadu', 'Kerala', 'Karnataka', 'Andhra Pradesh'], (v) => setState(() => _placeOfSupply = v!)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Middle Data Grid Table
                        Expanded(
                          child: IgnorePointer(
                            ignoring: widget.isViewOnly,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBEBEB),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Grid Headers (Date column removed)
                                  Container(
                                    color: const Color(0xFFE0E0E0),
                                    child: Row(
                                      children: [
                                        _buildGridHeader('Cr/Dr', 1),
                                        _buildGridHeader('Account Name (Search / Text)', 6),
                                        _buildGridHeader('Ref. No.', 2),
                                        _buildGridHeader('Amount', 2),
                                        _buildGridHeader('TDS Amount', 2),
                                        _buildGridHeader('Net Amount', 2),
                                        _buildGridHeader('GST Applicable?', 2),
                                        _buildGridHeader('Narration', 3),
                                        _buildGridHeader('', 1, isLast: true),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, color: Colors.grey, thickness: 1),

                                  // Grid Rows Body
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _formRows.length,
                                    itemBuilder: (ctx, idx) {
                                      final row = _formRows[idx];
                                      return Container(
                                        color: const Color(0xFFF5F5F5),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                _buildGridDropdownCell(row.crDr, ['CR', 'DR'], (v) => setState(() {
                                                  row.crDr = v!;
                                                  row.refNoCtrl.clear();
                                                }), 1),
                                                _buildAccountNameAutocompleteCell(row, 6),
                                                _buildRefNoDropdownCell(row, 2),
                                                _buildGridTextFieldCell(row.amountCtrl, 2, onChanged: (_) => setState(() {})),
                                                _buildGridTextFieldCell(row.tdsAmountCtrl, 2, onChanged: (_) => setState(() {})),
                                                _buildGridCell('₹ ${row.netAmount.toStringAsFixed(2)}', 2),
                                                _buildGridDropdownCell(row.gstApplicable, ['Yes', 'No'], (v) => setState(() => row.gstApplicable = v!), 2),
                                                _buildGridTextFieldCell(row.narrationCtrl, 3),
                                                Expanded(
                                                  flex: 1,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () => _removeFormRow(idx),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 1, color: Colors.grey, thickness: 1),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                                  Expanded(
                                    child: InkWell(
                                      onTap: _addFormRow,
                                      child: Container(color: const Color(0xFFEBEBEB)),
                                    ),
                                  ),

                                  // Grid Footer Calculations Bar (Ctrl+Del & Memo Voucher removed)
                                  const Divider(height: 1, color: _border, thickness: 1),
                                  Container(
                                    color: _headerBg,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      children: [
                                        const Text('Total Cr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)),
                                        const SizedBox(width: 6),
                                        _buildSummaryBox(_totalCr.toStringAsFixed(2)),
                                        const SizedBox(width: 12),
                                        const Text('Total Dr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)),
                                        const SizedBox(width: 6),
                                        _buildSummaryBox(_totalDr.toStringAsFixed(2)),
                                        const SizedBox(width: 12),
                                        const Text('Balance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)),
                                        const SizedBox(width: 6),
                                        _buildSummaryBox(_balanceStr),
                                        const SizedBox(width: 12),
                                        const Text('Cur. Book Bal.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)),
                                        const SizedBox(width: 6),
                                        _buildSummaryBox('0.00 Dr.'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Side Bill Breakdown Panel
                  _buildRightSideBillPanel(),
                ],
              ),
            ),

            // ── Sticky Bottom Footer (Narration & Save / Print Action Buttons, Close Button Removed) ────────────
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF3F0EB),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Narration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: IgnorePointer(
                        ignoring: widget.isViewOnly,
                        child: TextField(
                          controller: _formNarrationCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Row(
                    children: [
                      if (!widget.isViewOnly) ...[
                        _buildBeigeFooterButton('Save', Icons.save_rounded, _saveVoucher),
                        const SizedBox(width: 8),
                      ],
                      _buildBeigeFooterButton('Print', Icons.print_outlined, () {
                        final String fullVoucherNo = '$_voucherPrefix/${_voucherSuffixCtrl.text.trim()}';
                        final String activeVoucherType = _totalDr >= _totalCr ? 'Payment' : 'Receipt';
                        final double primaryAmt = activeVoucherType == 'Payment' ? (_totalDr - _totalCr) : (_totalCr - _totalDr);
                        final String mainParty = _formRows.isNotEmpty ? _formRows.first.accountNameCtrl.text.trim() : 'Party Account';
                        CashVoucherPrintDialog.show(
                          context,
                          voucherNo: fullVoucherNo,
                          date: DateFormat('dd/MM/yyyy').format(_voucherDate),
                          accountName: mainParty,
                          amount: primaryAmt > 0 ? primaryAmt : 0.0,
                          narration: _formNarrationCtrl.text.trim(),
                          voucherType: 'Cash $activeVoucherType',
                          placeOfSupply: _placeOfSupply,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    final List<String> effectiveItems = items.isNotEmpty ? List<String>.from(items) : ['Select Book'];
    final String effectiveValue = effectiveItems.contains(value) ? value : effectiveItems.first;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: _brown),
          items: effectiveItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGridHeader(String title, int flex, {bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
        ),
      ),
    );
  }

  Widget _buildGridCell(String text, int flex, {VoidCallback? onTap, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildGridDropdownCell(String value, List<String> items, ValueChanged<String?> onChanged, int flex, {bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
            style: const TextStyle(fontSize: 11, color: _brown),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildGridTextFieldCell(TextEditingController controller, int flex, {bool isLast = false, ValueChanged<String>? onChanged}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: isLast ? null : Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
    );
  }

  Widget _buildBeigeFooterButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 58,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF7EFE5),
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _brown),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _brown),
            ),
          ],
        ),
      ),
    );
  }
}
