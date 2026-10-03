import 'package:equatable/equatable.dart';

import 'blog_json.dart';
import 'news_block_model.dart';

/// Blog-only extension. NewsBlockModel and ArticleBlockRenderer stay unchanged.
sealed class BlogBlockModel extends Equatable {
  final String type;
  const BlogBlockModel(this.type);
  factory BlogBlockModel.fromJson(Map<String, dynamic> json) {
    final type = (BlogJson.string(json['type']) ?? 'unknown').toLowerCase();
    if (type == 'table') return TableBlogBlock.fromJson(json);
    if (type == 'factbox') return FactboxBlogBlock.fromJson(json);
    try {
      return StandardBlogBlock(block: NewsBlockModel.fromJson(json), raw: json);
    } catch (_) {
      return StandardBlogBlock(
        block: UnknownNewsBlock(type: type, raw: json),
        raw: json,
      );
    }
  }
  Map<String, dynamic> toJson();
}

class StandardBlogBlock extends BlogBlockModel {
  final NewsBlockModel block;
  final Map<String, dynamic> raw;
  StandardBlogBlock({required this.block, this.raw = const {}})
    : super(block.type);
  @override
  Map<String, dynamic> toJson() => {...raw, ...block.toJson()};
  @override
  List<Object?> get props => [block, toJson()];
}

class TableBlogBlock extends BlogBlockModel {
  final List<String> headers;
  final List<List<String>> rows;
  final String? html;
  const TableBlogBlock({
    this.headers = const [],
    this.rows = const [],
    this.html,
  }) : super('table');
  factory TableBlogBlock.fromJson(Map<String, dynamic> json) => TableBlogBlock(
    headers: _cells(json['headers']),
    rows: json['rows'] is List
        ? (json['rows'] as List).whereType<List>().map(_cells).toList()
        : const [],
    html: BlogJson.string(json['html']),
  );
  static List<String> _cells(dynamic value) => value is List
      ? value.map((cell) => BlogJson.string(cell) ?? '').toList()
      : const [];
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'headers': headers,
    'rows': rows,
    if (html != null) 'html': html,
  };
  @override
  List<Object?> get props => [type, headers, rows, html];
}

class FactboxBlogBlock extends BlogBlockModel {
  final String? title;
  final String? text;
  final List<String> items;
  const FactboxBlogBlock({this.title, this.text, this.items = const []})
    : super('factbox');
  factory FactboxBlogBlock.fromJson(Map<String, dynamic> json) =>
      FactboxBlogBlock(
        title: BlogJson.string(json['title']),
        text: BlogJson.string(json['text']),
        items: BlogJson.strings(json['items']),
      );
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'text': text,
    'items': items,
  };
  @override
  List<Object?> get props => [type, title, text, items];
}
