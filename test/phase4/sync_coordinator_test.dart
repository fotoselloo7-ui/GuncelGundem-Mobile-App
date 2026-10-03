import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/core/storage/device_storage.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/app_config_model.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/data/repositories/config_repository.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/data/repositories/home_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/design/branding_state.dart';
import 'package:guncelgundem/services/api_service.dart';
import 'package:guncelgundem/services/sync_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCoordinatorApiService extends ApiService {
  int configCallCount = 0;
  int homeCallCount = 0;
  int categoriesCallCount = 0;
  int locationsCallCount = 0;

  @override
  Future<ApiResponse<AppConfigModel>> getConfig({
    String? etag,
    dynamic cachedPayload,
  }) async {
    configCallCount++;
    return const ApiResponse<AppConfigModel>(
      success: true,
      data: AppConfigModel(
        apiVersion: 'v1',
        siteName: 'Senkronize Gazete',
        colors: {'primary': '#3B82F6'},
      ),
      etag: 'etag_cfg_1',
      isFromCache: false,
    );
  }

  @override
  Future<ApiResponse<HomeModel>> getHome({
    String? etag,
    dynamic cachedPayload,
  }) async {
    homeCallCount++;
    return const ApiResponse<HomeModel>(
      success: true,
      data: HomeModel(
        breaking: [
          NewsModel(
            id: 'sync_n1',
            slug: 'canli-haber',
            title: 'Canlı Haber',
            summary: 'Canlı Haber Özeti',
          ),
        ],
      ),
      etag: 'etag_home_1',
      isFromCache: false,
    );
  }

  @override
  Future<ApiResponse<List<CategoryModel>>> getCategories({
    String? etag,
    dynamic cachedPayload,
  }) async {
    categoriesCallCount++;
    return const ApiResponse<List<CategoryModel>>(
      success: true,
      data: [CategoryModel(id: 'cat_gundem', name: 'Gündem', slug: 'gundem')],
      isFromCache: false,
    );
  }

  @override
  Future<ApiResponse<List<LocationProvinceModel>>> getLocations({
    String? etag,
    dynamic cachedPayload,
  }) async {
    locationsCallCount++;
    return const ApiResponse<List<LocationProvinceModel>>(
      success: true,
      data: [
        LocationProvinceModel(
          id: 'loc_prov_antalya',
          name: 'Antalya',
          slug: 'antalya',
          districts: [],
        ),
      ],
      isFromCache: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalCacheService cacheService;
  late FakeCoordinatorApiService fakeApi;
  late ConfigRepository configRepo;
  late HomeRepository homeRepo;
  late TaxonomyRepository taxonomyRepo;
  late DeviceRepository deviceRepo;
  late BrandingState branding;
  late SyncCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('guncelgundem_coord_test_');
    cacheService = LocalCacheService.instance;
    await cacheService.init(overrideDir: tempDir);
    await cacheService.clear();

    fakeApi = FakeCoordinatorApiService();
    configRepo = ConfigRepository(
      apiService: fakeApi,
      cacheService: cacheService,
    );
    homeRepo = HomeRepository(apiService: fakeApi, cacheService: cacheService);
    taxonomyRepo = TaxonomyRepository(
      apiService: fakeApi,
      cacheService: cacheService,
    );
    deviceRepo = DeviceRepository(
      apiService: fakeApi,
      storage: DeviceStorage(),
    );
    branding = BrandingState.instance;

    coordinator = SyncCoordinator(
      configRepository: configRepo,
      homeRepository: homeRepo,
      taxonomyRepository: taxonomyRepo,
      deviceRepository: deviceRepo,
      brandingState: branding,
      resumeThreshold: const Duration(seconds: 2),
    );
  });

  tearDown(() async {
    await cacheService.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SyncCoordinator Startup and Resume Tests', () {
    test('syncOnStartup revalidates config, home, updates branding', () async {
      final result = await coordinator.syncOnStartup(force: true);

      expect(result.configUpdated, isTrue);
      expect(result.homeUpdated, isTrue);
      expect(branding.siteName, 'Senkronize Gazete');
      expect(fakeApi.configCallCount, 1);
      expect(fakeApi.homeCallCount, 1);
      expect(fakeApi.categoriesCallCount, 1);
      expect(fakeApi.locationsCallCount, 1);
    });

    test('syncOnResume throttles calls within threshold and executes after threshold', () async {
      // 1. Initial startup sync
      await coordinator.syncOnStartup();
      final initialConfigCalls = fakeApi.configCallCount;
      final initialHomeCalls = fakeApi.homeCallCount;

      // 2. Call resume immediately (< 2s threshold) -> should NOT make network calls
      final immediateResume = await coordinator.syncOnResume();
      expect(immediateResume, isFalse);
      expect(fakeApi.configCallCount, initialConfigCalls);
      expect(fakeApi.homeCallCount, initialHomeCalls);

      // 3. Wait for threshold to expire (> 2s)
      await Future.delayed(const Duration(milliseconds: 2100));

      // 4. Call resume again -> should execute sync
      final delayedResume = await coordinator.syncOnResume();
      expect(delayedResume, isTrue);
      expect(fakeApi.configCallCount, initialConfigCalls + 1);
      expect(fakeApi.homeCallCount, initialHomeCalls + 1);
    });
  });
}
