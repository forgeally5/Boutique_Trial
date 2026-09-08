import 'package:flutter/material.dart';
import '../state/admin_state.dart';

class RatesView extends StatefulWidget {
  final AdminState state;

  const RatesView({super.key, required this.state});

  @override
  State<RatesView> createState() => _RatesViewState();
}

class _RatesViewState extends State<RatesView> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, TextEditingController> _diamondControllers;




  @override
  void initState() {
    super.initState();
    widget.state.addListener(_syncFromState);
    _controllers = {};
    for (var rate in widget.state.liveRatesList) {
      final controller = TextEditingController(
        text: rate.ratePerGram.toStringAsFixed(0),
      );
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      _controllers[rate.id] = controller;
    }

    _diamondControllers = {};
    widget.state.diamondRates.forEach((key, value) {
      final controller = TextEditingController(
        text: value == 0.0 ? '0' : value.toStringAsFixed(0),
      );
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      _diamondControllers[key] = controller;
    });
  }

  void _syncFromState() {
    if (!mounted) return;
    setState(() {
      for (var rate in widget.state.liveRatesList) {
        final ctrl = _controllers[rate.id];
        if (ctrl != null) {
          final val = double.tryParse(ctrl.text) ?? -1;
          if (val != rate.ratePerGram && !ctrl.selection.isValid) {
            ctrl.text = rate.ratePerGram.toStringAsFixed(0);
          }
        }
      }
      widget.state.diamondRates.forEach((key, value) {
        final ctrl = _diamondControllers[key];
        if (ctrl != null) {
          final val = double.tryParse(ctrl.text) ?? -1;
          if (val != value && !ctrl.selection.isValid) {
            ctrl.text = value == 0.0 ? '0' : value.toStringAsFixed(0);
          }
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant RatesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_syncFromState);
      widget.state.addListener(_syncFromState);
    }
    _syncFromState();
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncFromState);
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in _diamondControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // Get color themes for the rate cards matching the screenshot
  Color _getCardBgColor(String id) {
    return const Color(0xFFFEF9E7); // Subtle gold tint for all
  }

  Color _getCardBorderColor(String id) {
    return const Color(0xFFFBE8A6); // Gold border for all
  }

  Widget _buildDecorationBadge(String id) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFF5B041), Color(0xFFCA6F1E)],
          center: Alignment(-0.3, -0.3),
          radius: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
    );
  }

  void _onRateChanged(String id, String value) {
    // No-op. We only save on Enter or clicking the bottom button.
  }


  void _saveAllRates() {
    FocusScope.of(context).unfocus();

    // 1. Save all metal rates
    final Map<String, double> metalUpdates = {};
    _controllers.forEach((id, controller) {
      final parsed = double.tryParse(controller.text) ?? 0.0;
      metalUpdates[id] = parsed;
    });
    widget.state.updateMultipleLiveRates(metalUpdates);

    // 2. Save all diamond rates
    final Map<String, double> newDiamondRates = {};
    _diamondControllers.forEach((key, controller) {
      final parsed = double.tryParse(controller.text) ?? 0.0;
      newDiamondRates[key] = parsed;
    });

    widget.state.updateDiamondRates(newDiamondRates);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('All live rates updated successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header descriptive line
          const Text(
            'Live Rates',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set current market rates for metals and diamond grades — synced across the platform instantly.',
            style: TextStyle(fontSize: 15, color: Color(0xFF5D4037)),
          ),
          const SizedBox(height: 32),

          // Main Metal Rates card container
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5DDD0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title of section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AC0D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metal Rates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E2723),
                            ),
                          ),
                          Text(
                            '₹ per gram · applied platform-wide',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Responsive grid for rate cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine items per row based on width
                      int crossAxisCount = 3;
                      if (constraints.maxWidth < 650) {
                        crossAxisCount = 1;
                      } else if (constraints.maxWidth < 950) {
                        crossAxisCount = 2;
                      }

                      // We will build them manually or via wrapping Row / Grid
                      if (crossAxisCount == 1) {
                        return Column(
                          children: widget.state.liveRatesList
                              .map(
                                (rate) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildRateCard(rate),
                                ),
                              )
                              .toList(),
                        );
                      }

                      // Multi-column row layout (highly controlled for specific widths)
                      final list = widget.state.liveRatesList;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: list.map((rate) {
                          // Standard width percentage-based sizing
                          double width =
                              (constraints.maxWidth -
                                  (crossAxisCount - 1) * 16) /
                              crossAxisCount;
                          return SizedBox(
                            width: width,
                            child: _buildRateCard(rate),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSaveButton(),
        ],
      ),
    );
  }







  Widget _buildSaveButton() {
    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3E2723),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        onPressed: _saveAllRates,
        icon: const Icon(Icons.check, size: 18),
        label: const Text(
          'Update All Live Rates',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRateCard(dynamic rate) {
    return HoverRateCard(
      rate: rate,
      controller: _controllers[rate.id],
      bgColor: _getCardBgColor(rate.id),
      borderColor: _getCardBorderColor(rate.id),
      badge: _buildDecorationBadge(rate.id),
      onChanged: (val) => _onRateChanged(rate.id, val),
      onSubmitted: (_) => _saveAllRates(),
    );
  }
}

// ── HoverRateCard Stateful Widget ──────────────────────────────────────────

class HoverRateCard extends StatefulWidget {
  final dynamic rate;
  final TextEditingController? controller;
  final Color bgColor;
  final Color borderColor;
  final Widget badge;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const HoverRateCard({
    super.key,
    required this.rate,
    required this.controller,
    required this.bgColor,
    required this.borderColor,
    required this.badge,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  State<HoverRateCard> createState() => _HoverRateCardState();
}

class _HoverRateCardState extends State<HoverRateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Check if value differs from the saved database value
    final double savedValue = widget.rate.ratePerGram;
    final double currentValue = double.tryParse(widget.controller?.text ?? '') ?? 0.0;
    final bool isUnsaved = (currentValue != savedValue);
    final Color textColor = isUnsaved ? Colors.red : const Color(0xFF3E2723);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? widget.borderColor.withAlpha(204) : widget.borderColor,
            width: _isHovered ? 2.0 : 1.5,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: widget.borderColor.withAlpha(64),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            else
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
          ],
        ),
        transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.rate.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.8,
                            color: Color(0xFF3E2723),
                          ),
                        ),
                        if (isUnsaved) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.red,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.rate.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF795548),
                      ),
                    ),
                  ],
                ),
                widget.badge,
              ],
            ),
            const SizedBox(height: 20),

            // Numeric Price Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isUnsaved ? Colors.red.withAlpha(178) : const Color(0xFFE5DDD0),
                  width: isUnsaved ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '₹ ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ),
                  Text(
                    widget.rate.unit,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

