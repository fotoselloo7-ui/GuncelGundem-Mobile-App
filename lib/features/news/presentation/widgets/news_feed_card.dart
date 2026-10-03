import 'package:flutter/material.dart';

import '../../../../data/models/news_model.dart';
import '../../../home/presentation/home_widgets.dart';

String newsDateTime(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  return '${homeDate(date)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Full title and summary: vertical growth is intentional, not a layout error.
class NewsFeedCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback onTap;
  const NewsFeedCard({super.key, required this.news, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      if (news.primaryCategory != null) news.primaryCategory!.name,
      ...news.categories.map((category) => category.name),
    }.where((name) => name.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: homeLine),
        ),
        child: InkWell(
          key: ValueKey('news-article-${news.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: HomeCover(
                  url: news.coverUrl,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (news.breaking)
                          _badge(context, 'SON DAKİKA', filled: true),
                        for (final name in categories) _badge(context, name),
                        if (news.featured) _badge(context, 'ÖNE ÇIKAN'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: homeNavy,
                      ),
                    ),
                    if (news.summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          news.summary,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.65,
                            color: homeMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      [
                        newsDateTime(news.publishedAt),
                        if (news.readingTime > 0)
                          '${news.readingTime} dk okuma',
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: homeMuted,
                      ),
                    ),
                    if (news.modifiedAt != null &&
                        news.modifiedAt != news.publishedAt)
                      Text(
                        'Güncellendi: ${newsDateTime(news.modifiedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: homeMuted,
                        ),
                      ),
                    if (news.locations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final location in news.locations)
                              Text(
                                location.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.6,
                                  color: homeMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String title, {bool filled = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: filled
              ? Theme.of(context).colorScheme.primary
              : const Color(0xfff0f3f7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: filled
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

/// One shared compact card for category, subcategory and visual search feeds.
class CompactNewsGridCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback onTap;
  const CompactNewsGridCard({
    super.key,
    required this.news,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: homeLine),
    ),
    child: InkWell(
      key: ValueKey('news-grid-${news.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: HomeCover(
              url: news.coverUrl,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (news.primaryCategory?.name.isNotEmpty ?? false)
                    Text(
                      news.primaryCategory!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (news.breaking)
                    Text(
                      'SON DAKİKA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      news.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: homeNavy,
                      ),
                    ),
                  ),
                  Text(
                    newsDateTime(news.publishedAt),
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

double compactNewsGridHeight(BuildContext context, double cardWidth) {
  final scale = MediaQuery.textScalerOf(context);
  return cardWidth * .75 + scale.scale(9) * 5 + scale.scale(13) * 1.25 * 3 + 40;
}
