import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../state/admin_state.dart';
import '../../../dialogs/cash_bank_card_receipt_print_dialog.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

class CashBankCardReceiptEntryView extends StatefulWidget {
  final AdminState state;

  const CashBankCardReceiptEntryView({super.key, required this.state});

  @override
  State<CashBankCardReceiptEntryView> createState() => _CashBankCardReceiptEntryViewState();
}

class _CashBankCardReceiptEntryViewState extends State<CashBankCardReceiptEntryView> {
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

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
      final snap = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').get();
      if (snap.docs.isNotEmpty) {
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
      // Fallback to local entries list
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
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
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _openEntryWindow([Map<String, dynamic>? initialData]) async {
    final dynamic newEntry = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CashBankCardReceiptDialog(initialData: initialData),
    );
    if (newEntry != null && newEntry is Map<String, dynamic>) {
      setState(() {
        if (initialData != null && _selectedIndex != null && _selectedIndex! < _entries.length) {
          _entries[_selectedIndex!] = newEntry;
        } else {
          _entries.add(newEntry);
        }
      });
    }
  }

  void _openPrintVoucher([Map<String, dynamic>? data]) {
    final entry = data ?? (_selectedIndex != null && _selectedIndex! < _entries.length ? _entries[_selectedIndex!] : null);
    List<Map<String, dynamic>> itemsList = [];
    if (entry?['rows'] is List) {
      itemsList = List<Map<String, dynamic>>.from(entry!['rows']);
    }
    CashBankCardReceiptPrintDialog.show(
      context,
      recNo: entry?['voucherNo']?.toString() ?? 'CBCR / 3',
      date: entry?['voucherDate']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
      name: entry?['accountName']?.toString() ?? entry?['acName']?.toString() ?? 'CHAMPAK JEWELS',
      address: entry?['address']?.toString() ?? 'NEHRU ROAD,JAMMU,',
      phone: entry?['phone']?.toString() ?? '',
      itPanNo: entry?['itPanNo']?.toString() ?? '',
      placeOfSupply: entry?['placeOfSupply']?.toString() ?? 'Gujarat',
      items: itemsList,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFromStr = DateFormat('dd/MM/yyyy').format(_dateFrom);
    final dateToStr = DateFormat('dd/MM/yyyy').format(_dateTo);

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Filters (Left) - ONLY Date From and Date To
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDateFilter('Date From', dateFromStr, () => _selectDate(context, true)),
                      ),
                      const SizedBox(width: 8),
                      const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDateFilter('', dateToStr, () => _selectDate(context, false)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Action Buttons (Right) - Voucher, Add, Modify, Delete, Image, View, Close
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () => _openPrintVoucher()),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openEntryWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openEntryWindow(_entries[_selectedIndex!]);
                        }
                      }),
                      _buildActionButton(Icons.cancel_outlined, 'Delete', iconColor: Colors.deepOrange, onTap: () async {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final docId = _entries[_selectedIndex!]['docId'];
                          if (docId != null) {
                            try {
                              await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').doc(docId).delete();
                            } catch (_) {}
                          }
                          setState(() {
                            _entries.removeAt(_selectedIndex!);
                            _selectedIndex = null;
                          });
                        }
                      }),
                      _buildActionButton(Icons.image_outlined, 'Image'),
                      _buildActionButton(Icons.pageview_outlined, 'View'),
                      _buildActionButton(Icons.exit_to_app_rounded, 'Close'),
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
                        Expanded(flex: 2, child: Text('Total Voucher Amt.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 3, child: Text('Narration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Salesman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  // Table Body
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: _brown))
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final isSelected = _selectedIndex == index;
                              return InkWell(
                                onTap: () => setState(() => _selectedIndex = index),
                                onDoubleTap: () => _openEntryWindow(entry),
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
                                      _buildRowCell(entry['amount']?.toString() ?? entry['totalAmount']?.toString() ?? '0.00', flex: 2),
                                      _buildRowCell(entry['reference']?.toString() ?? '', flex: 2),
                                      _buildRowCell(entry['narration']?.toString() ?? '', flex: 3),
                                      _buildRowCell(entry['salesman']?.toString() ?? '', flex: 2),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Summary Row with count box
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

  Widget _buildDateFilter(String label, String value, VoidCallback onTap) {
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
                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
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
// CASH / BANK / CARD RECEIPT ENTRY FORM DIALOG (Exact UI matching Screenshot)
// ═════════════════════════════════════════════════════════════════════════════

class CashBankCardRow {
  String book;
  String mode;
  String crDr;
  TextEditingController refNoCtrl;
  DateTime date;
  TextEditingController amountCtrl;
  TextEditingController partyBankCtrl;
  TextEditingController remarksCtrl;

  CashBankCardRow({
    this.book = 'Cash Book',
    this.mode = 'Cash',
    this.crDr = 'CR',
    String refNo = '',
    DateTime? date,
    String amount = '0.00',
    String partyBank = '',
    String remarks = '',
  })  : refNoCtrl = TextEditingController(text: refNo),
        date = date ?? DateTime.now(),
        amountCtrl = TextEditingController(text: amount),
        partyBankCtrl = TextEditingController(text: partyBank),
        remarksCtrl = TextEditingController(text: remarks);

  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0.0;
}

class _CashBankCardReceiptDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const _CashBankCardReceiptDialog({this.initialData});

  static List<Map<String, dynamic>>? cachedSuppliers;
  static List<Map<String, dynamic>>? cachedCustomers;
  static List<String>? cachedAccountsList;
  static List<String>? cachedBookOptions;

  @override
  State<_CashBankCardReceiptDialog> createState() => _CashBankCardReceiptDialogState();
}

class _CashBankCardReceiptDialogState extends State<_CashBankCardReceiptDialog> {
  String? _editingDocId;
  String _voucherPrefix = 'CBCR';
  final TextEditingController _voucherSuffixCtrl = TextEditingController(text: '3');
  DateTime _voucherDate = DateTime.now();
  final TextEditingController _entryRefCtrl = TextEditingController();
  String _placeOfSupply = 'Gujarat';
  final TextEditingController _accountNameCtrl = TextEditingController(
    text: '',
  );
  String _salesman = 'None';
  final TextEditingController _narrationCtrl = TextEditingController();

  List<String> _accountsList = [];
  bool _isLoadingAccounts = false;
  List<Map<String, dynamic>> _suppliersList = [];
  List<Map<String, dynamic>> _customersList = [];
  double _accountOpeningBalance = 0.0;
  String _accountBalanceType = 'Cr';
  bool _tcsEnabled = false;
  double _tcsPercent = 0.1;
  double get _tcsAmt => _tcsEnabled ? _gridTotalAmount * (_tcsPercent / 100.0) : 0.0;

  List<String> _filteredAccounts = [];
  final FocusNode _accountFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final GlobalKey _textFieldKey = GlobalKey();

  final List<CashBankCardRow> _formRows = [];

  final List<String> _prefixOptions = ['CBCR', 'C', 'B', 'CARD', 'CP', 'CS'];
  List<String> _placeOptions = ['Gujarat', 'Tamil Nadu', 'Kerala', 'Karnataka', 'Maharashtra', 'Delhi'];
  final List<String> _salesmanOptions = ['None', 'Staff 1', 'Staff 2', 'Staff 3'];
  List<String> _bookOptions = [
    'Cash', 'UPI', 'Card',
    ...(_CashBankCardReceiptDialog.cachedBookOptions?.where(
      (b) => b != 'Cash' && b != 'UPI' && b != 'Card'
    ).toList() ?? []),
  ];

  @override
  void initState() {
    super.initState();
    _initData();
    _loadAccounts();
  }

  @override
  void dispose() {
    _hideOverlay();
    _accountFocusNode.dispose();
    super.dispose();
  }

  double _getTextFieldWidth() {
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 350.0;
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted || _filteredAccounts.isEmpty) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    final double width = _getTextFieldWidth();
    return OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 28.0),
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _border),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredAccounts.length,
                itemBuilder: (context, idx) {
                  final item = _filteredAccounts[idx];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        String pureName = item;
                        String code = '';
                        if (item.contains(" - ")) {
                          final parts = item.split(" - ");
                          code = parts.first.trim();
                          pureName = parts.last.trim();
                        }
                        _accountNameCtrl.text = pureName;
                        _hideOverlay();
                        _accountFocusNode.unfocus();

                        // Dynamic Place of Supply Auto-Load based on selected Customer or Supplier details
                        String? foundState;
                        double balanceVal = 0.0;
                        String balanceType = 'Cr';

                        if (code.isNotEmpty) {
                          final matchingSupplier = _suppliersList.firstWhere(
                            (s) => (s['supplierCode'] ?? s['id'] ?? '').toString().trim() == code,
                            orElse: () => {},
                          );
                          if (matchingSupplier.isNotEmpty) {
                            foundState = matchingSupplier['state']?.toString();
                            balanceVal = (matchingSupplier['opBalance'] as num?)?.toDouble() ??
                                         (matchingSupplier['openingBalance'] as num?)?.toDouble() ?? 0.0;
                            balanceType = matchingSupplier['opBalanceType']?.toString() ?? 'Cr';
                          } else {
                            final matchingCustomer = _customersList.firstWhere(
                              (c) => (c['customerCode'] ?? c['id'] ?? '').toString().trim() == code,
                              orElse: () => {},
                            );
                            if (matchingCustomer.isNotEmpty) {
                              foundState = matchingCustomer['state']?.toString();
                              balanceVal = (matchingCustomer['opBalance'] as num?)?.toDouble() ??
                                           (matchingCustomer['openingBalance'] as num?)?.toDouble() ?? 0.0;
                              balanceType = matchingCustomer['opBalanceType']?.toString() ?? 'Cr';
                            }
                          }
                        }
                        _accountOpeningBalance = balanceVal;
                        _accountBalanceType = balanceType;

                        if (foundState != null && foundState.isNotEmpty) {
                          String cleaned = foundState.split(" - ").first.trim();
                          if (cleaned.toLowerCase().contains("tamil")) cleaned = "Tamil Nadu";
                          if (cleaned.toLowerCase().contains("gujarat")) cleaned = "Gujarat";
                          if (cleaned.toLowerCase().contains("kerala")) cleaned = "Kerala";
                          if (cleaned.toLowerCase().contains("karnat")) cleaned = "Karnataka";

                          if (!_placeOptions.contains(cleaned)) {
                            _placeOptions.add(cleaned);
                          }
                          _placeOfSupply = cleaned;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _rebuildPlaceOptions() {
    final Set<String> uniquePlaces = {'Tamil Nadu', 'Gujarat'};
    for (final s in _suppliersList) {
      final stateVal = s['state']?.toString().trim();
      if (stateVal != null && stateVal.isNotEmpty) {
        String clean = stateVal.split(" - ").first.trim();
        if (clean.toLowerCase().contains("tamil")) clean = "Tamil Nadu";
        if (clean.toLowerCase().contains("gujarat")) clean = "Gujarat";
        if (clean.toLowerCase().contains("kerala")) clean = "Kerala";
        if (clean.toLowerCase().contains("karnat")) clean = "Karnataka";
        uniquePlaces.add(clean);
      }
    }
    for (final c in _customersList) {
      final stateVal = c['state']?.toString().trim();
      if (stateVal != null && stateVal.isNotEmpty) {
        String clean = stateVal.split(" - ").first.trim();
        if (clean.toLowerCase().contains("tamil")) clean = "Tamil Nadu";
        if (clean.toLowerCase().contains("gujarat")) clean = "Gujarat";
        if (clean.toLowerCase().contains("kerala")) clean = "Kerala";
        if (clean.toLowerCase().contains("karnat")) clean = "Karnataka";
        uniquePlaces.add(clean);
      }
    }
    _placeOptions = uniquePlaces.toList();
  }

  void _defaultSelectFirstAccount() {
    final currentText = _accountNameCtrl.text.trim();
    if (currentText.isNotEmpty) {
      final match = _accountsList.firstWhere(
        (e) => e.toLowerCase().contains(currentText.toLowerCase()),
        orElse: () => '',
      );
      if (match.isEmpty) {
        _accountsList.insert(0, currentText);
      }
    }
  }

  Future<void> _loadAccounts() async {
    if (_CashBankCardReceiptDialog.cachedAccountsList != null) {
      setState(() {
        _suppliersList = _CashBankCardReceiptDialog.cachedSuppliers ?? [];
        _customersList = _CashBankCardReceiptDialog.cachedCustomers ?? [];
        _accountsList = _CashBankCardReceiptDialog.cachedAccountsList ?? [];
        if (_CashBankCardReceiptDialog.cachedBookOptions != null) {
          _bookOptions = _CashBankCardReceiptDialog.cachedBookOptions!;
        }
        _rebuildPlaceOptions();
        _defaultSelectFirstAccount();
        _filteredAccounts = _CashBankCardReceiptDialog.cachedAccountsList ?? [];
        _isLoadingAccounts = false;
      });
      // Always refresh books from Firestore to get latest bank names
      _refreshBookOptions();
      _fetchAccountsQuery(isBackground: true);
      return;
    }

    setState(() {
      _isLoadingAccounts = true;
    });
    await _fetchAccountsQuery(isBackground: false);
  }

  Future<void> _refreshBookOptions() async {
    try {
      final booksSnap = await FirebaseFirestore.instance.collection('book_names').get();
      final bankNames = booksSnap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (bankNames.isNotEmpty) {
        final updated = ['Cash', 'UPI', 'Card', ...bankNames];
        _CashBankCardReceiptDialog.cachedBookOptions = updated;
        if (mounted) {
          setState(() {
            _bookOptions = updated;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing book options: $e');
    }
  }

  Future<void> _fetchAccountsQuery({required bool isBackground}) async {
    try {
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('suppliers').get(),
        FirebaseFirestore.instance.collection('customers').get(),
      ]);
      final suppliersSnap = snapshots[0];
      final customersSnap = snapshots[1];
      
      final List<String> list = [];
      
      final List<Map<String, dynamic>> suppliers = suppliersSnap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();
      
      final List<Map<String, dynamic>> customers = customersSnap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();
      
      for (final s in suppliers) {
        final code = (s['supplierCode'] ?? s['id'] ?? '').toString().trim();
        final name = (s['name'] ?? s['companyName'] ?? '').toString().trim();
        if (code.isNotEmpty && name.isNotEmpty) {
          list.add("$code - $name");
        }
      }
      
      for (final c in customers) {
        final code = (c['customerCode'] ?? c['id'] ?? '').toString().trim();
        final name = (c['name'] ?? c['custName'] ?? c['companyName'] ?? '').toString().trim();
        if (code.isNotEmpty && name.isNotEmpty) {
          list.add("$code - $name");
        }
      }

      List<String> fetchedBooks = [];
      try {
        final booksSnap = await FirebaseFirestore.instance.collection('book_names').get();
        fetchedBooks = booksSnap.docs
            .map((d) => d.data()['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint("Error loading book names from Firestore: $e");
      }

      // Prepend fixed payment modes before bank ledger names
      if (fetchedBooks.isNotEmpty) {
        fetchedBooks = ['Cash', 'UPI', 'Card', ...fetchedBooks];
      } else {
        fetchedBooks = ['Cash', 'UPI', 'Card'];
      }

      _CashBankCardReceiptDialog.cachedSuppliers = suppliers;
      _CashBankCardReceiptDialog.cachedCustomers = customers;
      _CashBankCardReceiptDialog.cachedAccountsList = list;
      _CashBankCardReceiptDialog.cachedBookOptions = fetchedBooks;

      if (mounted) {
        setState(() {
          _suppliersList = suppliers;
          _customersList = customers;
          _accountsList = list;
          if (fetchedBooks.isNotEmpty) {
            _bookOptions = fetchedBooks;
          }
          _rebuildPlaceOptions();
          _defaultSelectFirstAccount();
          _filteredAccounts = list;
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading accounts: $e");
      if (mounted && !isBackground) {
        setState(() {
          _isLoadingAccounts = false;
        });
      }
    }
  }

  void _initData() {
    final data = widget.initialData;
    if (data != null) {
      _editingDocId = data['docId'];
      final vNo = data['voucherNo']?.toString() ?? 'CBCR/3';
      if (vNo.contains('/')) {
        final parts = vNo.split('/');
        _voucherPrefix = _prefixOptions.contains(parts.first) ? parts.first : 'CBCR';
        _voucherSuffixCtrl.text = parts.last;
      } else {
        _voucherSuffixCtrl.text = vNo;
      }
      _entryRefCtrl.text = data['reference']?.toString() ?? data['entryRef']?.toString() ?? '';
      _placeOfSupply = _placeOptions.contains(data['placeOfSupply']) ? data['placeOfSupply'] : 'Gujarat';
      _accountNameCtrl.text = data['accountName']?.toString() ?? data['acName']?.toString() ?? '';
      _salesman = _salesmanOptions.contains(data['salesman']) ? data['salesman'] : 'None';
      _narrationCtrl.text = data['narration']?.toString() ?? '';

      _formRows.clear();
      if (data['rows'] is List && (data['rows'] as List).isNotEmpty) {
        for (var r in (data['rows'] as List)) {
          _formRows.add(CashBankCardRow(
            book: r['book'] ?? 'Cash Book',
            mode: r['mode'] ?? 'Cash',
            crDr: r['crDr'] ?? 'CR',
            refNo: r['refNo'] ?? '',
            amount: r['amount']?.toString() ?? '0.00',
            partyBank: r['partyBank'] ?? '',
            remarks: r['remarks'] ?? '',
          ));
        }
      } else {
        _formRows.add(CashBankCardRow(
          book: _bookOptions.first,
          mode: 'Cash',
          crDr: 'CR',
          amount: (data['amount'] as double? ?? 0.0).toStringAsFixed(2),
        ));
      }
    } else {
      _editingDocId = null;
      _voucherPrefix = 'CBCR';
      _voucherSuffixCtrl.text = '3';
      _voucherDate = DateTime.now();
      _entryRefCtrl.clear();
      _placeOfSupply = 'Gujarat';
      _accountNameCtrl.text = '';
      _salesman = 'None';
      _narrationCtrl.clear();

      _formRows.clear();
      _formRows.add(CashBankCardRow(
        book: _bookOptions.first,
        mode: 'Cash',
        crDr: 'CR',
        amount: '0.00',
      ));
    }
  }

  Future<void> _selectVoucherDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _voucherDate,
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
        _voucherDate = picked;
        for (final r in _formRows) {
          r.date = picked;
        }
      });
    }
  }

  void _addGridRow() {
    setState(() {
      _formRows.add(CashBankCardRow(
        book: _bookOptions.isNotEmpty ? _bookOptions.first : 'Cash Book',
        mode: 'Cash',
        crDr: 'CR',
        date: _voucherDate,
      ));
    });
  }

  void _removeGridRow(int index) {
    if (_formRows.length <= 1) return;
    setState(() {
      _formRows.removeAt(index);
    });
  }

  double get _totalCashAmt {
    double total = 0.0;
    for (var r in _formRows) {
      if (r.mode == 'Cash') {
        if (r.crDr == 'CR') {
          total += r.amount;
        } else {
          total -= r.amount;
        }
      }
    }
    return total;
  }

  double get _totalUPIAmt {
    double total = 0.0;
    for (var r in _formRows) {
      if (r.mode == 'UPI') {
        if (r.crDr == 'CR') {
          total += r.amount;
        } else {
          total -= r.amount;
        }
      }
    }
    return total;
  }

  double get _totalCardAmt {
    double total = 0.0;
    for (var r in _formRows) {
      if (r.mode == 'Card') {
        if (r.crDr == 'CR') {
          total += r.amount;
        } else {
          total -= r.amount;
        }
      }
    }
    return total;
  }

  double get _totalBankAmt {
    double total = 0.0;
    for (var r in _formRows) {
      if (r.mode == 'Bank') {
        if (r.crDr == 'CR') {
          total += r.amount;
        } else {
          total -= r.amount;
        }
      }
    }
    return total;
  }

  double get _gridTotalAmount {
    double total = 0.0;
    for (var r in _formRows) {
      if (r.crDr == 'CR') {
        total += r.amount;
      } else {
        total -= r.amount;
      }
    }
    return total;
  }


  Future<void> _saveVoucher() async {
    final String fullVoucherNo = '$_voucherPrefix/${_voucherSuffixCtrl.text.trim()}';
    final double primaryAmt = _gridTotalAmount;
    final String mainParty = _accountNameCtrl.text.trim();

    final List<Map<String, dynamic>> rowData = _formRows.map((r) => {
      'book': r.book,
      'mode': r.mode,
      'crDr': r.crDr,
      'refNo': r.refNoCtrl.text.trim(),
      'amount': r.amount,
      'partyBank': r.partyBankCtrl.text.trim(),
      'remarks': r.remarksCtrl.text.trim(),
    }).toList();

    final entryData = {
      'docId': _editingDocId,
      'voucherNo': fullVoucherNo,
      'voucherDate': DateFormat('dd/MM/yyyy EEE').format(_voucherDate),
      'accountName': mainParty,
      'acName': mainParty,
      'amount': primaryAmt,
      'totalAmount': primaryAmt.toStringAsFixed(2),
      'reference': _entryRefCtrl.text.trim(),
      'placeOfSupply': _placeOfSupply,
      'salesman': _salesman,
      'narration': _narrationCtrl.text.trim(),
      'rows': rowData,
    };

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        if (_editingDocId != null) {
          await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').doc(_editingDocId).update(entryData);
        } else {
          final ref = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').add(entryData);
          entryData['docId'] = ref.id;
        }
      } else {
        if (!fullVoucherNo.endsWith('-OFF')) {
          entryData['voucherNo'] = '$fullVoucherNo-OFF';
        }
        await LocalDbService().insertEntry(
          'cash_bank_card_receipt_entries',
          entryData,
          operation: _editingDocId != null ? 'UPDATE' : 'ADD',
          docId: _editingDocId,
        );
        SyncService().syncNow();
        entryData['docId'] = _editingDocId ?? 'offline_dummy_id';
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context, entryData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('dd/MM/yyyy EEE').format(_voucherDate);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _hideOverlay();
          });
        },
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: screenWidth * 0.95,
          height: screenHeight * 0.92,
          child: Column(
          children: [
            // ── Clean Title Header ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingDocId != null ? 'Edit Cash / Bank / Card Receipt Entry' : 'Cash / Bank / Card Receipt Entry',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _brown),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _brownLight, size: 20),
                  ),
                ],
              ),
            ),

            // ── Top Form Fields Card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Column(
                children: [
                  // Row 1: Voucher No. / Voucher Date
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Voucher No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _voucherPrefix,
                                  isExpanded: false,
                                  icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 16),
                                  style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
                                  onChanged: (v) => setState(() => _voucherPrefix = v!),
                                  items: _prefixOptions.map((e) {
                                    String label = e;
                                    if (e == 'CBCR') {
                                      label = 'Cash Bank Card Receipt (CBCR)';
                                    } else if (e == 'C') {
                                      label = 'Cash Receipt (C)';
                                    } else if (e == 'B') {
                                      label = 'Bank Receipt (B)';
                                    } else if (e == 'CARD') {
                                      label = 'Card Receipt (CARD)';
                                    } else if (e == 'CP') {
                                      label = 'Cash Payment (CP)';
                                    } else if (e == 'CS') {
                                      label = 'Cash Sale (CS)';
                                    }
                                    return DropdownMenuItem(
                                      value: e,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('/', style: TextStyle(color: _brownLight, fontWeight: FontWeight.bold))),
                            SizedBox(
                              width: 40,
                              height: 26,
                              child: _buildTextField(_voucherSuffixCtrl),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Voucher Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectVoucherDate(context),
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.black)),
                                      const Icon(Icons.arrow_drop_down, size: 16, color: _brownLight),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Row 2: Entry Ref. / Place Of Supply
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Entry Ref.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Expanded(
                              child: SizedBox(height: 26, child: _buildTextField(_entryRefCtrl)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Place Of Supply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Expanded(
                              child: _buildDropdown(_placeOfSupply, _placeOptions, (v) => setState(() => _placeOfSupply = v!)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Row 3: Account Name / SalesMan
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Account Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Expanded(
                              child: _isLoadingAccounts
                                  ? const SizedBox(
                                      height: 26,
                                      width: 26,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: SizedBox(
                                          height: 12,
                                          width: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: _brownLight),
                                        ),
                                      ),
                                    )
                                  : CompositedTransformTarget(
                                      link: _layerLink,
                                      child: SizedBox(
                                        key: _textFieldKey,
                                        height: 26,
                                        child: TextField(
                                          controller: _accountNameCtrl,
                                          focusNode: _accountFocusNode,
                                          style: const TextStyle(fontSize: 12, color: Colors.black),
                                          decoration: InputDecoration(
                                            hintText: 'Enter Name',
                                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            isDense: true,
                                            suffixIcon: const Icon(Icons.search, size: 14, color: _brownLight),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(4),
                                              borderSide: const BorderSide(color: _border),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(4),
                                              borderSide: const BorderSide(color: _border),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(4),
                                              borderSide: const BorderSide(color: _brownLight, width: 1.5),
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              if (_accountNameCtrl.text.trim().isEmpty) {
                                                _filteredAccounts = List.from(_accountsList);
                                              } else {
                                                _filteredAccounts = _accountsList
                                                    .where((e) => e.toLowerCase().contains(_accountNameCtrl.text.toLowerCase()))
                                                    .toList();
                                              }
                                              _showOverlay();
                                            });
                                          },
                                          onChanged: (val) {
                                            setState(() {
                                              if (val.trim().isEmpty) {
                                                _filteredAccounts = List.from(_accountsList);
                                              } else {
                                                _filteredAccounts = _accountsList
                                                    .where((e) => e.toLowerCase().contains(val.toLowerCase()))
                                                    .toList();
                                              }
                                              _showOverlay();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('SalesMan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                            ),
                            Expanded(
                              child: Container(
                                height: 26,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _salesman,
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                    onChanged: (v) => setState(() => _salesman = v!),
                                    items: _salesmanOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: e == _salesman ? Colors.black : Colors.black)))).toList(),
                                  ),
                                ),
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
            const SizedBox(height: 6),

            // ── Main Body Split: Left (Table + Narration) & Right (Summary Panel) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left Column (Table & Narration) ─────────────────────
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab Header Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F2EB),
                              border: Border.all(color: _border),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            child: const Text(
                              'Cash / Bank / Card',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                            ),
                          ),

                          // Data Grid Table
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Grid Header
                                  Container(
                                    color: _headerBg,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: const Row(
                                      children: [
                                        SizedBox(width: 20),
                                        Expanded(flex: 1, child: Text('Dr/Cr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 4, child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 2, child: Text('Ref. No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 2, child: Text('Party Bank / Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 4),
                                        Expanded(flex: 2, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                                        SizedBox(width: 30),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, color: _border),

                                  // Grid Body Rows
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _formRows.length,
                                    itemBuilder: (context, index) {
                                        final row = _formRows[index];
                                        return Container(
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          child: Row(
                                            children: [
                                              // Arrow indicator icon
                                              const SizedBox(
                                                width: 16,
                                                child: Icon(Icons.arrow_right, size: 14, color: _brown),
                                              ),
                                              // Dr/Cr dropdown
                                              Expanded(
                                                flex: 1,
                                                child: _buildGridDropdown(row.crDr, ['DR', 'CR'], (v) => setState(() => row.crDr = v!)),
                                              ),
                                              const SizedBox(width: 4),
                                              // Mode Dropdown (Book Names)
                                              Expanded(
                                                flex: 4,
                                                child: _buildGridDropdown(row.book, _bookOptions, (v) {
                                                  if (v != null) {
                                                    setState(() {
                                                      row.book = v;
                                                      if (v == 'Cash') {
                                                        row.mode = 'Cash';
                                                      } else if (v == 'UPI') {
                                                        row.mode = 'UPI';
                                                      } else if (v == 'Card') {
                                                        row.mode = 'Card';
                                                      } else {
                                                        final lowerVal = v.toLowerCase();
                                                        if (lowerVal.contains('cash')) {
                                                          row.mode = 'Cash';
                                                        } else if (lowerVal.contains('card')) {
                                                          row.mode = 'Card';
                                                        } else if (lowerVal.contains('upi') || lowerVal.contains('gpay') || lowerVal.contains('phonepe')) {
                                                          row.mode = 'UPI';
                                                        } else {
                                                          row.mode = 'Bank';
                                                        }
                                                      }
                                                    });
                                                  }
                                                }),
                                              ),
                                              const SizedBox(width: 4),
                                              // Ref. No.
                                              Expanded(
                                                flex: 2,
                                                child: _buildGridTextField(row.refNoCtrl),
                                              ),
                                              const SizedBox(width: 4),
                                              // Date
                                              Expanded(
                                                flex: 2,
                                                child: InkWell(
                                                  onTap: () async {
                                                    final picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: row.date,
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                    if (picked != null) {
                                                      setState(() => row.date = picked);
                                                    }
                                                  },
                                                  child: Container(
                                                    height: 24,
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    alignment: Alignment.centerLeft,
                                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2), border: Border.all(color: _border)),
                                                    child: Text(DateFormat('dd/MM/yyyy').format(row.date), style: const TextStyle(fontSize: 11)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Amount
                                              Expanded(
                                                flex: 2,
                                                child: _buildGridTextField(row.amountCtrl, onChanged: (_) => setState(() {})),
                                              ),
                                              const SizedBox(width: 4),
                                              // Party Bank / Card
                                              Expanded(
                                                flex: 2,
                                                child: _buildGridTextField(row.partyBankCtrl),
                                              ),
                                              const SizedBox(width: 4),
                                              // Remarks
                                              Expanded(
                                                flex: 2,
                                                child: _buildGridTextField(row.remarksCtrl),
                                              ),
                                              // Add/Remove buttons
                                              SizedBox(
                                                width: 30,
                                                child: Row(
                                                  children: [
                                                    if (index == _formRows.length - 1)
                                                      InkWell(
                                                        onTap: _addGridRow,
                                                        child: const Icon(Icons.add_circle, color: Colors.green, size: 14),
                                                      ),
                                                    if (_formRows.length > 1)
                                                      InkWell(
                                                        onTap: () => _removeGridRow(index),
                                                        child: const Icon(Icons.remove_circle, color: Colors.red, size: 14),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    Expanded(
                                      child: InkWell(
                                        onTap: _addGridRow,
                                        child: Container(color: const Color(0xFFEBEBEB)),
                                      ),
                                    ),

                                    // Grid Summary Row
                                  Container(
                                    color: _headerBg,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 20),
                                        const Expanded(flex: 1, child: SizedBox()),
                                        const SizedBox(width: 4),
                                        const Expanded(flex: 4, child: SizedBox()),
                                        const SizedBox(width: 4),
                                        const Expanded(flex: 2, child: SizedBox()),
                                        const SizedBox(width: 4),
                                        const Expanded(flex: 2, child: SizedBox()),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            height: 22,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: _border),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              _gridTotalAmount.toStringAsFixed(2),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(flex: 2, child: SizedBox()),
                                        const SizedBox(width: 4),
                                        const Expanded(flex: 2, child: SizedBox()),
                                        const SizedBox(width: 30),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bottom Narration Box
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 100,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  color: _headerBg,
                                  child: const Text('Narration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                                ),
                                const VerticalDivider(width: 1, color: _border),
                                Expanded(
                                  child: TextField(
                                    controller: _narrationCtrl,
                                    maxLines: 3,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _tcsEnabled,
                                  activeColor: _brown,
                                  onChanged: (val) {
                                    setState(() {
                                      _tcsEnabled = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Apply TCS (${_tcsPercent.toStringAsFixed(2)}% on Total Amount)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Right Column (Summary Panel & Action Buttons) ──────
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary Breakdown Box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildBalanceRow('Cash Amt', _totalCashAmt),
                                  const SizedBox(height: 8),
                                  _buildBalanceRow('Bank Amt', _totalBankAmt),
                                  const SizedBox(height: 8),
                                  _buildBalanceRow('Card Amt', _totalCardAmt),
                                  const SizedBox(height: 8),
                                  _buildBalanceRow('UPI Amt', _totalUPIAmt),
                                  const SizedBox(height: 8),
                                  const Text('------------------------------------', style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  _buildBalanceRow('Total Amt', _gridTotalAmount),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onDoubleTap: _showEditTcsDialog,
                                    behavior: HitTestBehavior.opaque,
                                    child: _buildBalanceRow('TCS Amt (${_tcsPercent.toStringAsFixed(2)}%)', _tcsAmt),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('------------------------------------', style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  _buildSummaryRow(
                                    'Final O/s.',
                                    () {
                                      final double prevSigned = _accountBalanceType == 'Cr' ? _accountOpeningBalance : -_accountOpeningBalance;
                                      final double tcsVal = _tcsAmt;
                                      final double finalSigned = prevSigned + _gridTotalAmount - tcsVal;
                                      final String suffix = finalSigned >= 0 ? 'Cr' : 'Dr';
                                      return '${finalSigned.abs().toStringAsFixed(2)} $suffix';
                                    }(),
                                    textColor: const Color(0xFF1565C0),
                                    isBold: true,
                                    fontSize: 13,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bottom Right Action Buttons (Save, Print)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildDialogActionButton(Icons.check_circle_outline, 'Save', color: Colors.green.shade700, onTap: _saveVoucher),
                              const SizedBox(width: 6),
                              _buildDialogActionButton(Icons.print_outlined, 'Print', color: Colors.blue.shade700, onTap: () {
                                final String fullVoucherNo = '$_voucherPrefix/${_voucherSuffixCtrl.text.trim()}';
                                final List<Map<String, dynamic>> gridItems = _formRows.map((r) => {
                                  'particulars': r.mode,
                                  'book': r.book,
                                  'refNo': r.refNoCtrl.text.trim(),
                                  'date': DateFormat('dd/MM/yyyy').format(r.date),
                                  'bankName': r.partyBankCtrl.text.trim(),
                                  'amount': r.amount,
                                  'mode': r.mode,
                                }).toList();

                                CashBankCardReceiptPrintDialog.show(
                                  context,
                                  recNo: fullVoucherNo,
                                  date: DateFormat('dd/MM/yyyy').format(_voucherDate),
                                  name: _accountNameCtrl.text.trim().isNotEmpty ? _accountNameCtrl.text.trim() : 'CHAMPAK JEWELS',
                                  address: 'NEHRU ROAD,JAMMU,',
                                  placeOfSupply: _placeOfSupply,
                                  items: gridItems,
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
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBalanceRow(String label, double amount) {
    final String suffix = amount >= 0 ? 'Cr' : 'Dr';
    final Color color = amount >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return _buildSummaryRow(label, '${amount.abs().toStringAsFixed(2)} $suffix', textColor: color);
  }

  Widget _buildSummaryRow(String label, String value, {required Color textColor, bool isBold = false, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? textColor : _brownLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogActionButton(IconData icon, String label, {Color? color, VoidCallback? onTap}) {
    return Material(
      color: _btnBg,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color ?? _brown),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: color ?? _brown, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
      ),
    );
  }

  Widget _buildGridTextField(TextEditingController controller, {ValueChanged<String>? onChanged}) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2), border: Border.all(color: _border)),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 11),
        onChanged: onChanged,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 16),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ),
    );
  }

  Widget _buildGridDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2), border: Border.all(color: _border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 14),
          style: const TextStyle(fontSize: 11, color: Colors.black),
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ),
    );
  }

  void _showEditTcsDialog() {
    if (!_tcsEnabled) return;
    final TextEditingController controller = TextEditingController(
      text: _tcsPercent.toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Edit TCS Percentage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _brown)),
          content: SizedBox(
            width: 250,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'TCS Percentage (%)',
                labelStyle: TextStyle(color: _brownLight, fontSize: 12),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _brown)),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _brown),
              onPressed: () {
                final double? val = double.tryParse(controller.text);
                if (val != null) {
                  setState(() {
                    _tcsPercent = val;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
