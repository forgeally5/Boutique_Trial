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

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF8D6E63);
const _border = Color(0xFFE5DDD0);

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
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  // 0 = Create Bill, 1 = Bill History, 2 = Customer Ledger
  int _tab = 0;
  Map<String, dynamic>? _billToEdit;

  // One FocusNode per tab button so we can explicitly request focus on each
  final _tabFocus = [
    FocusNode(debugLabel: 'tab_create_bill'),
    FocusNode(debugLabel: 'tab_bill_history'),
    FocusNode(debugLabel: 'tab_customer_ledger'),
  ];

  @override
  void dispose() {
    for (final fn in _tabFocus) {
      fn.dispose();
    }
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

    return Column(
      children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              if (canCreateBill)
                _buildTab(0, Icons.receipt_long_rounded, 'Create Bill', visible),
              if (canCreateBill) const SizedBox(width: 4),
              if (canViewHistory)
                _buildTab(1, Icons.history_rounded, 'Bill History', visible),
              if (canViewHistory) const SizedBox(width: 4),
              _buildTab(
                  2, Icons.account_balance_wallet_rounded, 'Customer Ledger', visible),
              const Spacer(),
              Tooltip(
                message: 'Refresh data from server',
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: BoutiqueColors.textSecondary,
                  onPressed: reloadWebPage,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        // Content — Shift+Tab from anywhere inside content returns to the active tab button
        Expanded(
          child: Focus(
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.tab &&
                  HardwareKeyboard.instance.isShiftPressed) {
                // Go back to the currently active tab button
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
                      onSaved: () {
                        setState(() {
                          _billToEdit = null;
                          _tab = 1;
                        });
                      },
                    ),
                  ),
                if (_tab == 1 && canViewHistory)
                  BillHistoryScreen(
                    state: widget.state,
                    onEditBill: (bill) {
                      setState(() {
                        _billToEdit = bill;
                        _tab = 0;
                      });
                    },
                  ),
                if (_tab == 2) CustomerLedgerScreen(state: widget.state),
              ],
            ),
          ),
        ),

      ],
    );
  }

  Widget _buildTab(int index, IconData icon, String label, List<int> visible) {
    final isSelected = _tab == index;
    final fn = _tabFocus[index];

    return Focus(
      focusNode: fn,
      // Handle keyboard events on this tab button
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final pos = visible.indexOf(index);

        // Tab / Shift+Tab: cycle through tab buttons; after last Tab enters content
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            if (pos > 0) {
              _tabFocus[visible[pos - 1]].requestFocus();
              return KeyEventResult.handled;
            }
          } else {
            if (pos < visible.length - 1) {
              // Move to next tab button
              _tabFocus[visible[pos + 1]].requestFocus();
              return KeyEventResult.handled;
            }
            // Last tab button: let Tab fall through into content naturally
          }
        }

        // Enter / Space: select this tab and let focus fall into content
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          setState(() => _tab = index);
          // Unfocus tab bar so next Tab goes into content
          fn.unfocus();
          return KeyEventResult.handled;
        }

        // Left / Right arrows: navigate between tabs
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && pos < visible.length - 1) {
          _tabFocus[visible[pos + 1]].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && pos > 0) {
          _tabFocus[visible[pos - 1]].requestFocus();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: fn,
        builder: (context, _) {
          final isFocused = fn.hasFocus;
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _tab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                // Subtle keyboard-focus highlight on the tab button
                color: isFocused ? _brown.withOpacity(0.07) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? _brown : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: isSelected ? _brown : _brownLight),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? _brown : _brownLight,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
