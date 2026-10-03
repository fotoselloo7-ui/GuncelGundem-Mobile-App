import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../data/models/blog_article_model.dart';
import '../../../data/models/info_corner_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/repositories/blog_repository.dart';
import '../../news/presentation/news_navigation.dart';
import 'blog_category_explorer.dart';
import 'blog_detail_screen.dart';
import 'blog_feed_screen.dart';

enum BlogLinkKind { blog, news, external, invalid }

class BlogLinkTarget {
  final BlogLinkKind kind;
  final Uri? uri;
  final String? identifier;
  const BlogLinkTarget(this.kind, {this.uri, this.identifier});
}

class BlogNavigation {
  BlogNavigation._();
  static const index = '/bilgi-kosesi',
      category = '/bilgi-kosesi/kategori',
      article = '/bilgi-kosesi/makale';
  static bool validIdentifier(String value) =>
      value.trim().isNotEmpty &&
      !RegExp(r'[/\\?#\x00-\x1f]').hasMatch(value) &&
      value != '.' &&
      value != '..';
  static Route<dynamic>? generate(
    RouteSettings settings, {
    BlogRepository? repository,
  }) {
    final screen = switch (settings.name) {
      index => BlogFeedScreen(
        repository: repository,
        info: settings.arguments is InfoCornerModel
            ? settings.arguments as InfoCornerModel
            : null,
      ),
      category =>
        settings.arguments is BlogCategorySelection
            ? BlogFeedScreen(
                repository: repository,
                selection: settings.arguments as BlogCategorySelection,
              )
            : null,
      article =>
        settings.arguments is String &&
                validIdentifier(settings.arguments as String)
            ? BlogDetailScreen(
                identifier: settings.arguments as String,
                repository: repository,
              )
            : null,
      _ => null,
    };
    return screen == null
        ? null
        : MaterialPageRoute(settings: settings, builder: (_) => screen);
  }

  static void openIndex(BuildContext context, [InfoCornerModel? info]) =>
      Navigator.of(context).pushNamed(index, arguments: info);
  static void openCategory(
    BuildContext context,
    BlogCategorySelection selection,
  ) => Navigator.of(context).pushNamed(category, arguments: selection);
  static void openArticle(BuildContext context, BlogArticleModel value) =>
      openIdentifier(
        context,
        value.slug.trim().isNotEmpty ? value.slug : value.id,
      );
  static void openIdentifier(BuildContext context, String identifier) {
    if (!validIdentifier(identifier)) {
      NewsNavigation.unavailable(context, 'Yazı bağlantısı');
      return;
    }
    Navigator.of(context).pushNamed(article, arguments: identifier);
  }

  static BlogLinkTarget resolve(String raw, {String? canonicalUrl}) {
    try {
      if (raw.trim().isEmpty || RegExp(r'[\x00-\x1f]').hasMatch(raw)) {
        return const BlogLinkTarget(BlogLinkKind.invalid);
      }
      final api = Uri.parse(AppConfig.apiBaseUrl),
          canonical = Uri.tryParse(canonicalUrl ?? '');
      final base = canonical?.hasAuthority == true
          ? canonical!
          : api.replace(path: '/', query: null, fragment: null);
      final uri = base.resolve(raw.trim());
      if (!['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        return const BlogLinkTarget(BlogLinkKind.invalid);
      }
      final same = uri.origin == base.origin || uri.origin == api.origin;
      final segments = uri.pathSegments
          .where((part) => part.isNotEmpty)
          .toList();
      if (same && segments.length == 2 && validIdentifier(segments[1])) {
        if (segments[0] == 'blog' && !uri.path.endsWith('/')) {
          return BlogLinkTarget(
            BlogLinkKind.blog,
            uri: uri,
            identifier: segments[1],
          );
        }
        if (segments[0] == 'haber') {
          return BlogLinkTarget(
            BlogLinkKind.news,
            uri: uri,
            identifier: segments[1],
          );
        }
      }
      return BlogLinkTarget(BlogLinkKind.external, uri: uri);
    } catch (_) {
      return const BlogLinkTarget(BlogLinkKind.invalid);
    }
  }

  static Future<void> openLink(
    BuildContext context,
    String raw, {
    String? canonicalUrl,
  }) async {
    final target = resolve(raw, canonicalUrl: canonicalUrl);
    switch (target.kind) {
      case BlogLinkKind.blog:
        openIdentifier(context, target.identifier!);
      case BlogLinkKind.news:
        NewsNavigation.openArticle(
          context,
          NewsModel(
            id: '',
            slug: target.identifier!,
            title: '',
            summary: '',
            readingTime: 0,
          ),
        );
      case BlogLinkKind.invalid:
        NewsNavigation.unavailable(context, 'Güvenli bağlantı');
      case BlogLinkKind.external:
        var opened = false;
        try {
          opened = await launchUrl(
            target.uri!,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // Keep platform launch failures inside the existing link action.
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
        }
    }
  }
}
