import 'package:flutter/material.dart';

/// DİKKAT: TEMPORARY / PLACEHOLDER TOKEN YAPISI
///
/// Bu sınıftaki fontlar ve tipografi stilleri nihai ürün tasarımı DEĞİLDİR.
/// Faz 4 arayüz tasarım aşamasında kullanıcı tarafından verilecek
/// gerçek tipografi kuralları ile değiştirilecektir.
class AppTypography {
  AppTypography._();

  // TEMPORARY PLACEHOLDER TEXT STYLES (Flutter system fonts)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}
