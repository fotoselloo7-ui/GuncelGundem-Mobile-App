import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/app_config_model.dart';
import 'package:guncelgundem/design/branding_state.dart';

void main() {
  group('Server-Driven Dynamic Branding State Tests', () {
    late BrandingState branding;

    setUp(() {
      branding = BrandingState.instance;
    });

    test('Initial branding state has default values', () {
      expect(branding.siteName, isNotEmpty);
      expect(branding.primaryColor, isNotNull);
    });

    test('Hex color parsing handles 6-digit and 8-digit formats', () {
      final color1 = BrandingState.parseHexColor('#dc2626');
      expect(color1, const Color(0xFFDC2626));

      final color2 = BrandingState.parseHexColor('2563eb');
      expect(color2, const Color(0xFF2563EB));

      final invalid = BrandingState.parseHexColor('invalid-hex');
      expect(invalid, isNull);
    });

    test('updateFromConfig updates siteName, tagline, logos and colors', () {
      int notifyCount = 0;
      branding.addListener(() {
        notifyCount++;
      });

      const testConfig = AppConfigModel(
        apiVersion: 'v1',
        siteName: 'NetVera Haber',
        shortName: 'NetVera',
        tagline: 'Müşteri Odaklı Haber Portalı',
        logoUrl: 'https://example.com/logo-v2.png',
        logoMobileUrl: 'https://example.com/logo-mobile-v2.png',
        colors: {
          'primary': '#10B981',
          'secondary': '#6366F1',
          'accent': '#F59E0B',
        },
      );

      branding.updateFromConfig(testConfig);

      expect(branding.siteName, 'NetVera Haber');
      expect(branding.shortName, 'NetVera');
      expect(branding.tagline, 'Müşteri Odaklı Haber Portalı');
      expect(branding.logoUrl, 'https://example.com/logo-v2.png');
      expect(branding.logoMobileUrl, 'https://example.com/logo-mobile-v2.png');
      expect(branding.primaryColor, const Color(0xFF10B981));
      expect(branding.secondaryColor, const Color(0xFF6366F1));
      expect(branding.accentColor, const Color(0xFFF59E0B));
      expect(notifyCount, greaterThan(0));
    });

    test('Subsequent config change dynamically replaces logo and branding', () {
      const updatedConfig = AppConfigModel(
        apiVersion: 'v1',
        siteName: 'Yeni Müşteri Haber',
        logoUrl: 'https://example.com/customer-logo.png',
        colors: {'primary': '#0F172A'},
      );

      branding.updateFromConfig(updatedConfig);

      expect(branding.siteName, 'Yeni Müşteri Haber');
      expect(branding.logoUrl, 'https://example.com/customer-logo.png');
      expect(branding.primaryColor, const Color(0xFF0F172A));
    });
  });
}
