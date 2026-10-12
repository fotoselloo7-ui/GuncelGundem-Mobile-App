import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
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
      Row(
        children: [
          Expanded(
            child: Text(
              newsDateTime(detail.publishedAt),
              style: const TextStyle(fontSize: 12, color: homeMuted),
            ),
          ),
          const Icon(Icons.visibility_outlined, size: 16, color: homeMuted),
          const SizedBox(width: 5),
          Text(
            '${_formatCount(detail.viewCount)} okunma',
            style: const TextStyle(fontSize: 12, color: homeMuted),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _shareBar(detail),
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

  Widget _shareBar(NewsDetailModel detail) {
    final url = (detail.canonicalUrl?.trim().isNotEmpty ?? false)
        ? detail.canonicalUrl!.trim()
        : '${AppConfig.productionSiteUrl}/haber/${detail.slug}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: buttonWidth,
              child: _shareButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'WhatsApp',
                onTap: () => _openShare(
                  'https://wa.me/?text=${Uri.encodeComponent('${detail.title} $url')}',
                ),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _shareButton(
                icon: Icons.public_rounded,
                label: 'Facebook',
                onTap: () => _openShare(
                  'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}',
                ),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _shareButton(
                icon: Icons.alternate_email_rounded,
                label: 'X',
                onTap: () => _openShare(
                  'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(detail.title)}&url=${Uri.encodeComponent(url)}',
                ),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: _shareButton(
                icon: Icons.link_rounded,
                label: 'Linki Kopyala',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Haber bağlantısı kopyalandı.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shareButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      side: const BorderSide(color: homeLine),
      foregroundColor: homeNavy,
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Future<void> _openShare(String rawUrl) async {
    try {
      await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım bağlantısı açılamadı.')),
      );
    }
  }

  static String _formatCount(int value) {
    final raw = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return out.toString();
  }
}
