import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/ad_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/models/blog_article_model.dart';
import '../../../data/models/info_corner_model.dart';
import '../../blog/presentation/blog_navigation.dart';
import '../../../data/repositories/news_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../notifications/presentation/notification_preferences_screen.dart';
import '../../settings/presentation/app_settings_screen.dart';
import 'news_detail_route.dart';
import 'news_feed_screen.dart';
import 'news_category_explorer_screen.dart';
import 'city_screen.dart';
import 'video_screen.dart';
import 'news_submit_screen.dart';

/// Named routes use the existing MaterialApp/Navigator, not a new router.
class NewsNavigation {
  NewsNavigation._();
  static const breaking = '/son-dakika';
  static const categories = '/haber-kategorileri';
  static const search = '/arama';
  static const article = '/haber';
  static const categoryExplorer = '/tum-kategoriler';
  static const city = '/sehrim';
  static const video = '/videolar';
  static const submit = '/haber-gonder';
  static const notifications = '/bildirimler';
  static const settings = '/tercihler';

  static Route<dynamic>? generate(
    RouteSettings settings, {
    NewsRepository? repository,
    TaxonomyRepository? taxonomy,
  }) {
    final screen = switch (settings.name) {
      breaking => NewsFeedScreen(
        mode: NewsFeedMode.breaking,
        repository: repository,
      ),
      categories =>
        settings.arguments is CategoryModel
            ? NewsFeedScreen(
                mode: NewsFeedMode.categories,
                repository: repository,
                taxonomy: taxonomy,
                initialCategory: settings.arguments as CategoryModel,
              )
            : NewsCategoryExplorerScreen(taxonomy: taxonomy),
      categoryExplorer => NewsCategoryExplorerScreen(taxonomy: taxonomy),
      city => const CityScreen(),
      video => const VideoScreen(),
      submit => const NewsSubmitScreen(),
      notifications => const NotificationPreferencesScreen(),
      NewsNavigation.settings => const AppSettingsScreen(),
      '/guncel-haberler' => NewsFeedScreen(
        mode: NewsFeedMode.latest,
        repository: repository,
      ),
      '/one-cikan-haberler' => NewsFeedScreen(
        mode: NewsFeedMode.featured,
        repository: repository,
      ),
      '/cok-okunanlar' => NewsFeedScreen(
        mode: NewsFeedMode.mostRead,
        repository: repository,
      ),
      search => NewsFeedScreen(
        mode: NewsFeedMode.search,
        repository: repository,
      ),
      article =>
        settings.arguments is NewsModel
            ? NewsDetailRoute(
                news: settings.arguments as NewsModel,
                repository: repository,
              )
            : null,
      _ => null,
    };
    return screen == null
        ? null
        : MaterialPageRoute(settings: settings, builder: (_) => screen);
  }

  static void openBreaking(BuildContext context) =>
      Navigator.of(context).pushNamed(breaking);
  static void openCategories(BuildContext context) =>
      Navigator.of(context).pushNamed(categories);
  static void openCity(BuildContext context) =>
      Navigator.of(context).pushNamed(city);
  static void openVideo(BuildContext context) =>
      Navigator.of(context).pushNamed(video);
  static void openSubmit(BuildContext context) =>
      Navigator.of(context).pushNamed(submit);
  static void openNotifications(BuildContext context) =>
      Navigator.of(context).pushNamed(notifications);
  static void openSettings(BuildContext context) =>
      Navigator.of(context).pushNamed(settings);

  /// Kullanıcının alt menü slotuna atadığı hedefi açar.
  static void openDestination(BuildContext context, NavDestination target) {
    switch (target) {
      case NavDestination.city:
        openCity(context);
      case NavDestination.video:
        openVideo(context);
      case NavDestination.infoCorner:
        BlogNavigation.openIndex(context);
      case NavDestination.categories:
        openCategories(context);
    }
  }

  /// Reklam hedefi: sponsorlu haber → native detay; diğerleri güvenli link
  /// çözümleyici (iç haber/yazı linki veya harici tarayıcı).
  static void openAd(BuildContext context, MobileAdModel ad) {
    final newsId = ad.newsId?.trim() ?? '';
    if (newsId.isNotEmpty) {
      openArticle(
        context,
        NewsModel(
          id: newsId,
          slug: '',
          title: ad.title,
          summary: '',
          readingTime: 0,
        ),
      );
      return;
    }
    if (ad.targetUrl.trim().isNotEmpty) {
      BlogNavigation.openLink(context, ad.targetUrl);
      return;
    }
    unavailable(context, 'Reklam bağlantısı');
  }

  static void openSearch(BuildContext context) =>
      Navigator.of(context).pushNamed(search);
  static void openArticle(BuildContext context, NewsModel news) {
    if (news.slug.trim().isEmpty && news.id.trim().isEmpty) {
      unavailable(context, 'Bu haberin detay bağlantısı');
      return;
    }
    Navigator.of(context).pushNamed(article, arguments: news);
  }

  static void handleHome(
    BuildContext context,
    HomeAction action,
    Object? payload,
  ) {
    switch (action) {
      case HomeAction.breaking:
        openBreaking(context);
      case HomeAction.search:
        openSearch(context);
      case HomeAction.news:
        if (payload is NewsModel) openArticle(context, payload);
      case HomeAction.notifications:
        openNotifications(context);
      case HomeAction.submitNews:
        openSubmit(context);
      case HomeAction.selectCity:
        openCity(context);
      case HomeAction.blog:
        if (payload is BlogArticleModel) {
          BlogNavigation.openArticle(context, payload);
        }
      case HomeAction.blogIndex:
        BlogNavigation.openIndex(
          context,
          payload is InfoCornerModel ? payload : null,
        );
      case HomeAction.ad:
        if (payload is MobileAdModel) {
          openAd(context, payload);
        } else {
          unavailable(context, 'Reklam bağlantısı');
        }
    }
  }

  static void handleBottom(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case 1:
        openBreaking(context);
      case 2:
        openSubmit(context);
      case 3:
      case 4:
        openDestination(
          context,
          BottomNavPreferences.instance.destinationAt(index),
        );
    }
  }

  static void unavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label şu an açılamıyor.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
