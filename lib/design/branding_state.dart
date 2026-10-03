import 'package:flutter/material.dart';

import '../data/models/app_config_model.dart';
import 'app_colors.dart';

/// Server-Driven Dinamik Marka Durumu
///
/// GET /api/mobile/v1/config endpoint'inden gelen güncel marka kimliğini
/// (logo, site adı, slogan, ana renkler) çalışma anında yönetir.
/// Yeni config geldiğinde uygulamayı yeniden derlemeden anında güncellenir.
class BrandingState extends ChangeNotifier {
  static BrandingState? _instance;
  static BrandingState get instance => _instance ??= BrandingState._();

  BrandingState._();

  String _siteName = 'Güncel Gündem';
  String _shortName = 'Güncel Gündem';
  String _tagline = 'Son Dakika Haberleri, Gündem ve Güncel Gelişmeler';
  String? _logoUrl;
  String? _logoMobileUrl;
  String? _faviconUrl;
  Color _primaryColor = AppColors.primary;
  Color _secondaryColor = AppColors.secondary;
  Color _accentColor = AppColors.accent;
  Map<String, String> _colors = const {};

  String get siteName => _siteName;
  String get shortName => _shortName;
  String get tagline => _tagline;
  String? get logoUrl => _logoUrl;
  String? get logoMobileUrl => _logoMobileUrl;
  String? get faviconUrl => _faviconUrl;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get accentColor => _accentColor;
  Map<String, String> get colors => _colors;

  /// Config modelinden marka verilerini günceller ve dinleyicileri uyarır
  void updateFromConfig(AppConfigModel config) {
    bool hasChanged = false;

    if (_siteName != config.siteName) {
      _siteName = config.siteName;
      hasChanged = true;
    }

    if (config.shortName != null && _shortName != config.shortName) {
      _shortName = config.shortName!;
      hasChanged = true;
    }

    if (config.tagline != null && _tagline != config.tagline) {
      _tagline = config.tagline!;
      hasChanged = true;
    }

    if (_logoUrl != config.logoUrl) {
      _logoUrl = config.logoUrl;
      hasChanged = true;
    }

    if (_logoMobileUrl != config.logoMobileUrl) {
      _logoMobileUrl = config.logoMobileUrl;
      hasChanged = true;
    }

    if (_faviconUrl != config.faviconUrl) {
      _faviconUrl = config.faviconUrl;
      hasChanged = true;
    }

    if (config.colors != null) {
      _colors = Map<String, String>.from(config.colors!);

      final primaryHex = config.colors!['primary'];
      if (primaryHex != null) {
        final parsed = parseHexColor(primaryHex);
        if (parsed != null && parsed != _primaryColor) {
          _primaryColor = parsed;
          hasChanged = true;
        }
      }

      final secondaryHex = config.colors!['secondary'];
      if (secondaryHex != null) {
        final parsed = parseHexColor(secondaryHex);
        if (parsed != null && parsed != _secondaryColor) {
          _secondaryColor = parsed;
          hasChanged = true;
        }
      }

      final accentHex = config.colors!['accent'];
      if (accentHex != null) {
        final parsed = parseHexColor(accentHex);
        if (parsed != null && parsed != _accentColor) {
          _accentColor = parsed;
          hasChanged = true;
        }
      }
    }

    if (hasChanged) {
      notifyListeners();
    }
  }

  /// Hex renk kodunu (#dc2626 veya dc2626) Flutter Color nesnesine çevirir
  static Color? parseHexColor(String hexString) {
    final clean = hexString.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      return val != null ? Color(val) : null;
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      return val != null ? Color(val) : null;
    }
    return null;
  }
}
