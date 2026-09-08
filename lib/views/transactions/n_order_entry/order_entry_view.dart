import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../state/admin_state.dart';
import 'package:image_picker/image_picker.dart';
import '../../../cloudinary_service.dart';
import '../../../products/repositories/product_repository.dart';
import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../../../utils/pdf_order_entry_api.dart';
import '../../../dialogs/qr_scanner_dialog.dart';
import '../../../models/product.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);

class OrderEntryView extends StatefulWidget {
  final AdminState state;
  final String? initialSubSection;

  const OrderEntryView({
    super.key,
    required this.state,
    this.initialSubSection,
  });

  @override
  State<OrderEntryView> createState() => _OrderEntryViewState();
}

class _OrderEntryViewState extends State<OrderEntryView> {
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _setTabFromSection();
    _clearMockData();
  }

  Future<void> _clearMockData() async {
    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('order_entries')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      for (var doc in orderSnap.docs) {
        final vNo = doc.data()['voucherNo']?.toString() ?? '';
        if (vNo.startsWith('ORD-89')) {
          batch.delete(doc.reference);
          count++;
        }
      }
      final advSnap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .get();
      for (var doc in advSnap.docs) {
        final cust = doc.data()['customerName']?.toString() ?? '';
        if (cust == 'Shanthi Dev' ||
            cust == 'Deepak Kumar' ||
            cust == 'Priya Dharshini') {
          batch.delete(doc.reference);
          count++;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant OrderEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubSection != oldWidget.initialSubSection) {
      _setTabFromSection();
    }
  }

  void _setTabFromSection() {
    final sec = widget.initialSubSection;
    if (sec == 'M Customer Order') {
      _activeTab = 0;
    } else if (sec == 'M Supplier Order Allocation') {
      _activeTab = 1;
    } else if (sec == 'M Customer Order Allocation') {
      _activeTab = 2;
    } else if (sec == 'M Order Advance (Rate Fixing) Entry') {
      _activeTab = 3;
    } else if (sec == 'M Order Advance Refund Entry') {
      _activeTab = 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _activeTab,
              children: [
                _CustomerOrderSection(
                  state: widget.state,
                  activeTab: _activeTab,
                  onTabChanged: (val) => setState(() => _activeTab = val),
                ),
                _SupplierAllocationSection(
                  state: widget.state,
                  activeTab: _activeTab,
                  onTabChanged: (val) => setState(() => _activeTab = val),
                ),
                _CustomerAllocationSection(
                  state: widget.state,
                  activeTab: _activeTab,
                  onTabChanged: (val) => setState(() => _activeTab = val),
                ),
                _OrderAdvanceSection(
                  state: widget.state,
                  activeTab: _activeTab,
                  onTabChanged: (val) => setState(() => _activeTab = val),
                ),
                _AdvanceRefundSection(
                  state: widget.state,
                  activeTab: _activeTab,
                  onTabChanged: (val) => setState(() => _activeTab = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 0: CUSTOMER ORDER
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerOrderSection extends StatefulWidget {
  final AdminState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  const _CustomerOrderSection({
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  State<_CustomerOrderSection> createState() => _CustomerOrderSectionState();
}

class _CustomerOrderSectionState extends State<_CustomerOrderSection> {
  final List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  String _typeFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';
  int? _selectedIndex;

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final statusVal = o['status']?.toString() ?? 'Pending';
      if (_statusFilter != 'All' && statusVal.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      final rawDate = o['voucherDate']?.toString() ?? '';
      if (rawDate.isNotEmpty) {
        try {
          final dateVal = DateFormat('dd/MM/yyyy').parse(rawDate);
          if (_fromDate != null && dateVal.isBefore(_fromDate!)) return false;
          if (_toDate != null && dateVal.isAfter(_toDate!)) return false;
        } catch (_) {}
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final vouNo = (o['voucherNo'] ?? '').toString().toLowerCase();
        final custName = (o['customerName'] ?? '').toString().toLowerCase();
        final itemName = (o['itemName'] ?? '').toString().toLowerCase();
        final tagId = (o['tagId'] ?? '').toString().toLowerCase();
        if (!vouNo.contains(q) && !custName.contains(q) && !itemName.contains(q) && !tagId.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void didUpdateWidget(covariant _CustomerOrderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab == 0 && oldWidget.activeTab != 0) {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('order_entries')
          .orderBy('createdAt', descending: true)
          .get();
      final loaded = snap.docs.map((doc) {
        final d = doc.data();
        d['docId'] = doc.id;
        return d;
      }).toList();
      setState(() {
        _orders.clear();
        _orders.addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: 0,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: _brown,
                    size: 20,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _brown,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'Customer Order Bookings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _brown,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        'Supplier Order Allocation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _brown,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(
                        'Customer Order Allocation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _brown,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(
                        'Gold Rate Fixing Advances',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _brown,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(
                        'Advance Refunds',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _brown,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) widget.onTabChanged(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // ── Top Action & Filter Area (Second Reference Image Layout) ─────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Type filter
                    Expanded(
                      child: _buildFilterRow(
                        'Type',
                        _typeFilter,
                        ['All', 'Customer Order'],
                        (val) => setState(() {
                          _typeFilter = val!;
                          _selectedIndex = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status filter
                    Expanded(
                      child: _buildFilterRow(
                        'Status',
                        _statusFilter,
                        ['All', 'Pending', 'Allocated', 'Finished', 'Cancelled'],
                        (val) => setState(() {
                          _statusFilter = val!;
                          _selectedIndex = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Date From
                    Expanded(
                      child: _buildDateTile(
                        'Date From',
                        _fromDate == null ? '-' : DateFormat('dd/MM/yyyy').format(_fromDate!),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fromDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              _fromDate = picked;
                              _selectedIndex = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                    const SizedBox(width: 8),
                    // Date To
                    Expanded(
                      child: _buildDateTile(
                        '',
                        _toDate == null ? '-' : DateFormat('dd/MM/yyyy').format(_toDate!),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _toDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              _toDate = picked;
                              _selectedIndex = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Wrap of actions matching image
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildActionButton(Icons.add, 'Add', onTap: () => _showNewOrderDialog(context)),
                        _buildActionButton(Icons.share, 'Share', iconColor: Colors.teal, onTap: () {
                          if (_selectedIndex != null && _selectedIndex! < _filteredOrders.length) {
                            _shareOrder(_filteredOrders[_selectedIndex!]);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an order row first to share')),
                            );
                          }
                        }),
                        _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                          if (_selectedIndex != null && _selectedIndex! < _filteredOrders.length) {
                            _showNewOrderDialog(context, existing: _filteredOrders[_selectedIndex!]);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an order row first')),
                            );
                          }
                        }),
                        _buildActionButton(Icons.cancel_outlined, 'Cancel', iconColor: Colors.deepOrange, onTap: () async {
                          if (_selectedIndex != null && _selectedIndex! < _filteredOrders.length) {
                            final order = _filteredOrders[_selectedIndex!];
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Order'),
                                content: Text('Are you sure you want to delete order ${order['voucherNo']}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final docId = order['docId'];
                              if (docId != null) {
                                try {
                                  await FirebaseFirestore.instance.collection('order_entries').doc(docId).delete();
                                } catch (_) {}
                                _fetchOrders();
                                setState(() => _selectedIndex = null);
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an order row first')),
                            );
                          }
                        }),
                        _buildActionButton(Icons.refresh, 'Refresh', iconColor: Colors.green, onTap: () {
                          _fetchOrders();
                          setState(() => _selectedIndex = null);
                        }),
                        _buildActionButton(Icons.print, 'Print', onTap: () async {
                          if (_selectedIndex != null && _selectedIndex! < _filteredOrders.length) {
                            final order = _filteredOrders[_selectedIndex!];
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await PdfOrderEntryApi.printOrder(order);
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error generating PDF: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an order row first to print')),
                            );
                          }
                        }),
                        _buildActionButton(Icons.visibility_outlined, 'View', iconColor: Colors.blueAccent, onTap: () {
                          if (_selectedIndex != null && _selectedIndex! < _filteredOrders.length) {
                            _showNewOrderDialog(context, existing: _filteredOrders[_selectedIndex!], isViewOnly: true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an order row first')),
                            );
                          }
                        }),
                        _buildActionButton(Icons.swap_horiz, 'Convert', onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order allocation is done in the next tab.')),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _selectedIndex = null;
                          }),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search by Voucher No, Customer, Item, Tag ID...',
                            prefixIcon: const Icon(Icons.search, color: _brownLight, size: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2), // Vou No.
                              1: FlexColumnWidth(1.2), // Date
                              2: FlexColumnWidth(1.8), // Customer
                              3: FlexColumnWidth(2.2), // Item Name
                              4: FlexColumnWidth(0.8), // Pcs
                              5: FlexColumnWidth(1.0), // Gross Wt.
                              6: FlexColumnWidth(1.0), // Net Wt.
                              7: FlexColumnWidth(1.2), // Total Amt
                              8: FlexColumnWidth(1.2), // Deliv. Date
                              9: FlexColumnWidth(1.2), // Status
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: _border.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBF9F6),
                                ),
                                children: [
                                  _buildTableCell('Vou No.', isHeader: true),
                                  _buildTableCell('Date', isHeader: true),
                                  _buildTableCell('Customer', isHeader: true),
                                  _buildTableCell('Item Name', isHeader: true),
                                  _buildTableCell('Pcs', isHeader: true),
                                  _buildTableCell('Gross Wt.', isHeader: true),
                                  _buildTableCell('Net Wt.', isHeader: true),
                                  _buildTableCell('Total Amt', isHeader: true),
                                  _buildTableCell('Deliv. Date', isHeader: true),
                                  _buildTableCell('Status', isHeader: true),
                                ],
                              ),
                              ..._filteredOrders.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final dateStr = item['voucherDate']?.toString() ?? '—';
                                final isSelected = _selectedIndex == idx;
                                
                                Widget cell(Widget child) {
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = isSelected ? null : idx;
                                      });
                                    },
                                    child: child,
                                  );
                                }
                                
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFF2EDE6) : Colors.transparent,
                                  ),
                                  children: [
                                    cell(_buildTableCell(item['voucherNo']?.toString() ?? '—')),
                                    cell(_buildTableCell(dateStr)),
                                    cell(_buildTableCell(item['customerName']?.toString() ?? '—')),
                                    cell(_buildTableCell(item['itemName']?.toString() ?? '—')),
                                    cell(_buildTableCell(item['pcs']?.toString() ?? '0')),
                                    cell(_buildTableCell(item['grossWt']?.toString() ?? item['grossWeight']?.toString() ?? '0.000')),
                                    cell(_buildTableCell(item['netWt']?.toString() ?? item['netWeight']?.toString() ?? '0.000')),
                                    cell(_buildTableCell(item['billAmount']?.toString() ?? item['amount']?.toString() ?? '0.00')),
                                    cell(_buildTableCell(item['deliveryDate']?.toString() ?? '—')),
                                    cell(Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                        horizontal: 4.0,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusBg(item['status']),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['status']?.toString() ?? 'Pending',
                                            style: TextStyle(
                                              color: _getStatusTextColor(item['status']),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )),
                                  ],
                                );
                              }),
                            ],
                          ),
                          if (_filteredOrders.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  'No orders found.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
      String label, String value, List<String> items, ValueChanged<String?> onChanged,
      {bool isPrimary = false}) {
    final uniqueItems = items.toSet().toList();
    String displayValue = value;
    if (!uniqueItems.contains(displayValue)) {
      if (uniqueItems.contains('All')) {
        displayValue = 'All';
      } else if (uniqueItems.isNotEmpty) {
        displayValue = uniqueItems.first;
      } else {
        uniqueItems.add(displayValue);
      }
    }

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
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
                value: displayValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.grey, size: 16),
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.normal),
                onChanged: onChanged,
                items: uniqueItems
                    .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: isPrimary && displayValue == item
                                    ? _brown
                                    : Colors.black))))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(String label, String value, {required VoidCallback onTap}) {
    return Row(
      children: [
        if (label.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
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
                  Text(value, style: const TextStyle(fontSize: 11, color: Colors.black)),
                  const Icon(Icons.calendar_today, color: Colors.grey, size: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
    const btnBg = Color(0xFFF4F0E8);
    final isEnabled = onTap != null;
    return Material(
      color: isEnabled ? btnBg : btnBg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: _border.withValues(alpha: isEnabled ? 1.0 : 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isEnabled ? (iconColor ?? _brown) : Colors.grey),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 8.5,
                    color: isEnabled ? _brown : Colors.grey,
                    height: 1.1,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? _brown : Colors.black87,
        ),
      ),
    );
  }

  Color _getStatusBg(dynamic status) {
    final s = status?.toString().toLowerCase() ?? 'pending';
    if (s.contains('pending')) return Colors.orange.shade50;
    if (s.contains('allocated')) return Colors.green.shade50;
    if (s.contains('finished')) return Colors.blue.shade50;
    if (s.contains('cancel')) return Colors.red.shade50;
    return Colors.grey.shade50;
  }

  Color _getStatusTextColor(dynamic status) {
    final s = status?.toString().toLowerCase() ?? 'pending';
    if (s.contains('pending')) return Colors.orange.shade800;
    if (s.contains('allocated')) return Colors.green.shade800;
    if (s.contains('finished')) return Colors.blue.shade800;
    if (s.contains('cancel')) return Colors.red.shade800;
    return Colors.grey.shade800;
  }

  void _shareOrder(Map<String, dynamic> order) {
    final voucherNo = order['voucherNo'] ?? '';
    final date = order['date'] ?? '';
    final customer = order['customerName'] ?? 'Customer';
    final amount = order['billAmount'] ?? '0.00';
    final item = order['item'] ?? order['category'] ?? '';

    final text = '📦 *Order Receipt - Trilok Jewellers*\n'
        'Voucher No: $voucherNo\n'
        'Date: $date\n'
        'Customer: $customer\n'
        'Item: $item\n'
        'Total Amount: ₹$amount\n'
        'Thank you for booking your order with us!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Order Details'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order details copied to clipboard!')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNewOrderDialog(BuildContext context, {Map<String, dynamic>? existing, bool isViewOnly = false}) {
    showDialog(
      context: context,
      builder: (ctx) => _NewCustomerOrderDialog(
        existing: existing,
        isViewOnly: isViewOnly,
        onSaved: () {
          _fetchOrders();
        },
      ),
    );
  }
}

class _NewCustomerOrderDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  final bool isViewOnly;
  const _NewCustomerOrderDialog({required this.onSaved, this.existing, this.isViewOnly = false});

  @override
  State<_NewCustomerOrderDialog> createState() =>
      _NewCustomerOrderDialogState();
}

class _NewCustomerOrderDialogState extends State<_NewCustomerOrderDialog> {
  @override
  Widget build(BuildContext context) {
    return _OrderBookingDialog(onSaved: widget.onSaved, existing: widget.existing, isViewOnly: widget.isViewOnly);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPREHENSIVE ORDER BOOKING DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _OrderBookingDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  final bool isViewOnly;
  const _OrderBookingDialog({required this.onSaved, this.existing, this.isViewOnly = false});

  @override
  State<_OrderBookingDialog> createState() => _OrderBookingDialogState();
}

class _OrderBookingDialogState extends State<_OrderBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // ── Header ──
  final _voucherNoCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _deliveryDateCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _subTypeCtrl = TextEditingController();
  String? _selectedCustomer;
  String? _selectedSalesman;
  String _status = 'Pending';
  String? _imageUrl;

  // Proportional weight and bulk tag tracking
  int _maxPcs = 9999;
  double _singleGrossWt = 0.0;
  double _singleNetWt = 0.0;

  // ── Item Details Table ──
  final _tagIdCtrl = TextEditingController();
  String? _selectedItem;
  String? _selectedGroup;
  String? _selectedCategory;
  final _pcsCtrl = TextEditingController(text: '1');
  final _grossWtCtrl = TextEditingController();
  bool _otherWtChecked = false;
  final _otherWtCtrl = TextEditingController(text: '0.000');
  final _netWtCtrl = TextEditingController(text: '0.000');
  final _purityCtrl = TextEditingController(text: '916.0');
  final _fineWtCtrl = TextEditingController(text: '0.000');
  final _remarksCtrl = TextEditingController();

  // ── O.W. Subrows List ──
  final List<OrderSubRowController> _subRows = [];
  List<String> _extraStyles = [
    'Less Wt',
    'Black Beads',
    'Extra Charges',
    'Hallmark Charge',
    'Kedia',
    'Mani/Moti',
    'Rodium Charges',
    'diamond'
  ];

  void _addSubRowListener(OrderSubRowController sr) {
    sr.weightCtrl.addListener(_calculateBill);
    sr.pcsCtrl.addListener(_calculateBill);
  }

  void _removeSubRowListener(OrderSubRowController sr) {
    sr.weightCtrl.removeListener(_calculateBill);
    sr.pcsCtrl.removeListener(_calculateBill);
  }

  void _addNewSubRow() {
    setState(() {
      final newSr = OrderSubRowController();
      _addSubRowListener(newSr);
      _subRows.add(newSr);
      _calculateBill();
    });
  }

  void _removeSubRow(int index) {
    if (_subRows.length <= 1) return;
    setState(() {
      final sr = _subRows.removeAt(index);
      _removeSubRowListener(sr);
      sr.dispose();
      _calculateBill();
    });
  }

  List<String> _customers = [];
  List<String> _salesmen = [];
  List<String> _items = [];

  static const _statusOptions = [
    'Pending',
    'Allocate To Supplier',
    'Allocate To Customer',
    'Order Sold',
    'Finished',
    'Cancelled',
  ];

  List<Map<String, String>> _groupOptions = [];
  List<String> _categoryOptions = [];

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _generateVoucherNumber();
    _fetchMasterData();
    
    // Listeners for weight calculations
    _grossWtCtrl.addListener(_calculateBill);
    _otherWtCtrl.addListener(_calculateBill);
    _purityCtrl.addListener(_calculateBill);
    _pcsCtrl.addListener(_calculateBill);
    
    // Initialize default subrow
    final firstSr = OrderSubRowController();
    _addSubRowListener(firstSr);
    _subRows.add(firstSr);

    if (widget.existing != null) _populateExisting(widget.existing!);
  }

  @override
  void dispose() {
    _grossWtCtrl.removeListener(_calculateBill);
    _otherWtCtrl.removeListener(_calculateBill);
    _purityCtrl.removeListener(_calculateBill);
    _pcsCtrl.removeListener(_calculateBill);
    for (final sr in _subRows) {
      _removeSubRowListener(sr);
      sr.dispose();
    }
    super.dispose();
  }

  void _calculateBill() {
    int selectedQty = int.tryParse(_pcsCtrl.text) ?? 1;
    if (selectedQty > _maxPcs) {
      selectedQty = _maxPcs;
      _pcsCtrl.text = _maxPcs.toString();
      _pcsCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _pcsCtrl.text.length));
    } else if (selectedQty < 1) {
      selectedQty = 1;
      _pcsCtrl.text = '1';
      _pcsCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _pcsCtrl.text.length));
    }

    if (_singleGrossWt > 0.0) {
      final calculatedGross = _singleGrossWt * selectedQty;
      if (_grossWtCtrl.text != calculatedGross.toStringAsFixed(3)) {
        _grossWtCtrl.text = calculatedGross.toStringAsFixed(3);
      }
    }
    if (_singleNetWt > 0.0) {
      final calculatedNet = _singleNetWt * selectedQty;
      if (_netWtCtrl.text != calculatedNet.toStringAsFixed(3)) {
        _netWtCtrl.text = calculatedNet.toStringAsFixed(3);
      }
    }

    final grossWt = double.tryParse(_grossWtCtrl.text) ?? 0.0;
    final otherWt = double.tryParse(_otherWtCtrl.text) ?? 0.0;
    String purityStr = _purityCtrl.text.replaceAll('%', '').replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
    final purity = double.tryParse(purityStr) ?? 0.0;
    
    // 1. Calculate Net Wt
    double totalStyleWt = 0.0;
    if (_otherWtChecked) {
      for (final sr in _subRows) {
        totalStyleWt += double.tryParse(sr.weightCtrl.text) ?? 0.0;
      }
      if (_otherWtCtrl.text != totalStyleWt.toStringAsFixed(3)) {
        _otherWtCtrl.text = totalStyleWt.toStringAsFixed(3);
      }
    }
    final calculatedNetWt = _otherWtChecked ? (grossWt - totalStyleWt) : (grossWt - otherWt);
    if (_netWtCtrl.text != calculatedNetWt.toStringAsFixed(3)) {
      _netWtCtrl.text = calculatedNetWt.toStringAsFixed(3);
    }
    
    // 2. Calculate Fine Wt
    final calculatedFineWt = calculatedNetWt * (purity > 100 ? (purity / 1000) : (purity / 100));
    if (_fineWtCtrl.text != calculatedFineWt.toStringAsFixed(3)) {
      _fineWtCtrl.text = calculatedFineWt.toStringAsFixed(3);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _populateExisting(Map<String, dynamic> d) {
    _maxPcs = 9999;
    _singleGrossWt = 0.0;
    _singleNetWt = 0.0;

    _voucherNoCtrl.text = d['voucherNo'] ?? '';
    _dateCtrl.text = d['voucherDate'] ?? '';
    _deliveryDateCtrl.text = d['deliveryDate'] ?? '';
    _narrationCtrl.text = d['narration'] ?? '';
    _subTypeCtrl.text = d['subType'] ?? '';
    _selectedCustomer = d['customerName'];
    _selectedSalesman = d['salesmanName'];
    _status = d['status'] ?? 'Pending';
    _imageUrl = d['imageUrl'];
    
    // Redesigned Item fields
    _selectedItem = d['itemName'];
    if (_selectedItem != null && !_items.contains(_selectedItem)) {
      _items.add(_selectedItem!);
    }
    _selectedGroup = d['group'];
    if (_selectedGroup != null && !_groupOptions.any((g) => g['metalId'] == _selectedGroup)) {
      _groupOptions.add({'metalId': _selectedGroup!, 'groupName': _selectedGroup!});
    }
    _selectedCategory = d['itemCategory'];
    if (_selectedCategory != null && !_categoryOptions.contains(_selectedCategory)) {
      _categoryOptions.add(_selectedCategory!);
    }
    _tagIdCtrl.text = d['tagId'] ?? '';
    _remarksCtrl.text = d['remarks'] ?? '';
    _otherWtChecked = d['otherWtChecked'] ?? false;
    
    for (final sr in _subRows) {
      _removeSubRowListener(sr);
      sr.dispose();
    }
    _subRows.clear();
    
    final rawExtra = d['extraCharges'] ?? d['othersWeight'] ?? d['otherWeight'] ?? d['subRows'];
    if (rawExtra is List && rawExtra.isNotEmpty) {
      for (var charge in rawExtra) {
        if (charge is Map) {
          final w = ((charge['weight'] ?? charge['wt'] ?? 0.0) as num).toDouble();
          final p = ((charge['pcs'] ?? 1) as num).toInt();
          final name = (charge['styleName'] ?? charge['name'] ?? 'Less Wt').toString().trim();
          final rem = (charge['remarks'] ?? '').toString().trim();
          
          if (!_extraStyles.contains(name) && name.isNotEmpty) {
            _extraStyles.add(name);
          }
          
          final newSr = OrderSubRowController(
            styleName: name.isNotEmpty ? name : 'Less Wt',
            weight: w.toStringAsFixed(3),
            pcs: p.toString(),
            remarks: rem,
          );
          _addSubRowListener(newSr);
          _subRows.add(newSr);
        }
      }
    } else {
      final w = ((d['styleWt'] ?? 0.0) as num).toDouble();
      final p = ((d['otherPcs'] ?? 1) as num).toInt();
      final name = (d['styleName'] ?? 'Less Wt').toString().trim();
      final rem = (d['styleRemarks'] ?? '').toString().trim();
      
      if (!_extraStyles.contains(name) && name.isNotEmpty) {
        _extraStyles.add(name);
      }
      
      final newSr = OrderSubRowController(
        styleName: name.isNotEmpty ? name : 'Less Wt',
        weight: w.toStringAsFixed(3),
        pcs: p.toString(),
        remarks: rem,
      );
      _addSubRowListener(newSr);
      _subRows.add(newSr);
    }
    if (_subRows.isEmpty) {
      final defSr = OrderSubRowController();
      _addSubRowListener(defSr);
      _subRows.add(defSr);
    }
    
    _pcsCtrl.text = (d['pcs'] ?? 1).toString();
    
    // Weight fields
    _grossWtCtrl.text = (d['grossWt'] ?? '').toString();
    _otherWtCtrl.text = (d['otherWt'] ?? '').toString();
    _netWtCtrl.text = (d['netWt'] ?? '').toString();
    _purityCtrl.text = (d['purity'] ?? '').toString();
    _fineWtCtrl.text = (d['fineWt'] ?? '').toString();
  }

  Future<void> _fetchTagDetails(String tagId) async {
    if (tagId.trim().isEmpty) return;
    try {
      final cleanTag = tagId.trim().toUpperCase();
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(cleanTag).get();
      if (!doc.exists || doc.data() == null) {
        final base = getBaseTagId(cleanTag);
        if (base != cleanTag) {
          doc = await FirebaseFirestore.instance.collection('jewelry_inventory').doc(base).get();
        }
      }
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        List<Map<String, dynamic>> piecesList = [];
        if (data['pieces'] is List) {
          piecesList = List<Map<String, dynamic>>.from(
            (data['pieces'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
          );
        }

        if (piecesList.isNotEmpty && piecesList.any((p) => (p['tagId'] ?? '').toString().contains('['))) {
          final pieceMatch = piecesList.firstWhere(
            (p) => (p['tagId'] ?? '').toString().trim().toUpperCase() == cleanTag,
            orElse: () => {},
          );
          if (pieceMatch.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Please enter or scan the specific piece tag (e.g. $cleanTag[1], $cleanTag[2]). Base tag "$cleanTag" cannot be selected directly.'),
                  backgroundColor: const Color(0xFFC0392B),
                ),
              );
            }
            return;
          }
          if ((pieceMatch['status'] ?? '').toString().toLowerCase() == 'sold') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Piece "$cleanTag" is already SOLD!'),
                  backgroundColor: const Color(0xFFC0392B),
                ),
              );
            }
            return;
          }
        }

        setState(() {
          _tagIdCtrl.text = cleanTag;
          
          final fetchedItem = data['name'] ?? data['productName'] ?? '';
          if (fetchedItem.toString().isNotEmpty) {
            _selectedItem = fetchedItem.toString();
            if (!_items.contains(_selectedItem) && _selectedItem != null) {
              _items.add(_selectedItem!);
            }
          }
          
          final totalPcs = ((data['pcs'] ?? data['qty'] ?? 1) as num).toInt();
          _maxPcs = totalPcs > 0 ? totalPcs : 1;
          
          final gross = (data['grossWeight'] ?? data['grossWt'] ?? 0.0).toDouble();
          final net = (data['netWeight'] ?? data['netWt'] ?? 0.0).toDouble();
          
          _singleGrossWt = gross / _maxPcs;
          _singleNetWt = net / _maxPcs;
          
          _pcsCtrl.text = '1';
          _grossWtCtrl.text = _singleGrossWt.toStringAsFixed(3);
          _netWtCtrl.text = _singleNetWt.toStringAsFixed(3);
          
          double otherWtVal = 0.0;
          String fetchedStyleName = 'Less Wt';
          int fetchedPcs = 1;
          String fetchedRemarks = '';
          
          final rawExtra = data['extraCharges'] ?? data['othersWeight'] ?? data['otherWeight'] ?? data['subRows'];
          if (rawExtra is List && rawExtra.isNotEmpty) {
            double sumWt = 0.0;
            int sumPcs = 0;
            List<String> styleNames = [];
            List<String> remarksList = [];
            for (var charge in rawExtra) {
              if (charge is Map) {
                final w = ((charge['weight'] ?? charge['wt'] ?? 0.0) as num).toDouble();
                final p = ((charge['pcs'] ?? 1) as num).toInt();
                final name = (charge['styleName'] ?? charge['name'] ?? 'Less Wt').toString().trim();
                final rem = (charge['remarks'] ?? '').toString().trim();
                sumWt += w;
                sumPcs += p;
                if (name.isNotEmpty) {
                  styleNames.add(name);
                }
                if (rem.isNotEmpty) {
                  remarksList.add(rem);
                }
              }
            }
            otherWtVal = sumWt;
            fetchedPcs = sumPcs > 0 ? sumPcs : 1;
            if (styleNames.isNotEmpty) {
              fetchedStyleName = styleNames.first;
            }
            if (remarksList.isNotEmpty) {
              fetchedRemarks = remarksList.join(', ');
            }
          }
          
          if (otherWtVal == 0.0) {
            if (data['otherWt'] != null && (data['otherWt'] as num).toDouble() > 0) {
              otherWtVal = (data['otherWt'] as num).toDouble();
            } else if (data['stoneWt'] != null && (data['stoneWt'] as num).toDouble() > 0) {
              otherWtVal = (data['stoneWt'] as num).toDouble();
            } else {
              otherWtVal = (gross - net).clamp(0.0, double.infinity);
            }
          }
          
          _otherWtCtrl.text = otherWtVal.toStringAsFixed(3);
          _otherWtChecked = otherWtVal > 0.0;
          
          for (final sr in _subRows) {
            _removeSubRowListener(sr);
            sr.dispose();
          }
          _subRows.clear();
          
          if (_otherWtChecked) {
            if (rawExtra is List && rawExtra.isNotEmpty) {
              for (var charge in rawExtra) {
                if (charge is Map) {
                  final w = ((charge['weight'] ?? charge['wt'] ?? 0.0) as num).toDouble();
                  final p = ((charge['pcs'] ?? 1) as num).toInt();
                  final name = (charge['styleName'] ?? charge['name'] ?? 'Less Wt').toString().trim();
                  final rem = (charge['remarks'] ?? '').toString().trim();
                  
                  final matchingStyle = _extraStyles.firstWhere(
                    (s) => s.toUpperCase().replaceAll(' ', '') == name.toUpperCase().replaceAll(' ', ''),
                    orElse: () {
                      if (!_extraStyles.contains(name) && name.isNotEmpty) {
                        _extraStyles.add(name);
                      }
                      return name.isNotEmpty ? name : 'Less Wt';
                    },
                  );
                  
                  final newSr = OrderSubRowController(
                    styleName: matchingStyle,
                    weight: w.toStringAsFixed(3),
                    pcs: p.toString(),
                    remarks: rem,
                  );
                  _addSubRowListener(newSr);
                  _subRows.add(newSr);
                }
              }
            } else {
              final matchingStyle = _extraStyles.firstWhere(
                (s) => s.toUpperCase().replaceAll(' ', '') == fetchedStyleName.toUpperCase().replaceAll(' ', ''),
                orElse: () => 'Less Wt',
              );
              final newSr = OrderSubRowController(
                styleName: matchingStyle,
                weight: otherWtVal.toStringAsFixed(3),
                pcs: fetchedPcs.toString(),
                remarks: fetchedRemarks,
              );
              _addSubRowListener(newSr);
              _subRows.add(newSr);
            }
          }
          
          if (_subRows.isEmpty) {
            final defSr = OrderSubRowController();
            _addSubRowListener(defSr);
            _subRows.add(defSr);
          }
          
          final purity = data['purity']?.toString() ?? '916.0';
          _purityCtrl.text = purity;
          
          final categoryVal = data['category']?.toString() ?? '';
          if (categoryVal.isNotEmpty) {
            _selectedCategory = categoryVal;
            if (!_categoryOptions.contains(_selectedCategory) && _selectedCategory != null) {
              _categoryOptions.add(_selectedCategory!);
            }
          }
          
          final rawGroup = (data['metalId'] ?? data['metalGroupName'] ?? data['groupName'] ?? data['purity'] ?? data['metalType'] ?? '').toString();
          if (rawGroup.isNotEmpty) {
            final matchMap = _groupOptions.firstWhere(
              (g) => g['metalId']!.toUpperCase().replaceAll(' ', '') == rawGroup.toUpperCase().replaceAll(' ', ''),
              orElse: () => {'metalId': rawGroup, 'groupName': rawGroup},
            );
            if (!_groupOptions.any((g) => g['metalId'] == matchMap['metalId'])) {
              _groupOptions.add(matchMap);
            }
            _selectedGroup = matchMap['metalId'];
          }
          
          _calculateBill();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tag $cleanTag not found in inventory')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching tag details: $e');
    }
  }

  Future<void> _generateVoucherNumber() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('order_entries')
          .get();
      int maxNum = 0;
      for (final doc in snap.docs) {
        final vouNo = doc.data()['voucherNo']?.toString() ?? '';
        final numStr = vouNo.replaceAll(RegExp(r'\D'), '');
        final val = int.tryParse(numStr);
        if (val != null && val < 10000 && val > maxNum) maxNum = val;
      }
      if (mounted) setState(() => _voucherNoCtrl.text = 'ORD-${maxNum + 1}');
    } catch (_) {
      if (mounted) setState(() => _voucherNoCtrl.text = 'ORD-1');
    }
  }

  Future<void> _fetchMasterData() async {
    try {
      final repo = ProductRepository();
      
      // 1. Fetch customers and their states
      final custSnap = await FirebaseFirestore.instance.collection('customers').get();
      final Map<String, String> customerStates = {};
      final customers = custSnap.docs
          .map((d) {
            final data = d.data();
            final name = (data['name'] ?? '').toString();
            final stateVal = (data['state'] ?? data['stateName'] ?? data['city'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              customerStates[name] = stateVal;
            }
            return name;
          })
          .where((n) => n.isNotEmpty && n != 'All')
          .toSet()
          .toList()
        ..sort();

      // 2. Fetch salesmen using ProductRepository
      final salesmen = await repo.getUniqueSalesmen();

      // 3. Fetch unique item names using ProductRepository
      final items = await repo.getUniqueItemNames();

      // 4. Fetch metal groups from metal_groups_master
      final groupsSnap = await FirebaseFirestore.instance.collection('metal_groups_master').get();
      final List<Map<String, String>> groups = [];
      if (groupsSnap.docs.isNotEmpty) {
        for (final doc in groupsSnap.docs) {
          final mId = doc.data()['metalId']?.toString().trim() ?? '';
          final gName = doc.data()['groupName']?.toString().trim() ?? '';
          if (mId.isNotEmpty && gName.isNotEmpty) {
            groups.add({'metalId': mId, 'groupName': gName});
          }
        }
      }
      if (groups.isEmpty) {
        final fallbackList = [
          {'metalId': '18D', 'groupName': 'DIAMOND 18KT JEWELLERY'},
          {'metalId': '22D', 'groupName': 'DIAMOND 22KT JEWELLERY'},
          {'metalId': '18G', 'groupName': 'GOLD 18KT JEWELLERY'},
          {'metalId': '22G', 'groupName': 'GOLD 22KT JEWELLERY'},
          {'metalId': '24KT', 'groupName': 'GOLD-24 TRADING A/C'},
          {'metalId': 'OG', 'groupName': 'OLD-GOLD TRADING A/C'},
          {'metalId': 'REP', 'groupName': 'REPAIRING/SAMPLE(GOLD)'},
          {'metalId': 'DI', 'groupName': 'DIAMOND TRADING A/C'},
          {'metalId': 'ST', 'groupName': 'STONE TRADING A/C'},
          {'metalId': 'OS', 'groupName': 'OLD SILVER TRADING A/C'},
          {'metalId': '100T', 'groupName': 'PURE SILVER TRADING A/C'},
          {'metalId': 'S925', 'groupName': 'SILVER 925'},
          {'metalId': 'OPT', 'groupName': 'OLD PLATINUM'},
          {'metalId': 'PT', 'groupName': 'PLATINUM'},
          {'metalId': 'BR', 'groupName': 'BRANDED'},
        ];
        groups.addAll(fallbackList);
      }

      // 5. Fetch categories from item_prefixes
      final prefixesSnap = await FirebaseFirestore.instance.collection('item_prefixes').get();
      final categoriesSet = <String>{};
      for (final doc in prefixesSnap.docs) {
        final cat = doc.data()['type']?.toString() ?? '';
        if (cat.isNotEmpty) {
          categoriesSet.add(cat);
        }
      }
      if (categoriesSet.isEmpty) {
        categoriesSet.addAll(['Gold Necklaces', 'Gold Chains', 'Bangles & Bracelets', 'Rings & Bands', 'Earrings & Studs']);
      }
      final categories = categoriesSet.toList()..sort();

      // 6. Fetch dynamic style names from extra_styles_master using ProductRepository
      final styleNames = await repo.getUniqueExtraStyles();

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _salesmen = salesmen;
        _items = items;
        _groupOptions = groups;
        _categoryOptions = categories;
        if (styleNames.isNotEmpty) {
          _extraStyles = styleNames;
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        // Header
        'voucherNo': _voucherNoCtrl.text.trim(),
        'voucherDate': _dateCtrl.text.trim(),
        'deliveryDate': _deliveryDateCtrl.text.trim(),
        'narration': _narrationCtrl.text.trim(),
        'subType': _subTypeCtrl.text.trim(),
        'customerName': _selectedCustomer,
        'salesmanName': _selectedSalesman,
        'status': _status,
        'imageUrl': _imageUrl,
        
        // Item
        'itemName': _selectedItem ?? '',
        'group': _selectedGroup ?? '',
        'itemCategory': _selectedCategory ?? '',
        'tagId': _tagIdCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        'otherWtChecked': _otherWtChecked,
        'styleName': _subRows.isNotEmpty ? _subRows.first.styleNameCtrl.text.trim() : 'Less Wt',
        'styleWt': _subRows.isNotEmpty ? (double.tryParse(_subRows.first.weightCtrl.text) ?? 0.0) : 0.0,
        'otherPcs': _subRows.isNotEmpty ? (int.tryParse(_subRows.first.pcsCtrl.text) ?? 1) : 1,
        'styleRemarks': _subRows.isNotEmpty ? _subRows.first.remarksCtrl.text.trim() : '',
        'extraCharges': _subRows.map((sr) => {
          'styleName': sr.styleNameCtrl.text.trim(),
          'weight': double.tryParse(sr.weightCtrl.text) ?? 0.0,
          'pcs': int.tryParse(sr.pcsCtrl.text) ?? 1,
          'remarks': sr.remarksCtrl.text.trim(),
        }).toList(),
        'pcs': int.tryParse(_pcsCtrl.text) ?? 1,
        
        // Weight
        'grossWt': double.tryParse(_grossWtCtrl.text) ?? 0.0,
        'otherWt': double.tryParse(_otherWtCtrl.text) ?? 0.0,
        'netWt': double.tryParse(_netWtCtrl.text) ?? 0.0,
        'purity': double.tryParse(_purityCtrl.text) ?? 0.0,
        'fineWt': double.tryParse(_fineWtCtrl.text) ?? 0.0,
        
        // Rate & Amount (legacy defaults)
        'metalRate': 0.0,
        'metalAmt': 0.0,
        'labourOn': 'Per Gram (Gross Wt)',
        'labourRate': 0.0,
        'labourAmt': 0.0,
        'otherCharge': 0.0,
        'discountAmt': 0.0,
        'billAmount': 0.0,
        
        // Payment / Advance (legacy defaults)
        'receiptNo': '',
        'receivedAmt': 0.0,
        'chequeRefNo': '',
        'advanceAmount': 0.0,
        'paymentMode': 'None',
        'accountBook': 'None',
        
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docId = widget.existing?['docId'] as String?;
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('order_entries')
            .doc(docId)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('order_entries').add(data);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1100 ? screenWidth * 0.95 : 900.0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: dialogWidth,
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(
          children: [
            // ── Title Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isEdit
                        ? 'Edit Order — ${widget.existing!['voucherNo']}'
                        : 'New Customer Order Booking',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // ── Body Area ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IgnorePointer(
                  ignoring: widget.isViewOnly,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (Form Fields) - SCROLLABLE
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionWrapper(
                                  title: '① Voucher Header',
                                  child: _buildHeaderSection(),
                                ),
                                _buildSectionWrapper(
                                  title: '② Item Details & Weights',
                                  child: _buildItemDetailsTableSection(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Column (Weight Summary Card) - STICKY / FIXED
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionWrapper(
                              title: 'Weight Summary',
                              child: _buildBillingSummaryCard(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer Buttons ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(widget.isViewOnly ? 'Close' : 'Cancel'),
                  ),
                  if (!widget.isViewOnly) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 14),
                      label: Text(
                        _saving ? 'Saving…' : 'Save Order',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionWrapper({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF2EDE6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _brown,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 1 – VOUCHER HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Voucher Details'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field('Voucher No', _voucherNoCtrl, readOnly: true),
            ),
            const SizedBox(width: 12),
            Expanded(child: _dateField('Voucher Date', _dateCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _dateField('Delivery Date', _deliveryDateCtrl)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _field('Sub Type', _subTypeCtrl)),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownField<String>(
                'Status',
                _status,
                _statusOptions,
                (v) => setState(() => _status = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'Narration / Remarks',
                _narrationCtrl,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Customer & Salesman'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _searchableDropdown(
                'Customer Name',
                _customers,
                _selectedCustomer,
                (v) {
                  setState(() {
                    _selectedCustomer = v;
                    _calculateBill();
                  });
                },
                hint: 'Select Customer',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _searchableDropdown(
                'Salesman Name',
                _salesmen,
                _selectedSalesman,
                (v) => setState(() => _selectedSalesman = v),
                hint: 'Select Salesman',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Order Image'),
        const SizedBox(height: 8),
        _buildImagePicker(),
      ],
    );
  }

  Widget _buildItemDetailsTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Group',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _brownLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: DropdownButtonFormField<String>(
                      initialValue: (_selectedGroup != null && _groupOptions.any((g) => g['metalId'] == _selectedGroup)) ? _selectedGroup : null,
                      decoration: _inputDecoration(),
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      dropdownColor: Colors.white,
                      hint: const Text('Select Group', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      items: _groupOptions.map((g) {
                        final metalId = g['metalId'] ?? '';
                        final groupName = g['groupName'] ?? '';
                        return DropdownMenuItem<String>(
                          value: metalId,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEBE6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFF7D9CC)),
                                ),
                                child: Text(
                                  metalId,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD35400),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                groupName,
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedGroup = v;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Category',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _brownLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _categoryOptions;
                        }
                        return _categoryOptions.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      initialValue: TextEditingValue(text: _selectedCategory ?? ''),
                      onSelected: (String selection) {
                        setState(() {
                          _selectedCategory = selection;
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (textEditingController.text != (_selectedCategory ?? '')) {
                            textEditingController.text = _selectedCategory ?? '';
                          }
                        });
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: 12),
                          onChanged: (val) {
                            _selectedCategory = val;
                          },
                          decoration: _inputDecoration(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: const Color(0xFFF2EDE6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: const Row(
                      children: [
                        SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 110, child: Text('Tag ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 160, child: Text('Item Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('Gross Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 60, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 40, child: Text('O.W.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('Other Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('Net Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('Purity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('Fine Wt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                        SizedBox(width: 8),
                        Expanded(child: Text('Remarks / Narration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 30, child: Text('1', style: TextStyle(fontSize: 11, color: Colors.grey))),
                        SizedBox(
                          width: 110,
                          height: 30,
                          child: TextFormField(
                            controller: _tagIdCtrl,
                            style: const TextStyle(fontSize: 11),
                            onFieldSubmitted: (v) => _fetchTagDetails(v),
                            decoration: _inputDecoration().copyWith(
                              hintText: 'Tag ID',
                              suffixIcon: InkWell(
                                onTap: () async {
                                  String? res = await openQrScanner(context);
                                  if (res != null && res != '-1' && res.isNotEmpty) {
                                    final cleanTag = parseScannedTagId(res);
                                    _tagIdCtrl.text = cleanTag;
                                    _fetchTagDetails(cleanTag);
                                  }
                                },
                                child: const Icon(Icons.qr_code_scanner, size: 12, color: _brownLight),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 160,
                          height: 30,
                          child: DropdownButtonFormField<String>(
                            initialValue: (_selectedItem != null && _items.contains(_selectedItem)) ? _selectedItem : null,
                            hint: const Text('Select Item', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            items: _items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (val) => setState(() => _selectedItem = val),
                            decoration: _inputDecoration(),
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                            dropdownColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, height: 30, child: TextFormField(controller: _grossWtCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        SizedBox(width: 60, height: 30, child: TextFormField(controller: _pcsCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: _otherWtChecked,
                            activeColor: _brown,
                            onChanged: (val) {
                              setState(() {
                                _otherWtChecked = val ?? false;
                                if (!_otherWtChecked) {
                                  for (final sr in _subRows) {
                                    sr.weightCtrl.text = '0.000';
                                  }
                                }
                                _calculateBill();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, height: 30, child: TextFormField(controller: _otherWtCtrl, readOnly: _otherWtChecked, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, height: 30, child: TextFormField(controller: _netWtCtrl, readOnly: true, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, height: 30, child: TextFormField(controller: _purityCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, height: 30, child: TextFormField(controller: _fineWtCtrl, readOnly: true, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: _inputDecoration())),
                        const SizedBox(width: 8),
                        Expanded(child: SizedBox(height: 30, child: TextFormField(controller: _remarksCtrl, style: const TextStyle(fontSize: 11), decoration: _inputDecoration()))),
                      ],
                    ),
                  ),
                  if (_otherWtChecked)
                    ..._subRows.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final sr = entry.value;
                      final prefix = idx == 0 ? '↳ Other Wt. Style Name: ' : '↳ Additional Style Name: ';
                      return Container(
                        padding: const EdgeInsets.only(left: 40, right: 8, bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              prefix,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brownLight),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _addNewSubRow,
                              child: const Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _removeSubRow(idx),
                              child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 140,
                              height: 30,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _extraStyles.contains(sr.styleNameCtrl.text) ? sr.styleNameCtrl.text : 'Less Wt',
                                items: _extraStyles.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
                                onChanged: (val) => setState(() => sr.styleNameCtrl.text = val ?? 'Less Wt'),
                                decoration: _inputDecoration(),
                                dropdownColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              height: 30,
                              child: TextFormField(
                                controller: sr.weightCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11),
                                decoration: _inputDecoration().copyWith(hintText: 'Weight'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              height: 30,
                              child: TextFormField(
                                controller: sr.pcsCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 11),
                                decoration: _inputDecoration().copyWith(hintText: 'Pcs'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: TextFormField(
                                  controller: sr.remarksCtrl,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: _inputDecoration().copyWith(hintText: 'Remarks'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note: Customer Order booking is saved as one item per order entry.')),
                  );
                }
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Row', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _brown),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillingSummaryCard() {
    final grossWt = double.tryParse(_grossWtCtrl.text) ?? 0.0;
    final otherWt = double.tryParse(_otherWtCtrl.text) ?? 0.0;
    final netWt = double.tryParse(_netWtCtrl.text) ?? 0.0;
    final fineWt = double.tryParse(_fineWtCtrl.text) ?? 0.0;
    final pcs = int.tryParse(_pcsCtrl.text) ?? 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6ED),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total Quantity', '$pcs pcs'),
          const SizedBox(height: 4),
          _buildSummaryRow('Gross Weight', '${grossWt.toStringAsFixed(3)} g'),
          const SizedBox(height: 4),
          _buildSummaryRow('Other Weight', '${otherWt.toStringAsFixed(3)} g'),
          const SizedBox(height: 4),
          _buildSummaryRow('Net Weight', '${netWt.toStringAsFixed(3)} g', isBold: true, color: _brown),
          const SizedBox(height: 4),
          _buildSummaryRow('Purity', _purityCtrl.text.isNotEmpty ? _purityCtrl.text : '916.0'),
          const Divider(color: _border, height: 12),
          _buildSummaryRow('Fine Weight', '${fineWt.toStringAsFixed(3)} g', isBold: true, color: Colors.brown.shade800),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _brownLight, fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // IMAGE PICKER WIDGET
  // ══════════════════════════════════════════════════════
  Widget _buildImagePicker() {
    return Row(
      children: [
        if (_imageUrl != null && _imageUrl!.isNotEmpty)
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(_imageUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
          label: Text(
            _imageUrl != null ? 'Change Image' : 'Upload Image',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _brown,
            side: const BorderSide(color: _brown),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _imageUrl = null),
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            label: const Text(
              'Remove',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) {
        return;
      }
      final url = await CloudinaryService().uploadXFile(
        picked,
        resourceType: 'image',
      );
      if (url != null && mounted) {
        setState(() => _imageUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════
  Widget _sectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _brown,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1.5,
          width: 120,
          color: _brown.withValues(alpha: 0.25),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: true,
          style: const TextStyle(fontSize: 12),
          decoration: _inputDecoration().copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today, size: 14, color: _brown),
              onPressed: () async {
                final parsed =
                    DateFormat('dd/MM/yyyy').tryParse(ctrl.text) ??
                    DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    i.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: _inputDecoration(),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _searchableDropdown(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged, {
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: (value != null && options.contains(value))
              ? value
              : null,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: _inputDecoration(),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          isExpanded: true,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      fillColor: Colors.white,
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        borderSide: const BorderSide(color: _brown, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 1: SUPPLIER ORDER ALLOCATION
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierAllocationSection extends StatefulWidget {
  final AdminState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  const _SupplierAllocationSection({
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  State<_SupplierAllocationSection> createState() =>
      _SupplierAllocationSectionState();
}

class _SupplierAllocationSectionState
    extends State<_SupplierAllocationSection> {
  final List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  // Filters
  final TextEditingController _dateFromCtrl = TextEditingController(
    text: '01/04/2023',
  );
  final TextEditingController _dateToCtrl = TextEditingController(
    text: '30/04/2023',
  );
  String _selectedCustomerFilter = 'All';
  List<String> _customers = [];

  // Checkboxes status filter
  bool _statusPending = true;
  bool _statusAllocated = false;
  bool _statusFinished = false;
  bool _statusAll = false;

  List<String> _suppliers = [];

  // Caching for text editing controllers, focus nodes, and timers for debounced autosave
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, String> _emailSendStatus = {}; // supplierName -> 'idle' | 'sending' | 'success' | 'error'

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchCustomers();
    _fetchAndFilterData();
    _ensureEmailConfigExists();
  }

  Future<void> _ensureEmailConfigExists() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('email_config')
          .get();
      if (!doc.exists) {
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('email_config')
            .set({
          'username': '',
          'appPassword': '',
          'senderName': 'Trilok',
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var f in _focusNodes.values) {
      f.dispose();
    }
    for (var t in _debounceTimers.values) {
      t.cancel();
    }
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    super.dispose();
  }

  void _debouncedUpdateField(String docId, String fieldName, dynamic value) {
    final key = "${docId}_$fieldName";
    if (_debounceTimers[key]?.isActive ?? false) {
      _debounceTimers[key]!.cancel();
    }
    _debounceTimers[key] = Timer(const Duration(milliseconds: 800), () {
      _updateField(docId, fieldName, value);
    });
  }

  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint("Error fetching network image: $e");
    }
    return null;
  }

  Future<pw.Document> _generateSupplierPdf(
    String supplierName,
    List<Map<String, dynamic>> orders,
  ) async {
    final pdf = pw.Document();

    final Map<String, Uint8List> orderImages = {};
    for (var o in orders) {
      final url = o['imageUrl']?.toString() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) {
        final bytes = await _fetchImageBytes(url);
        if (bytes != null) {
          orderImages[o['docId']] = bytes;
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ORDER ALLOCATION SLIP',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E2723'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColor.fromHex('#E5DDD0'), thickness: 1.5),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Supplier: $supplierName',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Text(
                    'TRILOK JEWELLERS',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#5D4037'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Allocated Items:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E2723'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#E5DDD0'),
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#3E2723'),
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headers: [
                  'Vou No.',
                  'Item Name',
                  'Pcs',
                  'Gross Wt',
                  'Net Wt',
                  'Size',
                  'Description / Remarks',
                  'Deliv Date',
                ],
                data: orders.map((o) {
                  final vouNo = o['voucherNo']?.toString() ?? '—';
                  final itemName = o['itemName']?.toString() ?? '—';
                  final pcs = o['pcs']?.toString() ?? '—';
                  final grossWt = o['grossWeight']?.toString() ?? '0.000';
                  final netWt = o['netWeight']?.toString() ?? '0.000';
                  final size = o['size']?.toString() ?? '—';
                  final remarks = o['supplierRemarks']?.toString() ?? o['description']?.toString() ?? '';
                  final delDate = o['supplierDeliveryDate']?.toString() ?? o['deliveryDate']?.toString() ?? '—';
                  return [
                    vouNo,
                    itemName,
                    pcs,
                    '${grossWt}g',
                    '${netWt}g',
                    size,
                    remarks,
                    delDate,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    for (var o in orders) {
      final imgBytes = orderImages[o['docId']];
      if (imgBytes != null) {
        final vouNo = o['voucherNo']?.toString() ?? '—';
        final itemName = o['itemName']?.toString() ?? '—';

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              final image = pw.MemoryImage(imgBytes);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'ITEM IMAGE SPECIFICATION',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#3E2723'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Voucher No: $vouNo | Item: $itemName',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Divider(color: PdfColor.fromHex('#E5DDD0')),
                    ],
                  ),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Container(
                        height: 450,
                        width: 450,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColor.fromHex('#E5DDD0'),
                            width: 1,
                          ),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(8),
                          ),
                        ),
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Trilok Jewellers - Supplier Copy',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf;
  }

  Future<void> _sendAutomatedEmail({
    required String supplierName,
    required String recipientEmail,
    required String messageText,
    required List<Map<String, dynamic>> orders,
  }) async {
    setState(() {
      _emailSendStatus[supplierName] = 'sending';
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('email_config')
          .get();

      if (!doc.exists) {
        throw Exception(
          "Email SMTP config not found. Please create 'settings/email_config' document in Firestore."
        );
      }

      final data = doc.data()!;
      final username = data['username']?.toString() ?? '';
      final appPassword = data['appPassword']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? 'Trilok';

      if (username.isEmpty || appPassword.isEmpty) {
        throw Exception("SMTP username or appPassword is empty in Firestore 'settings/email_config'.");
      }

      // Generate the PDF
      final pdf = await _generateSupplierPdf(supplierName, orders);
      final pdfBytes = await pdf.save();
      
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/Order_Allocation_${supplierName.replaceAll(' ', '_')}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      final smtpServer = gmail(username, appPassword);
      final message = Message()
        ..from = Address(username, senderName)
        ..recipients.add(recipientEmail.trim())
        ..subject = 'Supplier Order Allocation Details - Trilok'
        ..text = messageText
        ..attachments.add(FileAttachment(tempFile));

      await send(message, smtpServer);

      setState(() {
        _emailSendStatus[supplierName] = 'success';
      });
    } catch (e) {
      debugPrint("Error sending automatic email: $e");
      setState(() {
        _emailSendStatus[supplierName] = 'error';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email to $supplierName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareSelectedOrders() async {
    final selectedOrders = _orders.where((o) => o['sendEmailSms'] == true).toList();
    if (selectedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders selected for sharing. Check the "Send Email / SMS" column.')),
      );
      return;
    }

    // Uncheck all selected orders in local state immediately so they are cleared in the background
    setState(() {
      for (var o in _orders) {
        o['sendEmailSms'] = false;
      }
    });

    final supplierNames = selectedOrders
        .map((o) => o['supplierName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    if (supplierNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected orders do not have any supplier assigned.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final Map<String, Map<String, dynamic>> supplierDetails = {};
    String emailUsername = '';
    String emailAppPassword = '';
    String emailSenderName = 'Trilok';

    try {
      // Load current SMTP configuration
      final configDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('email_config')
          .get();
      if (configDoc.exists) {
        final data = configDoc.data()!;
        emailUsername = data['username']?.toString() ?? '';
        emailAppPassword = data['appPassword']?.toString() ?? '';
        emailSenderName = data['senderName']?.toString() ?? 'Trilok';
      }

      for (var name in supplierNames) {
        final snap = await FirebaseFirestore.instance
            .collection('suppliers')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          supplierDetails[name] = snap.docs.first.data();
        }
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      setState(() => _isLoading = false);
    }

    final Map<String, List<Map<String, dynamic>>> supplierToOrders = {};
    for (var order in selectedOrders) {
      final name = order['supplierName']?.toString() ?? '';
      if (name.isNotEmpty) {
        supplierToOrders.putIfAbsent(name, () => []).add(order);
      }
    }

    // Set initial status for dialog
    for (var name in supplierNames) {
      _emailSendStatus.putIfAbsent(name, () => 'idle');
    }

    // Controllers for SMTP configuration form
    final settingsUserCtrl = TextEditingController(text: emailUsername);
    final settingsPassCtrl = TextEditingController(text: emailAppPassword);
    final settingsSenderCtrl = TextEditingController(text: emailSenderName);
    bool showEmailSettings = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    showEmailSettings ? 'SMTP Settings' : 'Share Order Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: showEmailSettings ? 'Back to Share' : 'Configure SMTP Email',
                        icon: Icon(
                          showEmailSettings ? Icons.arrow_back : Icons.settings,
                          color: _brown,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            showEmailSettings = !showEmailSettings;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _brown, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: showEmailSettings
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configure your Gmail SMTP settings to send automatic emails securely.',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: settingsUserCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Gmail Username',
                                hintText: 'example@gmail.com',
                                labelStyle: TextStyle(fontSize: 11, color: _brownLight),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: settingsPassCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Google App Password (16-char)',
                                hintText: 'xxxx xxxx xxxx xxxx',
                                labelStyle: TextStyle(fontSize: 11, color: _brownLight),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: settingsSenderCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Sender Display Name',
                                hintText: 'Trilok MCET',
                                labelStyle: TextStyle(fontSize: 11, color: _brownLight),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brown,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('settings')
                                        .doc('email_config')
                                        .set({
                                      'username': settingsUserCtrl.text.trim(),
                                      'appPassword': settingsPassCtrl.text.trim(),
                                      'senderName': settingsSenderCtrl.text.trim(),
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('SMTP Settings saved successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                    setDialogState(() {
                                      showEmailSettings = false;
                                    });
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to save settings: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  'Save SMTP Settings',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: supplierNames.map((name) {
                            final orders = supplierToOrders[name] ?? [];
                            final details = supplierDetails[name];
                            final phone = details?['mobileNo1']?.toString() ?? '';
                            final email = details?['email1']?.toString() ?? '';

                            final message = _generateShareMessage(name, orders);
                            final emailStatus = _emailSendStatus[name] ?? 'idle';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Phone: ${phone.isNotEmpty ? phone : "Not Found"} | Email: ${email.isNotEmpty ? email : "Not Found"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Items: ${orders.map((o) => o['itemName']).join(", ")} (${orders.length} items)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // WhatsApp Button (Semi-Automatic)
                                      ElevatedButton.icon(
                                        onPressed: phone.isEmpty ? null : () async {
                                          final text = Uri.encodeComponent(message);
                                          var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                                          if (cleanPhone.length == 10) {
                                            cleanPhone = '91$cleanPhone';
                                          }
                                          final url = 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$text';
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
                                        icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white),
                                        label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Email Button (Fully Automatic)
                                      ElevatedButton.icon(
                                        onPressed: email.isEmpty || emailStatus == 'sending' ? null : () async {
                                          setDialogState(() {
                                            _emailSendStatus[name] = 'sending';
                                          });
                                          await _sendAutomatedEmail(
                                            supplierName: name,
                                            recipientEmail: email,
                                            messageText: message,
                                            orders: orders,
                                          );
                                          setDialogState(() {});
                                        },
                                        icon: _buildEmailButtonIcon(emailStatus),
                                        label: _buildEmailButtonLabel(emailStatus),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: emailStatus == 'success'
                                              ? Colors.blue[700]
                                              : _brown,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmailButtonIcon(String status) {
    if (status == 'sending') {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
      );
    }
    if (status == 'success') {
      return const Icon(Icons.check, size: 14, color: Colors.white);
    }
    if (status == 'error') {
      return const Icon(Icons.error_outline, size: 14, color: Colors.white);
    }
    return const Icon(Icons.email_outlined, size: 14, color: Colors.white);
  }

  Widget _buildEmailButtonLabel(String status) {
    if (status == 'sending') {
      return const Text('Sending...', style: TextStyle(fontSize: 11, color: Colors.white));
    }
    if (status == 'success') {
      return const Text('Sent', style: TextStyle(fontSize: 11, color: Colors.white));
    }
    if (status == 'error') {
      return const Text('Retry', style: TextStyle(fontSize: 11, color: Colors.white));
    }
    return const Text('Send Email', style: TextStyle(fontSize: 11, color: Colors.white));
  }

  String _generateShareMessage(String supplierName, List<Map<String, dynamic>> orders) {
    final sb = StringBuffer();
    sb.writeln("Dear $supplierName,");
    sb.writeln();
    sb.writeln("Please find the order allocation details below:");
    sb.writeln("──────────────────────────");
    
    for (var o in orders) {
      final vouNo = o['voucherNo']?.toString() ?? '—';
      final itemName = o['itemName']?.toString() ?? '—';
      final pcs = o['pcs']?.toString() ?? '—';
      final grossWt = o['grossWeight']?.toString() ?? '0.000';
      final netWt = o['netWeight']?.toString() ?? '0.000';
      final size = o['size']?.toString() ?? '—';
      final delDate = o['supplierDeliveryDate']?.toString() ?? o['deliveryDate']?.toString() ?? '—';
      final desc = o['description']?.toString() ?? '';
      final remarks = o['supplierRemarks']?.toString() ?? '';
      
      sb.writeln("Voucher No: $vouNo");
      sb.writeln("Item Name: $itemName");
      sb.writeln("Pcs: $pcs");
      sb.writeln("Gross Wt: ${grossWt}g | Net Wt: ${netWt}g");
      if (size != '—' && size.isNotEmpty) sb.writeln("Size: $size");
      if (desc.isNotEmpty && desc != '—') sb.writeln("Desc: $desc");
      if (remarks.isNotEmpty && remarks != '—') sb.writeln("Remarks: $remarks");
      sb.writeln("Delivery Date: $delDate");
      sb.writeln("──────────────────────────");
    }
    
    sb.writeln("Thank you!");
    return sb.toString();
  }

  @override
  void didUpdateWidget(covariant _SupplierAllocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab == 1 && oldWidget.activeTab != 1) {
      _fetchAndFilterData();
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _customers = ['All'] + list.toSet().toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchSuppliers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('suppliers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _suppliers = list.toSet().toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchAndFilterData() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('order_entries')
          .get();
      final List<Map<String, dynamic>> loaded = [];

      for (var doc in snap.docs) {
        final d = doc.data();
        d['docId'] = doc.id;
        d['sendEmailSms'] = false;

        // Apply filters
        final cust = d['customerName']?.toString() ?? 'Walk-in';
        if (_selectedCustomerFilter != 'All' &&
            cust != _selectedCustomerFilter) {
          continue;
        }

        final status = d['status']?.toString() ?? 'Pending';
        if (!_statusAll) {
          bool keep = false;
          if (_statusPending &&
              (status == 'Pending' || status == 'Allocate To Supplier')) {
            keep = true;
          }
          if (_statusAllocated && status == 'Allocate To Customer') {
            keep = true;
          }
          if (_statusFinished &&
              (status == 'Finished' || status == 'Order Sold')) {
            keep = true;
          }
          if (!keep) {
            continue;
          }
        }

        loaded.add(d);
      }

      // Sort by voucherNumber descending (newest first)
      loaded.sort((a, b) {
        final aNum =
            int.tryParse(
              (a['voucherNumber']?.toString() ?? '').replaceAll(
                RegExp(r'[^0-9]'),
                '',
              ),
            ) ??
            0;
        final bNum =
            int.tryParse(
              (b['voucherNumber']?.toString() ?? '').replaceAll(
                RegExp(r'[^0-9]'),
                '',
              ),
            ) ??
            0;
        return bNum.compareTo(aNum);
      });

      setState(() {
        _orders.clear();
        _orders.addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: 1,
                      icon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: _brown,
                        size: 20,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'Customer Order Bookings',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Supplier Order Allocation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Customer Order Allocation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            'Gold Rate Fixing Advances',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text(
                            'Advance Refunds',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) widget.onTabChanged(val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Row 1
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _dateFromCtrl,
                      decoration: _inputDecoration('Date From'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _dateToCtrl,
                      decoration: _inputDecoration('To'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Customer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    height: 28,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerFilter,
                      decoration: _inputDecoration(''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      items: _customers
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCustomerFilter = val);
                          _fetchAndFilterData();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter Row 2 (Status Checkboxes)
              Row(
                children: [
                  _buildCheckbox('Pending', _statusPending, (v) {
                    setState(() => _statusPending = v ?? false);
                    _fetchAndFilterData();
                  }),
                  _buildCheckbox('Allocated', _statusAllocated, (v) {
                    setState(() => _statusAllocated = v ?? false);
                    _fetchAndFilterData();
                  }),
                  _buildCheckbox('Finished', _statusFinished, (v) {
                    setState(() => _statusFinished = v ?? false);
                    _fetchAndFilterData();
                  }),
                  _buildCheckbox('All', _statusAll, (v) {
                    setState(() => _statusAll = v ?? false);
                    _fetchAndFilterData();
                  }),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _shareSelectedOrders,
                    icon: const Icon(Icons.share, size: 16, color: Colors.white),
                    label: const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Grid table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 3450,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(100), // Vou No.
                                  1: FixedColumnWidth(100), // Vou Date
                                  2: FixedColumnWidth(160), // Party Name
                                  3: FixedColumnWidth(160), // Item Name
                                  4: FixedColumnWidth(130), // Gross Wt. (Aprx)
                                  5: FixedColumnWidth(130), // Net Wt. (Aprx)
                                  6: FixedColumnWidth(90), // Pcs. (Aprx)
                                  7: FixedColumnWidth(200), // Description
                                  8: FixedColumnWidth(140), // Cust. Delivery Date
                                  9: FixedColumnWidth(180), // Sup. Name
                                  10: FixedColumnWidth(130), // Sup. Vou. Date
                                  11: FixedColumnWidth(130), // Sup. Vou. No.
                                  12: FixedColumnWidth(180), // Sup. Remarks
                                  13: FixedColumnWidth(140), // Sup. Deliv. Date
                                  14: FixedColumnWidth(140), // Sup. Ref. Bill No.
                                  15: FixedColumnWidth(80), // Image
                                  16: FixedColumnWidth(120), // Total Advance
                                  17: FixedColumnWidth(140), // Salesman Name
                                  18: FixedColumnWidth(140), // Party Reference
                                  19: FixedColumnWidth(120), // Advance GOLD
                                  20: FixedColumnWidth(130), // Advance DIAMOND
                                  21: FixedColumnWidth(120), // Advance STONE
                                  22: FixedColumnWidth(140), // Send Email / SMS
                                  23: FixedColumnWidth(80), // Size
                                  24: FixedColumnWidth(190), // Status
                                },
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                    color: _border.withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                  verticalInside: BorderSide(
                                    color: _border.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFBF9F6),
                                    ),
                                    children: [
                                      _buildTableCell(
                                        'Vou No.',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Vou Date',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Party Name',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Item Name',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Gross Wt. (Aprx)',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Net Wt. (Aprx)',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Pcs. (Aprx)',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Description',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Cust. Delivery Date',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Name',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Vou. Date',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Vou. No.',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Remarks',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Deliv. Date',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Sup. Ref. Bill No.',
                                        isHeader: true,
                                      ),
                                      _buildTableCell('Image', isHeader: true),
                                      _buildTableCell(
                                        'Total Advance',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Salesman Name',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Party Reference',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Advance GOLD',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Advance DIAMOND',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Advance STONE',
                                        isHeader: true,
                                      ),
                                      _buildTableCell(
                                        'Send Email / SMS',
                                        isHeader: true,
                                      ),
                                      _buildTableCell('Size', isHeader: true),
                                      _buildTableCell('Status', isHeader: true),
                                    ],
                                  ),
                                  ..._orders.map((item) {
                                    final id = item['docId'];
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: _getRowColor(item['status']),
                                      ),
                                      children: [
                                        _buildTableCell(
                                          item['voucherNo']?.toString() ?? '—',
                                        ),
                                        _buildTableCell(
                                          item['voucherDate']?.toString() ??
                                              '—',
                                        ),
                                        _buildTableCell(
                                          item['customerName']?.toString() ??
                                              '—',
                                        ),
                                        _buildTableCell(
                                          item['itemName']?.toString() ?? '—',
                                        ),
                                        _buildTableCell(
                                          item['grossWeight']?.toString() ??
                                              '0.000',
                                        ),
                                        _buildTableCell(
                                          item['netWeight']?.toString() ??
                                              '0.000',
                                        ),
                                        _buildTableCell(
                                          item['pcs']?.toString() ?? '0',
                                        ),
                                        _buildTableCell(
                                          item['description']?.toString() ??
                                              '—',
                                        ),
                                        _buildTableCell(
                                          item['deliveryDate']?.toString() ??
                                              '—',
                                        ),
                                        _buildInlineSupplierCell(
                                          id,
                                          item['supplierName']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineDatePickerCell(
                                          context,
                                          id,
                                          'supplierVouDate',
                                          item['supplierVouDate']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'supplierVouNo',
                                          item['supplierVouNo']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'supplierRemarks',
                                          item['supplierRemarks']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineDatePickerCell(
                                          context,
                                          id,
                                          'supplierDeliveryDate',
                                          item['supplierDeliveryDate']
                                                  ?.toString() ??
                                              '',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'supplierRefBillNo',
                                          item['supplierRefBillNo']
                                                  ?.toString() ??
                                              '',
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                            vertical: 4.0,
                                          ),
                                          child:
                                              item['imageUrl'] != null &&
                                                  item['imageUrl']
                                                      .toString()
                                                      .isNotEmpty
                                              ? Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Image.network(
                                                        item['imageUrl']
                                                            .toString(),
                                                        width: 24,
                                                        height: 24,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 16,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 12,
                                                        color: Colors.grey,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      onPressed: () =>
                                                          _pickAndUploadImage(
                                                            id,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                              : IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                    size: 16,
                                                    color: _brown,
                                                  ),
                                                  onPressed: () =>
                                                      _pickAndUploadImage(id),
                                                ),
                                        ),
                                        _buildTableCell(
                                          item['advanceAmt']?.toString() ??
                                              '0.00',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'salesmanName',
                                          item['salesmanName']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'partyReference',
                                          item['partyReference']?.toString() ??
                                              '',
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'advanceGold',
                                          item['advanceGold']?.toString() ??
                                              '0.000',
                                          isNumeric: true,
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'advanceDiamond',
                                          item['advanceDiamond']?.toString() ??
                                              '0.00',
                                          isNumeric: true,
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'advanceStone',
                                          item['advanceStone']?.toString() ??
                                              '0.00',
                                          isNumeric: true,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                            horizontal: 4.0,
                                          ),
                                          child: Checkbox(
                                            value: item['sendEmailSms'] == true,
                                            activeColor: _brown,
                                            onChanged: (val) {
                                              setState(() {
                                                item['sendEmailSms'] = val ?? false;
                                              });
                                            },
                                          ),
                                        ),
                                        _buildInlineTextCell(
                                          id,
                                          'size',
                                          item['size']?.toString() ?? '',
                                        ),
                                        _buildInlineStatusCell(
                                          id,
                                          item['status']?.toString() ??
                                              'Pending',
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                              if (_orders.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.0),
                                  child: Center(
                                    child: Text(
                                      'No orders found matching filters.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: Row(
            children: [
              _buildLegendColor(
                const Color(0xFFFFF7ED),
                'Allocate To Customer',
              ),
              const SizedBox(width: 16),
              _buildLegendColor(
                const Color(0xFFE8F5E9),
                'Allocate To Supplier',
              ),
              const SizedBox(width: 16),
              _buildLegendColor(const Color(0xFFE3F2FD), 'Order Sold'),
              const SizedBox(width: 16),
              _buildLegendColor(const Color(0xFFFFEBEE), 'Order Canceled'),
              const SizedBox(width: 16),
              _buildLegendColor(
                const Color(0xFFEAB308).withValues(alpha: 0.2),
                'Job Canceled',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendColor(Color c, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }

  Color _getRowColor(dynamic status) {
    final s = status?.toString() ?? 'Pending';
    if (s == 'Pending') {
      return const Color(0xFFFFF7ED);
    }
    if (s == 'Allocate To Supplier') {
      return const Color(0xFFE8F5E9);
    }
    if (s == 'Allocate To Customer' || s == 'Finished') {
      return const Color(0xFFE3F2FD);
    }
    if (s.contains('Canceled')) {
      return const Color(0xFFFFEBEE);
    }
    return Colors.white;
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      children: [
        Checkbox(value: value, activeColor: _brown, onChanged: onChanged),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label.isNotEmpty ? label : null,
      labelStyle: const TextStyle(fontSize: 11, color: _brownLight),
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
        borderSide: const BorderSide(color: _brown),
      ),
    );
  }

  Future<void> _updateField(
    String docId,
    String fieldName,
    dynamic value,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('order_entries')
          .doc(docId)
          .update({fieldName: value});
      // Always update local state immediately so the row stays visible
      // with the new value (regardless of current filter).
      // The filter re-applies naturally on the next tab switch.
      setState(() {
        final index = _orders.indexWhere((o) => o['docId'] == docId);
        if (index != -1) {
          _orders[index][fieldName] = value;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update field: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(String docId) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
      }

      final service = CloudinaryService();
      final url = await service.uploadXFile(file, resourceType: 'image');
      if (url != null) {
        await _updateField(docId, 'imageUrl', url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildInlineSupplierCell(String docId, String currentValue) {
    final items = List<String>.from(_suppliers);
    final normalizedValue = currentValue.isEmpty
        ? 'Not Allocated'
        : currentValue;
    if (!items.contains(normalizedValue)) {
      items.add(normalizedValue);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: SizedBox(
        height: 32,
        child: DropdownButton<String>(
          value: normalizedValue,
          isExpanded: true,
          isDense: true,
          underline: Container(height: 1, color: _border),
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          items: items
              .map(
                (name) => DropdownMenuItem(
                  value: name,
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              _updateField(
                docId,
                'supplierName',
                val == 'Not Allocated' ? '' : val,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildInlineDatePickerCell(
    BuildContext context,
    String docId,
    String fieldName,
    String currentValue,
  ) {
    final controller = TextEditingController(
      text: currentValue == '—' ? '' : currentValue,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: SizedBox(
        height: 32,
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _border),
            ),
            suffixIcon: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.calendar_today, size: 14, color: _brown),
              onPressed: () async {
                final parsedDate =
                    DateFormat('dd/MM/yyyy').tryParse(controller.text) ??
                    DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate: parsedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  final formatted = DateFormat('dd/MM/yyyy').format(date);
                  controller.text = formatted;
                  _updateField(docId, fieldName, formatted);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTextCell(
    String docId,
    String fieldName,
    String currentValue, {
    bool isNumeric = false,
  }) {
    final key = "${docId}_$fieldName";
    final val = currentValue == '—' ? '' : currentValue;
    final controller = _controllers.putIfAbsent(key, () => TextEditingController(text: val));
    final focusNode = _focusNodes.putIfAbsent(key, () => FocusNode());

    // Update the controller text only if not currently focused by user
    if (!focusNode.hasFocus && controller.text != val) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = val;
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: SizedBox(
        height: 32,
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              if (_debounceTimers[key]?.isActive ?? false) {
                _debounceTimers[key]!.cancel();
              }
              final entered = controller.text.trim();
              _updateField(
                docId,
                fieldName,
                isNumeric ? (double.tryParse(entered) ?? 0.0) : entered,
              );
            }
          },
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
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
                borderSide: const BorderSide(color: _brown),
              ),
            ),
            onChanged: (text) {
              final entered = text.trim();
              final calculated = isNumeric ? (double.tryParse(entered) ?? 0.0) : entered;
              _debouncedUpdateField(docId, fieldName, calculated);
            },
            onFieldSubmitted: (val) {
              if (_debounceTimers[key]?.isActive ?? false) {
                _debounceTimers[key]!.cancel();
              }
              _updateField(
                docId,
                fieldName,
                isNumeric ? (double.tryParse(val) ?? 0.0) : val.trim(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInlineStatusCell(String docId, String currentValue) {
    const statusList = [
      'Pending',
      'Allocate To Supplier',
      'Allocate To Customer',
      'Order Sold',
      'Finished',
      'Order Canceled',
      'Job Canceled',
    ];
    // If stored value not in list, show it as-is by adding it dynamically
    final items = List<String>.from(statusList);
    if (!items.contains(currentValue) && currentValue.isNotEmpty) {
      items.insert(0, currentValue);
    }
    final safeValue = items.contains(currentValue) ? currentValue : 'Pending';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: SizedBox(
        height: 32,
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          isDense: true,
          underline: Container(height: 1, color: _border),
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          items: items
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(
                    status,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              _updateField(docId, 'status', val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? _brown : Colors.black87,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 1: SUPPLIER ORDER ALLOCATION (PLACEHOLDER - preserved from original)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 2: CUSTOMER ORDER ALLOCATION
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerAllocationSection extends StatefulWidget {
  final AdminState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  const _CustomerAllocationSection({
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  State<_CustomerAllocationSection> createState() =>
      _CustomerAllocationSectionState();
}

class _CustomerAllocationSectionState
    extends State<_CustomerAllocationSection> {
  final List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAllocatedOrders();
  }

  @override
  void didUpdateWidget(covariant _CustomerAllocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab == 2 && oldWidget.activeTab != 2) {
      _fetchAllocatedOrders();
    }
  }

  Future<void> _fetchAllocatedOrders() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('order_entries')
          .where('status', isEqualTo: 'Allocate To Customer')
          .get();
      final loaded = snap.docs.map((doc) {
        final d = doc.data();
        d['docId'] = doc.id;
        return d;
      }).toList();
      setState(() {
        _orders.clear();
        _orders.addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeAllocation(String docId, String nextStatus) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('order_entries')
          .doc(docId)
          .update({'status': nextStatus});
      await _fetchAllocatedOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order Status updated successfully!')),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: 2,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: _brown,
                size: 20,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(6),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _brown,
              ),
              items: const [
                DropdownMenuItem(
                  value: 0,
                  child: Text(
                    'Customer Order Bookings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Text(
                    'Supplier Order Allocation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text(
                    'Customer Order Allocation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text(
                    'Gold Rate Fixing Advances',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 4,
                  child: Text(
                    'Advance Refunds',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) widget.onTabChanged(val);
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : _orders.isEmpty
                  ? const Center(
                      child: Text('No orders pending customer delivery.'),
                    )
                  : ListView.separated(
                      itemCount: _orders.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _orders[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          title: Text(
                            '${item['customerName']} — ${item['itemName']} (${item['pcs']} Pcs)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Voucher No: ${item['voucherNo']} | Supplier: ${item['supplierName']} | Delivery Date: ${item['deliveryDate']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => _completeAllocation(
                                  item['docId'],
                                  'Order Sold',
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.green),
                                  foregroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Mark Sold',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _completeAllocation(
                                  item['docId'],
                                  'Finished',
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _brown),
                                  foregroundColor: _brown,
                                ),
                                child: const Text(
                                  'Complete Allocation',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 3: ORDER ADVANCE (RATE FIXING) ENTRY
// ─────────────────────────────────────────────────────────────────────────────

class _OrderAdvanceSection extends StatefulWidget {
  final AdminState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  const _OrderAdvanceSection({
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  State<_OrderAdvanceSection> createState() => _OrderAdvanceSectionState();
}

class _OrderAdvanceSectionState extends State<_OrderAdvanceSection> {
  final List<Map<String, dynamic>> _advances = [];
  bool _isLoading = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAdvances();
  }

  @override
  void didUpdateWidget(covariant _OrderAdvanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab == 3 && oldWidget.activeTab != 3) {
      _fetchAdvances();
    }
  }

  Future<void> _fetchAdvances() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .orderBy('createdAt', descending: true)
          .get();
      final loaded = snap.docs.map((doc) {
        final d = doc.data();
        d['docId'] = doc.id;
        return d;
      }).toList();
      setState(() {
        _advances.clear();
        _advances.addAll(loaded);
        _selectedIndex = null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildActionButton(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
    return Material(
      color: const Color(0xFFFAF7F2),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareAdvance(Map<String, dynamic> item) {
    final receiptNo = item['receiptNo'] ?? '';
    final date = item['date'] ?? '';
    final customer = item['customerName'] ?? '';
    final amount = item['amount'] ?? '0.00';
    final fixedRate = item['fixedRate'] ?? '0.00';
    final fixedWeight = item['fixedWeight'] ?? '0.000';
    final mode = item['paymentMode'] ?? 'Cash';

    final text = '💰 *Gold Rate Fixing Advance Receipt*\n'
        'Receipt No: $receiptNo\n'
        'Date: $date\n'
        'Customer: $customer\n'
        'Amount: ₹$amount\n'
        'Fixed Rate/gm: ₹$fixedRate\n'
        'Fixed Weight: $fixedWeight g\n'
        'Payment Mode: $mode\n'
        'Trilok Jewellers';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Advance Details'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Advance receipt details copied to clipboard!')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: DropdownButtonFormField<int>(
                    initialValue: widget.activeTab,
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          'Customer Order Bookings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          'Supplier Order Allocation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          'Customer Order Allocation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          'Gold Rate Fixing Advances',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text(
                          'Advance Refunds',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) widget.onTabChanged(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildActionButton(Icons.add, 'Add', onTap: () => _showNewAdvanceDialog(context)),
                  _buildActionButton(Icons.share, 'Share', iconColor: Colors.teal, onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _advances.length) {
                      _shareAdvance(_advances[_selectedIndex!]);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an advance record to share.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _advances.length) {
                      _showNewAdvanceDialog(context, existing: _advances[_selectedIndex!]);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an advance record to modify.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.visibility_outlined, 'View', iconColor: Colors.blueAccent, onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _advances.length) {
                      _showNewAdvanceDialog(context, existing: _advances[_selectedIndex!], isViewOnly: true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an advance record to view.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.print, 'Print', onTap: () async {
                    if (_selectedIndex != null && _selectedIndex! < _advances.length) {
                      final item = _advances[_selectedIndex!];
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await PdfOrderEntryApi.printAdvance(item);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to print advance receipt: $e')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an advance record first to print.')),
                      );
                    }
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2), // Receipt No.
                              1: FlexColumnWidth(1.2), // Date
                              2: FlexColumnWidth(2.2), // Customer
                              3: FlexColumnWidth(1.5), // Advance Amount
                              4: FlexColumnWidth(1.5), // Fixed Rate/gm
                              5: FlexColumnWidth(1.5), // Fixed Weight
                              6: FlexColumnWidth(1.5), // Payment Mode
                              7: FlexColumnWidth(1.8), // Status
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: _border.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBF9F6),
                                ),
                                children: [
                                  _buildTableCell('Receipt No.', isHeader: true),
                                  _buildTableCell('Date', isHeader: true),
                                  _buildTableCell('Customer', isHeader: true),
                                  _buildTableCell('Advance Amount', isHeader: true),
                                  _buildTableCell('Fixed Rate/gm', isHeader: true),
                                  _buildTableCell('Fixed Weight', isHeader: true),
                                  _buildTableCell('Payment Mode', isHeader: true),
                                  _buildTableCell('Status', isHeader: true),
                                ],
                              ),
                              ..._advances.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final isSelected = _selectedIndex == idx;
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFFF3E0) : null,
                                  ),
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['receiptNo']?.toString() ?? '—'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['date']?.toString() ?? '—'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['customerName']?.toString() ?? '—'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['amount']?.toString() ?? '0.00'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['fixedRate']?.toString() ?? '0.00'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['fixedWeight']?.toString() ?? '0.000'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCell(item['paymentMode']?.toString() ?? 'Cash'),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedIndex = idx),
                                      child: _buildTableCellWithColor(
                                        item['status']?.toString() == 'USED'
                                            ? 'USED${item['usedInBillNo'] != null ? ' (${item['usedInBillNo']})' : ''}'
                                            : 'ACTIVE',
                                        item['status']?.toString() == 'USED' ? Colors.grey : Colors.green,
                                        isBold: true,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                          if (_advances.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  'No advance payments found.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? _brown : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTableCellWithColor(String text, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  void _showNewAdvanceDialog(BuildContext context, {Map<String, dynamic>? existing, bool isViewOnly = false}) {
    showDialog(
      context: context,
      builder: (ctx) => _NewAdvanceDialog(
        existing: existing,
        isViewOnly: isViewOnly,
        onSaved: () {
          _fetchAdvances();
        },
      ),
    );
  }
}

class _NewAdvanceDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  final bool isViewOnly;
  const _NewAdvanceDialog({required this.onSaved, this.existing, this.isViewOnly = false});

  @override
  State<_NewAdvanceDialog> createState() => _NewAdvanceDialogState();
}

class _NewAdvanceDialogState extends State<_NewAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _receiptNoCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  String? _selectedCustomer;
  List<String> _customers = [];
  String _paymentMode = 'Cash';
  List<String> _paymentModes = ['Cash', 'UPI', 'Card'];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _receiptNoCtrl.text = 'ADV-1';
    _fetchNextReceiptNo();
    _fetchCustomers();
    _fetchBankNames();
  }

  Future<void> _fetchBankNames() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('book_names')
          .orderBy('name')
          .get();
      final names = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _paymentModes = ['Cash', 'UPI', 'Card', ...names];
      });
    } catch (_) {}
  }

  Future<void> _fetchNextReceiptNo() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .get();
      int maxNum = 0;
      for (final doc in snap.docs) {
        final String rNo = doc.data()['receiptNo']?.toString() ?? '';
        if (rNo.startsWith('ADV-')) {
          final suffix = rNo.substring(4);
          final numVal = int.tryParse(suffix);
          if (numVal != null) {
            if (numVal < 50000) {
              if (numVal > maxNum) {
                maxNum = numVal;
              }
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _receiptNoCtrl.text = 'ADV-${maxNum + 1}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _receiptNoCtrl.text = 'ADV-1';
        });
      }
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _customers = list.toSet().toList();
        if (_customers.isNotEmpty) _selectedCustomer = _customers.first;
      });
    } catch (_) {}
  }

  void _calculateWeight() {
    double amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    double rate = double.tryParse(_rateCtrl.text) ?? 0.0;
    if (rate > 0) {
      _weightCtrl.text = (amt / rate).toStringAsFixed(3);
    } else {
      _weightCtrl.text = '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a customer first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final advanceData = {
        'receiptNo': _receiptNoCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'customerName': _selectedCustomer,
        'amount': double.tryParse(_amountCtrl.text) ?? 0.0,
        'fixedRate': double.tryParse(_rateCtrl.text) ?? 0.0,
        'fixedWeight': double.tryParse(_weightCtrl.text) ?? 0.0,
        'paymentMode': _paymentMode,
        'narration': _narrationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('advance_payments')
          .add(advanceData);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving advance: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Gold Rate Fixing Advance Entry',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _brown,
        ),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Receipt No',
                        _receiptNoCtrl,
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: TextFormField(
                              controller: _dateCtrl,
                              readOnly: true,
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2101),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: _brown,
                                          onPrimary: Colors.white,
                                          onSurface: _brown,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                                  });
                                }
                              },
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration().copyWith(
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(Icons.calendar_month, size: 14, color: _brown),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Name',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCustomer,
                              decoration: _inputDecoration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: _customers
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCustomer = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Mode',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMode,
                              decoration: _inputDecoration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: _paymentModes
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _paymentMode = val ?? 'Cash'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Advance Amount',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: TextFormField(
                              controller: _amountCtrl,
                              onChanged: (_) => _calculateWeight(),
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fixed Rate / gm',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: TextFormField(
                              controller: _rateCtrl,
                              onChanged: (_) => _calculateWeight(),
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Fixed Weight (gm)',
                        _weightCtrl,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField('Narration / Remarks', _narrationCtrl),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _brown),
          child: _saving
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Advance',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: TextFormField(
            controller: ctrl,
            readOnly: readOnly,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
        borderSide: const BorderSide(color: _brown),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW 4: ORDER ADVANCE REFUND ENTRY
// ─────────────────────────────────────────────────────────────────────────────

class _AdvanceRefundSection extends StatefulWidget {
  final AdminState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  const _AdvanceRefundSection({
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  State<_AdvanceRefundSection> createState() => _AdvanceRefundSectionState();
}

class _AdvanceRefundSectionState extends State<_AdvanceRefundSection> {
  final List<Map<String, dynamic>> _refunds = [];
  bool _isLoading = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fetchRefunds();
  }

  @override
  void didUpdateWidget(covariant _AdvanceRefundSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab == 4 && oldWidget.activeTab != 4) {
      _fetchRefunds();
    }
  }

  Future<void> _fetchRefunds() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .where('amount', isLessThan: 0)
          .orderBy('amount')
          .get();
      final loaded = snap.docs.map((doc) {
        final d = doc.data();
        d['docId'] = doc.id;
        return d;
      }).toList();
      setState(() {
        _refunds.clear();
        _refunds.addAll(loaded);
        _selectedIndex = null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _shareRefund(Map<String, dynamic> item) {
    final receiptNo = item['receiptNo'] ?? '';
    final date = item['date'] ?? '';
    final customer = item['customerName'] ?? '';
    final amount = item['amount'] ?? '0.00';
    final mode = item['paymentMode'] ?? 'Cash';

    final text = '💸 *Advance Refund Voucher*\n'
        'Voucher No: $receiptNo\n'
        'Date: $date\n'
        'Customer: $customer\n'
        'Refund Amount: ₹$amount\n'
        'Payment Mode: $mode\n'
        'Trilok Jewellers';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Refund Details'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refund details copied to clipboard!')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {Color? iconColor, VoidCallback? onTap}) {
    return Material(
      color: const Color(0xFFFAF7F2),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: DropdownButtonFormField<int>(
                    initialValue: widget.activeTab,
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          'Customer Order Bookings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          'Supplier Order Allocation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          'Customer Order Allocation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          'Gold Rate Fixing Advances',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text(
                          'Advance Refunds',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) widget.onTabChanged(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildActionButton(Icons.add, 'Add', onTap: () => _showNewRefundDialog(context)),
                  _buildActionButton(Icons.share, 'Share', iconColor: Colors.teal, onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _refunds.length) {
                      _shareRefund(_refunds[_selectedIndex!]);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a refund record to share.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _refunds.length) {
                      _showNewRefundDialog(context, existing: _refunds[_selectedIndex!]);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a refund record to modify.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.visibility_outlined, 'View', iconColor: Colors.blueAccent, onTap: () {
                    if (_selectedIndex != null && _selectedIndex! < _refunds.length) {
                      _showNewRefundDialog(context, existing: _refunds[_selectedIndex!], isViewOnly: true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a refund record to view.')),
                      );
                    }
                  }),
                  _buildActionButton(Icons.print, 'Print', onTap: () async {
                    if (_selectedIndex != null && _selectedIndex! < _refunds.length) {
                      final item = _refunds[_selectedIndex!];
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await PdfOrderEntryApi.printRefund(item);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to print refund voucher: $e')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a refund record first to print.')),
                      );
                    }
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.4), // Refund Receipt No.
                              1: FlexColumnWidth(1.2), // Date
                              2: FlexColumnWidth(2.2), // Customer
                              3: FlexColumnWidth(1.4), // Refunded Amount
                              4: FlexColumnWidth(1.2), // Refund Mode
                              5: FlexColumnWidth(2.0), // Narration
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: _border.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBF9F6),
                                ),
                                children: [
                                  _buildTableCell(
                                    'Refund Receipt No.',
                                    isHeader: true,
                                  ),
                                  _buildTableCell('Date', isHeader: true),
                                  _buildTableCell('Customer', isHeader: true),
                                  _buildTableCell(
                                    'Refunded Amount',
                                    isHeader: true,
                                  ),
                                  _buildTableCell(
                                    'Refund Mode',
                                    isHeader: true,
                                  ),
                                  _buildTableCell('Narration', isHeader: true),
                                ],
                              ),
                              ..._refunds.map((item) {
                                final originalAmt =
                                    (item['amount'] as num?)?.toDouble() ?? 0.0;
                                final refundDisplay = originalAmt
                                    .abs()
                                    .toStringAsFixed(2);
                                return TableRow(
                                  children: [
                                    _buildTableCell(
                                      item['receiptNo']?.toString() ?? '—',
                                    ),
                                    _buildTableCell(
                                      item['date']?.toString() ?? '—',
                                    ),
                                    _buildTableCell(
                                      item['customerName']?.toString() ?? '—',
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 10.0,
                                      ),
                                      child: Text(
                                        refundDisplay,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    _buildTableCell(
                                      item['paymentMode']?.toString() ?? 'Cash',
                                    ),
                                    _buildTableCell(
                                      item['narration']?.toString() ?? '—',
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                          if (_refunds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  'No advance refund records found.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? _brown : Colors.black87,
        ),
      ),
    );
  }

  void _showNewRefundDialog(BuildContext context, {Map<String, dynamic>? existing, bool isViewOnly = false}) {
    showDialog(
      context: context,
      builder: (ctx) => _NewRefundDialog(
        existing: existing,
        isViewOnly: isViewOnly,
        onSaved: () {
          _fetchRefunds();
        },
      ),
    );
  }
}

class _NewRefundDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  final bool isViewOnly;
  const _NewRefundDialog({required this.onSaved, this.existing, this.isViewOnly = false});

  @override
  State<_NewRefundDialog> createState() => _NewRefundDialogState();
}

class _NewRefundDialogState extends State<_NewRefundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _refundNoCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  String? _selectedCustomer;
  List<String> _customers = [];
  String _refundMode = 'Cash';
  List<String> _refundModes = ['Cash', 'UPI', 'Card'];
  List<Map<String, dynamic>> _availableAdvances = [];
  String? _selectedAdvanceReceiptNo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refundNoCtrl.text = 'REF-1';
    _fetchNextRefundNo();
    _fetchCustomers();
    _fetchBankNames();
  }

  Future<void> _fetchBankNames() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('book_names')
          .orderBy('name')
          .get();
      final names = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _refundModes = ['Cash', 'UPI', 'Card', ...names];
      });
    } catch (_) {}
  }

  Future<void> _fetchNextRefundNo() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .get();
      int maxNum = 0;
      for (final doc in snap.docs) {
        final String rNo = doc.data()['receiptNo']?.toString() ?? '';
        if (rNo.startsWith('REF-')) {
          final suffix = rNo.substring(4);
          final numVal = int.tryParse(suffix);
          if (numVal != null) {
            if (numVal < 50000) {
              if (numVal > maxNum) {
                maxNum = numVal;
              }
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _refundNoCtrl.text = 'REF-${maxNum + 1}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _refundNoCtrl.text = 'REF-1';
        });
      }
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .get();
      final list = snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _customers = list.toSet().toList();
        if (_customers.isNotEmpty) {
          _selectedCustomer = _customers.first;
          _fetchCustomerAdvances();
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchCustomerAdvances() async {
    if (_selectedCustomer == null || _selectedCustomer == 'New Customer') {
      setState(() {
        _availableAdvances = [];
        _selectedAdvanceReceiptNo = null;
      });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('advance_payments')
          .where('customerName', isEqualTo: _selectedCustomer)
          .get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((data) {
        final rNo = data['receiptNo']?.toString() ?? '';
        final amt = (data['amount'] ?? 0.0).toDouble();
        final status = (data['status'] ?? '').toString().toUpperCase();
        return rNo.startsWith('ADV-') && amt > 0.0 && status != 'USED' && status != 'REFUNDED';
      }).toList();
      
      setState(() {
        _availableAdvances = list;
        if (_availableAdvances.isNotEmpty) {
          _selectedAdvanceReceiptNo = _availableAdvances.first['receiptNo'];
          _amountCtrl.text = (_availableAdvances.first['amount'] ?? 0.0).toString();
        } else {
          _selectedAdvanceReceiptNo = null;
          _amountCtrl.clear();
        }
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }
    if (_selectedAdvanceReceiptNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active advance bill to link')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final refundVal = double.tryParse(_amountCtrl.text) ?? 0.0;
      final refundData = {
        'receiptNo': _refundNoCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'customerName': _selectedCustomer,
        'amount': -refundVal,
        'paymentMode': _refundMode,
        'linkedAdvanceReceiptNo': _selectedAdvanceReceiptNo,
        'narration': _narrationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('advance_payments')
          .add(refundData);

      // Update linked advance status
      final q = await FirebaseFirestore.instance
          .collection('advance_payments')
          .where('receiptNo', isEqualTo: _selectedAdvanceReceiptNo)
          .get();
      for (final doc in q.docs) {
        await doc.reference.update({
          'status': 'USED',
          'usedInBillNo': 'Refunded via ${_refundNoCtrl.text.trim()}',
        });
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving refund: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Refund Customer Advance',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _brown,
        ),
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Refund Receipt No',
                        _refundNoCtrl,
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: TextFormField(
                              controller: _dateCtrl,
                              readOnly: true,
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2101),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: _brown,
                                          onPrimary: Colors.white,
                                          onSurface: _brown,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                                  });
                                }
                              },
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration().copyWith(
                                suffixIcon: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(Icons.calendar_month, size: 14, color: _brown),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Name',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCustomer,
                              decoration: _inputDecoration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: _customers
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCustomer = val;
                                });
                                _fetchCustomerAdvances();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Refund Mode',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: DropdownButtonFormField<String>(
                              initialValue: _refundMode,
                              decoration: _inputDecoration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: _refundModes
                                  .map(
                                    (m) => DropdownMenuItem<String>(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _refundMode = val ?? 'Cash'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Link Advance Bill',
                            style: TextStyle(
                              fontSize: 11,
                              color: _brownLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedAdvanceReceiptNo,
                              hint: Text(
                                _availableAdvances.isEmpty ? 'No active advances' : 'Select Advance',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              decoration: _inputDecoration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: _availableAdvances
                                  .map(
                                    (adv) {
                                      final rNo = adv['receiptNo'] ?? '';
                                      final amt = (adv['amount'] ?? 0.0).toDouble();
                                      return DropdownMenuItem<String>(
                                        value: rNo,
                                        child: Text('$rNo (₹${amt.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                                      );
                                    },
                                  )
                                  .toList(),
                              onChanged: _availableAdvances.isEmpty ? null : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedAdvanceReceiptNo = val;
                                    final selected = _availableAdvances.firstWhere((element) => element['receiptNo'] == val);
                                    _amountCtrl.text = (selected['amount'] ?? 0.0).toString();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField('Refund Amount', _amountCtrl),
                const SizedBox(height: 10),
                _buildTextField('Narration / Remarks', _narrationCtrl),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _brown),
          child: _saving
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Refund',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _brownLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: TextFormField(
            controller: ctrl,
            readOnly: readOnly,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
        borderSide: const BorderSide(color: _brown),
      ),
    );
  }
}

class OrderSubRowController {
  final styleNameCtrl = TextEditingController(text: 'Less Wt');
  final weightCtrl = TextEditingController(text: '0.000');
  final pcsCtrl = TextEditingController(text: '1');
  final remarksCtrl = TextEditingController();

  OrderSubRowController({
    String styleName = 'Less Wt',
    String weight = '0.000',
    String pcs = '1',
    String remarks = '',
  }) {
    styleNameCtrl.text = styleName;
    weightCtrl.text = weight;
    pcsCtrl.text = pcs;
    remarksCtrl.text = remarks;
  }

  void dispose() {
    styleNameCtrl.dispose();
    weightCtrl.dispose();
    pcsCtrl.dispose();
    remarksCtrl.dispose();
  }
}
