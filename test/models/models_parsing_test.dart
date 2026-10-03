import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/app_config_model.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/news_detail_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';

void main() {
  group('Models Parsing Tests (Faz 2 Real JSON Fixtures)', () {
    test('AppConfigModel correctly parses real config JSON', () {
      final json = {
        'api_version': 'v1',
        'site_name': 'Güncel Gündem',
        'short_name': 'Güncel Gündem',
        'tagline': 'Son Dakika Haberleri',
        'site_url': 'https://guncelgundem.tr',
        'logo_url': 'https://guncelgundem.tr/assets/images/ui/logo.png',
        'logo_mobile_url':
            'https://guncelgundem.tr/uploads/brand/logo-mobile.png',
        'favicon_url': 'https://guncelgundem.tr/uploads/brand/favicon.png',
        'colors': {
          'primary': '#dc2626',
          'secondary': '#1e293b',
          'accent': '#2563eb',
        },
        'social_links': {'x': 'https://x.com/guncelgundemtr'},
        'maintenance_mode': false,
        'maintenance_message': null,
        'minimum_app_version': '1.0.0',
        'recommended_app_version': '1.1.0',
        'force_update': false,
        'features': {'breaking_news_enabled': true, 'local_news_enabled': true},
      };

      final config = AppConfigModel.fromJson(json);

      expect(config.apiVersion, 'v1');
      expect(config.siteName, 'Güncel Gündem');
      expect(config.colors?['primary'], '#dc2626');
      expect(config.maintenanceMode, isFalse);
      expect(config.minimumAppVersion, '1.0.0');
      expect(config.features?['breaking_news_enabled'], isTrue);
    });

    test('NewsModel correctly parses news card and handles missing optional fields safely', () {
      final json = {
        'id': 'art_test_123',
        'slug': 'test-haberi',
        'title': 'Test Haber Başlığı',
        'summary': 'Bu bir özet metnidir.',
        'cover_url': 'https://guncelgundem.tr/uploads/cover.jpg',
        'primary_category': {
          'id': 'cat_gundem',
          'name': 'Gündem',
          'slug': 'gundem',
        },
        'categories': [
          {'id': 'cat_gundem', 'name': 'Gündem', 'slug': 'gundem'},
        ],
        'locations': [
          {
            'id': 'loc_antalya',
            'name': 'Antalya',
            'slug': 'antalya',
            'type': 'province',
            'province_code': '07',
          },
        ],
        'published_at': '2026-09-29T10:00:00+03:00',
        'modified_at': '2026-09-29T10:15:00+03:00',
        'breaking': true,
        'featured': false,
        'reading_time': 4,
        'canonical_url': 'https://guncelgundem.tr/haber/test-haberi',
      };

      final news = NewsModel.fromJson(json);

      expect(news.id, 'art_test_123');
      expect(news.slug, 'test-haberi');
      expect(news.title, 'Test Haber Başlığı');
      expect(news.primaryCategory?.slug, 'gundem');
      expect(news.locations.first.provinceCode, '07');
      expect(news.breaking, isTrue);
      expect(news.readingTime, 4);
    });

    test('NewsDetailModel parses blocks, gallery, videos, authors, sources, related', () {
      final json = {
        'id': 'art_test_detail',
        'slug': 'detay-haberi',
        'title': 'Detay Haber Başlığı',
        'summary': 'Özet',
        'body': {
          'format': 'blocks',
          'blocks': [
            {'type': 'paragraph', 'text': 'İlk paragraf metni.'},
            {'type': 'heading2', 'text': 'Alt Başlık'},
          ],
        },
        'gallery': [
          'https://guncelgundem.tr/uploads/gal1.jpg',
          'https://guncelgundem.tr/uploads/gal2.jpg',
        ],
        'videos': [
          {
            'url': 'https://guncelgundem.tr/uploads/video.mp4',
            'caption': 'Haber videosu',
          },
        ],
        'authors': [
          {
            'id': 'author_1',
            'name': 'Mehmet Yılmaz',
            'slug': 'mehmet-yilmaz',
            'title': 'Editör',
            'avatar_url': 'https://guncelgundem.tr/uploads/avatar.jpg',
          },
        ],
        'sources': [
          {
            'id': 'src_aa',
            'name': 'Anadolu Ajansı',
            'slug': 'aa',
            'website_url': 'https://aa.com.tr',
          },
        ],
        'tags': [
          {'id': 'tag_turkiye', 'name': 'Türkiye', 'slug': 'turkiye'},
        ],
        'topics': [
          {'id': 'topic_ekonomi', 'name': 'Ekonomi', 'slug': 'ekonomi'},
        ],
        'related_news': [
          {
            'id': 'art_related_1',
            'slug': 'ilgili-haber',
            'title': 'İlgili Haber',
            'summary': 'İlgili özet',
          },
        ],
      };

      final detail = NewsDetailModel.fromJson(json);

      expect(detail.id, 'art_test_detail');
      expect(detail.body.blocks.length, 2);
      expect(detail.gallery.length, 2);
      expect(detail.videos.first.caption, 'Haber videosu');
      expect(detail.authors.first.name, 'Mehmet Yılmaz');
      expect(detail.sources.first.name, 'Anadolu Ajansı');
      expect(detail.tags.first.slug, 'turkiye');
      expect(detail.relatedNews.first.title, 'İlgili Haber');
    });

    test('LocationProvinceModel and LocationDistrictModel preserve canonical IDs and province_id', () {
      final json = {
        'id': 'loc_antalya',
        'name': 'Antalya',
        'slug': 'antalya',
        'type': 'province',
        'province_code': '07',
        'districts': [
          {
            'id': 'loc_antalya_muratpasa',
            'name': 'Muratpaşa',
            'slug': 'muratpasa',
            'type': 'district',
            'province_id': 'loc_antalya',
            'parent_id': 'loc_antalya',
            'province_code': '07',
          },
        ],
      };

      final province = LocationProvinceModel.fromJson(json);

      expect(province.id, 'loc_antalya');
      expect(province.provinceCode, '07');
      expect(province.districts.length, 1);

      final district = province.districts.first;
      expect(district.id, 'loc_antalya_muratpasa');
      expect(district.provinceId, 'loc_antalya');
      expect(district.type, 'district');
    });

    test(
      'Empty or malformed JSON fields fall back safely without crashing',
      () {
        final emptyNews = NewsModel.fromJson(const {});
        expect(emptyNews.id, isEmpty);
        expect(emptyNews.title, isEmpty);
        expect(emptyNews.categories, isEmpty);
        expect(emptyNews.breaking, isFalse);

        final emptyDetail = NewsDetailModel.fromJson(const {});
        expect(emptyDetail.id, isEmpty);
        expect(emptyDetail.body.blocks, isEmpty);
        expect(emptyDetail.gallery, isEmpty);

        final emptyCat = CategoryModel.fromJson(const {});
        expect(emptyCat.id, isEmpty);
        expect(emptyCat.children, isEmpty);
      },
    );
  });
}
