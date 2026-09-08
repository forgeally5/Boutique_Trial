import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../state/admin_state.dart';
import '../../../dialogs/cheque_print_dialog.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../utils/pdf_delivery_challan_api.dart';
import 'delivery_challan_view.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);
const _btnBg = Color(0xFFF4F0E8);

class DeliveryChallanListView extends StatefulWidget {
  final AdminState state;

  const DeliveryChallanListView({super.key, required this.state});

  @override
  State<DeliveryChallanListView> createState() => _DeliveryChallanListViewState();
}

class _DeliveryChallanListViewState extends State<DeliveryChallanListView> {
  String _account = 'All';
  String _bookName = 'All';
  final String _dateFrom = '10/07/2026';
  final String _dateTo = '10/07/2026';
  String _vouType = 'All';
  String _prefix = 'All';

  final List<Map<String, dynamic>> _entries = [];
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadChallans();
  }

  Future<void> _loadChallans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('delivery_challans')
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
      if (mounted) {
        setState(() {
          _entries.clear();
          _entries.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Error loading challans: $e');
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
                      _buildFilterRow('Account', _account, (val) => setState(() => _account = val!), isPrimary: true),
                      const SizedBox(height: 8),
                      _buildFilterRow('Book Name', _bookName, (val) => setState(() => _bookName = val!)),
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
                      _buildActionButton(Icons.flash_on, 'Quick\nEntry', onTap: () => _openDeliveryChallanWindow()),
                      _buildActionButton(Icons.print_outlined, 'Voucher', onTap: () async {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final messenger = ScaffoldMessenger.of(context);
                          final List<DeliveryChallanSummaryItem> summaryItems = [];
                          final rawSummary = entry['summaryItems'] as List? ?? [];
                          for (int i = 0; i < rawSummary.length; i++) {
                            final r = rawSummary[i] as Map? ?? {};
                            summaryItems.add(DeliveryChallanSummaryItem(
                              sNo: '${i + 1}',
                              date: r['date']?.toString() ?? '',
                              description: r['description']?.toString() ?? '',
                              consigneeName: r['consigneeName']?.toString() ?? '',
                              gstin: r['gstin']?.toString() ?? '',
                              soldWt: r['soldWt']?.toString() ?? '',
                              invoiceNo: r['invoiceNo']?.toString() ?? '',
                              taxableValue: r['taxableValue']?.toString() ?? '',
                              sgst: r['sgst']?.toString() ?? '',
                              cgst: r['cgst']?.toString() ?? '',
                              igst: r['igst']?.toString() ?? '',
                              total: r['total']?.toString() ?? '',
                            ));
                          }

                          final printData = DeliveryChallanPrintData(
                            challanNo: entry['challanNo']?.toString() ?? '',
                            date: entry['date']?.toString() ?? '',
                            consigneeName: entry['consigneeName']?.toString() ?? '',
                            consigneeAddress: entry['consigneeAddress']?.toString() ?? '',
                            consigneeGstin: entry['consigneeGstin']?.toString() ?? '',
                            descGoodsHsn: entry['descGoodsHsn']?.toString() ?? '',
                            quantityGoods: entry['quantityGoods']?.toString() ?? '',
                            valueGoods: entry['valueGoods']?.toString() ?? '',
                            purposeTransport: entry['purposeTransport']?.toString() ?? '',
                            personCarrying: entry['personCarrying']?.toString() ?? '',
                            transportDetails: entry['transportDetails']?.toString() ?? '',
                            destinationDetails: entry['destinationDetails']?.toString() ?? '',
                            openingStock: entry['openingStock']?.toString() ?? '',
                            totalSale: entry['totalSale']?.toString() ?? '',
                            summaryItems: summaryItems,
                          );

                          try {
                             await Printing.layoutPdf(
                               onLayout: (format) => PdfDeliveryChallanApi.generate(printData, format: format),
                               format: PdfPageFormat.a4.landscape,
                               name: 'Delivery_Challan_${printData.challanNo}',
                             );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to print challan: $e')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a delivery challan row first to print')),
                          );
                        }
                      }),
                      _buildActionButton(Icons.receipt_long, 'Cheque\nPrint', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final double amtVal = double.tryParse(entry['valueGoods']?.toString() ?? '') ?? 0.0;
                          ChequePrintDialog.show(
                            context,
                            payee: entry['consigneeName']?.toString() ?? 'WALK-IN',
                            amount: amtVal,
                            date: entry['date']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          );
                        }
                      }),
                      _buildActionButton(Icons.note_add_outlined, 'Add', iconColor: Colors.blueAccent, onTap: () => _openDeliveryChallanWindow()),
                      _buildActionButton(Icons.edit_outlined, 'Modify', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openDeliveryChallanWindow(initialData: _entries[_selectedIndex!]);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a delivery challan row first to modify')),
                          );
                        }
                      }),
                      _buildActionButton(Icons.cancel_outlined, 'Delete', iconColor: Colors.deepOrange, onTap: () async {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          final entry = _entries[_selectedIndex!];
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Challan'),
                              content: Text('Are you sure you want to delete challan ${entry['challanNo']}?'),
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
                                await FirebaseFirestore.instance.collection('delivery_challans').doc(docId).delete();
                              } catch (_) {}
                            }
                            setState(() {
                              _entries.removeAt(_selectedIndex!);
                              _selectedIndex = null;
                            });
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a delivery challan row first to delete')),
                          );
                        }
                      }),
                      _buildActionButton(Icons.pageview_outlined, 'View', onTap: () {
                        if (_selectedIndex != null && _selectedIndex! < _entries.length) {
                          _openDeliveryChallanWindow(initialData: _entries[_selectedIndex!], isViewOnly: true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a delivery challan row first to view')),
                          );
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
                        Expanded(flex: 2, child: Text('Challan No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 3, child: Text('Consignee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Consignee GSTIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 3, child: Text('Purpose of Transport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Qty of Goods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                        Expanded(flex: 2, child: Text('Value of Goods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border, thickness: 1),

                  // Table Body
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(
                            child: Text(
                              'No delivery challans found. Click ADD to create a new challan.',
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
                                onDoubleTap: () => _openDeliveryChallanWindow(initialData: entry, isViewOnly: true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFDF6ED) : Colors.transparent,
                                    border: const Border(bottom: BorderSide(color: _border)),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildRowCell(entry['challanNo']?.toString() ?? '', flex: 2),
                                      _buildRowCell(entry['date']?.toString() ?? '', flex: 2),
                                      _buildRowCell(entry['consigneeName']?.toString() ?? '', flex: 3),
                                      _buildRowCell(entry['consigneeGstin']?.toString() ?? '', flex: 2),
                                      _buildRowCell(entry['purposeTransport']?.toString() ?? '', flex: 3),
                                      _buildRowCell(entry['quantityGoods']?.toString() ?? '', flex: 2),
                                      _buildRowCell(entry['valueGoods']?.toString() ?? '', flex: 2),
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
                items: [
                  DropdownMenuItem(value: 'All', child: Text('All', style: TextStyle(color: isPrimary && value == 'All' ? Colors.white : Colors.black))),
                ],
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

  Future<void> _openDeliveryChallanWindow({Map<String, dynamic>? initialData, bool isViewOnly = false}) async {
    await showDialog(
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
              child: DeliveryChallanView(
                state: widget.state,
                initialData: initialData,
                isViewOnly: isViewOnly,
                onBack: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
    _loadChallans(); // Reload list from Firestore
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
