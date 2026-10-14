import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/boutique_theme.dart';
import 'reports/issue_report_screen.dart';
import 'reports/stock_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/inward_report_screen.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  final List<FocusNode> _tabFocusNodes = [
    FocusNode(debugLabel: 'tab_issue_report'),
    FocusNode(debugLabel: 'tab_stock_report'),
    FocusNode(debugLabel: 'tab_sales_report'),
    FocusNode(debugLabel: 'tab_inward_report'),
  ];

  final FocusNode _issueSearchFocusNode = FocusNode(debugLabel: 'issue_search');
  final FocusNode _stockSearchFocusNode = FocusNode(debugLabel: 'stock_search');
  final FocusNode _salesSearchFocusNode = FocusNode(debugLabel: 'sales_search');
  final FocusNode _inwardSearchFocusNode = FocusNode(debugLabel: 'inward_search');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
        _focusSearchForTab(_tabController.index);
      }
    });
    _focusSearchForTab(0);
  }

  void _focusSearchForTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (index) {
        case 0:
          _issueSearchFocusNode.requestFocus();
          break;
        case 1:
          _stockSearchFocusNode.requestFocus();
          break;
        case 2:
          _salesSearchFocusNode.requestFocus();
          break;
        case 3:
          _inwardSearchFocusNode.requestFocus();
          break;
      }
    });
  }

  @override
  void dispose() {
    for (final fn in _tabFocusNodes) {
      fn.dispose();
    }
    _issueSearchFocusNode.dispose();
    _stockSearchFocusNode.dispose();
    _salesSearchFocusNode.dispose();
    _inwardSearchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_currentTab != index) {
      setState(() => _currentTab = index);
      _tabController.animateTo(index);
    }
    _focusSearchForTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          // ── Top Header ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: BoutiqueColors.bgCard,
              border: Border(
                bottom: BorderSide(color: BoutiqueColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 28,
                    right: 28,
                    top: 20,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BoutiqueColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: BoutiqueColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: BoutiqueColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Issue Returns • Stock Overview • Sales Analytics',
                            style: TextStyle(
                              fontSize: 12,
                              color: BoutiqueColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Tab Bar Buttons with Ordered Focus Traversal ────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _ReportTabButton(
                        focusNode: _tabFocusNodes[0],
                        index: 0,
                        icon: Icons.assignment_return_rounded,
                        label: 'Issue Report',
                        isSelected: _currentTab == 0,
                        order: 1.0,
                        onSelect: () => _selectTab(0),
                        onArrowRight: () => _tabFocusNodes[1].requestFocus(),
                        onArrowLeft: null,
                      ),
                      const SizedBox(width: 6),
                      _ReportTabButton(
                        focusNode: _tabFocusNodes[1],
                        index: 1,
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock Report',
                        isSelected: _currentTab == 1,
                        order: 2.0,
                        onSelect: () => _selectTab(1),
                        onArrowRight: () => _tabFocusNodes[2].requestFocus(),
                        onArrowLeft: () => _tabFocusNodes[0].requestFocus(),
                      ),
                      const SizedBox(width: 6),
                      _ReportTabButton(
                        focusNode: _tabFocusNodes[2],
                        index: 2,
                        icon: Icons.bar_chart_rounded,
                        label: 'Sales Report',
                        isSelected: _currentTab == 2,
                        order: 3.0,
                        onSelect: () => _selectTab(2),
                        onArrowRight: () => _tabFocusNodes[3].requestFocus(),
                        onArrowLeft: () => _tabFocusNodes[1].requestFocus(),
                      ),
                      const SizedBox(width: 6),
                      _ReportTabButton(
                        focusNode: _tabFocusNodes[3],
                        index: 3,
                        icon: Icons.input_rounded,
                        label: 'Inward Report',
                        isSelected: _currentTab == 3,
                        order: 4.0,
                        onSelect: () => _selectTab(3),
                        onArrowRight: null,
                        onArrowLeft: () => _tabFocusNodes[2].requestFocus(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Body ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FocusScope(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: IssueReportScreen(searchFocusNode: _issueSearchFocusNode),
                  ),
                ),
                FocusScope(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: StockReportScreen(searchFocusNode: _stockSearchFocusNode),
                  ),
                ),
                FocusScope(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: SalesReportScreen(searchFocusNode: _salesSearchFocusNode),
                  ),
                ),
                FocusScope(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: InwardReportScreen(searchFocusNode: _inwardSearchFocusNode),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Focusable Tab Button with Visible Focus Border & Keyboard Activation ─────

class _ReportTabButton extends StatefulWidget {
  final FocusNode focusNode;
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final double order;
  final VoidCallback onSelect;
  final VoidCallback? onArrowRight;
  final VoidCallback? onArrowLeft;

  const _ReportTabButton({
    required this.focusNode,
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.order,
    required this.onSelect,
    this.onArrowRight,
    this.onArrowLeft,
  });

  @override
  State<_ReportTabButton> createState() => _ReportTabButtonState();
}

class _ReportTabButtonState extends State<_ReportTabButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    const accent = BoutiqueColors.accent;

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: false,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onSelect();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                widget.onArrowRight != null) {
              widget.onArrowRight!();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                widget.onArrowLeft != null) {
              widget.onArrowLeft!();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _isFocused
                  ? accent.withAlpha(25)
                  : (isSelected
                      ? BoutiqueColors.accentSoft.withAlpha(70)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused
                    ? accent
                    : (isSelected ? accent.withAlpha(50) : Colors.transparent),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(60),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: isSelected ? accent : BoutiqueColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? accent : BoutiqueColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Bottom underline indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2.5,
                  width: isSelected ? 48 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
