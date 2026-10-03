import 'package:flutter/material.dart';

import '../../../core/network/content_availability.dart';
import '../../../data/models/blog_article_model.dart';
import '../../../data/models/blog_json.dart';
import '../../../data/repositories/blog_repository.dart';
import '../../home/presentation/home_widgets.dart';
import 'blog_block_renderer.dart';
import 'blog_category_explorer.dart';
import 'blog_navigation.dart';
import 'blog_widgets.dart';

class BlogDetailScreen extends StatefulWidget {
  final String identifier;
  final BlogRepository? repository;
  final BlogLinkHandler? onLink;
  const BlogDetailScreen({
    super.key,
    required this.identifier,
    this.repository,
    this.onLink,
  });
  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  late final BlogRepository _repo;
  late Future<BlogDetailResult> _future;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BlogRepository();
    _future = _load();
  }

  Future<BlogDetailResult> _load() =>
      BlogNavigation.validIdentifier(widget.identifier)
      ? _repo.getArticleDetailWithAvailability(
          Uri.encodeComponent(widget.identifier),
        )
      : Future.error(StateError('Yazı bağlantısı geçersiz.'));
  Future<void> _link(String url, BlogArticleModel article) =>
      widget.onLink?.call(url) ??
      BlogNavigation.openLink(context, url, canonicalUrl: article.canonicalUrl);
  @override
  Widget build(BuildContext context) => BlogShell(
    backgroundColor: Colors.white,
    body: FutureBuilder<BlogDetailResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const HomeMessage(
                    'Yazı yüklenemedi.',
                    icon: Icons.error_outline,
                  ),
                  TextButton(
                    key: const ValueKey('blog-detail-retry'),
                    onPressed: () => setState(() {
                      _future = _load();
                    }),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          );
        }
        final result = snapshot.data;
        if (result?.article == null ||
            result!.availability == ContentAvailability.unavailable) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: HomeMessage(
              'Yazı bulunamadı veya yayından kaldırıldı.',
              icon: Icons.menu_book_outlined,
            ),
          );
        }
        return _article(
          result.article!,
          result.availability == ContentAvailability.cachedOffline,
        );
      },
    ),
  );
  Widget _article(BlogArticleModel article, bool offline) {
    Future<void> onLink(String url) => _link(url, article);
    return CustomScrollView(
      key: const ValueKey('blog-detail-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (offline)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: HomeMessage(
                      'Kaydedilmiş makale gösteriliyor.',
                      icon: Icons.wifi_off,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (article.category != null)
                      BlogCategoryLabel(
                        category: article.category!,
                        onTap: () => BlogNavigation.openCategory(
                          context,
                          BlogCategorySelection(article.category!),
                        ),
                      ),
                    if (article.subcategory != null)
                      BlogCategoryLabel(
                        category: article.subcategory!,
                        onTap: () => BlogNavigation.openCategory(
                          context,
                          BlogCategorySelection(
                            article.subcategory!,
                            parent: article.category,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: homeNavy,
                  ),
                ),
                if (article.summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      article.summary,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: homeMuted,
                      ),
                    ),
                  ),
                BlogArticleMeta(article: article),
                if (article.modifiedAt != null &&
                    article.modifiedAt != article.publishedAt)
                  Text(
                    'Güncellendi: ${homeDate(article.modifiedAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.7,
                      color: homeMuted,
                    ),
                  ),
                if ((article.coverUrl ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: BlogImage(
                      url: article.coverUrl,
                      alt: article.coverAlt,
                      caption: article.coverCaption,
                      credit: article.coverCredit,
                    ),
                  ),
                if ((article.directAnswerSummary ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: BlogFactbox(
                      title: 'Hızlı Yanıt',
                      text: article.directAnswerSummary,
                    ),
                  ),
                if (article.keyTakeaways.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: BlogFactbox(
                      title: 'Önemli Noktalar',
                      items: article.keyTakeaways,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: BlogBlockRenderer(blocks: article.blocks, onLink: onLink),
        ),
        if (article.recipe != null && BlogRecipe.hasContent(article.recipe!))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            sliver: SliverToBoxAdapter(
              child: BlogRecipe(recipe: article.recipe!),
            ),
          ),
        if (article.faq.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: blogHeading('Sık Sorulan Sorular'),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: article.faq.length,
            itemBuilder: (context, index) {
              final question = BlogJson.string(article.faq[index]['question']),
                  answer = BlogJson.string(article.faq[index]['answer']);
              if ((question ?? '').isEmpty || (answer ?? '').isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BlogPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        question!,
                        style: blogText.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(answer!, style: blogText),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (article.sources.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: blogHeading('Kaynaklar')),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: article.sources.length,
            itemBuilder: (context, index) {
              final source = article.sources[index],
                  title =
                      BlogJson.string(
                        article.sources[index]['title'] ??
                            article.sources[index]['name'],
                      ) ??
                      '',
                  url = BlogJson.string(article.sources[index]['url']) ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  url.isEmpty
                      ? Text(title, style: blogText)
                      : BlogLinkLabel(
                          label: title.isNotEmpty ? title : url,
                          url: url,
                          onLink: onLink,
                        ),
                  if ((BlogJson.string(source['publisher']) ?? '').isNotEmpty)
                    Text(
                      BlogJson.string(source['publisher'])!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: homeMuted,
                      ),
                    ),
                  if ((BlogJson.string(source['accessed_at']) ?? '').isNotEmpty)
                    Text(
                      'Erişim: ${BlogJson.string(source['accessed_at'])}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: homeMuted,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if ([
          ...article.tags,
          ...article.topics,
          ...article.entities,
          ...article.locations,
        ].isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in [
                    ...article.tags,
                    ...article.topics,
                    ...article.entities,
                    ...article.locations,
                  ])
                    if ((BlogJson.string(value['name']) ?? '').isNotEmpty)
                      Text(
                        BlogJson.string(value['name'])!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: homeMuted,
                        ),
                      ),
                ],
              ),
            ),
          ),
        if (article.relatedArticles.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: blogHeading('İlgili Yazılar')),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: article.relatedArticles.length,
            itemBuilder: (context, index) => BlogArticleCard(
              article: article.relatedArticles[index],
              onTap: () => BlogNavigation.openArticle(
                context,
                article.relatedArticles[index],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}
