import 'package:equatable/equatable.dart';

/// Video Medya Modeli
class MediaVideoModel extends Equatable {
  final String url;
  final String? caption;
  final String? title;

  const MediaVideoModel({required this.url, this.caption, this.title});

  factory MediaVideoModel.fromJson(dynamic json) {
    if (json is String) {
      return MediaVideoModel(url: json);
    } else if (json is Map<String, dynamic>) {
      return MediaVideoModel(
        url: (json['url'] as String?) ?? '',
        caption: json['caption'] as String?,
        title: json['title'] as String?,
      );
    }
    return const MediaVideoModel(url: '');
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (caption != null) 'caption': caption,
    if (title != null) 'title': title,
  };

  @override
  List<Object?> get props => [url, caption, title];
}
