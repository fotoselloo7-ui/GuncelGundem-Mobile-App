import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/utils/pagination.dart';
import 'package:guncelgundem/data/models/app_config_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/services/version_check_service.dart';

void main() {
  group('Pagination and Version Check Tests', () {
    test('PaginatedList appends new items and deduplicates existing IDs', () {
      final initialList = PaginatedList<NewsModel>(
        items: const [
          NewsModel(id: 'n1', slug: 's1', title: 'Haber 1', summary: 'Özet 1'),
          NewsModel(id: 'n2', slug: 's2', title: 'Haber 2', summary: 'Özet 2'),
        ],
        page: 1,
        limit: 2,
        hasMore: true,
      );

      final newItems = const [
        NewsModel(
          id: 'n2',
          slug: 's2',
          title: 'Haber 2 (Tekrar)',
          summary: 'Özet 2',
        ), // Duplicate
        NewsModel(id: 'n3', slug: 's3', title: 'Haber 3', summary: 'Özet 3'),
      ];

      final updatedList = initialList.appendPage(
        newItems: newItems,
        hasMore: false,
        idSelector: (item) => item.id,
      );

      expect(updatedList.page, 2);
      expect(updatedList.hasMore, isFalse);
      expect(updatedList.items.length, 3); // n1, n2, n3
      expect(updatedList.items.map((i) => i.id).toList(), ['n1', 'n2', 'n3']);
    });

    test('VersionCheckService handles force update and recommendations correctly', () {
      // 1. Minimum sürümün altındaysa -> Force Update
      const configForce = AppConfigModel(
        apiVersion: 'v1',
        siteName: 'Test',
        minimumAppVersion: '2.0.0',
        recommendedAppVersion: '2.1.0',
        forceUpdate: false,
      );

      final result1 = VersionCheckService.check(
        currentVersion: '1.5.0',
        config: configForce,
      );
      expect(result1.isSupported, isFalse);
      expect(result1.needsForceUpdate, isTrue);

      // 2. Minimum sürümde ama tavsiye edilenin altındaysa -> Recommends Update
      const configRecommend = AppConfigModel(
        apiVersion: 'v1',
        siteName: 'Test',
        minimumAppVersion: '1.0.0',
        recommendedAppVersion: '1.2.0',
        forceUpdate: false,
      );

      final result2 = VersionCheckService.check(
        currentVersion: '1.0.0',
        config: configRecommend,
      );
      expect(result2.isSupported, isTrue);
      expect(result2.needsForceUpdate, isFalse);
      expect(result2.recommendsUpdate, isTrue);

      // 3. force_update: true bayrağı doğrudan force update tetikler
      const configFlagForce = AppConfigModel(
        apiVersion: 'v1',
        siteName: 'Test',
        forceUpdate: true,
      );

      final result3 = VersionCheckService.check(
        currentVersion: '1.0.0',
        config: configFlagForce,
      );
      expect(result3.needsForceUpdate, isTrue);

      // 4. Sürüm bilgisi null ise normal devam eder
      const configNull = AppConfigModel(apiVersion: 'v1', siteName: 'Test');

      final result4 = VersionCheckService.check(
        currentVersion: '1.0.0',
        config: configNull,
      );
      expect(result4.isSupported, isTrue);
      expect(result4.needsForceUpdate, isFalse);
      expect(result4.recommendsUpdate, isFalse);
    });
  });
}
