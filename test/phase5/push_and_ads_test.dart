import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/core/storage/device_storage.dart';
import 'package:guncelgundem/data/models/ad_model.dart';
import 'package:guncelgundem/data/models/device_model.dart';
import 'package:guncelgundem/data/models/notification_preference_model.dart';
import 'package:guncelgundem/data/models/push_notification_model.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/services/ad_service.dart';
import 'package:guncelgundem/services/analytics_service.dart';
import 'package:guncelgundem/services/api_service.dart';
import 'package:guncelgundem/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPhase5ApiClient extends ApiClient {
  final List<Map<String, dynamic>> postedEvents = [];
  List<Map<String, dynamic>> adsToReturn = [];

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) fromDataJson,
  }) async {
    if (data is Map<String, dynamic>) {
      postedEvents.add(Map<String, dynamic>.from(data));
    }
    return ApiResponse<T>(success: true, data: fromDataJson(data));
  }

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? etag,
    dynamic cachedPayload,
    required T Function(dynamic) fromDataJson,
    int maxRetries = 1,
  }) async {
    return ApiResponse<T>(success: true, data: fromDataJson(adsToReturn));
  }
}

class MockDeviceApiService extends ApiService {
  Map<String, dynamic>? lastUpdateData;
  String? lastUpdateDeviceId;

  @override
  Future<ApiResponse<DeviceModel>> updateDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    lastUpdateDeviceId = deviceId;
    lastUpdateData = data;
    return ApiResponse<DeviceModel>(
      success: true,
      data: DeviceModel(
        deviceId: deviceId,
        platform: 'android',
        pushToken: data['push_token'] as String?,
        preferences: const NotificationPreferenceModel(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PushNotificationPayload Tests', () {
    test('parses standard manual news push payload correctly', () {
      final json = {
        'title': 'Özel Haber',
        'body': 'Önemli ekonomik gelişmeler',
        'data': {
          'event_type': 'MANUAL_NEWS',
          'news_id': '101',
          'slug': 'onemli-gelisme',
          'url': '/haber/onemli-gelisme',
          'category_id': 'ekonomi',
          'location_ids': '34,06',
          'breaking': 'false',
          'push_event_id': 'cmp_12345',
        },
      };

      final payload = PushNotificationPayload.fromJson(json);

      expect(payload.title, 'Özel Haber');
      expect(payload.body, 'Önemli ekonomik gelişmeler');
      expect(payload.eventType, 'MANUAL_NEWS');
      expect(payload.newsId, '101');
      expect(payload.slug, 'onemli-gelisme');
      expect(payload.url, '/haber/onemli-gelisme');
      expect(payload.categoryId, 'ekonomi');
      expect(payload.locationIds, ['34', '06']);
      expect(payload.breaking, false);
      expect(payload.pushEventId, 'cmp_12345');
    });

    test('PendingNotificationIntent detects target content', () {
      const payload = PushNotificationPayload(
        title: 'Son Dakika',
        body: 'Flaş haber',
        eventType: 'BREAKING',
        newsId: '202',
        slug: 'flas-haber',
        breaking: true,
        pushEventId: 'cmp_breaking_1',
      );

      final intent = PendingNotificationIntent.fromPayload(payload);
      expect(intent.hasTargetContent, true);
      expect(intent.newsId, '202');
      expect(intent.slug, 'flas-haber');
      expect(intent.pushEventId, 'cmp_breaking_1');
    });
  });

  group('MobileAdModel Tests', () {
    test('parses ad model and verifies helper getters', () {
      final json = {
        'campaign_id': 'ad_999',
        'advertiser_name': 'Test Reklamveren A.Ş.',
        'campaign_name': 'Bahar Kampanyası',
        'type': 'sponsored_news',
        'placement_ids': ['home_top', 'news_detail_top'],
        'image_url': 'https://example.com/banner.jpg',
        'mobile_image_url': 'https://example.com/mobile-banner.jpg',
        'title': 'Özel Sponsorlu İçerik',
        'description': 'Ayrıntılı açıklama',
        'cta_text': 'Habere Git',
        'target_url': 'https://example.com/detay',
        'news_id': '303',
        'priority': 25,
      };

      final ad = MobileAdModel.fromJson(json);

      expect(ad.campaignId, 'ad_999');
      expect(ad.advertiserName, 'Test Reklamveren A.Ş.');
      expect(ad.type, 'sponsored_news');
      expect(ad.placementIds, contains('home_top'));
      expect(ad.placementIds, contains('news_detail_top'));
      expect(ad.effectiveImageUrl, 'https://example.com/mobile-banner.jpg');
      expect(ad.isSponsoredNews, true);
      expect(ad.newsId, '303');
      expect(ad.priority, 25);
    });
  });

  group('PushService Tests', () {
    test(
      'initial status reports firebaseConfigurationRequired safely',
      () async {
        final service = PushService();
        expect(service.status, PushServiceStatus.firebaseConfigurationRequired);

        final status = await service.initialize(
          isNativeFirebaseConfigured: false,
        );
        expect(status, PushServiceStatus.firebaseConfigurationRequired);
        expect(service.maskedToken, isNull);
      },
    );

    test(
      'permission denied is honored without bypassing OS settings',
      () async {
        final service = PushService();
        final granted = await service.requestPermission(
          permissionGrantedBySystem: false,
        );

        expect(granted, false);
        expect(service.status, PushServiceStatus.permissionDenied);
      },
    );

    test('token refresh updates device repository and masks token', () async {
      final mockApi = MockDeviceApiService();
      final storage = DeviceStorage();
      final repo = DeviceRepository(apiService: mockApi, storage: storage);
      final service = PushService(deviceRepository: repo);

      const rawToken = 'fcm_token_abcdef1234567890_secret_xyz';
      final ok = await service.handleTokenRefresh(rawToken);

      expect(ok, true);
      expect(mockApi.lastUpdateData?['push_token'], rawToken);
      expect(service.maskedToken, 'fcm_to..._xyz');
      expect(service.maskedToken!.contains('abcdef1234567890'), false);
    });

    test('handleNotificationOpen emits click intent to stream', () async {
      final service = PushService();
      const payload = PushNotificationPayload(
        title: 'Özel Bildirim',
        body: 'Haber detayı',
        pushEventId: 'cmp_click_test',
        newsId: '505',
      );

      expectLater(
        service.onNotificationClicked,
        emits(
          predicate<PendingNotificationIntent>((intent) {
            return intent.newsId == '505' &&
                intent.pushEventId == 'cmp_click_test';
          }),
        ),
      );

      await service.handleNotificationOpen(payload);
    });
  });

  group('AnalyticsService & Deduplication Tests', () {
    test(
      'records notification open and deduplicates duplicate calls',
      () async {
        final mockClient = MockPhase5ApiClient();
        final storage = DeviceStorage();
        final repo = DeviceRepository(storage: storage);
        final analytics = AnalyticsService(
          apiClient: mockClient,
          deviceRepository: repo,
        );

        // First call
        final ok1 = await analytics.trackNotificationOpen(
          pushEventId: 'event_001',
          campaignId: 'camp_001',
          newsId: '101',
        );
        expect(ok1, true);
        expect(mockClient.postedEvents.length, 1);
        expect(
          mockClient.postedEvents.first['event_type'],
          'notification_open',
        );
        expect(mockClient.postedEvents.first['push_event_id'], 'event_001');

        // Duplicate immediate call - should be debounced
        final ok2 = await analytics.trackNotificationOpen(
          pushEventId: 'event_001',
          campaignId: 'camp_001',
          newsId: '101',
        );
        expect(ok2, true);
        expect(
          mockClient.postedEvents.length,
          1,
        ); // Debounced, no second network post!
      },
    );

    test('records ad impression and ad click', () async {
      final mockClient = MockPhase5ApiClient();
      final storage = DeviceStorage();
      final repo = DeviceRepository(storage: storage);
      final analytics = AnalyticsService(
        apiClient: mockClient,
        deviceRepository: repo,
      );

      await analytics.trackAdImpression(
        campaignId: 'ad_camp_1',
        placementId: 'home_top',
        newsId: '202',
      );

      await analytics.trackAdClick(
        campaignId: 'ad_camp_1',
        placementId: 'home_top',
      );

      expect(mockClient.postedEvents.length, 2);
      expect(mockClient.postedEvents[0]['event_type'], 'ad_impression');
      expect(mockClient.postedEvents[1]['event_type'], 'ad_click');
    });
  });

  group('AdService Tests', () {
    test('fetches active ads for placement and returns top ad', () async {
      final mockClient = MockPhase5ApiClient();
      mockClient.adsToReturn = [
        {
          'campaign_id': 'ad_top_1',
          'advertiser_name': 'Sponsor 1',
          'campaign_name': 'En Üst Reklam',
          'type': 'image',
          'placement_ids': ['home_top'],
          'title': 'Sponsor Başlık',
          'cta_text': 'Tıkla',
          'target_url': 'https://example.com',
          'priority': 50,
        },
      ];

      final adService = AdService(apiClient: mockClient);
      final adsResponse = await adService.getAds(placement: 'home_top');

      expect(adsResponse.success, true);
      expect(adsResponse.data?.length, 1);
      expect(adsResponse.data?.first.campaignId, 'ad_top_1');

      final topAd = await adService.getTopAd(placement: 'home_top');
      expect(topAd, isNotNull);
      expect(topAd!.campaignId, 'ad_top_1');
    });
  });
}
