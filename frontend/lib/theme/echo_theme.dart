import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette — dark first, gold accents, faint paper warmth.
class EchoColors {
  // Backgrounds — slightly warmer than pure git-hub black; suggests aged paper.
  static const bg = Color(0xFF0E0B07);       // deep ink black with warm undertone
  static const bgSoft = Color(0xFF15110B);   // raised surfaces
  static const panel = Color(0xFF1A140D);    // card surfaces
  static const panelHi = Color(0xFF221A11);  // hovered/selected
  static const border = Color(0xFF3B2E1F);   // bronze patina edge
  static const borderHi = Color(0xFF6B5232); // illuminated edge

  // Text
  static const fg = Color(0xFFE9DDC9);       // bone-paper text
  static const fgSoft = Color(0xFFCBB995);
  static const muted = Color(0xFF8F7B5A);

  // Accents
  static const accent = Color(0xFFD4A574);       // antique gold
  static const accentSoft = Color(0xFFB08C5F);
  static const accentGlow = Color(0xFFF1C988);   // brighter gold for highlights
  static const cinnabar = Color(0xFFC5483B);     // 朱砂 — seal red, used sparingly

  // Wuxing
  static const wMetal = Color(0xFFD6CFC0);  // burnished pewter
  static const wWood = Color(0xFF7BAE52);   // 青翠
  static const wWater = Color(0xFF4F8FB8);  // 深淵青
  static const wFire = Color(0xFFD8463B);   // 火朱
  static const wEarth = Color(0xFFC79B5C);  // 黃土

  // Rarity
  static const rCommon = Color(0xFF8B7E62);
  static const rRare = Color(0xFF4F8FB8);
  static const rLegendary = Color(0xFFE8B97A);

  static Color wuxing(String w) => switch (w) {
        'metal' => wMetal,
        'wood' => wWood,
        'water' => wWater,
        'fire' => wFire,
        'earth' => wEarth,
        _ => muted,
      };
  static Color rarity(String r) => switch (r) {
        'rare' => rRare,
        'legendary' => rLegendary,
        _ => rCommon,
      };
  static String wuxingCN(String w) => switch (w) {
        'metal' => '金',
        'wood' => '木',
        'water' => '水',
        'fire' => '火',
        'earth' => '土',
        _ => w,
      };
  static String rarityStar(String r) => switch (r) {
        'legendary' => '★★',
        'rare' => '★',
        _ => '·',
      };

  /// Subtle gold gradient — use as Border or BoxDecoration gradient.
  static LinearGradient goldEdge = const LinearGradient(
    colors: [Color(0xFF6B5232), Color(0xFFD4A574), Color(0xFF6B5232)],
    stops: [0.0, 0.5, 1.0],
  );
}

/// Typography — Noto Serif TC for display/titles, Noto Sans TC for body.
TextStyle echoDisplay(double size, {Color? color, double letterSpacing = 4}) =>
    GoogleFonts.notoSerifTc(
      fontSize: size,
      color: color ?? EchoColors.accent,
      letterSpacing: letterSpacing,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

TextStyle echoTitle(double size, {Color? color, double letterSpacing = 2}) =>
    GoogleFonts.notoSerifTc(
      fontSize: size,
      color: color ?? EchoColors.accent,
      letterSpacing: letterSpacing,
      fontWeight: FontWeight.w500,
    );

TextStyle echoBody(double size, {Color? color, double height = 1.7}) =>
    GoogleFonts.notoSansTc(
      fontSize: size,
      color: color ?? EchoColors.fg,
      height: height,
    );

TextStyle echoMono(double size, {Color? color}) =>
    GoogleFonts.notoSerifTc(
      fontSize: size,
      color: color ?? EchoColors.muted,
      fontWeight: FontWeight.w400,
    );

ThemeData echoTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EchoColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: EchoColors.accent,
        secondary: EchoColors.accentSoft,
        surface: EchoColors.panel,
        onSurface: EchoColors.fg,
      ),
      textTheme: GoogleFonts.notoSansTcTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme.apply(
              bodyColor: EchoColors.fg,
              displayColor: EchoColors.accent,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSerifTc(
          color: EchoColors.accent,
          fontSize: 19,
          letterSpacing: 6,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: const IconThemeData(color: EchoColors.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EchoColors.bgSoft,
        hintStyle: TextStyle(color: EchoColors.muted.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: EchoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: EchoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: EchoColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EchoColors.accent,
          foregroundColor: const Color(0xFF1A1106),
          elevation: 0,
          textStyle: GoogleFonts.notoSerifTc(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _FadeUpTransitionBuilder(),
        TargetPlatform.iOS: _FadeUpTransitionBuilder(),
      }),
      useMaterial3: true,
    );

class _FadeUpTransitionBuilder extends PageTransitionsBuilder {
  const _FadeUpTransitionBuilder();
  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Wuxing badge — seal-style rounded plaque with element character.
class WuxingBadge extends StatelessWidget {
  const WuxingBadge(this.wuxing, {super.key, this.size = 22});
  final String wuxing;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = EchoColors.wuxing(wuxing);
    return Container(
      width: size + 8,
      height: size + 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.78)],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.35), blurRadius: 6, spreadRadius: -1),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.18), width: 0.5),
      ),
      child: Text(
        EchoColors.wuxingCN(wuxing),
        style: GoogleFonts.notoSerifTc(
          color: const Color(0xFF15110B),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.62,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}

/// Decorative section divider with central glyph — `── ◇ ──` motif.
class EchoDivider extends StatelessWidget {
  const EchoDivider({super.key, this.glyph = '◇'});
  final String glyph;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        const Expanded(child: Divider(color: EchoColors.border, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(glyph,
              style: const TextStyle(color: EchoColors.accentSoft, fontSize: 11)),
        ),
        const Expanded(child: Divider(color: EchoColors.border, thickness: 0.5)),
      ]),
    );
  }
}

/// Card surface — paper-warm with double inner gold border and ink shadow.
class EchoCard extends StatelessWidget {
  const EchoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    this.glowColor,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: EchoColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: EchoColors.border, width: 0.8),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: (glowColor ?? EchoColors.accent).withOpacity(0.18),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          const BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: EchoColors.accent.withOpacity(0.08), width: 0.3),
      ),
      child: child,
    );
  }
}

/// Seal stamp — a small red square with white seal text. Use as logo accent.
class EchoSeal extends StatelessWidget {
  const EchoSeal({super.key, required this.text, this.size = 28});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: EchoColors.cinnabar,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: EchoColors.cinnabar.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSerifTc(
          fontSize: size * 0.4,
          color: const Color(0xFFFFEDD8),
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
