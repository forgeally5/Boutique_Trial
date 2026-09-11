import 'package:flutter/material.dart';
import '../state/admin_state.dart';
import 'billing/create_bill_screen.dart';
import 'billing/bill_history_screen.dart';

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
  // 0 = Create Bill, 1 = Bill History
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
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
              _buildTab(0, Icons.receipt_long_rounded, 'Create Bill'),
              const SizedBox(width: 4),
              _buildTab(1, Icons.history_rounded, 'Bill History'),
            ],
          ),
        ),
        // Content — Offstage keeps CreateBillScreen state alive without
        // building BillHistoryScreen until the user first opens it.
        Expanded(
          child: Stack(
            children: [
              Offstage(
                offstage: _tab != 0,
                child: CreateBillScreen(
                  state: widget.state,
                  onSaved: () {
                    setState(() => _tab = 1);
                  },
                ),
              ),
              if (_tab == 1)
                BillHistoryScreen(state: widget.state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? _brown : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16,
              color: isSelected ? _brown : _brownLight),
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
  }
}
