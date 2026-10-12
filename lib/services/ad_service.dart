import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_response.dart';
import '../data/models/ad_model.dart';

/// Mobil Reklam Servisi
///
/// FAZ 5 / DİNAMİK REKLAM VE SPONSORLU HABER ALTYAPISI
///
/// Uygulama slotları için backend'den aktif reklamları çeker.
/// Reklam kapatıldığında veya süresi dolduğunda anında güncellenir, yeni APK gerekmez.
class AdService {
  final ApiClient _client;

  AdService({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();

  /// Belirtilen slot için aktif reklamları çeker
  ///
  /// [placement]: 'home_top', 'home_after_hero', 'home_feed_inline',
  ///              'category_feed_inline', 'local_feed_inline',
  ///              'news_detail_top', 'news_detail_middle', 'news_detail_bottom'
  Future<ApiResponse<List<MobileAdModel>>> getAds({
    required String placement,
    String? categoryId,
    String? locationId,
  }) {
    final params = <String, dynamic>{
      'placement': placement,
      if (categoryId != null && categoryId.isNotEmpty)
        'category_id': categoryId,
      if (locationId != null && locationId.isNotEmpty)
        'location_id': locationId,
    };

    return _client.get<List<MobileAdModel>>(
      ApiEndpoints.ads,
      queryParameters: params,
      fromDataJson: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((a) => MobileAdModel.fromJson(a))
              .toList();
        }
        return const <MobileAdModel>[];
      },
    );
  }

  /// Belirtilen slot için en yüksek öncelikli tek reklamı döner
  Future<MobileAdModel?> getTopAd({
    required String placement,
    String? categoryId,
    String? locationId,
  }) async {
    final response = await getAds(
      placement: placement,
      categoryId: categoryId,
      locationId: locationId,
    );
    if (response.success &&
        response.data != null &&
        response.data!.isNotEmpty) {
      return response.data!.first;
    }
    return null;
  }
}
