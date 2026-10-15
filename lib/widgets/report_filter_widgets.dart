import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/boutique_theme.dart';

// ── 1. Reusable Report Search Bar with 2.0px Accent Focus Border & Glow ──────

class ReportSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final double order;
  final ValueChanged<String>? onChanged;

  const ReportSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Search…',
    this.order = 1.0,
    this.onChanged,
  });

  @override
  State<ReportSearchBar> createState() => _ReportSearchBarState();
}

class _ReportSearchBarState extends State<ReportSearchBar> {
  late FocusNode _focusNode;
  bool _ownFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode(debugLabel: 'report_search_bar');
      _ownFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
    _isFocused = _focusNode.hasFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant ReportSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      if (_ownFocusNode) _focusNode.dispose();
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownFocusNode = false;
      } else {
        _focusNode = FocusNode(debugLabel: 'report_search_bar');
        _ownFocusNode = true;
      }
      _focusNode.addListener(_onFocusChange);
      _isFocused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: BoutiqueColors.accent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: TextField(
          focusNode: _focusNode,
          controller: widget.controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          onChanged: widget.onChanged,
          decoration: BoutiqueInputDecoration.field(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: BoutiqueColors.textSecondary),
          ).copyWith(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: BoutiqueColors.accent, width: 2.0),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 2. Reusable Report Date Pill with 2.0px Accent Focus Border & Glow ────────

class ReportDatePill extends StatefulWidget {
  final String label;
  final DateTime dt;
  final VoidCallback onTap;
  final double order;
  final DateFormat fmt;

  final FocusNode? focusNode;

  const ReportDatePill({
    super.key,
    required this.label,
    required this.dt,
    required this.onTap,
    required this.order,
    required this.fmt,
    this.focusNode,
  });

  @override
  State<ReportDatePill> createState() => _ReportDatePillState();
}

class _ReportDatePillState extends State<ReportDatePill> {
  late FocusNode _focusNode;
  bool _ownFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode(debugLabel: 'date_pill_${widget.label}');
      _ownFocusNode = true;
    }
  }

  @override
  void dispose() {
    if (_ownFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        onFocusChange: (focused) {
          if (mounted) setState(() => _isFocused = focused);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  _isFocused ? BoutiqueColors.accentSoft : BoutiqueColors.bgSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isFocused ? BoutiqueColors.accent : BoutiqueColors.border,
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: BoutiqueColors.accent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.label}: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _isFocused ? FontWeight.w600 : FontWeight.normal,
                    color: _isFocused
                        ? BoutiqueColors.accent
                        : BoutiqueColors.textSecondary,
                  ),
                ),
                Text(
                  widget.fmt.format(widget.dt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isFocused
                        ? BoutiqueColors.accent
                        : BoutiqueColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: _isFocused
                      ? BoutiqueColors.accent
                      : BoutiqueColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3. Reusable Report Action Icon Button with 2.0px Focus Border & Glow ──────

class ReportActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final double order;

  const ReportActionIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    required this.order,
  });

  @override
  State<ReportActionIconButton> createState() =>
      _ReportActionIconButtonState();
}

class _ReportActionIconButtonState extends State<ReportActionIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.order),
      child: Focus(
        onFocusChange: (focused) {
          if (mounted) setState(() => _isFocused = focused);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Tooltip(
          message: widget.tooltip,
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isFocused
                    ? widget.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isFocused ? widget.color : Colors.transparent,
                  width: _isFocused ? 2.0 : 1.0,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 4. Reusable Keyboard-Accessible Date Picker with Escape & Arrow Support ────

Future<DateTime?> showBoutiqueDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  String? helpText,
}) async {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialEntryMode: initialEntryMode,
    helpText: helpText,
    barrierDismissible: true,
    builder: (BuildContext dialogContext, Widget? child) {
      return Theme(
        data: Theme.of(dialogContext).copyWith(
          colorScheme: const ColorScheme.light(
            primary: BoutiqueColors.accent,
            onPrimary: Colors.white,
            surface: BoutiqueColors.bgCard,
            onSurface: BoutiqueColors.textPrimary,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: BoutiqueColors.accent,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        child: FocusScope(
          autofocus: true,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop(null);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: child!,
          ),
        ),
      );
    },
  );
}

Future<DateTimeRange?> showBoutiqueDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) async {
  return showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: initialDateRange,
    barrierDismissible: true,
    builder: (BuildContext dialogContext, Widget? child) {
      return Theme(
        data: Theme.of(dialogContext).copyWith(
          colorScheme: const ColorScheme.light(
            primary: BoutiqueColors.accent,
            onPrimary: Colors.white,
            surface: BoutiqueColors.bgCard,
            onSurface: BoutiqueColors.textPrimary,
          ),
        ),
        child: FocusScope(
          autofocus: true,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop(null);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: child!,
          ),
        ),
      );
    },
  );
}
