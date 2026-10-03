import 'package:equatable/equatable.dart';

Map<String, dynamic> liveMap(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};
double? liveNumber(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

String? liveText(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;

bool liveExpired(String? expiry) =>
    expiry != null &&
    !(DateTime.tryParse(expiry)?.isAfter(DateTime.now()) ?? false);

class MarketItemModel extends Equatable {
  final String code, name, provider;
  final double? value, buy, sell, changePercent;
  final String? currency, unit, updatedAt, source, status, expiresAt;
  final bool isReference, isStale;
  const MarketItemModel({
    required this.code,
    required this.name,
    required this.provider,
    this.value,
    this.buy,
    this.sell,
    this.changePercent,
    this.currency,
    this.unit,
    this.updatedAt,
    this.expiresAt,
    this.source,
    this.status,
    this.isReference = false,
    this.isStale = false,
  });
  factory MarketItemModel.fromJson(Map<String, dynamic> json) =>
      MarketItemModel(
        code: liveText(json['code']) ?? '',
        name: liveText(json['name']) ?? '',
        provider: liveText(json['provider']) ?? '',
        value: liveNumber(json['value']),
        buy: liveNumber(json['buy']),
        sell: liveNumber(json['sell']),
        changePercent: liveNumber(json['change_percent']),
        currency: liveText(json['currency']),
        unit: json['unit'] == null ? null : '${json['unit']}',
        updatedAt: liveText(json['updated_at']),
        expiresAt: liveText(json['expires_at']),
        source: liveText(json['source']),
        status: liveText(json['status']),
        isReference: json['is_reference'] == true,
        isStale: json['is_stale'] == true,
      );
  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'provider': provider,
    'value': value,
    'buy': buy,
    'sell': sell,
    'change_percent': changePercent,
    'currency': currency,
    'unit': unit,
    'updated_at': updatedAt,
    'expires_at': expiresAt,
    'source': source,
    'status': status,
    'is_reference': isReference,
    'is_stale': isStale,
  };
  bool get stale => isStale || status != 'FRESH' || liveExpired(expiresAt);
  @override
  List<Object?> get props => [toJson()];
}

class MarketModuleModel extends Equatable {
  final bool available, offline;
  final String title;
  final List<MarketItemModel> items;
  const MarketModuleModel({
    this.available = false,
    this.offline = false,
    this.title = 'Piyasalar',
    this.items = const [],
  });
  factory MarketModuleModel.fromJson(Map<String, dynamic> json) =>
      MarketModuleModel(
        available: json['available'] == true,
        offline: json['offline'] == true,
        title: liveText(json['title']) ?? 'Piyasalar',
        items: json['items'] is List
            ? (json['items'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(MarketItemModel.fromJson)
                  .where((item) => item.code.isNotEmpty && item.value != null)
                  .toList()
            : const [],
      );
  Map<String, dynamic> toJson() => {
    'available': available,
    'offline': offline,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
  };
  MarketModuleModel asOffline() => MarketModuleModel(
    available: available,
    offline: true,
    title: title,
    items: items,
  );
  @override
  List<Object?> get props => [available, offline, title, items];
}

class WeatherModuleModel extends Equatable {
  final bool available, offline, isStale;
  final String? locationId,
      cityName,
      districtName,
      citySlug,
      fallback,
      condition,
      icon,
      updatedAt,
      expiresAt,
      source,
      status;
  final double? temperature, feelsLike, humidity, wind;
  const WeatherModuleModel({
    this.available = false,
    this.offline = false,
    this.isStale = false,
    this.locationId,
    this.cityName,
    this.districtName,
    this.citySlug,
    this.fallback,
    this.condition,
    this.icon,
    this.updatedAt,
    this.expiresAt,
    this.source,
    this.status,
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.wind,
  });
  factory WeatherModuleModel.fromJson(Map<String, dynamic> json) =>
      WeatherModuleModel(
        available: json['available'] == true,
        offline: json['offline'] == true,
        isStale: json['is_stale'] == true,
        locationId: liveText(json['location_id']),
        cityName: liveText(json['city_name']),
        districtName: liveText(json['district_name']),
        citySlug: liveText(json['city_slug']),
        fallback: liveText(json['fallback']),
        condition: liveText(json['condition']),
        icon: liveText(json['icon']),
        updatedAt: liveText(json['updated_at']),
        expiresAt: liveText(json['expires_at']),
        source: liveText(json['source']),
        status: liveText(json['status']),
        temperature: liveNumber(json['temperature']),
        feelsLike: liveNumber(json['feels_like']),
        humidity: liveNumber(json['humidity']),
        wind: liveNumber(json['wind_speed']),
      );
  bool get hasData => available && temperature != null;
  bool get stale =>
      offline || isStale || status != 'FRESH' || liveExpired(expiresAt);
  Map<String, dynamic> toJson() => {
    'available': available,
    'offline': offline,
    'is_stale': isStale,
    'location_id': locationId,
    'city_name': cityName,
    'district_name': districtName,
    'city_slug': citySlug,
    'fallback': fallback,
    'condition': condition,
    'icon': icon,
    'updated_at': updatedAt,
    'expires_at': expiresAt,
    'source': source,
    'status': status,
    'temperature': temperature,
    'feels_like': feelsLike,
    'humidity': humidity,
    'wind_speed': wind,
  };
  WeatherModuleModel asOffline() =>
      WeatherModuleModel.fromJson({...toJson(), 'offline': true});
  @override
  List<Object?> get props => [toJson()];
}

class LiveModulesModel extends Equatable {
  final MarketModuleModel market;
  final WeatherModuleModel weather;
  final LiveListModuleModel earthquake, pharmacy, prayerTimes;
  const LiveModulesModel({
    this.market = const MarketModuleModel(),
    this.weather = const WeatherModuleModel(),
    this.earthquake = const LiveListModuleModel(),
    this.pharmacy = const LiveListModuleModel(),
    this.prayerTimes = const LiveListModuleModel(),
  });
  factory LiveModulesModel.fromJson(Map<String, dynamic> json) =>
      LiveModulesModel(
        market: MarketModuleModel.fromJson(liveMap(json['market'])),
        weather: WeatherModuleModel.fromJson(liveMap(json['weather'])),
        earthquake: LiveListModuleModel.fromJson(liveMap(json['earthquake'])),
        pharmacy: LiveListModuleModel.fromJson(liveMap(json['pharmacy'])),
        prayerTimes: LiveListModuleModel.fromJson(
          liveMap(json['prayer_times']),
        ),
      );
  Map<String, dynamic> toJson() => {
    'market': market.toJson(),
    'weather': weather.toJson(),
    'earthquake': earthquake.toJson(),
    'pharmacy': pharmacy.toJson(),
    'prayer_times': prayerTimes.toJson(),
  };
  LiveModulesModel asOffline() => LiveModulesModel(
    market: market.asOffline(),
    weather: weather.asOffline(),
    earthquake: earthquake.asOffline(),
    pharmacy: pharmacy.asOffline(),
    prayerTimes: prayerTimes.asOffline(),
  );
  LiveModulesModel forLocation(String? id) => LiveModulesModel(
    market: market,
    earthquake: earthquake,
    weather: WeatherModuleModel(locationId: id),
  );
  @override
  List<Object?> get props => [
    market,
    weather,
    earthquake,
    pharmacy,
    prayerTimes,
  ];
}

/// Existing server-normalized list modules, using the same Home state/cache.
class LiveListModuleModel extends Equatable {
  final bool available, offline, isStale;
  final String? locationId,
      expiresAt,
      updatedAt,
      source,
      status,
      cityName,
      fallback,
      disclaimer;
  final List<Map<String, dynamic>> items;
  const LiveListModuleModel({
    this.available = false,
    this.offline = false,
    this.isStale = false,
    this.locationId,
    this.expiresAt,
    this.updatedAt,
    this.source,
    this.status,
    this.cityName,
    this.fallback,
    this.disclaimer,
    this.items = const [],
  });
  factory LiveListModuleModel.fromJson(Map<String, dynamic> json) =>
      LiveListModuleModel(
        available: json['available'] == true,
        offline: json['offline'] == true,
        isStale: json['is_stale'] == true,
        locationId: liveText(json['location_id']),
        expiresAt: liveText(json['expires_at']),
        updatedAt: liveText(json['updated_at']),
        source: liveText(json['source']),
        status: liveText(json['status']),
        cityName: liveText(json['city_name']),
        fallback: liveText(json['fallback']),
        disclaimer: liveText(json['disclaimer']),
        items: json['items'] is List
            ? (json['items'] as List).whereType<Map<String, dynamic>>().toList()
            : const [],
      );
  bool get stale =>
      offline ||
      isStale ||
      status != 'FRESH' ||
      (expiresAt != null &&
          !(DateTime.tryParse(expiresAt!)?.isAfter(DateTime.now()) ?? false));
  Map<String, dynamic> toJson() => {
    'available': available,
    'offline': offline,
    'is_stale': isStale,
    'location_id': locationId,
    'expires_at': expiresAt,
    'updated_at': updatedAt,
    'source': source,
    'status': status,
    'city_name': cityName,
    'fallback': fallback,
    'disclaimer': disclaimer,
    'items': items,
  };
  LiveListModuleModel asOffline() =>
      LiveListModuleModel.fromJson({...toJson(), 'offline': true});
  @override
  List<Object?> get props => [toJson()];
}
