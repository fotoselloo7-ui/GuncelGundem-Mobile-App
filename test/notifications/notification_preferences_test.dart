import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/notification_preference_model.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/features/home/presentation/home_widgets.dart';
import 'package:guncelgundem/features/news/presentation/news_navigation.dart';
import 'package:guncelgundem/features/notifications/presentation/notification_preferences_screen.dart';
import 'package:guncelgundem/design/branding_state.dart';
import 'package:guncelgundem/services/notification_permission_service.dart';

class FakeDeviceRepository extends DeviceRepository {
  NotificationPreferenceModel prefs;
  final List<NotificationPreferenceModel> saved = [];
  FakeDeviceRepository(this.prefs);

  @override
  Future<NotificationPreferenceModel> getPreferences() async => prefs;

  @override
  Future<bool> updatePreferences(NotificationPreferenceModel next) async {
    prefs = next;
    saved.add(next);
    return true;
  }
}

class FakeTaxonomyRepository extends TaxonomyRepository {
  final List<CategoryModel> categories;
  final List<LocationProvinceModel> provinces;
  FakeTaxonomyRepository({
    this.categories = const [],
    this.provinces = const [],
  });

  @override
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async =>
      categories;

  @override
  Future<List<LocationProvinceModel>> getLocations({
    bool forceRefresh = false,
  }) async => provinces;
}

class FakePermissionService extends NotificationPermissionService {
  NotificationPermissionStatus statusToReturn;
  NotificationPermissionStatus requestResult;
  int requestCount = 0;
  int openSettingsCount = 0;

  FakePermissionService({
    this.statusToReturn = NotificationPermissionStatus.granted,
    this.requestResult = NotificationPermissionStatus.granted,
  });

  @override
  Future<NotificationPermissionStatus> status() async => statusToReturn;

  @override
  Future<NotificationPermissionStatus> request() async {
    requestCount++;
    statusToReturn = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    return true;
  }
}

CategoryModel _cat(String id, String name) =>
    CategoryModel(id: id, name: name, slug: name.toLowerCase());

final _antalya = const LocationProvinceModel(
  id: '07',
  name: 'Antalya',
  slug: 'antalya',
);

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPermissionService (MethodChannel contract)', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channel = NotificationPermissionService.defaultChannel;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('parses native status/request/openSettings results', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'checkStatus':
            return 'denied';
          case 'request':
            return 'granted';
          case 'openSettings':
            return true;
        }
        return null;
      });

      final service = NotificationPermissionService();
      expect(await service.status(), NotificationPermissionStatus.denied);
      expect(await service.request(), NotificationPermissionStatus.granted);
      expect(await service.openSettings(), true);
      expect(calls, ['checkStatus', 'request', 'openSettings']);
    });

    test('permanentlyDenied is parsed correctly', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => 'permanentlyDenied',
      );
      final service = NotificationPermissionService();
      expect(
        await service.status(),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });

    test('missing native bridge degrades safely to notApplicable', () async {
      // No handler registered -> MissingPluginException; must not throw.
      messenger.setMockMethodCallHandler(channel, null);
      final service = NotificationPermissionService();
      expect(
        await service.status(),
        NotificationPermissionStatus.notApplicable,
      );
      expect(await service.openSettings(), false);
    });
  });

  group('Notification route wiring', () {
    test('/bildirimler resolves to a route', () {
      final route = NewsNavigation.generate(
        const RouteSettings(name: '/bildirimler'),
      );
      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute<dynamic>>());
    });

    testWidgets('header bell pushes the notifications route', (tester) async {
      final pushed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == NewsNavigation.notifications) {
              pushed.add(settings.name!);
              return MaterialPageRoute<dynamic>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('ROUTED')),
              );
            }
            return NewsNavigation.generate(settings);
          },
          home: Builder(
            builder: (context) => Scaffold(
              appBar: HomeBrandHeader(
                brand: BrandingState.instance,
                onSearch: () {},
                onNotifications: () =>
                    NewsNavigation.openNotifications(context),
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      expect(pushed, [NewsNavigation.notifications]);
      expect(find.text('ROUTED'), findsOneWidget);
    });
  });

  group('NotificationPreferencesScreen', () {
    testWidgets('renders only backend-supported sections', (tester) async {
      final device = FakeDeviceRepository(
        const NotificationPreferenceModel(locationIds: ['07']),
      );
      final taxonomy = FakeTaxonomyRepository(
        categories: [_cat('ekonomi', 'Ekonomi'), _cat('spor', 'Spor')],
        provinces: [_antalya],
      );
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: taxonomy,
            permission: FakePermissionService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pref-master')), findsOneWidget);
      expect(find.text('Son Dakika'), findsOneWidget);
      expect(find.text('Tüm Haber Kategorileri'), findsOneWidget);
      expect(find.byKey(const ValueKey('pref-category-ekonomi')), findsOneWidget);
      expect(find.byKey(const ValueKey('pref-category-spor')), findsOneWidget);
      expect(find.text('Şehrim'), findsOneWidget);
      expect(find.text('Antalya'), findsOneWidget);
      expect(find.byKey(const ValueKey('pref-quiet')), findsOneWidget);
    });

    testWidgets('toggling Son Dakika persists via device repository', (
      tester,
    ) async {
      final device = FakeDeviceRepository(const NotificationPreferenceModel());
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(),
            permission: FakePermissionService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pref-breaking')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(device.prefs.breakingNews, false);
      expect(device.saved, isNotEmpty);
    });

    testWidgets('master ON requests OS permission; OFF does not', (
      tester,
    ) async {
      final device = FakeDeviceRepository(
        const NotificationPreferenceModel(notificationsEnabled: false),
      );
      final permission = FakePermissionService(
        statusToReturn: NotificationPermissionStatus.denied,
        requestResult: NotificationPermissionStatus.granted,
      );
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(),
            permission: permission,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Turn ON -> requests permission.
      await tester.tap(find.byKey(const ValueKey('pref-master')));
      await tester.pumpAndSettle();
      expect(device.prefs.notificationsEnabled, true);
      expect(permission.requestCount, 1);

      // Turn OFF -> no additional request.
      await tester.tap(find.byKey(const ValueKey('pref-master')));
      await tester.pumpAndSettle();
      expect(device.prefs.notificationsEnabled, false);
      expect(permission.requestCount, 1);
    });

    testWidgets('selecting a category updates category_ids only', (
      tester,
    ) async {
      final device = FakeDeviceRepository(
        const NotificationPreferenceModel(locationIds: ['07']),
      );
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(
              categories: [_cat('ekonomi', 'Ekonomi')],
              provinces: [_antalya],
            ),
            permission: FakePermissionService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pref-category-ekonomi')));
      await tester.pumpAndSettle();

      expect(device.prefs.categoryIds, contains('ekonomi'));
      // City selection (locationIds) must be preserved, not overwritten.
      expect(device.prefs.locationIds, ['07']);
    });

    testWidgets('enabling quiet hours reveals time fields', (tester) async {
      final device = FakeDeviceRepository(const NotificationPreferenceModel());
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(),
            permission: FakePermissionService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pref-quiet-start')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pref-quiet')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(device.prefs.quietHours.enabled, true);
      expect(find.byKey(const ValueKey('pref-quiet-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('pref-quiet-end')), findsOneWidget);
    });

    testWidgets('denied permission shows request banner', (tester) async {
      final device = FakeDeviceRepository(const NotificationPreferenceModel());
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(),
            permission: FakePermissionService(
              statusToReturn: NotificationPermissionStatus.denied,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('permission-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('permission-request')), findsOneWidget);
    });

    testWidgets('permanentlyDenied banner offers open settings', (
      tester,
    ) async {
      final device = FakeDeviceRepository(const NotificationPreferenceModel());
      final permission = FakePermissionService(
        statusToReturn: NotificationPermissionStatus.permanentlyDenied,
      );
      tester.view.physicalSize = const Size(1000, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          NotificationPreferencesScreen(
            device: device,
            taxonomy: FakeTaxonomyRepository(),
            permission: permission,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('permission-open-settings')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('permission-open-settings')));
      await tester.pumpAndSettle();
      expect(permission.openSettingsCount, 1);
    });
  });
}
