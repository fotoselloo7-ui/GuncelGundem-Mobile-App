import 'package:equatable/equatable.dart';

/// Standart Faz 2 Backend API Yanıt Zarfı
class ApiResponse<T> extends Equatable {
  final bool success;
  final T? data;
  final ApiError? error;
  final ApiMeta? meta;

  /// HTTP ETag başlığı (Cache / 304 takibi için)
  final String? etag;

  /// Bu yanıt yerel önbellekten mi sağlandı?
  final bool isFromCache;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.meta,
    this.etag,
    this.isFromCache = false,
  });

  bool get isSuccess => success && error == null;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic dataJson) fromDataJson, {
    String? etag,
    bool isFromCache = false,
  }) {
    final success = json['success'] as bool? ?? false;
    final rawData = json['data'];
    final rawError = json['error'];
    final rawMeta = json['meta'];

    return ApiResponse<T>(
      success: success,
      data: (success && rawData != null) ? fromDataJson(rawData) : null,
      error: rawError != null
          ? ApiError.fromJson(rawError as Map<String, dynamic>)
          : null,
      meta: rawMeta != null
          ? ApiMeta.fromJson(rawMeta as Map<String, dynamic>)
          : null,
      etag: etag,
      isFromCache: isFromCache,
    );
  }

  /// Önbellek kopyası üretir
  ApiResponse<T> copyWithCacheFlag({required bool isFromCache, String? etag}) {
    return ApiResponse<T>(
      success: success,
      data: data,
      error: error,
      meta: meta,
      etag: etag ?? this.etag,
      isFromCache: isFromCache,
    );
  }

  @override
  List<Object?> get props => [success, data, error, meta, etag, isFromCache];
}

/// Backend Hata Nesnesi
class ApiError extends Equatable {
  final String code;
  final String message;
  final dynamic details;

  const ApiError({required this.code, required this.message, this.details});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: (json['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: (json['message'] as String?) ?? 'Bilinmeyen bir hata oluştu.',
      details: json['details'],
    );
  }

  @override
  List<Object?> get props => [code, message, details];
}

/// Yanıt Meta Bilgisi (Pagination & Version)
class ApiMeta extends Equatable {
  final String? timestamp;
  final String? version;
  final int? page;
  final int? limit;
  final bool? hasMore;
  final int? total;

  const ApiMeta({
    this.timestamp,
    this.version,
    this.page,
    this.limit,
    this.hasMore,
    this.total,
  });

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      timestamp: json['timestamp'] as String?,
      version: json['version'] as String?,
      page: json['page'] as int?,
      limit: json['limit'] as int?,
      hasMore: json['has_more'] as bool?,
      total: json['total'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (timestamp != null) 'timestamp': timestamp,
      if (version != null) 'version': version,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (hasMore != null) 'has_more': hasMore,
      if (total != null) 'total': total,
    };
  }

  @override
  List<Object?> get props => [timestamp, version, page, limit, hasMore, total];
}
