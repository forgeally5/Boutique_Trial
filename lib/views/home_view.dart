// ignore_for_file: non_const_argument_for_const_parameter
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';

class ShortcutItem {
  final String id;
  final String title;
  final String type; // 'tab' or 'billing'
  final String target;
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
      color: Color(map['colorValue'] ?? BoutiqueColors.accent.toARGB32()),
    );
  }
}

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
  const ShortcutPreset(label: 'Sales Entry', type: 'billing', target: 'A Sales Entry', icon: Icons.point_of_sale_rounded, color: BoutiqueColors.accent),
  const ShortcutPreset(label: 'Inventory Management', type: 'tab', target: '1', icon: Icons.inventory_2_rounded, color: Color(0xFF2E7D32)),
  const ShortcutPreset(label: 'Add Item Master', type: 'tab', target: '3', icon: Icons.add_shopping_cart_rounded, color: Color(0xFFD97706)),
  const ShortcutPreset(label: 'Reports Hub', type: 'report', target: 'A Daily Activity Report', icon: Icons.bar_chart_rounded, color: Color(0xFF6B21A8)),
  const ShortcutPreset(label: 'Sales Register', type: 'report', target: 'A Sales Register', icon: Icons.receipt_rounded, color: BoutiqueColors.accent),
  const ShortcutPreset(label: 'Purchase Entry', type: 'billing', target: 'B Purchase Entry', icon: Icons.receipt_long_rounded, color: Color(0xFFC62828)),
  const ShortcutPreset(label: 'Delivery Challan', type: 'billing', target: 'H Delivery Challan', icon: Icons.local_shipping_rounded, color: Color(0xFFD97706)),
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
    setState(() {
      _shortcuts.clear();
      _shortcuts.add(ShortcutItem(id: '1', title: 'Sales Entry', type: 'billing', target: 'A Sales Entry', icon: Icons.point_of_sale_rounded, color: BoutiqueColors.accent));
      _shortcuts.add(ShortcutItem(id: '2', title: 'Inventory', type: 'tab', target: '1', icon: Icons.inventory_2_outlined, color: const Color(0xFF2E7D32)));
      _shortcuts.add(ShortcutItem(id: '3', title: 'Add Item', type: 'tab', target: '3', icon: Icons.add_circle_outline_rounded, color: const Color(0xFFD97706)));
      _shortcuts.add(ShortcutItem(id: '4', title: 'Reports Hub', type: 'report', target: 'A Daily Activity Report', icon: Icons.bar_chart_rounded, color: const Color(0xFF6B21A8)));
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
      final docRef = await FirebaseFirestore.instance.collection('home_shortcuts').add({
        ...newItemMap,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final newItem = ShortcutItem.fromMap(newItemMap, docRef.id);
      setState(() => _shortcuts.add(newItem));
      if (mounted) BoutiqueToast.showSuccess(context, 'Shortcut "${newItem.title}" added!');
    } catch (e) {
      final newItem = ShortcutItem.fromMap(newItemMap, 'local_${DateTime.now().millisecondsSinceEpoch}');
      setState(() => _shortcuts.add(newItem));
      if (mounted) BoutiqueToast.showSuccess(context, 'Shortcut "${newItem.title}" created!');
    }
  }

  Future<void> _deleteShortcut(ShortcutItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Shortcut?', style: TextStyle(fontFamily: 'serif', color: BoutiqueColors.textPrimary)),
        content: Text('Remove "${item.title}" shortcut from your dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _shortcuts.removeWhere((s) => s.id == item.id));
    }
  }

  void _launchShortcut(ShortcutItem item) {
    widget.adminState.navigatedFromHomeShortcut = true;
    if (item.type == 'report') {
      widget.onNavigateToReport?.call(item.target);
    } else if (item.target == '0_estimation') {
      widget.adminState.autoOpenEstimation = true;
      widget.onNavigateToTab(1);
    } else if (item.target == '0_add_item') {
      widget.adminState.autoOpenAddItem = true;
      widget.onNavigateToTab(3);
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
            backgroundColor: BoutiqueColors.bgCard,
            title: const Text('Create New Shortcut', style: TextStyle(color: BoutiqueColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BoutiqueColors.border),
                      color: BoutiqueColors.bgSubtle,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ShortcutPreset>(
                        value: selectedPreset,
                        isExpanded: true,
                        items: kShortcutPresets.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: p.color.withOpacity(0.15),
                                  child: Icon(p.icon, size: 14, color: p.color),
                                ),
                                const SizedBox(width: 10),
                                Text(p.label, style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary)),
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
                  const Text('Shortcut Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BoutiqueColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 13),
                    decoration: BoutiqueInputDecoration.field(hintText: 'Display name'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BoutiqueColors.accent,
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
    return ListenableBuilder(
      listenable: widget.adminState,
      builder: (context, _) {
        final totalProducts = widget.adminState.totalProductsCount;
        final lowStock = widget.adminState.lowStockCount;
        final available = widget.adminState.availableProductsCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Boutique Overview',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: BoutiqueColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back! Here is what is happening across your store today.',
                        style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => widget.onNavigateToBilling('A Sales Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BoutiqueColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text('New Sale Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Summary Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  int count = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                  final cardWidth = (constraints.maxWidth - (count - 1) * 16) / count;

                  final cards = [
                    _buildSummaryCard(
                      icon: Icons.monetization_on_outlined,
                      title: '₹24,850',
                      subtitle: "TODAY'S SALES",
                      detail: '14 Transactions completed today',
                      color: BoutiqueColors.accentSoft,
                      iconColor: BoutiqueColors.accent,
                    ),
                    _buildSummaryCard(
                      icon: Icons.inventory_2_outlined,
                      title: '$totalProducts',
                      subtitle: 'ITEMS IN STOCK',
                      detail: '$available available for billing',
                      color: BoutiqueColors.bgCard,
                      iconColor: const Color(0xFF2E7D32),
                    ),
                    _buildSummaryCard(
                      icon: Icons.warning_amber_rounded,
                      title: '$lowStock',
                      subtitle: 'LOW STOCK ALERTS',
                      detail: 'Items needing restock',
                      color: BoutiqueColors.lowStockBg,
                      iconColor: const Color(0xFFD97706),
                    ),
                    _buildSummaryCard(
                      icon: Icons.receipt_long_outlined,
                      title: '3',
                      subtitle: 'PENDING ORDERS',
                      detail: 'Alterations & Client orders',
                      color: BoutiqueColors.goldSoft,
                      iconColor: BoutiqueColors.gold,
                    ),
                  ];

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Sales Trend Chart & Recent Activity Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sales Trend Visual
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sales Velocity Trend',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: BoutiqueColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Weekly revenue breakdown',
                                    style: TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: BoutiqueColors.accentSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'This Week',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.accent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Visual Bar Chart
                          SizedBox(
                            height: 180,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBar('Mon', 0.45, '₹12k'),
                                _buildBar('Tue', 0.60, '₹18k'),
                                _buildBar('Wed', 0.35, '₹9k'),
                                _buildBar('Thu', 0.80, '₹24k', isHighlight: true),
                                _buildBar('Fri', 0.70, '₹21k'),
                                _buildBar('Sat', 0.95, '₹32k', isHighlight: true),
                                _buildBar('Sun', 0.50, '₹15k'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Quick Action Shortcuts Grid
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoutiqueDecoration.card(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Quick Shortcuts',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: BoutiqueColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isEditing ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                                  color: _isEditing ? BoutiqueColors.accent : BoutiqueColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isEditing = !_isEditing),
                                tooltip: 'Edit Shortcuts',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ..._shortcuts.map((s) => _buildShortcutTile(s)),
                              if (_isEditing)
                                InkWell(
                                  onTap: _showAddShortcutDialog,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 100,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: BoutiqueColors.border, width: 1.5),
                                      color: BoutiqueColors.bgSubtle,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add, color: BoutiqueColors.textSecondary, size: 28),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String detail,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoutiqueDecoration.card(backgroundColor: color),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: BoutiqueDecoration.softShadow,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: BoutiqueColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: BoutiqueColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: BoutiqueColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor, String amount, {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          amount,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isHighlight ? BoutiqueColors.accent : BoutiqueColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 120 * heightFactor,
          decoration: BoxDecoration(
            color: isHighlight ? BoutiqueColors.accent : BoutiqueColors.accentSoft,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BoutiqueColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildShortcutTile(ShortcutItem item) {
    return InkWell(
      onTap: _isEditing ? null : () => _launchShortcut(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BoutiqueColors.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BoutiqueColors.border),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: item.color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
                  ),
                ],
              ),
            ),
            if (_isEditing)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _deleteShortcut(item),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: BoutiqueColors.destructive, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
