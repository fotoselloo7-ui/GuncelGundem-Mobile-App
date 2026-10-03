/// Temel Uygulama Hatası (Exception)
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  const AppException(this.message, {this.code, this.statusCode, this.details});

  @override
  String toString() =>
      '$runtimeType(code: $code, statusCode: $statusCode, message: $message)';
}

/// Ağ / Bağlantı Hatası (Offline, DNS, Socket)
class NetworkException extends AppException {
  const NetworkException([super.message = 'İnternet bağlantısı kurulamadı.'])
    : super(code: 'NETWORK_ERROR');
}

/// Zaman Aşımı Hatası (Connect / Receive Timeout)
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'İstek zaman aşımına uğradı.'])
    : super(code: 'TIMEOUT_ERROR');
}

/// Sunucu Hatası (HTTP 500, 502)
class ServerException extends AppException {
  const ServerException({
    String message = 'Sunucu ile iletişim kurulurken bir hata oluştu.',
    String? code,
    int? statusCode,
  }) : super(message, code: code ?? 'SERVER_ERROR', statusCode: statusCode);
}

/// Bakım Modu Hatası (HTTP 503)
class MaintenanceException extends AppException {
  final String? maintenanceMessage;

  const MaintenanceException({
    this.maintenanceMessage,
    String message = 'Sistem şu anda bakım aşamasındadır.',
  }) : super(message, code: 'MAINTENANCE_MODE', statusCode: 503);
}

/// Bulunamadı Hatası (HTTP 404)
class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'İstenen kaynak bulunamadı.',
    String? code,
  }) : super(message, code: code ?? 'ENDPOINT_NOT_FOUND', statusCode: 404);
}

/// Doğrulama / Geçersiz Parametre Hatası (HTTP 422)
class ValidationException extends AppException {
  const ValidationException({
    String message = 'Gönderilen parametreler geçersiz.',
    String? code,
    dynamic details,
  }) : super(
         message,
         code: code ?? 'VALIDATION_ERROR',
         statusCode: 422,
         details: details,
       );
}

/// İstek Limiti Aşımı (HTTP 429)
class RateLimitException extends AppException {
  const RateLimitException([
    super.message = 'Çok fazla istek gönderildi. Lütfen bekleyin.',
  ]) : super(code: 'RATE_LIMIT_EXCEEDED', statusCode: 429);
}

/// İzin Verilmeyen Metot (HTTP 405)
class MethodNotAllowedException extends AppException {
  const MethodNotAllowedException([
    super.message = 'Bu HTTP metoduna izin verilmiyor.',
  ]) : super(code: 'METHOD_NOT_ALLOWED', statusCode: 405);
}

/// Yanıt Format / JSON Ayrıştırma Hatası
class ParseException extends AppException {
  const ParseException([super.message = 'Veri formatı ayrıştırılamadı.'])
    : super(code: 'PARSE_ERROR');
}

/// Önbellek Hatası
class CacheException extends AppException {
  const CacheException([super.message = 'Önbellek işlemi başarısız oldu.'])
    : super(code: 'CACHE_ERROR');
}
