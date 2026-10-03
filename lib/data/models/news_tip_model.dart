/// Haber Gönder (haber ihbarı) istek modeli.
///
/// Backend sözleşmesi: POST /api/mobile/v1/news-tips
/// title, description, location_id?, contact_name?, contact_phone?,
/// contact_email?, consent (zorunlu), opsiyonel multipart `photo`.
class NewsTipRequest {
  final String title;
  final String description;
  final String? locationId;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final bool consent;
  final String? photoPath;

  const NewsTipRequest({
    required this.title,
    required this.description,
    this.locationId,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    required this.consent,
    this.photoPath,
  });

  static String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    if (_clean(locationId) != null) 'location_id': _clean(locationId),
    if (_clean(contactName) != null) 'contact_name': _clean(contactName),
    if (_clean(contactPhone) != null) 'contact_phone': _clean(contactPhone),
    if (_clean(contactEmail) != null) 'contact_email': _clean(contactEmail),
    'consent': consent,
  };
}

/// Sunucunun döndürdüğü takip bilgisi.
class NewsTipReceipt {
  final String reference;
  final String status;
  final bool duplicate;

  const NewsTipReceipt({
    required this.reference,
    required this.status,
    this.duplicate = false,
  });

  factory NewsTipReceipt.fromJson(Map<String, dynamic> json) => NewsTipReceipt(
    reference: json['reference']?.toString() ?? '',
    status: json['status']?.toString() ?? 'RECEIVED',
    duplicate: json['duplicate'] == true,
  );
}
