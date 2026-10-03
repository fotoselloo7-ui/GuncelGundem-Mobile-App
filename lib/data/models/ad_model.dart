/// Mobil Reklam Modeli
///
/// FAZ 5 / MOBİL REKLAM SÖZLEŞMESİ VE VERİ MODELİ
///
/// Görsel yerleşim ve tasarım Faz 6'da yapılacaktır.
/// Bu model backend reklam API kontratını tip güvenli karşılar.
class MobileAdModel {
  final String campaignId;
  final String advertiserName;
  final String campaignName;
  final String type;
  final List<String> placementIds;
  final String? imageUrl;
  final String? mobileImageUrl;
  final String title;
  final String? description;
  final String ctaText;
  final String targetUrl;
  final String? newsId;
  final int priority;

  const MobileAdModel({
    required this.campaignId,
    required this.advertiserName,
    required this.campaignName,
    required this.type,
    required this.placementIds,
    this.imageUrl,
    this.mobileImageUrl,
    required this.title,
    this.description,
    this.ctaText = 'İncele',
    required this.targetUrl,
    this.newsId,
    this.priority = 10,
  });

  factory MobileAdModel.fromJson(Map<String, dynamic> json) {
    final placements = json['placement_ids'] is List
        ? (json['placement_ids'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return MobileAdModel(
      campaignId: json['campaign_id']?.toString() ?? '',
      advertiserName: json['advertiser_name']?.toString() ?? 'Genel',
      campaignName: json['campaign_name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'image',
      placementIds: placements,
      imageUrl: json['image_url']?.toString(),
      mobileImageUrl: json['mobile_image_url']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      ctaText: json['cta_text']?.toString() ?? 'İncele',
      targetUrl: json['target_url']?.toString() ?? '',
      newsId: json['news_id']?.toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
    'campaign_id': campaignId,
    'advertiser_name': advertiserName,
    'campaign_name': campaignName,
    'type': type,
    'placement_ids': placementIds,
    if (imageUrl != null) 'image_url': imageUrl,
    if (mobileImageUrl != null) 'mobile_image_url': mobileImageUrl,
    'title': title,
    if (description != null) 'description': description,
    'cta_text': ctaText,
    'target_url': targetUrl,
    if (newsId != null) 'news_id': newsId,
    'priority': priority,
  };

  /// Reklamın hedeflediği görsel URL'i (varsa mobil versiyonu öncelikler)
  String? get effectiveImageUrl => mobileImageUrl ?? imageUrl;

  /// Reklam sponsorlu bir haber mi?
  bool get isSponsoredNews =>
      type == 'sponsored_news' && (newsId != null && newsId!.isNotEmpty);

  /// Harici tarayıcıda mı açılmalı?
  bool get isExternalLink =>
      type == 'external_link' || (targetUrl.isNotEmpty && !isSponsoredNews);
}
