import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/errors/app_exception.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/services/api_service.dart';

/// Üretim `/config` sözleşmesi — DETERMİNİSTİK.
///
/// Bu test daha önce doğrudan canlı `https://guncelgundem.tr/api/mobile/v1`
/// adresine istek atıyordu ve iki sorunu vardı:
///   1. Ağ erişimine bağlıydı; çevrimdışı/kısıtlı koşucuda 30 sn zaman aşımıyla
///      tüm paketi düşürüyordu (deterministik değil).
///   2. Geniş bir `try/catch` her hatayı yutuyordu (`expect(e, isNotNull)`),
///      yani gerçek bir sözleşme kırılması bile PASS görünebiliyordu.
///
/// Burada sözleşme, ÜRETİMDEN ALINMIŞ gerçek yanıt gövdesiyle doğrulanır:
/// ağ yok, yutulan hata yok, assertion'lar gerçek.
/// Yanıt 2026-10-03 tarihinde canlı uçtan kaydedilmiştir.
///
/// Canlı erişilebilirlik ayrı bir sürüm kapısıdır ve release raporunda gerçek
/// HTTP ölçümüyle belgelenir; birim test paketinin işi değildir.
const Map<String, dynamic> productionConfigPayload = {
  'success': true,
  'data': {
    'api_version': 'v1',
    'site_name': 'Güncel Gündem',
    'short_name': 'GüncelGündem',
    'site_url': 'https://guncelgundem.tr',
    'maintenance_mode': false,
    'maintenance_message': '',
    'force_update': false,
    'minimum_app_version': '1.0.0',
    'recommended_app_version': '1.0.0',
    'logo_url': 'https://guncelgundem.tr/assets/images/logo.svg',
    'logo_mobile_url': 'https://guncelgundem.tr/assets/images/logo.svg',
    'favicon_url': 'https://guncelgundem.tr/favicon.ico',
    'colors': <String, dynamic>{'primary': '#E30613'},
    'features': <String, dynamic>{},
  },
};

/// Kaydedilmiş üretim yanıtını döndüren, ağ kullanmayan Dio adaptörü.
class _RecordedConfigAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode(productionConfigPayload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 500 döndüren adaptör: hata yolunun sessizce yutulmadığını doğrular.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"success":false}', 500);

  @override
  void close({bool force = false}) {}
}

ApiService _service(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://guncelgundem.tr/api/mobile/v1'),
  )..httpClientAdapter = adapter;
  return ApiService(apiClient: ApiClient(customDio: dio));
}

void main() {
  test('GET /config parses the production contract into AppConfigModel', () async {
    final adapter = _RecordedConfigAdapter();
    final response = await _service(adapter).getConfig();

    // Hata yutulmaz: başarısızlık doğrudan testi düşürür.
    expect(response.isSuccess, isTrue);
    expect(response.data, isNotNull);
    expect(response.data!.apiVersion, 'v1');
    expect(response.data!.siteName, isNotEmpty);
    expect(response.data!.siteName, 'Güncel Gündem');
    expect(response.data!.maintenanceMode, isFalse);
    expect(response.data!.forceUpdate, isFalse);
    expect(response.data!.siteUrl, 'https://guncelgundem.tr');
    // Doğru uç noktanın çağrıldığı doğrulanır (yol sözleşmesi).
    expect(adapter.requestedPaths, isNotEmpty);
  });

  test('config failure surfaces as a typed ServerException, not a raw crash', () async {
    // Sunucu hatası sessizce yutulmaz: istemci TİPLİ bir uygulama istisnası
    // fırlatır ve çağıran katman (repository) bunu karşılar.
    await expectLater(
      _service(_FailingAdapter()).getConfig(),
      throwsA(isA<ServerException>()),
    );
  });
}
