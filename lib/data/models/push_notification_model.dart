/// Mobil Push Bildirim Modeli
///
/// FAZ 5 / PUSH KAMPANYALARI VE ASENKRON BİLDİRİM VERİ MODELİ
///
/// Firebase FCM HTTP v1 ve yerel bildirim yüklerini tip güvenli modeller.
class PushNotificationPayload {
  final String title;
  final String body;
  final String eventType;
  final String? newsId;
  final String? slug;
  final String? url;
  final String? categoryId;
  final List<String> locationIds;
  final bool breaking;
  final String? pushEventId;
  final Map<String, dynamic> rawData;

  const PushNotificationPayload({
    required this.title,
    required this.body,
    this.eventType = 'MANUAL_NEWS',
    this.newsId,
    this.slug,
    this.url,
    this.categoryId,
    this.locationIds = const [],
    this.breaking = false,
    this.pushEventId,
    this.rawData = const {},
  });

  factory PushNotificationPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final locRaw = data['location_ids'] ?? data['location_id'];
    List<String> locs = [];
    if (locRaw is String && locRaw.isNotEmpty) {
      locs = locRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (locRaw is List) {
      locs = locRaw.map((e) => e.toString()).toList();
    }

    return PushNotificationPayload(
      title:
          json['title'] as String? ??
          (data['title'] as String? ?? 'GüncelGündem'),
      body: json['body'] as String? ?? (data['body'] as String? ?? ''),
      eventType: data['event_type'] as String? ?? 'MANUAL_NEWS',
      newsId: (data['news_id'] ?? data['content_id'])?.toString(),
      slug: data['slug']?.toString(),
      url: data['url']?.toString(),
      categoryId: data['category_id']?.toString(),
      locationIds: locs,
      breaking:
          data['breaking'] == true ||
          data['breaking'] == 'true' ||
          data['breaking'] == '1',
      pushEventId: (data['push_event_id'] ?? data['campaign_id'])?.toString(),
      rawData: Map<String, dynamic>.from(data),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'event_type': eventType,
    if (newsId != null) 'news_id': newsId,
    if (slug != null) 'slug': slug,
    if (url != null) 'url': url,
    if (categoryId != null) 'category_id': categoryId,
    'location_ids': locationIds,
    'breaking': breaking,
    if (pushEventId != null) 'push_event_id': pushEventId,
    'data': rawData,
  };
}

/// Bildirime tıklandığında hedeflenen içeriği temsil eden intent modeli
class PendingNotificationIntent {
  final String? newsId;
  final String? slug;
  final String? url;
  final String? pushEventId;
  final String? campaignId;
  final DateTime occurredAt;

  const PendingNotificationIntent({
    this.newsId,
    this.slug,
    this.url,
    this.pushEventId,
    this.campaignId,
    required this.occurredAt,
  });

  factory PendingNotificationIntent.fromPayload(
    PushNotificationPayload payload,
  ) {
    return PendingNotificationIntent(
      newsId: payload.newsId,
      slug: payload.slug,
      url: payload.url,
      pushEventId: payload.pushEventId,
      campaignId: payload.pushEventId,
      occurredAt: DateTime.now(),
    );
  }

  bool get hasTargetContent =>
      (newsId != null && newsId!.isNotEmpty) ||
      (slug != null && slug!.isNotEmpty) ||
      (url != null && url!.isNotEmpty);
}
