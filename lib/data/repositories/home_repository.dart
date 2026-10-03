import '../../app/app_config.dart';
import '../../core/storage/local_cache_service.dart';
import '../../services/api_service.dart';
import '../models/home_model.dart';
import '../state/home_data_state.dart';
import '../models/live_module_model.dart';
import 'device_repository.dart';
import 'taxonomy_repository.dart';

/// Ana Sayfa Veri Deposu
class HomeRepository {
  final ApiService _apiService;
  final LocalCacheService _cacheService;
  final HomeDataState _state;
  final DeviceRepository _device;
  final TaxonomyRepository _taxonomy;
  static final Map<String, Future<HomeModel>> _inFlight = {};

  static const String cacheKey = 'cache_home_v1';

  HomeRepository({
    ApiService? apiService,
    LocalCacheService? cacheService,
    HomeDataState? state,
    DeviceRepository? deviceRepository,
    TaxonomyRepository? taxonomyRepository,
  }) : _apiService = apiService ?? ApiService(),
       _cacheService = cacheService ?? LocalCacheService.instance,
       _state = state ?? HomeDataState.instance,
       _device = deviceRepository ?? DeviceRepository(),
       _taxonomy = taxonomyRepository ?? TaxonomyRepository();

  HomeDataState get homeState => _state;
  static String locationCacheKey(String? id) =>
      id == null || id.isEmpty ? cacheKey : '${cacheKey}_location_$id';
  Future<String?> _selectedLocation() async {
    try {
      final ids = (await _device.getPreferences()).locationIds;
      if (ids.isEmpty) return null;
      if (ids.length == 1) return ids.first;
      final provinces = await _taxonomy.getLocations();
      // Match HomeCity.resolve: district first, preserving saved-ID order.
      for (final id in ids) {
        for (final province in provinces) {
          for (final district in province.districts) {
            if (id == district.id) return id;
          }
        }
      }
      for (final id in ids) {
        for (final province in provinces) {
          if (id == province.id) return id;
        }
      }
    } catch (_) {
      // Missing local preferences must not stop the original Home contract.
    }
    return null;
  }

  HomeModel _publish(HomeModel home, String? id, int epoch) {
    if (_state.isActiveLocation(id, epoch)) _state.updateFromHome(home);
    return home;
  }

  /// Önbellekteki ana sayfa verisini okur
  Future<HomeModel?> getCachedHome() async {
    final id = await _selectedLocation();
    final epoch = _state.activateLocation(id);
    final entry = await _cacheService.get(locationCacheKey(id));
    if (entry != null && entry.payload is Map<String, dynamic>) {
      return _publish(
        HomeModel.fromJson(entry.payload as Map<String, dynamic>),
        id,
        epoch,
      );
    }
    return null;
  }

  /// Ana sayfa akışını getirir (Stale-While-Revalidate)
  Future<HomeModel> getHome({bool forceRefresh = false}) async {
    return getHomeForLocation(
      await _selectedLocation(),
      forceRefresh: forceRefresh,
    );
  }

  Future<HomeModel> getHomeForLocation(
    String? locationId, {
    bool forceRefresh = false,
  }) {
    final epoch = _state.activateLocation(locationId);
    final flightKey =
        '${identityHashCode(_state)}:$epoch:${locationCacheKey(locationId)}';
    return _inFlight.putIfAbsent(flightKey, () async {
      try {
        return await _loadForLocation(
          locationId,
          epoch,
          forceRefresh: forceRefresh,
        );
      } finally {
        _inFlight.remove(flightKey);
      }
    });
  }

  /// City and Home use the same Home response/state/cache, never a second weather API.
  Future<WeatherModuleModel?> getWeatherForLocation(
    String locationId, {
    bool forceRefresh = false,
  }) async {
    final epoch = _state.activateLocation(locationId);
    final entry = await _cacheService.get(locationCacheKey(locationId));
    if (!_state.isActiveLocation(locationId, epoch)) return null;
    if (!forceRefresh &&
        entry?.payload is Map<String, dynamic> &&
        DateTime.now().difference(entry!.savedAt) < AppConfig.homeCacheTtl) {
      final current = _state.home?.liveModules?.weather;
      if (current?.locationId == locationId && current!.offline) {
        return current;
      }
      return _publish(
        HomeModel.fromJson(entry.payload),
        locationId,
        epoch,
      ).liveModules?.weather;
    }
    return (await getHomeForLocation(
      locationId,
      forceRefresh: forceRefresh,
    )).liveModules?.weather;
  }

  Future<HomeModel> _loadForLocation(
    String? locationId,
    int epoch, {
    bool forceRefresh = false,
  }) async {
    final key = locationCacheKey(locationId);
    final cachedEntry = await _cacheService.get(key);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = locationId == null || locationId.isEmpty
          ? await _apiService.getHome(etag: etag, cachedPayload: cachedPayload)
          : await _apiService.getHomeForLocation(
              locationId,
              etag: etag,
              cachedPayload: cachedPayload,
            );

      if (response.data != null) {
        if (!response.isFromCache) {
          await _cacheService.set(
            key,
            response.data!.toJson(),
            etag: response.etag,
            // Keep the last successful live snapshot for offline use. Requests
            // still revalidate; Home TTL remains the reuse/freshness window.
            ttl: response.data!.liveModules == null
                ? AppConfig.homeCacheTtl
                : null,
          );
        } else if (response.etag != null) {
          await _cacheService.updateEtag(key, response.etag!);
        }
        return _publish(response.data!, locationId, epoch);
      }
    } catch (_) {
      if (cachedPayload is Map<String, dynamic>) {
        return _publish(
          HomeModel.fromJson(cachedPayload).withOfflineLiveModules(),
          locationId,
          epoch,
        );
      }
      rethrow;
    }

    throw StateError('Ana sayfa verisi alınamadı.');
  }
}
