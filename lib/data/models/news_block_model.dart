import 'package:equatable/equatable.dart';

/// Semantic Haber Gövde Bloğu Temel Sınıfı
sealed class NewsBlockModel extends Equatable {
  final String type;

  const NewsBlockModel(this.type);

  factory NewsBlockModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toLowerCase() ?? 'unknown';

    switch (type) {
      case 'paragraph':
        return ParagraphNewsBlock.fromJson(json);

      case 'heading2':
        return HeadingNewsBlock(
          level: 2,
          text: (json['text'] as String?) ?? '',
        );

      case 'heading3':
        return HeadingNewsBlock(
          level: 3,
          text: (json['text'] as String?) ?? '',
        );

      case 'heading':
        return HeadingNewsBlock.fromJson(json);

      case 'image':
        return ImageNewsBlock.fromJson(json);

      case 'quote':
        return QuoteNewsBlock.fromJson(json);

      case 'list':
        return ListNewsBlock.fromJson(json);

      case 'video':
        return VideoNewsBlock.fromJson(json);

      case 'html':
        return HtmlNewsBlock.fromJson(json);

      default:
        return UnknownNewsBlock(type: type, raw: json);
    }
  }

  Map<String, dynamic> toJson();
}

/// Paragraf Bloğu
class ParagraphNewsBlock extends NewsBlockModel {
  final String text;

  const ParagraphNewsBlock({required this.text}) : super('paragraph');

  factory ParagraphNewsBlock.fromJson(Map<String, dynamic> json) {
    return ParagraphNewsBlock(text: (json['text'] as String?) ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'paragraph', 'text': text};

  @override
  List<Object?> get props => [type, text];
}

/// Başlık Bloğu (H2, H3, H4)
class HeadingNewsBlock extends NewsBlockModel {
  final int level;
  final String text;

  const HeadingNewsBlock({required this.level, required this.text})
    : super('heading');

  factory HeadingNewsBlock.fromJson(Map<String, dynamic> json) {
    return HeadingNewsBlock(
      level: (json['level'] as num?)?.toInt() ?? 2,
      text: (json['text'] as String?) ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'heading',
    'level': level,
    'text': text,
  };

  @override
  List<Object?> get props => [type, level, text];
}

/// Metin İçi Görsel Bloğu
class ImageNewsBlock extends NewsBlockModel {
  final String url;
  final String? caption;
  final String? credit;

  const ImageNewsBlock({required this.url, this.caption, this.credit})
    : super('image');

  factory ImageNewsBlock.fromJson(Map<String, dynamic> json) {
    return ImageNewsBlock(
      url: (json['url'] as String?) ?? '',
      caption: json['caption'] as String?,
      credit: json['credit'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'url': url,
    if (caption != null) 'caption': caption,
    if (credit != null) 'credit': credit,
  };

  @override
  List<Object?> get props => [type, url, caption, credit];
}

/// Alıntı Bloğu
class QuoteNewsBlock extends NewsBlockModel {
  final String text;
  final String? author;

  const QuoteNewsBlock({required this.text, this.author}) : super('quote');

  factory QuoteNewsBlock.fromJson(Map<String, dynamic> json) {
    return QuoteNewsBlock(
      text: (json['text'] as String?) ?? '',
      author: json['author'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'quote',
    'text': text,
    if (author != null) 'author': author,
  };

  @override
  List<Object?> get props => [type, text, author];
}

/// Liste Bloğu (Ordered / Bullet)
class ListNewsBlock extends NewsBlockModel {
  final String style; // 'ordered' | 'bullet'
  final List<String> items;

  const ListNewsBlock({this.style = 'bullet', required this.items})
    : super('list');

  bool get isOrdered => style == 'ordered';

  factory ListNewsBlock.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final items = rawItems != null
        ? rawItems
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : const <String>[];

    return ListNewsBlock(
      style: (json['style'] as String?) == 'ordered' ? 'ordered' : 'bullet',
      items: items,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'list',
    'style': style,
    'items': items,
  };

  @override
  List<Object?> get props => [type, style, items];
}

/// Video Bloğu
class VideoNewsBlock extends NewsBlockModel {
  final String url;
  final String? caption;

  const VideoNewsBlock({required this.url, this.caption}) : super('video');

  factory VideoNewsBlock.fromJson(Map<String, dynamic> json) {
    return VideoNewsBlock(
      url: (json['url'] as String?) ?? '',
      caption: json['caption'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'video',
    'url': url,
    if (caption != null) 'caption': caption,
  };

  @override
  List<Object?> get props => [type, url, caption];
}

/// Güvenli HTML Fallback Bloğu
class HtmlNewsBlock extends NewsBlockModel {
  final String html;

  const HtmlNewsBlock({required this.html}) : super('html');

  factory HtmlNewsBlock.fromJson(Map<String, dynamic> json) {
    return HtmlNewsBlock(
      html: (json['html'] as String?) ?? (json['content'] as String?) ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'html', 'html': html};

  @override
  List<Object?> get props => [type, html];
}

/// Bilinmeyen / Gelecekteki Yeni Blok Tipleri İçin Güvenli Çökme Koruması (Fallback)
class UnknownNewsBlock extends NewsBlockModel {
  final Map<String, dynamic> raw;

  const UnknownNewsBlock({required String type, required this.raw})
    : super(type);

  String? get textFallback =>
      raw['text']?.toString() ?? raw['content']?.toString();

  @override
  Map<String, dynamic> toJson() => raw;

  @override
  List<Object?> get props => [type, raw];
}

/// Haber Gövdesi Taşıyıcı Modeli (Format ve Bloklar)
class NewsBodyModel extends Equatable {
  final String format;
  final List<NewsBlockModel> blocks;

  const NewsBodyModel({this.format = 'blocks', this.blocks = const []});

  factory NewsBodyModel.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>?;
    final blocks = rawBlocks != null
        ? rawBlocks
              .whereType<Map<String, dynamic>>()
              .map((b) => NewsBlockModel.fromJson(b))
              .toList()
        : const <NewsBlockModel>[];

    return NewsBodyModel(
      format: (json['format'] as String?) ?? 'blocks',
      blocks: blocks,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  @override
  List<Object?> get props => [format, blocks];
}
