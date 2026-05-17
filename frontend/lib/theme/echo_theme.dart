import 'package:flutter/material.dart';

class EchoColors {
  static const bg = Color(0xFF0D1117);
  static const panel = Color(0xFF161B22);
  static const border = Color(0xFF30363D);
  static const fg = Color(0xFFE6EDF3);
  static const accent = Color(0xFFD4A574);
  static const accentSoft = Color(0xFFB08C5F);
  static const muted = Color(0xFF8B949E);

  static const wMetal = Color(0xFFD4D4D4);
  static const wWood = Color(0xFF7CB342);
  static const wWater = Color(0xFF5C9CE6);
  static const wFire = Color(0xFFE64B4B);
  static const wEarth = Color(0xFFC08A4E);

  static const rCommon = Color(0xFF8B949E);
  static const rRare = Color(0xFF5C9CE6);
  static const rLegendary = Color(0xFFD4A574);

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
}

ThemeData echoTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EchoColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: EchoColors.accent,
        secondary: EchoColors.accentSoft,
        surface: EchoColors.panel,
        onSurface: EchoColors.fg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: EchoColors.accent,
          fontSize: 20,
          letterSpacing: 3,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: EchoColors.accent),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: EchoColors.fg, height: 1.6),
        bodySmall: TextStyle(color: EchoColors.muted),
        titleMedium: TextStyle(color: EchoColors.accent, letterSpacing: 1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EchoColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: EchoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: EchoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: EchoColors.accent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EchoColors.accent,
          foregroundColor: const Color(0xFF1A1A1A),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      useMaterial3: true,
    );

class WuxingBadge extends StatelessWidget {
  const WuxingBadge(this.wuxing, {super.key});
  final String wuxing;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: EchoColors.wuxing(wuxing),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        EchoColors.wuxingCN(wuxing),
        style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700),
      ),
    );
  }
}
