import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/errors/app_exception.dart';
import 'package:guncelgundem/core/errors/failure.dart';
import 'package:guncelgundem/core/network/api_response.dart';

void main() {
  group('API Envelope and Error Mapping Tests', () {
    test(
      'ApiResponse correctly parses success envelope with data and meta',
      () {
        final json = {
          'success': true,
          'data': {'title': 'Örnek Başlık'},
          'meta': {
            'timestamp': '2026-09-29T10:48:35+03:00',
            'version': 'v1',
            'page': 1,
            'limit': 15,
            'has_more': false,
          },
        };

        final response = ApiResponse<String>.fromJson(
          json,
          (data) => (data as Map<String, dynamic>)['title'] as String,
          etag: 'w/"etag123"',
        );

        expect(response.isSuccess, isTrue);
        expect(response.data, 'Örnek Başlık');
        expect(response.meta?.page, 1);
        expect(response.meta?.limit, 15);
        expect(response.meta?.hasMore, isFalse);
        expect(response.etag, 'w/"etag123"');
        expect(response.isFromCache, isFalse);
      },
    );

    test(
      'ApiResponse correctly parses error envelope (404, 422, 503, etc.)',
      () {
        final json404 = {
          'success': false,
          'error': {
            'code': 'ENDPOINT_NOT_FOUND',
            'message': 'İstenen endpoint bulunamadı.',
          },
          'meta': {'version': 'v1'},
        };

        final response404 = ApiResponse<dynamic>.fromJson(json404, (d) => d);
        expect(response404.isSuccess, isFalse);
        expect(response404.error?.code, 'ENDPOINT_NOT_FOUND');
        expect(response404.error?.message, 'İstenen endpoint bulunamadı.');

        final json422 = {
          'success': false,
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Arama sorgusu en az 2 karakter olmalıdır.',
          },
        };

        final response422 = ApiResponse<dynamic>.fromJson(json422, (d) => d);
        expect(response422.error?.code, 'VALIDATION_ERROR');
      },
    );

    test('Failure.fromException correctly maps all AppException types', () {
      expect(
        Failure.fromException(const NetworkException()),
        isA<NetworkFailure>(),
      );

      expect(
        Failure.fromException(const TimeoutException()),
        isA<TimeoutFailure>(),
      );

      expect(
        Failure.fromException(const MaintenanceException(message: 'Bakım var')),
        isA<MaintenanceFailure>(),
      );

      expect(
        Failure.fromException(const NotFoundException()),
        isA<NotFoundFailure>(),
      );

      expect(
        Failure.fromException(const ValidationException()),
        isA<ValidationFailure>(),
      );

      expect(
        Failure.fromException(const RateLimitException()),
        isA<RateLimitFailure>(),
      );

      expect(
        Failure.fromException(const CacheException()),
        isA<CacheFailure>(),
      );

      expect(
        Failure.fromException(const ServerException(statusCode: 500)),
        isA<ServerFailure>(),
      );
    });

    test('ApiMeta serializes and deserializes accurately', () {
      const meta = ApiMeta(
        timestamp: '2026-09-29T10:00:00Z',
        version: 'v1',
        page: 2,
        limit: 15,
        hasMore: true,
        total: 45,
      );

      final json = meta.toJson();
      final parsed = ApiMeta.fromJson(json);

      expect(parsed.page, 2);
      expect(parsed.hasMore, isTrue);
      expect(parsed.total, 45);
    });
  });
}
