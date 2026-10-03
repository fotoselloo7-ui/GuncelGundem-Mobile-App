import 'package:equatable/equatable.dart';

import 'app_exception.dart';

/// UI ve Repository katmanları arasında taşınan tip güvenli hata nesnesi
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final int? statusCode;

  const Failure(this.message, {this.code, this.statusCode});

  @override
  List<Object?> get props => [message, code, statusCode];

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';

  /// AppException'ı ilgili Failure'a dönüştürür
  factory Failure.fromException(AppException exception) {
    if (exception is NetworkException) {
      return NetworkFailure(message: exception.message, code: exception.code);
    } else if (exception is TimeoutException) {
      return TimeoutFailure(message: exception.message, code: exception.code);
    } else if (exception is MaintenanceException) {
      return MaintenanceFailure(
        message: exception.message,
        code: exception.code,
        maintenanceMessage: exception.maintenanceMessage,
      );
    } else if (exception is NotFoundException) {
      return NotFoundFailure(message: exception.message, code: exception.code);
    } else if (exception is ValidationException) {
      return ValidationFailure(
        message: exception.message,
        code: exception.code,
      );
    } else if (exception is RateLimitException) {
      return RateLimitFailure(message: exception.message, code: exception.code);
    } else if (exception is CacheException) {
      return CacheFailure(message: exception.message, code: exception.code);
    } else {
      return ServerFailure(
        message: exception.message,
        code: exception.code,
        statusCode: exception.statusCode,
      );
    }
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    String message = 'İnternet bağlantınızı kontrol ediniz.',
    String? code,
  }) : super(message, code: code ?? 'NETWORK_ERROR');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    String message = 'Bağlantı zaman aşımına uğradı.',
    String? code,
  }) : super(message, code: code ?? 'TIMEOUT_ERROR');
}

class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'Sunucu ile iletişim kurulurken bir hata oluştu.',
    String? code,
    int? statusCode,
  }) : super(message, code: code ?? 'SERVER_ERROR', statusCode: statusCode);
}

class MaintenanceFailure extends Failure {
  final String? maintenanceMessage;

  const MaintenanceFailure({
    String message = 'Sistem şu anda bakım aşamasındadır.',
    String? code,
    this.maintenanceMessage,
  }) : super(message, code: code ?? 'MAINTENANCE_MODE', statusCode: 503);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    String message = 'İstenen kaynak bulunamadı.',
    String? code,
  }) : super(message, code: code ?? 'ENDPOINT_NOT_FOUND', statusCode: 404);
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    String message = 'Gönderilen parametreler geçersiz.',
    String? code,
  }) : super(message, code: code ?? 'VALIDATION_ERROR', statusCode: 422);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({
    String message = 'Çok fazla istek gönderildi.',
    String? code,
  }) : super(message, code: code ?? 'RATE_LIMIT_EXCEEDED', statusCode: 429);
}

class CacheFailure extends Failure {
  const CacheFailure({
    String message = 'Önbellek verisi okunamadı.',
    String? code,
  }) : super(message, code: code ?? 'CACHE_ERROR');
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    String message = 'Beklenmeyen bir hata oluştu.',
    String? code,
  }) : super(message, code: code ?? 'UNKNOWN_ERROR');
}
