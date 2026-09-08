import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../state/admin_state.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);

class PortalOrdersView extends StatefulWidget {
  final AdminState adminState;

  const PortalOrdersView({
    super.key,
    required this.adminState,
  });

  @override
  State<PortalOrdersView> createState() => _PortalOrdersViewState();
}

class _PortalOrdersViewState extends State<PortalOrdersView> {
  final List<Map<String, dynamic>> _portalOrders = [];
  bool _isLoading = false;

  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchPortalOrders();
  }

  Future<void> _fetchPortalOrders() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('portal_orders')
          .orderBy('createdAt', descending: true)
          .get();

      final list = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'orderId': data['orderId']?.toString() ?? '',
          'customerName': data['customerName']?.toString() ?? '',
          'createdAt': data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          'status': data['status']?.toString() ?? 'Pending',
          'amount': double.tryParse(data['amount']?.toString() ?? '0.0') ?? 0.0,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _portalOrders.clear();
          _portalOrders.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Error fetching portal orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _portalOrders.where((order) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final orderId = (order['orderId'] ?? '').toString().toLowerCase();
        final customerName = (order['customerName'] ?? '').toString().toLowerCase();
        if (!orderId.contains(q) && !customerName.contains(q)) {
          return false;
        }
      }

      // 2. Status Filter
      if (_statusFilter != 'All') {
        final status = (order['status'] ?? 'Pending').toString();
        if (status.toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Date Range Filter
      if (_selectedDateRange != null) {
        final date = order['createdAt'] as DateTime;
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
        if (date.isBefore(start) || date.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _totalRevenue {
    return _filteredOrders
        .where((o) => (o['status'] ?? '').toString().toLowerCase() != 'cancelled')
        .fold(0.0, (total, item) => total + (item['amount'] as double));
  }

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) {
        final items = order['items'] as List?;
        final date = order['createdAt'] as DateTime;
        final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(date);
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            color: _bg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Details - ${order['orderId']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _brownLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: _border),
                const SizedBox(height: 12),
                _buildDetailRow('Customer Name', order['customerName']?.toString() ?? '—'),
                _buildDetailRow('Date & Time', formattedDate),
                _buildDetailRow('Status', order['status']?.toString() ?? 'Pending'),
                _buildDetailRow('Total Amount', '₹${(order['amount'] as double).toStringAsFixed(2)}'),
                if (order['phone'] != null) _buildDetailRow('Phone No', order['phone'].toString()),
                if (order['email'] != null) _buildDetailRow('Email ID', order['email'].toString()),
                if (order['address'] != null) _buildDetailRow('Shipping Address', order['address'].toString()),
                const SizedBox(height: 16),
                const Text(
                  'Ordered Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brown),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: items == null || items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('No items listed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: _border),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is Map) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['itemName']?.toString() ?? 'Unknown Item',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      '${item['qty'] ?? 1} x ₹${double.tryParse(item['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(item.toString(), style: const TextStyle(fontSize: 12)),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredOrders;
    final totalOrdersCount = filteredList.length;

    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dashboard Metrics Row ──────────────────────────────────────────
          Row(
            children: [
              _buildMetricCard(
                title: 'TOTAL ORDERS',
                value: totalOrdersCount.toString(),
                icon: Icons.shopping_bag_rounded,
                iconColor: const Color(0xFFCA6F1E),
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: 'TOTAL REVENUE',
                value: '₹${_totalRevenue.toStringAsFixed(0)}',
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: 'ACTIVE PORTAL',
                value: 'Trilok Hub',
                icon: Icons.hub_rounded,
                iconColor: const Color(0xFF6A1B9A),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Search and Filters Row ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search by Order ID, Customer...',
                        prefixIcon: const Icon(Icons.search, color: _brownLight, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        fillColor: const Color(0xFFFCFAF5),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                      dropdownColor: Colors.white,
                      onChanged: (v) {
                        if (v != null) setState(() => _statusFilter = v);
                      },
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Processing', child: Text('Processing')),
                        DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brown,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 15),
                  label: Text(
                    _selectedDateRange == null
                        ? 'Date Filter'
                        : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _selectedDateRange,
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
                    if (range != null) {
                      setState(() => _selectedDateRange = range);
                    }
                  },
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                    onPressed: () => setState(() => _selectedDateRange = null),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Recent Portal Orders Table Panel ───────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Panel Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Portal Orders ($totalOrdersCount)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brown,
                            side: const BorderSide(color: _border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _fetchPortalOrders,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border),

                  // Table Body
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: _brown))
                        : filteredList.isEmpty
                            ? _buildEmptyState()
                            : SingleChildScrollView(
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.2), // ORDER ID
                                    1: FlexColumnWidth(2.0), // CUSTOMER
                                    2: FlexColumnWidth(1.5), // DATE & TIME
                                    3: FlexColumnWidth(1.0), // STATUS
                                    4: FlexColumnWidth(1.2), // AMOUNT
                                    5: FlexColumnWidth(1.0), // ACTION
                                  },
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: _border.withValues(alpha: 0.5),
                                      width: 0.5,
                                    ),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(color: Color(0xFFFBF9F6)),
                                      children: [
                                        _buildTableCell('ORDER ID', isHeader: true),
                                        _buildTableCell('CUSTOMER', isHeader: true),
                                        _buildTableCell('DATE & TIME', isHeader: true),
                                        _buildTableCell('STATUS', isHeader: true),
                                        _buildTableCell('AMOUNT', isHeader: true),
                                        _buildTableCell('ACTION', isHeader: true),
                                      ],
                                    ),
                                    ...filteredList.map((order) {
                                      final orderId = order['orderId']?.toString() ?? '—';
                                      final customer = order['customerName']?.toString() ?? '—';
                                      final date = order['createdAt'] as DateTime;
                                      final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(date);
                                      final status = order['status']?.toString() ?? 'Pending';
                                      final amountStr = '₹${(order['amount'] as double).toStringAsFixed(2)}';

                                      return TableRow(
                                        children: [
                                          _buildTableCell(orderId),
                                          _buildTableCell(customer),
                                          _buildTableCell(formattedDate),
                                          _buildStatusCell(status),
                                          _buildTableCell(amountStr),
                                          _buildActionCell(order),
                                        ],
                                      );
                                    }),
                                  ],
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _brown,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? _brown : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    Color bg = Colors.orange.shade50;
    Color fg = Colors.orange.shade800;

    final s = status.toLowerCase();
    if (s == 'completed') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (s == 'processing') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else if (s == 'cancelled') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCell(Map<String, dynamic> order) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brown,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _showOrderDetailsDialog(order),
          child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.brown.shade200,
          ),
          const SizedBox(height: 16),
          const Text(
            'No orders found matching the filter criteria.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
