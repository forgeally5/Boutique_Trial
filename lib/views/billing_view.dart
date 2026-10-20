import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/admin_state.dart';
import '../auth/models/app_user_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../utils/file_downloader.dart';
import '../utils/boutique_theme.dart';
import 'billing/create_bill_screen.dart';
import 'billing/bill_history_screen.dart';
import 'billing/customer_ledger_screen.dart';


class BillingView extends StatefulWidget {
  final AdminState state;
  final String initialSection;
  final ValueChanged<String>? onSectionChanged;

  const BillingView({
    super.key,
    required this.state,
    this.initialSection = 'Create Bill',
    this.onSectionChanged,
  });

  @override
  State<BillingView> createState() => BillingViewState();
}

class BillingViewState extends State<BillingView> {
  // 0 = Create Bill, 1 = Bill History, 2 = Customer Ledger
  int _tab = 0;
  Map<String, dynamic>? _billToEdit;
  final GlobalKey<BillHistoryScreenState> _billHistoryKey = GlobalKey<BillHistoryScreenState>();

  // One FocusNode per tab button so we can explicitly request focus on each
  final _tabFocus = [
    FocusNode(debugLabel: 'tab_create_bill'),
    FocusNode(debugLabel: 'tab_bill_history'),
    FocusNode(debugLabel: 'tab_customer_ledger'),
  ];

  final FocusNode _createBillFocusNode = FocusNode(debugLabel: 'create_bill_first_field');
  final FocusNode _billHistoryFocusNode = FocusNode(debugLabel: 'bill_history_first_field');
  final FocusNode _customerLedgerFocusNode = FocusNode(debugLabel: 'customer_ledger_first_field');

  void _cancelEditBill() {
    if (_billToEdit != null) {
      setState(() {
        _billToEdit = null;
        _tab = 1;
      });
      _focusFirstFieldForTab(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialSection == 'Bill History'
        ? 1
        : (widget.initialSection == 'Customer Ledger' ? 2 : 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabFocus[_tab].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final fn in _tabFocus) {
      fn.dispose();
    }
    _createBillFocusNode.dispose();
    _billHistoryFocusNode.dispose();
    _customerLedgerFocusNode.dispose();
    super.dispose();
  }

  /// Visible tab indices given current permissions.
  List<int> _visible(bool canCreate, bool canHistory) {
    return [
      if (canCreate) 0,
      if (canHistory) 1,
      2,
    ];
  }

  void selectTab(int index, {bool focusFirstField = true}) {
    final authUser = context.read<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    final canCreateBill = perms.salesEntry;
    final canViewHistory = perms.salesEntry || perms.viewReports;
    final visible = _visible(canCreateBill, canViewHistory);
    if (!visible.contains(index)) return;

    if (_tab != index) {
      setState(() => _tab = index);
    }
    widget.onSectionChanged?.call(
      index == 0 ? 'Create Bill' : (index == 1 ? 'Bill History' : 'Customer Ledger'),
    );

    if (focusFirstField) {
      _focusFirstFieldForTab(index);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && index >= 0 && index < _tabFocus.length) {
          _tabFocus[index].requestFocus();
        }
      });
    }
  }

  void _focusFirstFieldForTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        switch (index) {
          case 0:
            _createBillFocusNode.requestFocus();
            break;
          case 1:
            _billHistoryFocusNode.requestFocus();
            break;
          case 2:
            _customerLedgerFocusNode.requestFocus();
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();
    final canCreateBill = perms.salesEntry;
    final canViewHistory = perms.salesEntry || perms.viewReports;

    if (!canCreateBill && _tab == 0) {
      _tab = 1;
    }

    final visible = _visible(canCreateBill, canViewHistory);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () => selectTab(0, focusFirstField: true),
        const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () => selectTab(1, focusFirstField: true),
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () => selectTab(2, focusFirstField: true),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true): () => selectTab(0, focusFirstField: true),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true): () => selectTab(1, focusFirstField: true),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () => selectTab(2, focusFirstField: true),
      },
      child: Column(
        children: [
          // Tab bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: BoutiqueColors.borderLight)),
            ),
            child: Row(
              children: [
                if (canCreateBill)
                  _buildTab(0, Icons.receipt_long_rounded, 'Create Bill', 'Alt+B', visible),
                if (canCreateBill) const SizedBox(width: 4),
                if (canViewHistory)
                  _buildTab(1, Icons.history_rounded, 'Bill History', 'Alt+H', visible),
                if (canViewHistory) const SizedBox(width: 4),
                _buildTab(
                    2, Icons.account_balance_wallet_rounded, 'Customer Ledger', 'Alt+C', visible),
                const Spacer(),
                Tooltip(
                  message: 'Refresh data from server (F5)',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BoutiqueColors.accent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: BoutiqueColors.bgCard,
                      side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: reloadWebPage,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          // Content — Escape from anywhere inside content returns focus to the active tab button or cancels bill edit
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  if (_billToEdit != null) {
                    _cancelEditBill();
                    return KeyEventResult.handled;
                  }
                  _tabFocus[_tab].requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Stack(
                children: [
                  if (canCreateBill)
                    Offstage(
                      offstage: _tab != 0,
                      child: CreateBillScreen(
                        key: ValueKey(_billToEdit?['billNo'] ?? 'create'),
                        state: widget.state,
                        initialBill: _billToEdit,
                        firstFieldFocusNode: _createBillFocusNode,
                        onReturnToMainTab: () => _tabFocus[0].requestFocus(),
                        onCancelEdit: _cancelEditBill,
                        onSaved: () {
                          setState(() {
                            _billToEdit = null;
                            _tab = 1;
                          });
                          _billHistoryKey.currentState?.reloadBills();
                          _focusFirstFieldForTab(1);
                        },
                      ),
                    ),
                  if (canViewHistory)
                    Offstage(
                      offstage: _tab != 1,
                      child: BillHistoryScreen(
                        key: _billHistoryKey,
                        state: widget.state,
                        searchFocusNode: _billHistoryFocusNode,
                        onReturnToMainTab: () => _tabFocus[1].requestFocus(),
                        onEditBill: (bill) {
                          setState(() {
                            _billToEdit = bill;
                            _tab = 0;
                          });
                          _focusFirstFieldForTab(0);
                        },
                      ),
                    ),
                  Offstage(
                    offstage: _tab != 2,
                    child: CustomerLedgerScreen(
                      state: widget.state,
                      searchFocusNode: _customerLedgerFocusNode,
                      onReturnToMainTab: () => _tabFocus[2].requestFocus(),
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

  Widget _buildTab(int index, IconData icon, String label, String shortcut, List<int> visible) {
    final isSelected = _tab == index;
    final fn = _tabFocus[index];

    return Focus(
      focusNode: fn,
      canRequestFocus: true,
      // Handle keyboard events on this tab button
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final pos = visible.indexOf(index);
        if (pos == -1) return KeyEventResult.ignored;

        // Tab / Shift+Tab: cycle through tab buttons
        // e.g. Customer Ledger -> Create Bill -> Bill History -> Customer Ledger
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          final nextPos = (pos + 1) % visible.length;
          _tabFocus[visible[nextPos]].requestFocus();
          return KeyEventResult.handled;
        }

        // Left / Right arrows: navigate focus across tabs
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final nextPos = (pos + 1) % visible.length;
          _tabFocus[visible[nextPos]].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final prevPos = (pos - 1 + visible.length) % visible.length;
          _tabFocus[visible[prevPos]].requestFocus();
          return KeyEventResult.handled;
        }

        // Enter / Space / ArrowDown: select this tab and go to its first field
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          selectTab(index, focusFirstField: true);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: fn,
        builder: (context, _) {
          final isFocused = fn.hasFocus;
          return InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              fn.requestFocus();
              selectTab(index, focusFirstField: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? BoutiqueColors.accentSoft.withAlpha(90)
                    : (isFocused ? BoutiqueColors.accent.withAlpha(25) : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? BoutiqueColors.accent
                      : (isFocused ? BoutiqueColors.accent : Colors.transparent),
                  width: isSelected ? 1.5 : (isFocused ? 1.5 : 1.0),
                ),
                boxShadow: (isSelected || isFocused)
                    ? [
                        BoxShadow(
                          color: BoutiqueColors.accent.withAlpha(35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      icon,
                      size: 16,
                      color: (isSelected || isFocused)
                          ? BoutiqueColors.accent
                          : BoutiqueColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight:
                            (isSelected || isFocused) ? FontWeight.bold : FontWeight.w500,
                        color: (isSelected || isFocused)
                            ? BoutiqueColors.accent
                            : BoutiqueColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($shortcut)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            (isSelected || isFocused) ? FontWeight.bold : FontWeight.w500,
                        color: (isSelected || isFocused)
                            ? BoutiqueColors.accent.withAlpha(200)
                            : BoutiqueColors.textSecondary.withAlpha(160),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  // Bottom underline indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2.5,
                    width: isSelected ? 48 : (isFocused ? 32 : 0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? BoutiqueColors.accent
                          : (isFocused
                              ? BoutiqueColors.accent.withAlpha(140)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
