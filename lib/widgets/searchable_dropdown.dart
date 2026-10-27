import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable searchable dropdown widget that shows a dialog with a search bar.
/// When users type, the list filters in real-time to show matching options.
///
/// Usage:
/// ```dart
/// SearchableDropdownField(
///   label: 'Category',
///   value: selectedCategory,
///   items: categoryList,
///   onChanged: (val) => setState(() => selectedCategory = val!),
/// )
/// ```
class SearchableDropdownField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? error;
  final bool isExpanded;
  final FocusNode? focusNode;

  static const _brown = Color(0xFF3E2723);
  static const _lightBrown = Color(0xFF8D6E63);
  static const _border = Color(0xFFE5DDD0);
  static const _errorColor = Color(0xFFB71C1C);

  const SearchableDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.error,
    this.isExpanded = true,
    this.focusNode,
  });

  @override
  State<SearchableDropdownField> createState() => _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends State<SearchableDropdownField> {
  bool _isFocused = false;

  void _showSearchableDropdownDialog(BuildContext context, String displayValue) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _SearchableDropdownDialog(
          label: widget.label,
          currentValue: displayValue,
          items: widget.items,
          onSelected: (val) {
            widget.onChanged(val);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.value.trim().isNotEmpty
        ? widget.value
        : (widget.items.isNotEmpty ? widget.items.first : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SearchableDropdownField._lightBrown,
          ),
        ),
        const SizedBox(height: 5),
        Focus(
          focusNode: widget.focusNode,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _showSearchableDropdownDialog(context, displayValue);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6A1B29).withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                canRequestFocus: false,
                onTap: () => _showSearchableDropdownDialog(context, displayValue),
                focusColor: SearchableDropdownField._brown.withValues(alpha: 0.1),
                hoverColor: SearchableDropdownField._brown.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  isFocused: _isFocused,
                  decoration: InputDecoration(
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: widget.error != null ? SearchableDropdownField._errorColor : SearchableDropdownField._border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: widget.error != null ? SearchableDropdownField._errorColor : const Color(0xFF6A1B29), width: 2.0),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: SearchableDropdownField._lightBrown),
                  ),
                  child: Text(
                    displayValue,
                    style: const TextStyle(color: SearchableDropdownField._brown, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(widget.error!,
                style: const TextStyle(fontSize: 11, color: SearchableDropdownField._errorColor)),
          ),
      ],
    );
  }
}

// ── Searchable Dropdown Dialog ────────────────────────────────────────────────

class _SearchableDropdownDialog extends StatefulWidget {
  final String label;
  final String currentValue;
  final List<String> items;
  final ValueChanged<String> onSelected;

  const _SearchableDropdownDialog({
    required this.label,
    required this.currentValue,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_SearchableDropdownDialog> createState() =>
      _SearchableDropdownDialogState();
}

class _SearchableDropdownDialogState extends State<_SearchableDropdownDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  List<String> _filtered = [];
  int _highlightIdx = -1;

  static const _brown = Color(0xFF3E2723);
  static const _lightBrown = Color(0xFF8D6E63);
  static const _border = Color(0xFFE5DDD0);
  static const _accent = Color(0xFF5E1729);

  bool _isClosed = false;

  void _closeDialog() {
    if (_isClosed) return;
    _isClosed = true;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  List<String> get _baseItems {
    final itemsList = List<String>.from(widget.items);
    if (widget.currentValue.trim().isNotEmpty &&
        !itemsList.any((it) => it.trim().toLowerCase() == widget.currentValue.trim().toLowerCase())) {
      itemsList.insert(0, widget.currentValue.trim());
    }
    return itemsList;
  }

  @override
  void initState() {
    super.initState();
    _filtered = _baseItems;
    if (widget.currentValue.trim().isNotEmpty) {
      final idx = _filtered.indexWhere((it) => it.trim().toLowerCase() == widget.currentValue.trim().toLowerCase());
      if (idx != -1) {
        _highlightIdx = idx;
      }
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    final itemsList = _baseItems;
    setState(() {
      _highlightIdx = -1;
      if (q.isEmpty) {
        _filtered = itemsList;
      } else {
        _filtered =
            itemsList.where((item) => item.toLowerCase().contains(q)).toList();
      }
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_highlightIdx < _filtered.length - 1) {
          _highlightIdx++;
          _scrollToHighlight();
        }
      });
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_highlightIdx > 0) {
          _highlightIdx--;
          _scrollToHighlight();
        }
      });
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_highlightIdx >= 0 && _highlightIdx < _filtered.length) {
        widget.onSelected(_filtered[_highlightIdx]);
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.escape) {
      _closeDialog();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToHighlight() {
    if (!_scrollCtrl.hasClients || _highlightIdx < 0) return;
    final itemHeight = 46.0; // Approximate height of each item
    final offset = _highlightIdx * itemHeight;
    final viewportDimension = _scrollCtrl.position.viewportDimension;
    
    if (offset < _scrollCtrl.offset) {
      _scrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    } else if (offset + itemHeight > _scrollCtrl.offset + viewportDimension) {
      _scrollCtrl.animateTo(offset + itemHeight - viewportDimension, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _closeDialog,
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _isClosed = true;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: _brown, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Select ${widget.label.replaceAll(' *', '')}',
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: _closeDialog,
                      ),
                    ],
                  ),
                ),

            // ── Search Bar ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Focus(
                onKeyEvent: _onKeyEvent,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  onChanged: _onSearch,
                  style: const TextStyle(fontSize: 14, color: _brown),
                  decoration: InputDecoration(
                    hintText: 'Type to search...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon:
                        const Icon(Icons.search, color: _lightBrown, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.grey, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                              _focusNode.requestFocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF9F6F0),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // ── Results Count ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} option${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Options List ───────────────────
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            'No matching options',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = _filtered[i];
                        final isSelected = item == widget.currentValue;
                        final isHighlighted = i == _highlightIdx;
                        
                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 13),
                            decoration: BoxDecoration(
                              color: isHighlighted 
                                  ? _accent.withValues(alpha: 0.15) 
                                  : (isSelected ? _accent.withValues(alpha: 0.07) : null),
                              border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: (isSelected || isHighlighted)
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: (isSelected || isHighlighted) ? _accent : _brown,
                                    ),
                                  ),
                                ),
                                if (isSelected && !isHighlighted)
                                  const Icon(Icons.check_rounded,
                                      color: _accent, size: 18),
                                if (isHighlighted)
                                  const Icon(Icons.keyboard_return_rounded, color: _accent, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
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
