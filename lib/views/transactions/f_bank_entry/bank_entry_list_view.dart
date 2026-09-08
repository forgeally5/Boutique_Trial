import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/local_db_service.dart';
import '../../../state/admin_state.dart';
import '../../../dialogs/cash_voucher_print_dialog.dart';
import '../../../dialogs/cheque_print_dialog.dart';
import 'bank_voucher_entry_dialog.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

class BankEntryListView extends StatefulWidget {
  final AdminState state;

  const BankEntryListView({super.key, required this.state});

  @override
  State<BankEntryListView> createState() => _BankEntryListViewState();
}

class _BankEntryListViewState extends State<BankEntryListView> {
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
            .collection('bank_entries')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('bank_entries')
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

  void _openBankEntryWindow({Map<String, dynamic>? entry, bool isViewOnly = false}) async {
    final dynamic result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BankVoucherEntryDialog(initialData: entry, isViewOnly: isViewOnly),
    );
    if (result != null && result is Map<String, dynamic>) {
      if (entry != null) {
        // Edit/Modify existing entry
        final docId = entry['docId']?.toString();
        setState(() {
          final index = _entries.indexOf(entry);
          if (index != -1) {
            _entries[index] = {...result, 'docId': docId};
          }
        });
      } else {
        // Create new entry
        setState(() {
          _entries.add(result);
        });
      }
    }
  }

  void _openPrintVoucher([Map<String, dynamic>? data]) {
    final entry = data ?? (_selectedIndex != null && _selectedIndex! < _entries.length ? _entries[_selectedIndex!] : null);
    CashVoucherPrintDialog.show(
      context,
      voucherNo: entry?['voucherNo']?.toString() ?? 'B / 1',
      date: entry?['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
      accountName: entry?['accountName']?.toString() ?? entry?['acName']?.toString() ?? 'KAMLESHJI',
      address: entry?['address']?.toString() ?? 'ARJUN TOWER, 4TH FLOOR ABOVE MCDONALD, JH, BANDRA, AKBARPUR',
      phone: entry?['phone']?.toString() ?? 'Mob.: 9580215566',
      amount: (entry?['amount'] as double?) ?? double.tryParse(entry?['amount']?.toString() ?? '') ?? 20000.00,
      narration: entry?['narration']?.toString() ?? '',
      voucherType: entry?['voucherType']?.toString() ?? 'Bank Receipt',
      placeOfSupply: entry?['placeOfSupply']?.toString() ?? 'Gujarat',
      isBank: true,
      chequeRefNo: entry?['refNo']?.toString() ?? '1',
      chequeDate: entry?['chequeDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
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
                      _buildActionButton(Icons.flash_on, 'Quick\nEntry', onTap: () => _openBankEntryWindow()),
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () => _openPrintVoucher()),
                      _buildActionButton(Icons.receipt_long, 'Cheque\nPrint', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final double amtVal = double.tryParse(entry['totalAmount']?.toString() ?? '') ?? 0.0;
                          
                          String chequeDate = entry['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
                          String payeeName = entry['accountName']?.toString() ?? entry['acName']?.toString() ?? 'WALK-IN';

                          final rows = entry['rows'] as List<dynamic>?;
                          if (rows != null && rows.isNotEmpty) {
                            try {
                              final chequeRow = rows.firstWhere((r) => r['mode'] == 'Cheque', orElse: () => null);
                              if (chequeRow != null) {
                                if (chequeRow['chequeDate'] != null && chequeRow['chequeDate'].toString().isNotEmpty) {
                                  final dt = DateTime.parse(chequeRow['chequeDate'].toString());
                                  chequeDate = DateFormat('dd/MM/yyyy').format(dt);
                                }
                                if (chequeRow['acName'] != null && chequeRow['acName'].toString().isNotEmpty) {
                                  payeeName = chequeRow['acName'].toString();
                                }
                              }
                            } catch (_) {}
                          }

                          ChequePrintDialog.show(
                            context,
                            payee: payeeName,
                            amount: amtVal,
                            date: chequeDate,
                          );
                        }
                      }),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openBankEntryWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openBankEntryWindow(entry: _entries[_selectedIndex!]);
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
                                    FirebaseFirestore.instance.collection('bank_entries').doc(docId).delete();
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
                          _openBankEntryWindow(entry: _entries[_selectedIndex!], isViewOnly: true);
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

                  // Table Body (from Firestore)
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _entries.isEmpty
                            ? const Center(
                                child: Text(
                                  'No bank entries found.\nTap Add to create a new entry.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final isSelected = _selectedIndex == index;
                        return InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          onDoubleTap: () => _openBankEntryWindow(entry: entry, isViewOnly: true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFDF6ED) : Colors.transparent,
                              border: const Border(bottom: BorderSide(color: _border)),
                            ),
                            child: Row(
                            children: [
                              _buildRowCell(entry['voucherNo']?.toString() ?? '', flex: 2),
                              _buildRowCell(entry['voucherDate']?.toString() ?? '', flex: 2),
                              _buildRowCell(entry['accountName']?.toString() ?? '', flex: 3),
                              _buildRowCell(entry['voucherType']?.toString() ?? '', flex: 2),
                              _buildRowCell(entry['totalAmount']?.toString() ?? '', flex: 2),
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
                            child: Text('${_entries.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
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
