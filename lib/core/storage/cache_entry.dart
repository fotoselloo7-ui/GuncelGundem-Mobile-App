/// Önbellek kaydı modeli
///
/// HTTP ETag, saklanma zamanı ve son kullanma tarihini yönetir.
class CacheEntry {
  final String key;
  final dynamic payload;
  final String? etag;
  final DateTime savedAt;
  final DateTime? expiresAt;

  const CacheEntry({
    required this.key,
    required this.payload,
    this.etag,
    required this.savedAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'payload': payload,
      'etag': etag,
      'saved_at': savedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      key: json['key'] as String,
      payload: json['payload'],
      etag: json['etag'] as String?,
      savedAt:
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  CacheEntry copyWithUpdatedEtag(String newEtag) {
    return CacheEntry(
      key: key,
      payload: payload,
      etag: newEtag,
      savedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
  }
}
