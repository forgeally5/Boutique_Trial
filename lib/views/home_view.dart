// ignore_for_file: non_const_argument_for_const_parameter
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/admin_state.dart';

const _brown = Color(0xFF000000);
const _brownLight = Color(0xFF333333);
const _border = Color(0xFFE0E0E0);
const _bg = Color(0xFFFFFFFF);

class ShortcutItem {
  final String id;
  final String title;
  final String type; // 'tab' or 'billing'
  final String target; // tab index (as string e.g. '0') or billing section (e.g. 'A Sales Entry')
  final IconData icon;
  final Color color;

  ShortcutItem({
    required this.id,
    required this.title,
    required this.type,
    required this.target,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'target': target,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'colorValue': color.toARGB32(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ShortcutItem.fromMap(Map<String, dynamic> map, String id) {
    return ShortcutItem(
      id: id,
      title: map['title'] ?? '',
      type: map['type'] ?? 'tab',
      target: map['target'] ?? '',
      icon: IconData(
        map['iconCodePoint'] ?? Icons.bookmark.codePoint,
        fontFamily: map['iconFontFamily'] ?? 'MaterialIcons',
        fontPackage: map['iconFontPackage'],
      ),
      color: Color(map['colorValue'] ?? Colors.brown.toARGB32()),
    );
  }
}

// Preset Targets for adding shortcuts easily
class ShortcutPreset {
  final String label;
  final String type;
  final String target;
  final IconData icon;
  final Color color;

  const ShortcutPreset({
    required this.label,
    required this.type,
    required this.target,
    required this.icon,
    required this.color,
  });
}

final List<ShortcutPreset> kShortcutPresets = [
  const ShortcutPreset(label: 'Sales Entry', type: 'billing', target: 'A Sales Entry', icon: Icons.shopping_cart_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Purchase Entry', type: 'billing', target: 'B Purchase Entry', icon: Icons.receipt_long_rounded, color: Colors.red),
  const ShortcutPreset(label: 'Inward Service', type: 'billing', target: 'C Inward Service Entry', icon: Icons.login_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Outward Service', type: 'billing', target: 'C Outward Service Entry', icon: Icons.logout_rounded, color: Colors.deepOrange),
  const ShortcutPreset(label: 'Cash Receipt Entry', type: 'billing', target: 'D Cash Bank Card Receipt Entry', icon: Icons.account_balance_wallet_rounded, color: Colors.lightGreen),
  const ShortcutPreset(label: 'Cash Entry', type: 'billing', target: 'E Cash Entry', icon: Icons.money_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Bank Entry', type: 'billing', target: 'F Bank Entry', icon: Icons.store_rounded, color: Colors.blueGrey),
  const ShortcutPreset(label: 'Journal Entry', type: 'billing', target: 'G Journal Entry', icon: Icons.auto_stories_rounded, color: Colors.pink),
  const ShortcutPreset(label: 'Delivery Challan', type: 'billing', target: 'H Delivery Challan', icon: Icons.local_shipping_rounded, color: Colors.orange),
  const ShortcutPreset(label: 'Outsource Mfg', type: 'billing', target: 'I Outsource Manufacturing', icon: Icons.settings_suggest_rounded, color: Colors.amber),
  const ShortcutPreset(label: 'Customer Issue/Receipt', type: 'billing', target: 'J Customer Issue / Receipt Entry', icon: Icons.swap_horiz_rounded, color: Colors.brown),
  const ShortcutPreset(label: 'Refinery Issue/Receipt', type: 'billing', target: 'K Refinery Issue / Receipt Entry', icon: Icons.local_fire_department_rounded, color: Colors.orangeAccent),
  const ShortcutPreset(label: 'Approval Issue/Receipt', type: 'billing', target: 'L Approval Issue / Receipt Entry', icon: Icons.fact_check_rounded, color: Colors.blue),
  const ShortcutPreset(label: 'Customer Order', type: 'billing', target: 'M Customer Order', icon: Icons.description_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Supplier Allocation', type: 'billing', target: 'M Supplier Order Allocation', icon: Icons.assignment_ind_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Customer Allocation', type: 'billing', target: 'M Customer Order Allocation', icon: Icons.assignment_turned_in_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Order Adv (Rate Fix)', type: 'billing', target: 'M Order Advance (Rate Fixing) Entry', icon: Icons.price_change_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Order Adv Refund', type: 'billing', target: 'M Order Advance Refund Entry', icon: Icons.replay_rounded, color: Colors.red),
  const ShortcutPreset(label: 'Alteration Entry', type: 'billing', target: 'N Alteration Entry', icon: Icons.content_cut_rounded, color: Colors.deepPurple),
  const ShortcutPreset(label: 'Daily Counter Stock', type: 'billing', target: 'O Daily Counter Stock Entry', icon: Icons.analytics_rounded, color: Colors.amber),
  const ShortcutPreset(label: 'Estimation', type: 'tab', target: '0_estimation', icon: Icons.assessment_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Add Item Master', type: 'tab', target: '0_add_item', icon: Icons.add_shopping_cart_rounded, color: Colors.deepOrange),
  const ShortcutPreset(label: 'Inventory Management', type: 'tab', target: '0', icon: Icons.warehouse_rounded, color: Colors.blue),
  const ShortcutPreset(label: 'Rates Management', type: 'tab', target: '2', icon: Icons.currency_exchange_rounded, color: Colors.amber),
  const ShortcutPreset(label: 'Master Settings', type: 'tab', target: '3', icon: Icons.admin_panel_settings_rounded, color: Colors.purple),
  const ShortcutPreset(label: 'Orders List', type: 'tab', target: '4', icon: Icons.assignment_turned_in_rounded, color: Colors.teal),
  
  // Reports Shortcuts
  const ShortcutPreset(label: 'Reports Hub', type: 'report', target: 'A Daily Activity Report', icon: Icons.bar_chart_rounded, color: Colors.brown),
  const ShortcutPreset(label: 'GST Exception Report', type: 'report', target: 'A GST Exception Report', icon: Icons.warning_amber_rounded, color: Colors.deepOrange),
  const ShortcutPreset(label: 'GST Summary Report', type: 'report', target: 'B GST Summary Report', icon: Icons.assessment_rounded, color: Colors.brown),
  const ShortcutPreset(label: 'GST Ratewise Summary', type: 'report', target: 'C GST Ratewise Summary Report', icon: Icons.percent_rounded, color: Colors.purple),
  const ShortcutPreset(label: 'GST Advance Receipt', type: 'report', target: 'D GST Advance Receipt Report', icon: Icons.payments_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'GST Reverse Charge (RCM)', type: 'report', target: 'E GST Reverse Charge Report', icon: Icons.published_with_changes_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Pending Approval Report (GST)', type: 'report', target: 'F Pending Approval Report (GST)', icon: Icons.assignment_late_rounded, color: Colors.orange),
  const ShortcutPreset(label: 'Pending Supplier O/s. Report (GST)', type: 'report', target: 'G Pending Supplier O/s. Report (GST)', icon: Icons.account_balance_wallet_rounded, color: Colors.red),
  const ShortcutPreset(label: 'GST Return (GSTR)', type: 'report', target: 'H GST Return', icon: Icons.assignment_turned_in_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Ledger / Account Stmt', type: 'report', target: 'A Ledger / Account Statement', icon: Icons.menu_book_rounded, color: Colors.brown),
  const ShortcutPreset(label: 'Day Book Report', type: 'report', target: 'B Day Book Report', icon: Icons.book_rounded, color: Colors.amber),
  const ShortcutPreset(label: 'Cash / Bank Book', type: 'report', target: 'C Cash / Bank Book Report', icon: Icons.account_balance_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Trial Balance Report', type: 'report', target: 'D Trial Balance Report', icon: Icons.balance_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Profit & Loss Account', type: 'report', target: 'E Profit & Loss Account', icon: Icons.trending_up_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Balance Sheet Report', type: 'report', target: 'F Balance Sheet Report', icon: Icons.pie_chart_rounded, color: Colors.purple),
  const ShortcutPreset(label: 'Group Summary Report', type: 'report', target: 'G Group Summary Report', icon: Icons.workspaces_rounded, color: Colors.deepPurple),
  const ShortcutPreset(label: 'Closing Stock Report', type: 'report', target: 'A Closing Stock Report', icon: Icons.inventory_2_rounded, color: Colors.blue),
  const ShortcutPreset(label: 'Counter Sales Summary', type: 'report', target: 'A Counter Sales Summary', icon: Icons.point_of_sale_rounded, color: Colors.green),
  // Fix Format Register Shortcuts (Daily Reports -> F Fix Format Register)
  const ShortcutPreset(label: 'Sales Register', type: 'report', target: 'A Sales Register', icon: Icons.receipt_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Purchase Register', type: 'report', target: 'B Purchase Register', icon: Icons.shopping_bag_rounded, color: Colors.red),
  const ShortcutPreset(label: 'Supplier Issue Register', type: 'report', target: 'C Supplier Issue Register', icon: Icons.local_shipping_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Supplier Receipt Register', type: 'report', target: 'D Supplier Receipt Register', icon: Icons.inventory_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Customer Issue Register', type: 'report', target: 'E Customer Issue Register', icon: Icons.person_add_rounded, color: Colors.brown),
  const ShortcutPreset(label: 'Customer Receipt Register', type: 'report', target: 'F Customer Receipt Register', icon: Icons.person_remove_rounded, color: Colors.amber),
  const ShortcutPreset(label: 'Refinery Issue Register', type: 'report', target: 'G Refinery Issue Register', icon: Icons.local_fire_department_rounded, color: Colors.orangeAccent),
  const ShortcutPreset(label: 'Refinery Receipt Register', type: 'report', target: 'H Refinery Receipt Register', icon: Icons.opacity_rounded, color: Colors.deepOrange),
  const ShortcutPreset(label: 'Sales Return Register', type: 'report', target: 'I Sales Return Register', icon: Icons.undo_rounded, color: Colors.redAccent),
  const ShortcutPreset(label: 'Purchase Return Register', type: 'report', target: 'J Purchase Return Register', icon: Icons.redo_rounded, color: Colors.purple),
  const ShortcutPreset(label: 'Supplier Approval Challan', type: 'report', target: 'K Supplier Approval Challan Register', icon: Icons.approval_rounded, color: Colors.blue),
  const ShortcutPreset(label: 'Approval Rate Fixing Register', type: 'report', target: 'L Supplier Approval Challan Rate Fixing Register', icon: Icons.price_check_rounded, color: Colors.green),
  const ShortcutPreset(label: 'Credit Note Register', type: 'report', target: 'M Credit Note Register', icon: Icons.note_add_rounded, color: Colors.indigo),
  const ShortcutPreset(label: 'Debit Note Register', type: 'report', target: 'N Debit Note Register', icon: Icons.request_quote_rounded, color: Colors.deepPurple),
  const ShortcutPreset(label: 'Inward Service Register', type: 'report', target: 'O Inward Service Register', icon: Icons.login_rounded, color: Colors.teal),
  const ShortcutPreset(label: 'Outward Service Register', type: 'report', target: 'P Outward Service Register', icon: Icons.logout_rounded, color: Colors.orange),
];

class HomeView extends StatefulWidget {
  final ValueChanged<String> onNavigateToBilling;
  final ValueChanged<int> onNavigateToTab;
  final ValueChanged<String>? onNavigateToReport;
  final AdminState adminState;

  const HomeView({
    super.key,
    required this.onNavigateToBilling,
    required this.onNavigateToTab,
    this.onNavigateToReport,
    required this.adminState,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final List<ShortcutItem> _shortcuts = [];
  bool _isLoading = false;
  bool _isEditing = false;
  
  @override
  void initState() {
    super.initState();
    _fetchShortcuts();
  }

    Future<void> _fetchShortcuts() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _shortcuts.clear();
      _shortcuts.add(ShortcutItem(id: '1', title: 'Sales Entry', type: 'billing', target: 'A Sales Entry', icon: Icons.shopping_cart_rounded, color: Colors.green));
      _shortcuts.add(ShortcutItem(id: '2', title: 'Inventory Management', type: 'tab', target: '0', icon: Icons.warehouse_rounded, color: Colors.blue));
      _isLoading = false;
    });
  }

  Future<void> _addShortcut(ShortcutPreset preset, String customTitle) async {
    final newItemMap = {
      'title': customTitle.isNotEmpty ? customTitle : preset.label,
      'type': preset.type,
      'target': preset.target,
      'iconCodePoint': preset.icon.codePoint,
      'iconFontFamily': preset.icon.fontFamily,
      'iconFontPackage': preset.icon.fontPackage,
      'colorValue': preset.color.toARGB32(),
    };

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('home_shortcuts')
          .add({
            ...newItemMap,
            'createdAt': FieldValue.serverTimestamp(),
          });
      
      final newItem = ShortcutItem.fromMap(newItemMap, docRef.id);
      setState(() {
        _shortcuts.add(newItem);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shortcut "${newItem.title}" added to Home!'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      final newItem = ShortcutItem.fromMap(
        newItemMap,
        'local_${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() {
        _shortcuts.add(newItem);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally: Shortcut "${newItem.title}"'),
            backgroundColor: _brown,
          ),
        );
      }
    }
  }

  Future<void> _deleteShortcut(ShortcutItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shortcut?'),
        content: Text('Are you sure you want to remove the shortcut for "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (item.id.startsWith('local_') || item.id.startsWith('def_')) {
        setState(() {
          _shortcuts.removeWhere((s) => s.id == item.id);
        });
      } else {
        try {
          await FirebaseFirestore.instance.collection('home_shortcuts').doc(item.id).delete();
          setState(() {
            _shortcuts.removeWhere((s) => s.id == item.id);
          });
        } catch (e) {
          setState(() {
            _shortcuts.removeWhere((s) => s.id == item.id);
          });
        }
      }
    }
  }

  void _launchShortcut(ShortcutItem item) {
    widget.adminState.navigatedFromHomeShortcut = true;
    if (item.type == 'report') {
      String targetToUse = item.target;
      for (final p in kShortcutPresets) {
        if (p.type == 'report' && p.label.toLowerCase().trim() == item.title.toLowerCase().trim()) {
          targetToUse = p.target;
          break;
        }
      }
      widget.onNavigateToReport?.call(targetToUse);
    } else if (item.target == '0_estimation') {
      widget.adminState.autoOpenEstimation = true;
      widget.onNavigateToTab(0);
    } else if (item.target == '0_add_item') {
      widget.adminState.autoOpenAddItem = true;
      widget.onNavigateToTab(0);
    } else if (item.type == 'tab') {
      final idx = int.tryParse(item.target) ?? 0;
      widget.onNavigateToTab(idx);
    } else {
      widget.onNavigateToBilling(item.target);
    }
  }

  void _showAddShortcutDialog() {
    ShortcutPreset selectedPreset = kShortcutPresets.first;
    final titleController = TextEditingController(text: selectedPreset.label);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create Shortcut', style: TextStyle(color: _brown, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Target Page *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                      color: Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ShortcutPreset>(
                        value: selectedPreset,
                        isExpanded: true,
                        items: kShortcutPresets.map((p) {
                          final isReport = p.type == 'report';
                          final isTab = p.type == 'tab';
                          final badgeLabel = isReport ? 'Report' : (isTab ? 'Tab' : 'Billing');
                          final badgeBg = isReport ? Colors.purple[50] : (isTab ? Colors.blue[50] : Colors.amber[50]);
                          final badgeTextColor = isReport ? Colors.purple[800] : (isTab ? Colors.blue[800] : Colors.amber[900]);

                          return DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: p.color.withValues(alpha: 0.15),
                                  child: Icon(p.icon, size: 14, color: p.color),
                                ),
                                const SizedBox(width: 10),
                                Text(p.label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedPreset = val;
                              titleController.text = val.label;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Shortcut Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter shortcut display name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brown, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [selectedPreset.color, selectedPreset.color.withValues(alpha: 0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: selectedPreset.color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))
                              ],
                            ),
                            child: Icon(selectedPreset.icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            titleController.text.isNotEmpty ? titleController.text : selectedPreset.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _addShortcut(selectedPreset, titleController.text);
                  Navigator.pop(ctx);
                },
                child: const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: _bg,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _brown))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end, // Align the button on the right
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _isEditing ? const Color(0xFFE8F5E9) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isEditing ? const Color(0xFF81C784) : _border,
                                width: 1.2,
                              ),
                            ),
                            child: IconButton(
                              tooltip: _isEditing ? 'Done' : 'Edit Shortcuts',
                              onPressed: () {
                                setState(() {
                                  _isEditing = !_isEditing;
                                });
                              },
                              icon: Icon(
                                _isEditing ? Icons.check_rounded : Icons.edit_note_rounded,
                                size: 22,
                                color: _isEditing ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Windows-like Grid layout
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          ..._shortcuts.map((s) => _ShortcutCard(
                                shortcut: s,
                                isEditing: _isEditing,
                                onTap: () => _launchShortcut(s),
                                onDelete: () => _deleteShortcut(s),
                              )),
                          
                          // Dotted Add Shortcut placeholder card (only visible in edit mode)
                          if (_isEditing)
                            InkWell(
                              onTap: _showAddShortcutDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 110,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, size: 32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  final ShortcutItem shortcut;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ShortcutCard({
    super.key,
    required this.shortcut,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _isHovered = false;
  final Color _border = const Color(0xFFE0E0E0); // Added to avoid missing variables

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: widget.isEditing ? null : widget.onTap,
        onTap: widget.isEditing ? null : widget.onTap,       // Standard single-click also launches for smooth web experience
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 110,
          height: 120, // Increased height to prevent vertical text overflow
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // Optimized padding
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.shortcut.color.withValues(alpha: 0.3) : _border.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.shortcut.color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Container (reduced to 40x40 to leave more room for label)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.shortcut.color,
                            widget.shortcut.color.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: widget.shortcut.color.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Icon(
                        widget.shortcut.icon,
                        color: Colors.white,
                        size: 20, // Reduced icon size slightly to keep proportion
                      ),
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    // Title Label
                    Text(
                      widget.shortcut.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Option Delete Button (Visible constantly when isEditing is active)
              if (widget.isEditing)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DottedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Draw dashed path
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    
    final Path dashPath = Path();
    double distance = 0.0;
    
    for (final PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


