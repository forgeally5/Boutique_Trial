import 'package:flutter/material.dart';

/// Boutique Design System Palette & Styling Constants
class BoutiqueColors {
  // Base Palette: Warm Neutrals
  static const Color bgMain = Color(0xFFFAF7F2); // Warm Cream / Ivory
  static const Color bgCard = Color(0xFFFFFFFF); // Pure White Card
  static const Color bgSecondary = Color(0xFFF3EEE7); // Soft Beige
  static const Color bgSubtle = Color(0xFFF7F3ED);

  // Accent Color: Refined Deep Rose / Burgundy & Warm Gold Highlights
  static const Color accent = Color(0xFF8B263E); // Deep Burgundy / Rose
  static const Color accentHover = Color(0xFF701C31);
  static const Color accentSoft = Color(0xFFF7EBEF); // Soft Blush Pink Tint
  static const Color accentLightBorder = Color(0xFFE8C5CE);
  
  static const Color gold = Color(0xFFC5A059); // Muted Gold Accent
  static const Color goldSoft = Color(0xFFFAF4E8);

  // Text Colors
  static const Color textPrimary = Color(0xFF2C2523); // Dark Charcoal
  static const Color textSecondary = Color(0xFF706663); // Warm Slate/Brown
  static const Color textMuted = Color(0xFF9E9491);

  // Borders & Dividers
  static const Color border = Color(0xFFE8E2D9); // Subtle Warm Border
  static const Color borderLight = Color(0xFFF0EAE1);

  // Feedback Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  
  static const Color destructive = Color(0xFFC62828);
  static const Color destructiveBg = Color(0xFFFFEBEE);

  // Status Tints
  static const Color inStockBg = Color(0xFFE8F5E9);
  static const Color lowStockBg = Color(0xFFFFF3E0);
  static const Color soldOutBg = Color(0xFFFFEBEE);
}

class BoutiqueTypography {
  // Heading Font Family: High-Contrast Elegant Serif
  static const String serifFont = 'serif';
  static const String sansFont = 'sans-serif';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: serifFont,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: BoutiqueColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingLarge = TextStyle(
    fontFamily: serifFont,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: BoutiqueColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: serifFont,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: BoutiqueColors.textPrimary,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: sansFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: BoutiqueColors.textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: sansFont,
    fontSize: 14,
    color: BoutiqueColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: sansFont,
    fontSize: 12,
    color: BoutiqueColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sansFont,
    fontSize: 11,
    color: BoutiqueColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: sansFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class BoutiqueDecoration {
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A2C2523),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x042C2523),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> hoverShadow = [
    BoxShadow(
      color: Color(0x142C2523),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static BoxDecoration card({
    Color backgroundColor = BoutiqueColors.bgCard,
    Color borderColor = BoutiqueColors.border,
    double borderRadius = 12,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: hasShadow ? softShadow : null,
    );
  }
}

class BoutiqueInputDecoration {
  static InputDecoration field({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
    Color fillColor = BoutiqueColors.bgSubtle,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor,
      hintStyle: const TextStyle(color: BoutiqueColors.textMuted, fontSize: 13),
      labelStyle: const TextStyle(color: BoutiqueColors.textSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BoutiqueColors.border, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BoutiqueColors.border, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BoutiqueColors.accent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BoutiqueColors.destructive, width: 1.0),
      ),
    );
  }
}

class BoutiqueToast {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: BoutiqueColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: BoutiqueColors.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
