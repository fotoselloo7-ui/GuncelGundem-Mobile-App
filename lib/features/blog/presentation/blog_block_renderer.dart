import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../data/models/blog_block_model.dart';
import '../../../data/models/blog_json.dart';
import '../../../data/models/blog_recipe_model.dart';
import '../../../data/models/news_block_model.dart';
import '../../home/presentation/home_widgets.dart';
import 'blog_widgets.dart';

typedef BlogLinkHandler = Future<void> Function(String url);

/// Blok metni satır içi HTML içeriyor mu? (<strong>, <em>, <a>, sarmalayıcı <p> ...)
///
/// Backend semantik blok metinlerinde güvenli satır içi biçimlendirme saklar.
/// Bu metin düz `Text` ile çizilirse kullanıcıya "<strong>...</strong>" olarak
/// GÖRÜNÜR (web tarafındaki aynı hatanın mobil karşılığı). Etiket yoksa düz
/// metin yolu korunur; gereksiz HTML ayrıştırma maliyeti oluşmaz.
bool blogTextHasMarkup(String? value) =>
    value != null && RegExp(r'<\s*/?\s*[a-zA-Z][a-zA-Z0-9]*[^>]*>').hasMatch(value);

/// Başlık/etiket alanları düz metindir: olası etiketler ayıklanır.
String blogStripTags(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();


/// Lazy, native blog-only renderer. The news renderer is intentionally untouched.
class BlogBlockRenderer extends StatelessWidget {
  final List<BlogBlockModel> blocks;
  final BlogLinkHandler onLink;
  const BlogBlockRenderer({
    super.key,
    required this.blocks,
    required this.onLink,
  });
  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: blocks.length,
    itemBuilder: (context, index) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: BlogBlockView(block: blocks[index], onLink: onLink),
    ),
  );
}

class BlogBlockView extends StatelessWidget {
  final BlogBlockModel block;
  final BlogLinkHandler onLink;
  const BlogBlockView({super.key, required this.block, required this.onLink});
  @override
  Widget build(BuildContext context) {
    switch (block) {
      case TableBlogBlock():
        return _table(context, block as TableBlogBlock);
      case FactboxBlogBlock():
        final box = block as FactboxBlogBlock;
        if ((box.title ?? '').isEmpty &&
            (box.text ?? '').isEmpty &&
            box.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return BlogFactbox(
          title: box.title,
          text: box.text,
          items: box.items,
          onLink: onLink,
        );
      case StandardBlogBlock():
        final standard = block as StandardBlogBlock;
        switch (standard.block) {
          case ParagraphNewsBlock(:final text):
            return blogTextHasMarkup(text)
                ? _html(text)
                : Text(text, style: blogText);
          case HeadingNewsBlock(:final text, :final level):
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                blogStripTags(text),
                style: TextStyle(
                  fontSize: level <= 2 ? 23 : 19,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: homeNavy,
                ),
              ),
            );
          case ListNewsBlock(:final items, :final isOrdered):
            return BlogNativeList(
              items: items,
              ordered: isOrdered,
              onLink: onLink,
            );
          case QuoteNewsBlock(:final text, :final author):
            return Container(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (blogTextHasMarkup(text))
                    _html(text)
                  else
                    Text(
                      text,
                      style: blogText.copyWith(fontStyle: FontStyle.italic),
                    ),
                  if ((author ?? '').isNotEmpty)
                    Text(
                      '— $author',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: homeMuted,
                      ),
                    ),
                ],
              ),
            );
          case ImageNewsBlock(:final url, :final caption, :final credit):
            final width = num.tryParse('${standard.raw['width']}'),
                height = num.tryParse('${standard.raw['height']}');
            return BlogImage(
              url: url,
              caption: caption,
              credit: credit,
              alt: BlogJson.string(standard.raw['alt']),
              ratio: width != null && height != null && width > 0 && height > 0
                  ? width / height
                  : 16 / 9,
            );
          case HtmlNewsBlock(:final html):
            return _html(html);
          case VideoNewsBlock(:final url, :final caption):
            return BlogLinkLabel(
              label: caption ?? url,
              url: url,
              onLink: onLink,
            );
          case UnknownNewsBlock(:final raw, :final textFallback):
            final url = BlogJson.string(raw['url'] ?? raw['href']);
            if ((standard.type == 'link' || standard.type == 'internal_link') &&
                url != null) {
              return BlogLinkLabel(
                label: BlogJson.string(raw['text'] ?? raw['title']) ?? url,
                url: url,
                onLink: onLink,
              );
            }
            return (textFallback ?? '').isEmpty
                ? const SizedBox.shrink()
                : Text(textFallback!, style: blogText);
        }
    }
  }

  Widget _html(String html) => HtmlWidget(
    html,
    textStyle: blogText,
    onTapUrl: (url) async {
      await onLink(url);
      return true;
    },
    customWidgetBuilder: (element) {
      if ([
        'script',
        'iframe',
        'style',
        'object',
        'embed',
      ].contains(element.localName)) {
        return const SizedBox.shrink();
      }
      if (element.localName == 'img') {
        return BlogImage(
          url: element.attributes['src'],
          alt: element.attributes['alt'],
        );
      }
      return null;
    },
  );
  Widget _table(BuildContext context, TableBlogBlock table) {
    final columns = math.max(
      table.headers.length,
      table.rows.fold<int>(0, (n, row) => math.max(n, row.length)),
    );
    if (columns == 0) {
      return table.html?.isNotEmpty == true
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 640, child: _html(table.html!)),
            )
          : const SizedBox.shrink();
    }
    Widget rowText(String text, bool header) => Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: blogText.copyWith(
          fontSize: 14,
          fontWeight: header ? FontWeight.w600 : FontWeight.w400,
          color: header ? Colors.white : homeNavy,
        ),
      ),
    );
    TableRow row(List<String> cells, bool header, int index) => TableRow(
      decoration: BoxDecoration(
        color: header
            ? homeNavy
            : index.isEven
            ? Colors.white
            : const Color(0xfff4f7fa),
      ),
      children: List.generate(
        columns,
        (i) => rowText(i < cells.length ? cells[i] : '', header),
      ),
    );
    return Semantics(
      label: 'Tablo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          key: const ValueKey('blog-table-scroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: columns * 180.0,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(180),
              border: TableBorder.all(color: homeLine),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [
                if (table.headers.isNotEmpty) row(table.headers, true, 0),
                for (var i = 0; i < table.rows.length; i++)
                  row(table.rows[i], false, i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlogLinkLabel extends StatelessWidget {
  final String label, url;
  final BlogLinkHandler onLink;
  const BlogLinkLabel({
    super.key,
    required this.label,
    required this.url,
    required this.onLink,
  });
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => onLink(url),
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    child: Text(
      label,
      style: blogText.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

class BlogNativeList extends StatelessWidget {
  final List<String> items;
  final bool ordered;

  /// Madde metni satır içi HTML içerebildiği için bağlantı dokunuşları da
  /// desteklenir. Verilmezse bağlantılar yok sayılır (crash etmez).
  final BlogLinkHandler? onLink;
  const BlogNativeList({
    super.key,
    required this.items,
    this.ordered = false,
    this.onLink,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++)
        if (items[i].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordered ? '${i + 1}. ' : '• ',
                  style: blogText.copyWith(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: blogTextHasMarkup(items[i])
                      ? BlogInlineHtml(html: items[i], onLink: onLink)
                      : Text(items[i], style: blogText),
                ),
              ],
            ),
          ),
    ],
  );
}

/// Satır içi HTML'i güvenli şekilde çizen paylaşılan görünüm.
/// script/iframe/style/object/embed etiketleri atılır; <img> blog görseline,
/// bağlantı dokunuşları [onLink] akışına yönlendirilir.
class BlogInlineHtml extends StatelessWidget {
  final String html;
  final BlogLinkHandler? onLink;
  final TextStyle? style;
  const BlogInlineHtml({
    super.key,
    required this.html,
    this.onLink,
    this.style,
  });
  @override
  Widget build(BuildContext context) => HtmlWidget(
    html,
    textStyle: style ?? blogText,
    onTapUrl: (url) async {
      final handler = onLink;
      if (handler == null) return false;
      await handler(url);
      return true;
    },
    customWidgetBuilder: (element) {
      if ([
        'script',
        'iframe',
        'style',
        'object',
        'embed',
      ].contains(element.localName)) {
        return const SizedBox.shrink();
      }
      if (element.localName == 'img') {
        return BlogImage(
          url: element.attributes['src'],
          alt: element.attributes['alt'],
        );
      }
      return null;
    },
  );
}

class BlogFactbox extends StatelessWidget {
  final String? title, text;
  final List<String> items;
  final BlogLinkHandler? onLink;
  const BlogFactbox({
    super.key,
    this.title,
    this.text,
    this.items = const [],
    this.onLink,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xffeef2f7),
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(
          width: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((title ?? '').isNotEmpty)
          Text(
            blogStripTags(title!),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: homeNavy,
            ),
          ),
        if ((text ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: blogTextHasMarkup(text)
                ? BlogInlineHtml(html: text!, onLink: onLink)
                : Text(text!, style: blogText),
          ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BlogNativeList(items: items, onLink: onLink),
          ),
      ],
    ),
  );
}

class BlogRecipe extends StatelessWidget {
  final BlogRecipeModel recipe;
  const BlogRecipe({super.key, required this.recipe});
  static bool hasContent(BlogRecipeModel recipe) => [
    recipe.recipeName,
    recipe.description,
    recipe.prepTime,
    recipe.cookTime,
    recipe.totalTime,
    recipe.servings,
    recipe.difficulty,
    recipe.cuisine,
    recipe.calories,
    ...recipe.ingredients,
    ...recipe.instructions,
  ].any((value) => value?.trim().isNotEmpty == true);
  String _time(String raw) {
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?$',
      caseSensitive: false,
    ).firstMatch(raw);
    return match == null
        ? raw
        : [
            if (match[1] != null) '${match[1]} saat',
            if (match[2] != null) '${match[2]} dk',
          ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent(recipe)) return const SizedBox.shrink();
    final meta = <String, String?>{
      'Hazırlık': recipe.prepTime,
      'Pişirme': recipe.cookTime,
      'Toplam': recipe.totalTime,
      'Porsiyon': recipe.servings,
      'Zorluk': recipe.difficulty,
      'Mutfak': recipe.cuisine,
      'Kalori': recipe.calories,
    };
    return BlogPanel(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TARİF ÖZETİ',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (recipe.recipeName.isNotEmpty) blogHeading(recipe.recipeName),
          if ((recipe.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(recipe.description!, style: blogText),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in meta.entries)
                if (entry.value?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: homeBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: homeMuted,
                          ),
                        ),
                        Text(
                          _time(entry.value!),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: homeNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          if (recipe.ingredients.any((item) => item.isNotEmpty)) ...[
            blogHeading('Malzemeler'),
            BlogNativeList(items: recipe.ingredients),
          ],
          if (recipe.instructions.any((item) => item.isNotEmpty)) ...[
            blogHeading('Hazırlanışı'),
            BlogNativeList(items: recipe.instructions, ordered: true),
          ],
        ],
      ),
    );
  }
}
