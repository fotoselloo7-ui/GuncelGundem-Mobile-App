import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../../data/models/news_block_model.dart';
import '../../../../design/app_colors.dart';
import '../../../../design/app_spacing.dart';
import 'cached_image_widget.dart';

/// Semantic Haber Gövde Okuma Motoru
///
/// Backend'den gelen blokları teknik kurallara göre Flutter widget'larına çevirir.
/// Görsel değerleri doğrudan Theme ve Design System'den alır.
class ArticleBlockRenderer extends StatelessWidget {
  final List<NewsBlockModel> blocks;
  final EdgeInsetsGeometry padding;

  const ArticleBlockRenderer({
    super.key,
    required this.blocks,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks.map((block) => _renderBlock(context, block)).toList(),
      ),
    );
  }

  Widget _renderBlock(BuildContext context, NewsBlockModel block) {
    switch (block) {
      case ParagraphNewsBlock():
        return _renderParagraph(context, block);

      case HeadingNewsBlock():
        return _renderHeading(context, block);

      case ImageNewsBlock():
        return _renderImage(context, block);

      case QuoteNewsBlock():
        return _renderQuote(context, block);

      case ListNewsBlock():
        return _renderList(context, block);

      case VideoNewsBlock():
        return _renderVideo(context, block);

      case HtmlNewsBlock():
        return _renderHtml(context, block);

      case UnknownNewsBlock():
        return _renderUnknown(context, block);
    }
  }

  Widget _renderParagraph(BuildContext context, ParagraphNewsBlock block) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(block.text, style: theme.textTheme.bodyLarge),
    );
  }

  Widget _renderHeading(BuildContext context, HeadingNewsBlock block) {
    final theme = Theme.of(context);
    TextStyle? style;

    switch (block.level) {
      case 2:
        style = theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case 3:
        style = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      default:
        style = theme.textTheme.titleMedium;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(block.text, style: style),
    );
  }

  Widget _renderImage(BuildContext context, ImageNewsBlock block) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedImageWidget(
            imageUrl: block.url,
            width: double.infinity,
            borderRadius: BorderRadius.circular(8),
            fit: BoxFit.cover,
          ),
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              block.caption!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
              ),
            ),
          ],
          if (block.credit != null && block.credit!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Fotoğraf: ${block.credit}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.labelSmall?.color?.withAlpha(140),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderQuote(BuildContext context, QuoteNewsBlock block) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 3.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${block.text}"',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (block.author != null && block.author!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '— ${block.author}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _renderList(BuildContext context, ListNewsBlock block) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(block.items.length, (index) {
          final prefix = block.isOrdered ? '${index + 1}. ' : '• ';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefix,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    block.items[index],
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _renderVideo(BuildContext context, VideoNewsBlock block) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
              if (block.caption != null && block.caption!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  block.caption!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderHtml(BuildContext context, HtmlNewsBlock block) {
    // Güvenli: WebView DEĞİLDİR, Remote script çalıştırmaz, JS çalıştırmaz.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HtmlWidget(
        block.html,
        textStyle: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget _renderUnknown(BuildContext context, UnknownNewsBlock block) {
    final fallback = block.textFallback;
    if (fallback != null && fallback.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(fallback, style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return const SizedBox.shrink();
  }
}
