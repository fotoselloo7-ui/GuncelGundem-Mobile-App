import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/core/storage/device_storage.dart';
import 'package:guncelgundem/data/models/device_model.dart';
import 'package:guncelgundem/data/models/notification_preference_model.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDeviceApiService extends ApiService {
  Map<String, dynamic>? lastRegisteredBody;
  Map<String, dynamic>? lastUpdatedBody;
  String? lastUpdatedDeviceId;
  bool shouldThrowNetworkError = false;

  @override
  Future<ApiResponse<DeviceModel>> registerDevice(
    Map<String, dynamic> data,
  ) async {
    if (shouldThrowNetworkError) {
      throw Exception('Network offline');
    }
    lastRegisteredBody = data;
    return ApiResponse<DeviceModel>(
      success: true,
      data: DeviceModel.fromJson(data),
      isFromCache: false,
    );
  }

  @override
  Future<ApiResponse<DeviceModel>> updateDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    if (shouldThrowNetworkError) {
      throw Exception('Network offline');
    }
    lastUpdatedDeviceId = deviceId;
    lastUpdatedBody = data;
    return ApiResponse<DeviceModel>(
      success: true,
      data: DeviceModel(
        deviceId: deviceId,
        platform: 'android',
        preferences: data['preferences'] is Map<String, dynamic>
            ? NotificationPreferenceModel.fromJson(
                data['preferences'] as Map<String, dynamic>,
              )
            : const NotificationPreferenceModel(),
      ),
      isFromCache: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDeviceApiService fakeApi;
  late DeviceStorage storage;
  late DeviceRepository deviceRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeDeviceApiService();
    storage = DeviceStorage();
    deviceRepo = DeviceRepository(apiService: fakeApi, storage: storage);
  });

  group('Device ID & Notification Preference Tests', () {
    test(
      'Anonymous device UUID v4 is generated, persistent, and valid format',
      () async {
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );

        final deviceId1 = await deviceRepo.getDeviceId();
        expect(deviceId1, isNotEmpty);
        expect(uuidRegex.hasMatch(deviceId1), isTrue);

        // Subsequent call must return the exact same UUID
        final deviceId2 = await deviceRepo.getDeviceId();
        expect(deviceId2, equals(deviceId1));
      },
    );

    test('Initial notification preferences have secure defaults', () async {
      final prefs = await deviceRepo.getPreferences();

      expect(prefs.notificationsEnabled, isTrue);
      expect(prefs.breakingNews, isTrue);
      expect(prefs.allCategories, isFalse);
      expect(prefs.categoryIds, isEmpty);
      expect(prefs.allLocations, isFalse);
      expect(prefs.locationIds, isEmpty);
      expect(prefs.quietHours.enabled, isFalse);
    });

    test(
      'Offline preference update saves locally and flags pending sync',
      () async {
        fakeApi.shouldThrowNetworkError = true;

        const newPrefs = NotificationPreferenceModel(
          notificationsEnabled: true,
          breakingNews: true,
          categoryIds: ['cat_gundem', 'cat_ekonomi'],
          locationIds: ['loc_prov_antalya'],
        );

        final success = await deviceRepo.updatePreferences(newPrefs);
        // Online update failed, but local was saved
        expect(success, isFalse);

        final localPrefs = await deviceRepo.getPreferences();
        expect(localPrefs.categoryIds, contains('cat_gundem'));
        expect(localPrefs.locationIds, contains('loc_prov_antalya'));

        expect(await deviceRepo.isPendingSync(), isTrue);
      },
    );

    test(
      'Online syncPendingPreferences synchronizes and clears pending flag',
      () async {
        // 1. Save offline with pending flag
        await storage.savePreferences(
          const NotificationPreferenceModel(categoryIds: ['cat_spor']),
          markPending: true,
        );
        expect(await deviceRepo.isPendingSync(), isTrue);

        // 2. Network is now online
        fakeApi.shouldThrowNetworkError = false;

        final synced = await deviceRepo.syncPendingPreferences();
        expect(synced, isTrue);
        expect(await deviceRepo.isPendingSync(), isFalse);
        expect(
          fakeApi.lastUpdatedBody?['preferences']?['category_ids'],
          contains('cat_spor'),
        );
      },
    );

    test('sanitizePreferencesAgainstTaxonomy removes obsolete category and location IDs', () async {
      // User previously selected valid and removed items
      const initialPrefs = NotificationPreferenceModel(
        categoryIds: ['cat_gundem', 'cat_deleted_category'],
        locationIds: ['loc_prov_antalya', 'loc_removed_location'],
      );

      await storage.savePreferences(initialPrefs, markPending: false);

      // Sanitize against currently published backend taxonomy
      await deviceRepo.sanitizePreferencesAgainstTaxonomy(
        validCategoryIds: ['cat_gundem', 'cat_ekonomi', 'cat_spor'],
        validLocationIds: ['loc_prov_antalya', 'loc_prov_istanbul'],
      );

      final cleaned = await deviceRepo.getPreferences();

      // Only valid IDs remain
      expect(cleaned.categoryIds, equals(['cat_gundem']));
      expect(cleaned.categoryIds.contains('cat_deleted_category'), isFalse);

      expect(cleaned.locationIds, equals(['loc_prov_antalya']));
      expect(cleaned.locationIds.contains('loc_removed_location'), isFalse);

      // Dirty flag is marked for server sync
      expect(await deviceRepo.isPendingSync(), isTrue);
    });
  });
}
