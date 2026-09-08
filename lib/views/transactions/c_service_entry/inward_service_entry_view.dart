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

class ServiceEntryRow {
  String crDr; // 'DR' or 'CR'
  String accountName;
  final TextEditingController amountController;
  final TextEditingController tdsController;
  String gstApplicable; // 'No' or 'Yes'
  final TextEditingController narrationController;

  ServiceEntryRow({
    this.crDr = 'DR',
    this.accountName = 'ABC ARTISAN',
    String amount = '0.00',
    String tds = '0.00',
    this.gstApplicable = 'No',
    String narration = '',
  })  : amountController = TextEditingController(text: amount),
        tdsController = TextEditingController(text: tds),
        narrationController = TextEditingController(text: narration);

  double get amount => double.tryParse(amountController.text.trim()) ?? 0.0;
  double get tds => double.tryParse(tdsController.text.trim()) ?? 0.0;
  double get netAmount {
    double baseNet = amount - tds;
    if (gstApplicable == 'Yes') {
      baseNet += amount * 0.18;
    }
    return baseNet;
  }
}

class InwardServiceEntryView extends StatefulWidget {
  final AdminState state;

  const InwardServiceEntryView({super.key, required this.state});

  @override
  State<InwardServiceEntryView> createState() => _InwardServiceEntryViewState();
}

class _InwardServiceEntryViewState extends State<InwardServiceEntryView> {
  String _account = 'All';
  String _bookName = 'All';
  DateTime _dateFromVal = DateTime(2019, 10, 23);
  DateTime _dateToVal = DateTime(2019, 10, 23);
  String _vouType = 'All';
  String _prefix = 'All';

  int? _selectedIndex;
  final List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
      
      if (isOnline) {
        QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore.instance
            .collection('service_entries')
            .orderBy('createdAt', descending: true)
            .get();
        if (mounted) {
          setState(() {
            _entries.clear();
            for (var doc in snap.docs) {
              final data = doc.data();
              data['docId'] = doc.id;
              final type = data['serviceType']?.toString() ?? 'Inward';
              if (type == 'Inward') {
                _entries.add(data);
              }
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFilterDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFromVal : _dateToVal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _brown,
            onPrimary: Colors.white,
            onSurface: _brown,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFromVal = picked;
        } else {
          _dateToVal = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateFromStr = DateFormat('dd/MM/yyyy').format(_dateFromVal);
    final String dateToStr = DateFormat('dd/MM/yyyy').format(_dateToVal);

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
                      _buildFilterRow('Account', _account, (val) => setState(() => _account = val!), isPrimary: true),
                      const SizedBox(height: 8),
                      _buildFilterRow('Book Name', _bookName, (val) => setState(() => _bookName = val!)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateFilter('Date From', dateFromStr, onTap: () => _selectFilterDate(context, true)),
                          ),
                          const SizedBox(width: 8),
                          const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateFilter('', dateToStr, onTap: () => _selectFilterDate(context, false)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildFilterRow('Vou.Type', _vouType, (val) => setState(() => _vouType = val!))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildFilterRow('Prefix', _prefix, (val) => setState(() => _prefix = val!))),
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
                      _buildActionButton(Icons.flash_on, 'Quick\nEntry', onTap: () => _openServiceEntryWindow()),
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () => _showPrintPreview()),
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
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openServiceEntryWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openServiceEntryWindow(initialData: _entries[_selectedIndex!]);
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
                                await FirebaseFirestore.instance.collection('service_entries').doc(docId).delete();
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
                          _openServiceEntryWindow(initialData: _entries[_selectedIndex!], isViewOnly: true);
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
                                  'No service entries found.\nTap Add to create a new entry.',
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
                                onDoubleTap: () => _openServiceEntryWindow(initialData: entry, isViewOnly: true),
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
                                      _buildRowCell(entry['voucherType']?.toString() ?? 'Inward Service', flex: 2),
                                      _buildRowCell(entry['amount']?.toString() ?? entry['totalAmount']?.toString() ?? '0.00', flex: 2),
                                      _buildRowCell(entry['bookName']?.toString() ?? '-', flex: 2),
                                      _buildRowCell(entry['reference']?.toString() ?? '-', flex: 2),
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

  void _openServiceEntryWindow({Map<String, dynamic>? initialData, bool isViewOnly = false}) async {
    final dynamic newEntry = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceEntryFormWindowDialog(
        initialData: initialData,
        isViewOnly: isViewOnly,
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
          _entries.add(newEntry);
        }
      });
    }
  }

  void _showPrintPreview([Map<String, dynamic>? data]) {
    final entry = data ?? (_selectedIndex != null && _selectedIndex! < _entries.length ? _entries[_selectedIndex!] : null);
    if (entry == null) return;
    final double primaryAmt = (entry['amount'] as double?) ?? double.tryParse(entry['amount']?.toString() ?? '') ?? 0.00;

    final bool hasGst = entry['gstApplicable'] == 'Yes';
    double taxable = primaryAmt;
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;
    if (hasGst) {
      taxable = primaryAmt / 1.18;
      final bool isLocal = (entry['placeOfSupply'] ?? 'Tamil Nadu').toString().trim().toLowerCase() == 'tamil nadu';
      if (isLocal) {
        cgst = taxable * 0.09;
        sgst = taxable * 0.09;
      } else {
        igst = taxable * 0.18;
      }
    }

    CashVoucherPrintDialog.show(
      context,
      voucherNo: entry['voucherNo']?.toString() ?? 'J-1',
      date: entry['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
      accountName: entry['accountName']?.toString() ?? entry['acName']?.toString() ?? 'ABC ARTISAN',
      amount: primaryAmt,
      narration: entry['narration']?.toString() ?? '',
      voucherType: 'Inward Service',
      placeOfSupply: entry['placeOfSupply']?.toString() ?? 'Tamil Nadu',
      billNo: entry['billNo']?.toString() ?? '',
      billDate: entry['billDate']?.toString() ?? '',
      gstNo: entry['gstNo']?.toString() ?? '',
      address: entry['address']?.toString() ?? '',
      phone: entry['phone']?.toString() ?? '',
      panNo: entry['panNo']?.toString() ?? '',
      gstApplicable: hasGst,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      taxableAmount: taxable,
    );
  }

  Widget _buildFilterRow(String label, String value, ValueChanged<String?> onChanged, {bool isPrimary = false}) {
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
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilter(String label, String value, {VoidCallback? onTap}) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
          ),
        Expanded(
          child: InkWell(
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
                  Text(value, style: const TextStyle(fontSize: 12, color: Colors.black)),
                  const Icon(Icons.calendar_today, color: Colors.grey, size: 14),
                ],
              ),
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

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE ENTRY FORM WINDOW DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ServiceEntryFormWindowDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isViewOnly;

  const _ServiceEntryFormWindowDialog({
    this.initialData,
    this.isViewOnly = false,
  });

  @override
  State<_ServiceEntryFormWindowDialog> createState() => _ServiceEntryFormWindowDialogState();
}

class _ServiceEntryFormWindowDialogState extends State<_ServiceEntryFormWindowDialog> {
  String? _editingDocId;
  String _voucherPrefix = 'IS';
  final TextEditingController _voucherSuffixCtrl = TextEditingController(text: '1');
  DateTime _voucherDate = DateTime.now();
  final TextEditingController _referenceCtrl = TextEditingController();

  String _headerAcName = 'Cash Party';
  String _placeOfSupply = 'Tamil Nadu';
  bool _isMemoVoucher = false;
  String _paymentMode = 'Cash';

  final TextEditingController _formNarrationCtrl = TextEditingController();
  final List<ServiceEntryRow> _formRows = [];

  List<Map<String, dynamic>> _customersList = [];
  List<String> _bankNamesList = [];
  final TextEditingController _billNoCtrl = TextEditingController();
  final TextEditingController _billDateCtrl = TextEditingController();

  double _currentBookBalanceVal = 0.0;
  bool _isLoadingBalance = false;

  List<Map<String, dynamic>> _customerBills = [];

  @override
  void initState() {
    super.initState();
    _initData();
    _loadCustomers();
    _loadBankNames();
    _updateBookBalance();
    if (_headerAcName != 'Cash Party') {
      _fetchCustomerBills(_headerAcName);
    }
    if (widget.initialData == null) {
      _fetchNextVoucherNumber();
    }
  }

  Future<void> _loadBankNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').orderBy('name').get();
      final names = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty &&
                        !s.toLowerCase().contains('cash') &&
                        !s.toLowerCase().contains('card'))
          .toList();
      if (mounted) {
        setState(() {
          _bankNamesList = names;
        });
      }
    } catch (e) {
      debugPrint('Error loading bank names: $e');
    }
  }

  Future<void> _updateBookBalance() async {
    final String mode = _paymentMode;
    if (!mounted) return;
    setState(() {
      _isLoadingBalance = true;
      _currentBookBalanceVal = 0.0;
    });

    try {
      double drSum = 0.0;
      double crSum = 0.0;

      // 1. Query cash_entries (for Cash book names)
      final cashSnap = await FirebaseFirestore.instance.collection('cash_entries').get();
      for (final doc in cashSnap.docs) {
        final d = doc.data();
        final bName = (d['bookName'] ?? d['acName'] ?? '').toString();
        final bool isMatch = (mode.toLowerCase() == 'cash' && (bName.toLowerCase().contains('cash') || bName.toLowerCase() == 'main cash')) ||
                             (bName.toLowerCase() == mode.toLowerCase());
        if (isMatch) {
          final double amt = double.tryParse(d['amount']?.toString() ?? d['totalAmount']?.toString() ?? '0') ?? 0.0;
          final bool isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;
          if (isPayment) {
            crSum += amt; // Payment decreases cash (Credit)
          } else {
            drSum += amt; // Receipt increases cash (Debit)
          }
        }
      }

      // 2. Query bank_entries (for Bank book names)
      final bankSnap = await FirebaseFirestore.instance.collection('bank_entries').get();
      for (final doc in bankSnap.docs) {
        final d = doc.data();
        final bName = (d['bookName'] ?? d['acName'] ?? '').toString();
        final bool isMatch = (bName.toLowerCase() == mode.toLowerCase());
        if (isMatch) {
          final double amt = double.tryParse(d['amount']?.toString() ?? d['totalAmount']?.toString() ?? '0') ?? 0.0;
          final bool isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;
          if (isPayment) {
            crSum += amt; // Payment decreases bank (Credit)
          } else {
            drSum += amt; // Receipt increases bank (Debit)
          }
        }
      }

      // 3. Query cash_bank_card_receipt_entries (for Cash, Card, UPI, and Bank names)
      final receiptSnap = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').get();
      for (final doc in receiptSnap.docs) {
        final d = doc.data();
        final rows = d['rows'] as List?;
        if (rows != null) {
          for (final row in rows) {
            if (row is Map) {
              final rBook = (row['book'] ?? '').toString();
              final rMode = (row['mode'] ?? '').toString();
              final double rAmt = double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;

              final bool isMatch = (rBook.toLowerCase() == mode.toLowerCase()) ||
                                   (rMode.toLowerCase() == mode.toLowerCase()) ||
                                   (mode.toLowerCase() == 'cash' && (rBook.toLowerCase().contains('cash') || rMode.toLowerCase() == 'cash')) ||
                                   (mode.toLowerCase() == 'card' && (rBook.toLowerCase().contains('card') || rMode.toLowerCase() == 'card')) ||
                                   (mode.toLowerCase() == 'upi' && (rBook.toLowerCase().contains('upi') || rMode.toLowerCase() == 'upi'));

              if (isMatch) {
                drSum += rAmt; // Receipt increases balance (Debit)
              }
            }
          }
        }
      }

      // 4. Query bills (for Cash/Bank payments recorded in sales/purchases)
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final String pMode = (d['paymentMode'] ?? d['mode'] ?? '').toString();
        final double paid = double.tryParse(d['paymentAmt']?.toString() ?? '0') ?? 0.0;
        final bool isMatch = (pMode.toLowerCase() == mode.toLowerCase()) ||
                             (mode.toLowerCase() == 'cash' && pMode.toLowerCase().contains('cash')) ||
                             (mode.toLowerCase() == 'bank' && pMode.toLowerCase().contains('bank'));
        if (isMatch && paid > 0) {
          drSum += paid; // Sale receipt increases balance (Debit)
        }
      }

      // 5. Query service_entries
      final serviceSnap = await FirebaseFirestore.instance.collection('service_entries').get();
      for (final doc in serviceSnap.docs) {
        final d = doc.data();
        final String pMode = (d['paymentMode'] ?? d['mode'] ?? '').toString();
        final double amt = double.tryParse(d['amount']?.toString() ?? d['totalAmount']?.toString() ?? '0') ?? 0.0;
        final bool isMatch = (pMode.toLowerCase() == mode.toLowerCase()) ||
                             (mode.toLowerCase() == 'cash' && pMode.toLowerCase().contains('cash'));
        if (isMatch && amt > 0) {
          drSum += amt; // Service receipt increases balance (Debit)
        }
      }

      final double finalBalance = drSum - crSum;
      if (mounted) {
        setState(() {
          _currentBookBalanceVal = finalBalance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      debugPrint('Error updating book balance: $e');
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _fetchNextVoucherNumber() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
    if (!isOnline) {
      if (mounted) setState(() => _voucherSuffixCtrl.text = '1');
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('service_entries').get();
      int maxNum = 0;
      for (final doc in snap.docs) {
        final vNo = doc.data()['voucherNo']?.toString();
        if (vNo != null) {
          final sep = vNo.contains('-') ? '-' : '/';
          if (vNo.contains(sep)) {
            final suffix = vNo.split(sep)[1].replaceAll('-OFF', '');
            final num = int.tryParse(suffix);
            if (num != null && num > maxNum) {
              maxNum = num;
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _voucherSuffixCtrl.text = (maxNum + 1).toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching next voucher number: $e');
    }
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _billDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('customers').get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) {
        setState(() {
          _customersList = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading customers in service entry: $e');
    }
  }

  Future<void> _fetchCustomerBills(String accountName) async {
    if (!mounted) return;
    setState(() {
      _customerBills.clear();
    });
    if (accountName == 'Cash Party') {
      return;
    }
    final parts = accountName.split(' - ');
    final code = parts[0].trim().toLowerCase();
    final name = parts.length > 1 ? parts[1].trim().toLowerCase() : '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('billType', isEqualTo: 'Sale')
          .get();

      final filtered = snap.docs.where((doc) {
        final data = doc.data();
        final String billAc = (data['acName'] ?? '').toString().trim().toLowerCase();
        return billAc.contains(code) || (name.isNotEmpty && billAc.contains(name));
      }).map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _customerBills = filtered;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer bills: $e');
    }
  }

  List<String> get _billNoDropdownItems {
    final list = <String>[];
    for (var bill in _customerBills) {
      final String invNo = (bill['voucherNo'] ?? '').toString();
      if (invNo.isNotEmpty && !list.contains(invNo)) {
        list.add(invNo);
      }
    }
    final currentBillNo = _billNoCtrl.text.trim();
    if (currentBillNo.isNotEmpty && !list.contains(currentBillNo)) {
      list.add(currentBillNo);
    }
    return list;
  }

  List<String> get _dropdownItems {
    final list = <String>['Cash Party'];
    for (var e in _customersList) {
      final code = (e['customerCode'] ?? e['id'] ?? '').toString();
      final name = (e['name'] ?? e['companyName'] ?? '').toString();
      list.add("$code - $name");
    }
    if (_headerAcName.isNotEmpty && !list.contains(_headerAcName)) {
      list.add(_headerAcName);
    }
    return list;
  }

  List<String> get _paymentModeItems {
    final list = <String>['Cash', 'Card', 'UPI'];
    list.addAll(_bankNamesList);
    if (_paymentMode.isNotEmpty && !list.contains(_paymentMode)) {
      list.add(_paymentMode);
    }
    return list;
  }

  List<String> get _placeOfSupplyItems {
    final list = <String>['Tamil Nadu', 'Gujarat', 'Maharashtra', 'Karnataka'];
    if (_placeOfSupply.isNotEmpty && !list.contains(_placeOfSupply)) {
      list.add(_placeOfSupply);
    }
    return list;
  }

  void _initData() {
    final data = widget.initialData;
    if (data != null) {
      _editingDocId = data['docId'];
      final vNo = data['voucherNo']?.toString() ?? 'J-1';
      if (vNo.contains('-')) {
        final parts = vNo.split('-');
        _voucherPrefix = parts.first;
        _voucherSuffixCtrl.text = parts.last;
      } else {
        _voucherSuffixCtrl.text = vNo;
      }
      _referenceCtrl.text = data['reference']?.toString() ?? '';
      _headerAcName = data['accountName']?.toString() ?? data['acName']?.toString() ?? 'Cash Party';
      _placeOfSupply = data['placeOfSupply']?.toString() ?? 'Tamil Nadu';
      _isMemoVoucher = data['memoVoucher'] == 'Yes';
      _formNarrationCtrl.text = data['narration']?.toString() ?? '';
      _billNoCtrl.text = data['billNo']?.toString() ?? '';
      _billDateCtrl.text = data['billDate']?.toString() ?? '';
      _paymentMode = data['paymentMode']?.toString() ?? 'Cash';

      _formRows.clear();
      _formRows.add(ServiceEntryRow(
        crDr: 'DR',
        accountName: _headerAcName,
        amount: (data['amount']?.toString() ?? '0.00'),
        tds: (data['tds']?.toString() ?? '0.00'),
        narration: _formNarrationCtrl.text,
      ));
    } else {
      _editingDocId = null;
      _voucherPrefix = 'IS';
      _voucherSuffixCtrl.text = '1';
      _voucherDate = DateTime.now();
      _referenceCtrl.clear();
      _headerAcName = 'Cash Party';
      _placeOfSupply = 'Tamil Nadu';
      _isMemoVoucher = false;
      _formNarrationCtrl.clear();
      _billNoCtrl.clear();
      _billDateCtrl.clear();
      _paymentMode = 'Cash';

      _formRows.clear();
      _formRows.add(ServiceEntryRow());
    }
  }



  void _addFormRow() {
    setState(() {
      _formRows.add(ServiceEntryRow());
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

  void _printFormVoucher() {
    final String fullVoucherNo = '$_voucherPrefix-${_voucherSuffixCtrl.text.trim()}';
    final double primaryAmt = _formRows.fold(0.0, (prev, element) => prev + element.netAmount);
    final String masterNarration = _formNarrationCtrl.text.trim().isNotEmpty
        ? _formNarrationCtrl.text.trim()
        : (_formRows.isNotEmpty ? _formRows.first.narrationController.text.trim() : '');

    // Fetch customer details from the selected customer
    Map<String, dynamic>? selectedContact;
    if (_headerAcName != 'Cash Party') {
      final parts = _headerAcName.split(' - ');
      final code = parts[0];
      try {
        selectedContact = _customersList.firstWhere(
          (e) => (e['customerCode'] ?? e['id'] ?? '').toString() == code,
        );
      } catch (_) {}
    }

    final String contactAddress = selectedContact != null
        ? [
            selectedContact['blockNo'] ?? selectedContact['buildingName'],
            selectedContact['street'] ?? selectedContact['address'],
            selectedContact['area'],
            selectedContact['city'],
            selectedContact['state'],
            selectedContact['zipCode'] ?? selectedContact['pinCode']
          ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ')
        : '';

    final String contactPhone = selectedContact != null
        ? (selectedContact['mobileNo1'] ?? selectedContact['phone'] ?? selectedContact['mobileNo2'] ?? '').toString()
        : '';

    final String contactPan = selectedContact != null
        ? (selectedContact['pan'] ?? selectedContact['panNumber'] ?? '').toString()
        : '';

    final String customerGst = selectedContact != null
        ? (selectedContact['gstNo'] ?? selectedContact['gstin'] ?? selectedContact['gstinNo'] ?? selectedContact['gstNumber'] ?? '').toString()
        : '';

    final double taxable = _formRows.fold(0.0, (acc, r) => acc + (r.amount - r.tds));
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;
    final bool hasGst = _formRows.any((r) => r.gstApplicable == 'Yes');
    if (hasGst) {
      final double gstBase = _formRows.where((r) => r.gstApplicable == 'Yes').fold(0.0, (acc, r) => acc + (r.amount - r.tds));
      final bool isLocal = _placeOfSupply.trim().toLowerCase() == 'tamil nadu';
      if (isLocal) {
        cgst = gstBase * 0.09;
        sgst = gstBase * 0.09;
      } else {
        igst = gstBase * 0.18;
      }
    }

    CashVoucherPrintDialog.show(
      context,
      voucherNo: fullVoucherNo,
      date: DateFormat('dd/MM/yyyy EEE').format(_voucherDate),
      accountName: _headerAcName,
      address: contactAddress,
      phone: contactPhone,
      panNo: contactPan,
      gstNo: customerGst,
      amount: primaryAmt,
      narration: masterNarration,
      voucherType: 'Inward Service',
      placeOfSupply: _placeOfSupply,
      billNo: _billNoCtrl.text.trim(),
      billDate: _billDateCtrl.text.trim(),
      gstApplicable: hasGst,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      taxableAmount: taxable,
    );
  }

  Future<void> _saveVoucher() async {
    final String fullVoucherNo = '$_voucherPrefix-${_voucherSuffixCtrl.text.trim()}';
    final double primaryAmt = _formRows.fold(0.0, (prev, element) => prev + element.netAmount);
    final String rowGst = _formRows.isNotEmpty ? _formRows.first.gstApplicable : 'No';

    final entryData = {
      'docId': _editingDocId,
      'voucherNo': fullVoucherNo,
      'voucherDate': DateFormat('dd/MM/yyyy EEE').format(_voucherDate),
      'date': DateFormat('dd/MM/yyyy').format(_voucherDate),
      'acName': _headerAcName,
      'accountName': _headerAcName,
      'voucherType': 'Inward Service',
      'serviceType': 'Inward',
      'amount': primaryAmt,
      'totalAmount': primaryAmt.toStringAsFixed(2),
      'bookName': 'Service Book',
      'reference': _referenceCtrl.text.trim(),
      'narration': _formNarrationCtrl.text.trim(),
      'placeOfSupply': _placeOfSupply,
      'memoVoucher': _isMemoVoucher ? 'Yes' : 'No',
      'billNo': _billNoCtrl.text.trim(),
      'billDate': _billDateCtrl.text.trim(),
      'paymentMode': _paymentMode,
      'gstApplicable': rowGst,
    };

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        if (_editingDocId != null) {
          await FirebaseFirestore.instance.collection('service_entries').doc(_editingDocId).update(entryData);
        } else {
          final firestoreData = Map<String, dynamic>.from(entryData)
            ..['createdAt'] = FieldValue.serverTimestamp();
          final docRef = await FirebaseFirestore.instance.collection('service_entries').add(firestoreData);
          entryData['docId'] = docRef.id;
        }
      } else {
        if (!fullVoucherNo.endsWith('-OFF')) {
          entryData['voucherNo'] = '$fullVoucherNo-OFF';
        }
        await LocalDbService().insertEntry(
          'service_entries',
          entryData,
          operation: _editingDocId != null ? 'UPDATE' : 'ADD',
          docId: _editingDocId,
        );
        SyncService().syncNow();
        entryData['docId'] = _editingDocId ?? 'offline_dummy_id';
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inward Service Entry saved successfully!')),
      );
      Navigator.pop(context, entryData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dayOfWeek = DateFormat('EEEE').format(_voucherDate);
    final String formattedDate = DateFormat('dd/MM/yyyy EEE').format(_voucherDate);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: screenWidth * 0.9,
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
                    _editingDocId != null ? 'Edit Inward Service Entry' : 'Inward Service Entry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _brownLight),
                  ),
                ],
              ),
            ),

            // ── Top Form Fields Card ─────────────────────────────────────────
            IgnorePointer(
              ignoring: widget.isViewOnly,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
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
                            Text(
                              _voucherPrefix,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('/', style: TextStyle(color: _brownLight))),
                            SizedBox(width: 50, height: 26, child: _buildTextField(_voucherSuffixCtrl, readOnly: true)),
                            const SizedBox(width: 4),
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
                              child: InkWell(
                                onTap: null,
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const Icon(Icons.calendar_today, size: 14, color: _brownLight),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(dayOfWeek, style: const TextStyle(fontSize: 12, color: _brownLight)),
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

                  // Row 2: Account Name & Place of Supply
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('A/c. Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: _buildDropdown(
                                _headerAcName,
                                _dropdownItems,
                                (v) {
                                  setState(() {
                                    _headerAcName = v!;
                                    if (_headerAcName != 'Cash Party') {
                                      final parts = _headerAcName.split(' - ');
                                      final code = parts[0];
                                      try {
                                        final contact = _customersList.firstWhere(
                                          (e) => (e['customerCode'] ?? e['id'] ?? '').toString() == code,
                                        );
                                        final String stateVal = (contact['state'] ?? 'Tamil Nadu').toString().trim();
                                        if (stateVal.isNotEmpty) {
                                          _placeOfSupply = stateVal;
                                        }
                                      } catch (_) {}
                                    }
                                    _fetchCustomerBills(_headerAcName);
                                  });
                                },
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const SizedBox(width: 100, child: Text('Place Of Supply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: _buildDropdown(
                                _placeOfSupplyItems.contains(_placeOfSupply) ? _placeOfSupply : 'Tamil Nadu',
                                _placeOfSupplyItems,
                                (v) => setState(() => _placeOfSupply = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 3: Bill No. & Bill Date & Payment Mode
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 90, child: Text('Bill No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 26,
                                      child: _buildTextField(_billNoCtrl),
                                    ),
                                  ),
                                  if (_billNoDropdownItems.isNotEmpty)
                                    SizedBox(
                                      width: 24,
                                      height: 26,
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.arrow_drop_down, size: 20, color: _brownLight),
                                        padding: EdgeInsets.zero,
                                        onSelected: (v) {
                                          setState(() {
                                            _billNoCtrl.text = v;
                                            try {
                                              final bill = _customerBills.firstWhere(
                                                (b) => (b['voucherNo'] ?? '').toString() == v,
                                              );
                                              final vDate = bill['voucherDate'];
                                              if (vDate != null) {
                                                if (vDate is Timestamp) {
                                                  _billDateCtrl.text = DateFormat('dd/MM/yyyy').format(vDate.toDate());
                                                } else {
                                                  _billDateCtrl.text = vDate.toString();
                                                }
                                              }
                                            } catch (_) {}
                                          });
                                        },
                                        itemBuilder: (context) {
                                          return _billNoDropdownItems
                                              .map((e) => PopupMenuItem(
                                                    value: e,
                                                    height: 32,
                                                    child: Text(e, style: const TextStyle(fontSize: 12)),
                                                  ))
                                              .toList();
                                        },
                                      ),
                                    ),
                                ],
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
                            const SizedBox(width: 70, child: Text('Bill Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _billDateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                                    });
                                  }
                                },
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
                                      Text(
                                        _billDateCtrl.text.isNotEmpty ? _billDateCtrl.text : 'Select Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _billDateCtrl.text.isNotEmpty ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
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
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const SizedBox(width: 100, child: Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight))),
                            Expanded(
                              child: _buildDropdown(
                                _paymentModeItems.contains(_paymentMode) ? _paymentMode : 'Cash',
                                _paymentModeItems,
                                (v) {
                                  setState(() {
                                    _paymentMode = v!;
                                  });
                                  _updateBookBalance();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

            // ── Middle Data Grid Table ───────────────────────────────────────
            Expanded(
              child: IgnorePointer(
                ignoring: widget.isViewOnly,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Divider(height: 1, color: _border),
                      // Header Row
                      Container(
                        color: _headerBg,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: const Row(
                          children: [
                            SizedBox(width: 60, child: Text('Cr/Dr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            Expanded(flex: 2, child: Text('TDS Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            Expanded(flex: 2, child: Text('Net Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            SizedBox(width: 110, child: Text('GST Applicable?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            Expanded(flex: 6, child: Text('Narration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                            SizedBox(width: 24),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _border),

                      // Grid Body List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _formRows.length,
                          itemBuilder: (context, index) {
                            final row = _formRows[index];
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: _border)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: _buildCellDropdown(['DR', 'CR'], row.crDr, (v) {
                                      setState(() {
                                        row.crDr = v!;
                                        if (row.gstApplicable == 'Yes' && row.amount > 0) {
                                          _showGSTModal(row);
                                        }
                                      });
                                    }),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildCellTextField(row.amountController, (v) => setState(() {})),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildCellTextField(row.tdsController, (v) => setState(() {})),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        row.netAmount.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: _buildCellDropdown(['No', 'Yes'], row.gstApplicable, (v) {
                                      setState(() {
                                        row.gstApplicable = v!;
                                      });
                                      if (v == 'Yes') {
                                        _showGSTModal(row);
                                      }
                                    }),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: _buildCellTextField(row.narrationController, (v) {
                                      if (_formRows.last == row && v.isNotEmpty) {
                                        _addFormRow();
                                      }
                                    }),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: InkWell(
                                      onTap: () => _removeFormRow(index),
                                      child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.deepOrange),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Footer (Narration & Action Buttons) ────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      const Text('Total Cr. ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF7F2EB), border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
                        child: Text(_totalCr.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown), textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: 12),
                      const Text('Total Dr. ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF7F2EB), border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
                        child: Text(_totalDr.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown), textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: 12),
                      const Text('Balance ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                      Container(
                        width: 90,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF7F2EB), border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
                        child: Text(_balanceStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown), textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: 12),
                      const Text('Cur. Book Bal. ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                      Container(
                        width: 120,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF7F2EB), border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          _isLoadingBalance ? 'Loading...' : '${_currentBookBalanceVal.abs().toStringAsFixed(2)} ${_currentBookBalanceVal >= 0 ? 'Dr.' : 'Cr.'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Buttons & Master Narration
                  Row(
                    children: [
                      const Text('Narration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: IgnorePointer(
                            ignoring: widget.isViewOnly,
                            child: _buildTextField(_formNarrationCtrl),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (!widget.isViewOnly) ...[
                        ElevatedButton.icon(
                          onPressed: _saveVoucher,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF132052),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _printFormVoucher,
                        icon: const Icon(Icons.print, size: 16, color: _brown),
                        label: const Text('Print', style: TextStyle(color: _brown)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),

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

  void _showGSTModal(ServiceEntryRow row) {
    if (row.amount <= 0) return;

    final bool isLocal = _placeOfSupply == 'Tamil Nadu';
    final double taxable = row.amount;
    final double cgst = isLocal ? taxable * 0.09 : 0.0;
    final double sgst = isLocal ? taxable * 0.09 : 0.0;
    final double igst = isLocal ? 0.0 : taxable * 0.18;
    final double total = taxable + cgst + sgst + igst;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: isLocal ? 600 : 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GST Advance Settlement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown)),
                    IconButton(icon: const Icon(Icons.close, size: 20, color: _brownLight), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: _border),
                // Grid headers
                Row(
                  children: [
                    _gstHeader('Cr/Dr', 40),
                    _gstHeader('HSN/SAC', 80),
                    _gstHeader('Amount', 80),
                    _gstHeader('Taxable Amt', 80),
                    if (isLocal) ...[
                      _gstHeader('CGST %', 60),
                      _gstHeader('CGST', 70),
                      _gstHeader('SGST %', 60),
                      _gstHeader('SGST', 70),
                    ] else ...[
                      _gstHeader('IGST %', 60),
                      _gstHeader('IGST', 70),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Data Row
                Row(
                  children: [
                    _gstCell('DR', 40),
                    _gstCell('998593', 80),
                    _gstCell(total.toStringAsFixed(2), 80),
                    _gstCell(taxable.toStringAsFixed(2), 80),
                    if (isLocal) ...[
                      _gstCell('9.00', 60),
                      _gstCell(cgst.toStringAsFixed(2), 70),
                      _gstCell('9.00', 60),
                      _gstCell(sgst.toStringAsFixed(2), 70),
                    ] else ...[
                      _gstCell('18.00', 60),
                      _gstCell(igst.toStringAsFixed(2), 70),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF132052), foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        if (_formRows.last == row) {
                          _addFormRow();
                        }
                      });
                    },
                    child: const Text('OK'),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gstHeader(String label, double width) {
    return SizedBox(width: width, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight)));
  }

  Widget _gstCell(String value, double width) {
    return SizedBox(width: width, child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)));
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged, {bool isPrimary = false}) {
    final List<String> effectiveItems = items.isNotEmpty ? List<String>.from(items) : ['Select Item'];
    final String effectiveValue = effectiveItems.contains(value) ? value : effectiveItems.first;

    return Container(
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
          icon: Icon(Icons.arrow_drop_down, color: isPrimary ? Colors.white : Colors.grey, size: 16),
          style: TextStyle(fontSize: 12, color: isPrimary ? Colors.white : Colors.black, fontWeight: isPrimary ? FontWeight.w500 : FontWeight.normal),
          onChanged: onChanged,
          items: effectiveItems.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isPrimary ? Colors.black : Colors.black)))).toList(),
        ),
      ),
    );
  }

  Widget _buildCellDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    final List<String> effectiveItems = items.isNotEmpty ? List<String>.from(items) : ['Select Item'];
    final String effectiveValue = effectiveItems.contains(value) ? value : effectiveItems.first;

    return Container(
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          style: const TextStyle(fontSize: 10, color: Colors.black),
          onChanged: onChanged,
          items: effectiveItems.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildCellTextField(TextEditingController controller, ValueChanged<String> onChanged) {
    return Container(
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 11),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.circular(4)),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _brown), borderRadius: BorderRadius.circular(4)),
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
        filled: true,
        fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _brown), borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
