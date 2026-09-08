import 'package:flutter/material.dart';
import '../../state/admin_state.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final AdminState state;
  final double fontSize;
  final double dotSize;

  const ConnectionStatusBadge({
    super.key,
    required this.state,
    this.fontSize = 11,
    this.dotSize = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final isOnline = state.isOnline;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
