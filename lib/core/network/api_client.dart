import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../app/app_config.dart';
import '../errors/app_exception.dart';
import 'api_response.dart';

/// Production-ready Dio tabanlı Mobil HTTP İstemcisi
///
/// ETag / If-None-Match, HTTP durum kodu eşlemesi, kontrollü kısa retry ve
/// standart API zarfı ayrıştırması içerir.
class ApiClient {
  final Dio dio;

  ApiClient({Dio? customDio}) : dio = customDio ?? _createDefaultDio();

  static Dio _createDefaultDio() {
    final baseOptions = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'tr.guncelgundem.app',
      },
      // 304'ü ve 4xx/5xx'i kendimiz yönetmek için validateStatus esnek tutulur
      validateStatus: (status) =>
          status != null && status >= 200 && status < 600,
    );

    return Dio(baseOptions);
  }

  /// Güvenli GET İsteği
  ///
  /// [etag]: Varsa If-None-Match başlığı eklenir.
  /// [cachedPayload]: 304 Not Modified döndüğünde bu payload kullanılır.
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? etag,
    dynamic cachedPayload,
    required T Function(dynamic dataJson) fromDataJson,
    int maxRetries = 1,
  }) async {
    final headers = <String, dynamic>{};
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await dio.get(
          path,
          queryParameters: queryParameters,
          options: Options(headers: headers),
        );

        final statusCode = response.statusCode ?? 200;

        // 1. 304 Not Modified
        if (statusCode == 304) {
          if (cachedPayload != null) {
            final parsedData = fromDataJson(cachedPayload);
            return ApiResponse<T>(
              success: true,
              data: parsedData,
              etag: etag,
              isFromCache: true,
            );
          }
          // Cached payload yoksa sunucudan etag'siz zorla çek
          return await get(
            path,
            queryParameters: queryParameters,
            etag: null,
            fromDataJson: fromDataJson,
            maxRetries: 0,
          );
        }

        // 2. HTTP Hata Kodları Eşlemesi
        if (statusCode >= 400) {
          _handleHttpError(response, statusCode);
        }

        // 3. Başarılı Yanıt (200 OK)
        final data = response.data;
        if (data is! Map<String, dynamic>) {
          throw const ParseException('Sunucu geçersiz formatta yanıt verdi.');
        }

        final responseEtag = response.headers.value('etag');

        return ApiResponse<T>.fromJson(
          data,
          fromDataJson,
          etag: responseEtag ?? etag,
          isFromCache: false,
        );
      } on DioException catch (e) {
        // Kontrollü kısa retry (Yalnızca geçici ağ veya zaman aşımı hatalarında)
        if (attempts <= maxRetries && _isTransientError(e)) {
          await Future.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        }
        throw _mapDioException(e);
      } catch (e) {
        if (e is AppException) rethrow;
        throw ServerException(message: 'Beklenmeyen hata: $e');
      }
    }
  }

  /// Güvenli POST İsteği
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic dataJson) fromDataJson,
  }) async {
    try {
      final response = await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );

      final statusCode = response.statusCode ?? 200;
      if (statusCode >= 400) {
        _handleHttpError(response, statusCode);
      }

      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw const ParseException('Sunucu geçersiz formatta yanıt verdi.');
      }

      final responseEtag = response.headers.value('etag');

      return ApiResponse<T>.fromJson(
        responseData,
        fromDataJson,
        etag: responseEtag,
        isFromCache: false,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Beklenmeyen hata: $e');
    }
  }

  /// Güvenli PUT İsteği
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic dataJson) fromDataJson,
  }) async {
    try {
      final response = await dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );

      final statusCode = response.statusCode ?? 200;
      if (statusCode >= 400) {
        _handleHttpError(response, statusCode);
      }

      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw const ParseException('Sunucu geçersiz formatta yanıt verdi.');
      }

      final responseEtag = response.headers.value('etag');

      return ApiResponse<T>.fromJson(
        responseData,
        fromDataJson,
        etag: responseEtag,
        isFromCache: false,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Beklenmeyen hata: $e');
    }
  }

  bool _isTransientError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const TimeoutException(
          'Sunucu bağlantısı zaman aşımına uğradı.',
        );

      case DioExceptionType.connectionError:
        return const NetworkException(
          'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol ediniz.',
        );

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status != null) {
          _handleHttpError(e.response!, status);
        }
        return ServerException(message: e.message ?? 'Sunucu hatası.');

      default:
        if (e.error is SocketException) {
          return const NetworkException('İnternet bağlantısı kurulamadı.');
        }
        return ServerException(message: e.message ?? 'Ağ hatası oluştu.');
    }
  }

  void _handleHttpError(Response response, int statusCode) {
    String message = 'Bir hata oluştu.';
    String code = 'HTTP_$statusCode';
    dynamic details;

    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] is Map) {
      final err = data['error'] as Map<String, dynamic>;
      message = (err['message'] as String?) ?? message;
      code = (err['code'] as String?) ?? code;
      details = err['details'];
    }

    switch (statusCode) {
      case 404:
        throw NotFoundException(message: message, code: code);

      case 405:
        throw MethodNotAllowedException(message);

      case 422:
        throw ValidationException(
          message: message,
          code: code,
          details: details,
        );

      case 429:
        throw RateLimitException(message);

      case 503:
        throw MaintenanceException(
          message: message,
          maintenanceMessage: message,
        );

      default:
        throw ServerException(
          message: message,
          code: code,
          statusCode: statusCode,
        );
    }
  }
}
