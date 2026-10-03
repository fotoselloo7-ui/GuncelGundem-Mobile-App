import '../data/models/app_config_model.dart';

/// Sürüm Denetimi Sonuç Durumu
class VersionCheckResult {
  final bool isSupported;
  final bool needsForceUpdate;
  final bool recommendsUpdate;
  final String? minimumVersion;
  final String? recommendedVersion;

  const VersionCheckResult({
    required this.isSupported,
    required this.needsForceUpdate,
    required this.recommendsUpdate,
    this.minimumVersion,
    this.recommendedVersion,
  });

  factory VersionCheckResult.pass() => const VersionCheckResult(
    isSupported: true,
    needsForceUpdate: false,
    recommendsUpdate: false,
  );
}

/// Sürüm Denetim Servisi
///
/// Semantic versioning (SemVer) mantığıyla uygulama sürümünü kontrol eder.
class VersionCheckService {
  /// Mevcut uygulama sürümünü backend yapılandırmasıyla karşılaştırır
  static VersionCheckResult check({
    required String currentVersion,
    required AppConfigModel config,
  }) {
    final minVer = config.minimumAppVersion;
    final recVer = config.recommendedAppVersion;
    final force = config.forceUpdate;

    if (force) {
      return VersionCheckResult(
        isSupported: false,
        needsForceUpdate: true,
        recommendsUpdate: false,
        minimumVersion: minVer,
        recommendedVersion: recVer,
      );
    }

    if (minVer == null && recVer == null) {
      return VersionCheckResult.pass();
    }

    final isBelowMin =
        minVer != null && _compareVersions(currentVersion, minVer) < 0;
    final isBelowRec =
        recVer != null && _compareVersions(currentVersion, recVer) < 0;

    final needsForce = isBelowMin;

    return VersionCheckResult(
      isSupported: !needsForce,
      needsForceUpdate: needsForce,
      recommendsUpdate: !needsForce && isBelowRec,
      minimumVersion: minVer,
      recommendedVersion: recVer,
    );
  }

  /// SemVer karşılaştırıcı:
  /// v1 < v2 ise negatif
  /// v1 == v2 ise 0
  /// v1 > v2 ise pozitif
  static int _compareVersions(String v1, String v2) {
    final clean1 = v1.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final clean2 = v2.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');

    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }
    return 0;
  }
}
