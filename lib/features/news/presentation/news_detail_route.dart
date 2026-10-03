import 'package:flutter/material.dart';

import '../../../data/models/news_model.dart';
import '../../../data/models/news_detail_model.dart';
import '../../../data/repositories/news_repository.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_widgets.dart';
import 'news_navigation.dart';
import 'widgets/article_block_renderer.dart';
import 'widgets/news_feed_card.dart';

/// Approved minimal route adapter. Final detail UI is deliberately deferred;
/// existing detail availability, model, cache and ArticleBlockRenderer are reused.
class NewsDetailRoute extends StatefulWidget {
  final NewsModel news;
  final NewsRepository? repository;
  const NewsDetailRoute({super.key, required this.news, this.repository});
  @override
  State<NewsDetailRoute> createState() => _NewsDetailRouteState();
}

class _NewsDetailRouteState extends State<NewsDetailRoute> {
  late final NewsRepository _repository;
  late Future<NewsDetailResult> _future;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NewsRepository();
    _future = _load();
  }

  Future<NewsDetailResult> _load() {
    final identifier = widget.news.slug.trim().isNotEmpty
        ? widget.news.slug
        : widget.news.id;
    if (identifier.trim().isEmpty) {
      return Future.error(StateError('Haber bağlantısı bulunamadı.'));
    }
    return _repository.getNewsDetailWithAvailability(
      Uri.encodeComponent(identifier),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: BrandingState.instance,
    builder: (context, _) => Theme(
      data: homeTheme(BrandingState.instance),
      child: Scaffold(
        appBar: HomeBrandHeader(
          brand: BrandingState.instance,
          allowBack: true,
          onSearch: () => NewsNavigation.openSearch(context),
          onNotifications: () => NewsNavigation.openNotifications(context),
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<NewsDetailResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HomeMessage(
                        'Haber yüklenemedi.',
                        icon: Icons.error_outline,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _future = _load()),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                );
              }
              final result = snapshot.data;
              if (result?.news == null || result!.isUnavailable) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: HomeMessage(
                    'Haber bulunamadı veya yayından kaldırıldı.',
                    icon: Icons.article_outlined,
                  ),
                );
              }
              final detail = result.news!;
              return SingleChildScrollView(
                key: const ValueKey('news-detail-scroll'),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _content(detail, result.isOffline),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _content(NewsDetailModel detail, bool offline) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (offline)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: HomeMessage(
            'Kaydedilmiş haber gösteriliyor.',
            icon: Icons.wifi_off,
          ),
        ),
      if ((detail.coverUrl ?? '').isNotEmpty)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: HomeCover(
            url: detail.coverUrl,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      const SizedBox(height: 16),
      if (detail.primaryCategory != null)
        Text(
          detail.primaryCategory!.name,
          style: TextStyle(
            color: BrandingState.instance.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      const SizedBox(height: 8),
      Text(
        detail.title,
        style: const TextStyle(
          fontSize: 24,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: homeNavy,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        newsDateTime(detail.publishedAt),
        style: const TextStyle(fontSize: 12, color: homeMuted),
      ),
      if (detail.authors.isNotEmpty)
        Text(
          detail.authors.map((author) => author.name).join(' · '),
          style: const TextStyle(fontSize: 12, height: 1.8, color: homeMuted),
        ),
      if (detail.summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            detail.summary,
            style: const TextStyle(fontSize: 15, height: 1.6, color: homeNavy),
          ),
        ),
      ArticleBlockRenderer(
        blocks: detail.body.blocks,
        padding: EdgeInsets.zero,
      ),
      if (detail.sources.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Kaynak: ${detail.sources.map((source) => source.name).join(' · ')}',
            style: const TextStyle(fontSize: 12, height: 1.6, color: homeMuted),
          ),
        ),
      if (detail.tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in detail.tags)
                Text(
                  '#${tag.name}',
                  style: const TextStyle(fontSize: 12, color: homeMuted),
                ),
            ],
          ),
        ),
      const SizedBox(height: 24),
    ],
  );
}
