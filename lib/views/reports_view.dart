import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/boutique_theme.dart';
import 'reports/issue_report_screen.dart';
import 'reports/stock_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/inward_report_screen.dart';

class ReportsView extends StatefulWidget {
  final bool isActive;
  final int? targetSubTab;
  final ValueChanged<int>? onSubTabChanged;
  const ReportsView({
    super.key,
    this.isActive = false,
    this.targetSubTab,
    this.onSubTabChanged,
  });

  @override
  ReportsViewState createState() => ReportsViewState();
}

class ReportsViewState extends State<ReportsView>
  with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  final GlobalKey<InwardReportScreenState> _inwardReportKey =
      GlobalKey<InwardReportScreenState>();

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

  void selectTab(int index) {
    _selectTab(index);
  }

  @override
  void didUpdateWidget(ReportsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetSubTab != null && widget.targetSubTab != oldWidget.targetSubTab) {
      _selectTab(widget.targetSubTab!);
    } else if (widget.isActive && !oldWidget.isActive) {
      if (_currentTab == 3) {
        _inwardReportKey.currentState?.refresh();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.targetSubTab ?? 0;
    _tabController = TabController(length: 4, vsync: this, initialIndex: _currentTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
        widget.onSubTabChanged?.call(_tabController.index);
        if (_tabController.index == 3) {
          _inwardReportKey.currentState?.refresh();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabFocusNodes[_currentTab].requestFocus();
      }
    });
  }

  void _focusSearchForTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 60), () {
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
    widget.onSubTabChanged?.call(index);
    if (mounted) {
      _tabFocusNodes[index].requestFocus();
      _focusSearchForTab(index);
    }
    if (index == 3) {
      _inwardReportKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _selectTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _selectTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _selectTab(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _selectTab(3),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true, shift: true): () => _selectTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true, shift: true): () => _selectTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true, shift: true): () => _selectTab(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true, shift: true): () => _selectTab(3),
      },
      child: FocusTraversalGroup(
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
                        const Spacer(),
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
                          shortcut: 'Alt+1',
                          isSelected: _currentTab == 0,
                          order: 1.0,
                          onSelect: () => _selectTab(0),
                          onTabNext: () => _tabFocusNodes[1].requestFocus(),
                          onTabPrev: () => _tabFocusNodes[3].requestFocus(),
                          onArrowRight: () => _tabFocusNodes[1].requestFocus(),
                          onArrowLeft: () => _tabFocusNodes[3].requestFocus(),
                        ),
                        const SizedBox(width: 6),
                        _ReportTabButton(
                          focusNode: _tabFocusNodes[1],
                          index: 1,
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock Report',
                          shortcut: 'Alt+2',
                          isSelected: _currentTab == 1,
                          order: 2.0,
                          onSelect: () => _selectTab(1),
                          onTabNext: () => _tabFocusNodes[2].requestFocus(),
                          onTabPrev: () => _tabFocusNodes[0].requestFocus(),
                          onArrowRight: () => _tabFocusNodes[2].requestFocus(),
                          onArrowLeft: () => _tabFocusNodes[0].requestFocus(),
                        ),
                        const SizedBox(width: 6),
                        _ReportTabButton(
                          focusNode: _tabFocusNodes[2],
                          index: 2,
                          icon: Icons.bar_chart_rounded,
                          label: 'Sales Report',
                          shortcut: 'Alt+3',
                          isSelected: _currentTab == 2,
                          order: 3.0,
                          onSelect: () => _selectTab(2),
                          onTabNext: () => _tabFocusNodes[3].requestFocus(),
                          onTabPrev: () => _tabFocusNodes[1].requestFocus(),
                          onArrowRight: () => _tabFocusNodes[3].requestFocus(),
                          onArrowLeft: () => _tabFocusNodes[1].requestFocus(),
                        ),
                        const SizedBox(width: 6),
                        _ReportTabButton(
                          focusNode: _tabFocusNodes[3],
                          index: 3,
                          icon: Icons.input_rounded,
                          label: 'Inward Report',
                          shortcut: 'Alt+4',
                          isSelected: _currentTab == 3,
                          order: 4.0,
                          onSelect: () => _selectTab(3),
                          onTabNext: () => _tabFocusNodes[0].requestFocus(),
                          onTabPrev: () => _tabFocusNodes[2].requestFocus(),
                          onArrowRight: () => _tabFocusNodes[0].requestFocus(),
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _tabFocusNodes[_currentTab].requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
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
                      child: StockReportScreen(
                        searchFocusNode: _stockSearchFocusNode,
                        onReturnToMainTab: () => _tabFocusNodes[1].requestFocus(),
                      ),
                    ),
                  ),
                  FocusScope(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: SalesReportScreen(
                        searchFocusNode: _salesSearchFocusNode,
                        onReturnToMainTab: () => _tabFocusNodes[2].requestFocus(),
                      ),
                    ),
                  ),
                  FocusScope(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: InwardReportScreen(
                        key: _inwardReportKey,
                        searchFocusNode: _inwardSearchFocusNode,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  final String? shortcut;
  final bool isSelected;
  final double order;
  final VoidCallback onSelect;
  final VoidCallback? onTabNext;
  final VoidCallback? onTabPrev;
  final VoidCallback? onArrowRight;
  final VoidCallback? onArrowLeft;

  const _ReportTabButton({
    required this.focusNode,
    required this.index,
    required this.icon,
    required this.label,
    this.shortcut,
    required this.isSelected,
    required this.order,
    required this.onSelect,
    this.onTabNext,
    this.onTabPrev,
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

    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: true,
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
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              final isShift = HardwareKeyboard.instance.isShiftPressed;
              if (isShift && widget.onTabPrev != null) {
                widget.onTabPrev!();
                return KeyEventResult.handled;
              } else if (!isShift && widget.onTabNext != null) {
                widget.onTabNext!();
                return KeyEventResult.handled;
              }
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
          onTap: () {
            widget.focusNode.requestFocus();
            widget.onSelect();
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? BoutiqueColors.accentSoft.withAlpha(90)
                  : (_isFocused ? BoutiqueColors.accent.withAlpha(20) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? accent
                    : (_isFocused ? BoutiqueColors.border : Colors.transparent),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
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
                    if (widget.shortcut != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        '(${widget.shortcut})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? accent.withValues(alpha: 0.8)
                              : BoutiqueColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
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
