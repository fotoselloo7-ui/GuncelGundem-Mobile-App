import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/app_config.dart';
import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/blog_article_model.dart';
import '../../../data/models/blog_category_model.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';
import '../../news/presentation/news_navigation.dart';

const blogText = TextStyle(fontSize: 17, height: 1.7, color: homeNavy);

class BlogShell extends StatelessWidget {
  final Widget body;
  final Color? backgroundColor;
  const BlogShell({super.key, required this.body, this.backgroundColor});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: BrandingState.instance,
    builder: (context, _) => Theme(
      data: homeTheme(BrandingState.instance),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: HomeBrandHeader(
          brand: BrandingState.instance,
          allowBack: true,
          onSearch: () => NewsNavigation.openSearch(context),
          onNotifications: () => NewsNavigation.openNotifications(context),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: body,
            ),
          ),
        ),
        bottomNavigationBar: HomeBottomBar(
          selected: BottomNavPreferences.instance.indexOf(
            NavDestination.infoCorner,
          ),
          onSelect: (index) => NewsNavigation.handleBottom(context, index),
        ),
      ),
    ),
  );
}

class BlogPanel extends StatelessWidget {
  final Widget child;
  final bool accent;
  const BlogPanel({super.key, required this.child, this.accent = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: homeLine),
      boxShadow: accent
          ? const [
              BoxShadow(
                color: Color(0x06142239),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

Widget blogHeading(String text) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 14),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: homeNavy,
    ),
  ),
);

class BlogImage extends StatelessWidget {
  final String? url, alt, caption, credit;
  final double ratio;
  const BlogImage({
    super.key,
    this.url,
    this.alt,
    this.caption,
    this.credit,
    this.ratio = 16 / 9,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        image: true,
        label: alt,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: ratio.isFinite && ratio > 0 ? ratio : 16 / 9,
            child: _cover(),
          ),
        ),
      ),
      if ((caption ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            caption!,
            style: const TextStyle(fontSize: 12, height: 1.6, color: homeMuted),
          ),
        ),
      if ((credit ?? '').isNotEmpty)
        Text(
          'Fotoğraf: $credit',
          style: const TextStyle(fontSize: 11, height: 1.6, color: homeMuted),
        ),
    ],
  );

  Widget _cover() {
    final resolved = _resolvedUrl;
    if (resolved != null &&
        Uri.parse(resolved).path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        resolved,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        placeholderBuilder: (_) => const HomeCover(url: null),
        errorBuilder: (_, _, _) => const HomeCover(url: null),
      );
    }
    return HomeCover(
      url: resolved,
      width: double.infinity,
      height: double.infinity,
    );
  }

  String? get _resolvedUrl {
    if ((url ?? '').isEmpty) return null;
    try {
      final parsed = Uri.parse(url!);
      final base = Uri.parse(AppConfig.apiBaseUrl)
          .replace(path: '/', query: null, fragment: null);
      final resolved = base.resolveUri(parsed);
      return ['http', 'https'].contains(resolved.scheme) &&
              resolved.userInfo.isEmpty
          ? resolved.toString()
          : null;
    } catch (_) {
      return null;
    }
  }
}

class BlogCategoryLabel extends StatelessWidget {
  final BlogCategoryModel category;
  final VoidCallback? onTap;
  const BlogCategoryLabel({super.key, required this.category, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : 48),
      decoration: BoxDecoration(
        color: const Color(0xffeef2f6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

class BlogArticleCard extends StatelessWidget {
  final BlogArticleModel article;
  final VoidCallback onTap;
  final bool featured;
  const BlogArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.featured = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: homeLine),
      ),
      child: InkWell(
        key: ValueKey(
          'blog-card-${article.id.isNotEmpty ? article.id : article.slug}',
        ),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BlogImage(url: article.coverUrl, alt: article.coverAlt),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (article.category != null)
                        BlogCategoryLabel(category: article.category!),
                      if (article.subcategory != null)
                        BlogCategoryLabel(category: article.subcategory!),
                      if (featured || article.featured)
                        Text(
                          'ÖNE ÇIKAN',
                          style: TextStyle(
                            fontSize: 11,
                            height: 2,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: featured ? 22 : 19,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: homeNavy,
                    ),
                  ),
                  if (article.summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        article.summary,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: homeMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  BlogArticleMeta(article: article),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared compact card for all blog feeds; details keep the full native renderer.
class CompactBlogGridCard extends StatelessWidget {
  final BlogArticleModel article;
  final VoidCallback onTap;
  const CompactBlogGridCard({
    super.key,
    required this.article,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: homeLine),
    ),
    child: InkWell(
      key: ValueKey('blog-grid-${article.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlogImage(url: article.coverUrl, alt: article.coverAlt, ratio: 4 / 3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.subcategory?.name ?? article.category?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      article.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: homeNavy,
                      ),
                    ),
                  ),
                  if (article.publishedAt != null)
                    Text(
                      homeDate(article.publishedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: homeMuted),
                    ),
                  if (article.readingTime > 0)
                    Text(
                      '${article.readingTime} dk okuma',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: homeMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

double compactBlogGridHeight(BuildContext context, double cardWidth) {
  final scale = MediaQuery.textScalerOf(context);
  return cardWidth * .75 + scale.scale(13) * 1.25 * 4 + scale.scale(9) * 5 + 28;
}

class BlogArticleMeta extends StatelessWidget {
  final BlogArticleModel article;
  const BlogArticleMeta({super.key, required this.article});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (article.authors.isNotEmpty)
        Text(
          article.authors
              .map((a) => a.name)
              .where((s) => s.isNotEmpty)
              .join(' · '),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.7,
            color: homeNavy,
          ),
        ),
      Text(
        [
          if (article.publishedAt != null) homeDate(article.publishedAt),
          if (article.readingTime > 0) '${article.readingTime} dk okuma',
        ].join(' · '),
        style: const TextStyle(fontSize: 11, height: 1.7, color: homeMuted),
      ),
    ],
  );
}
