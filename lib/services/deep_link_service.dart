import 'dart:async';

import 'package:flutter/services.dart';

import '../app/app_config.dart';

/// Deep link / Universal link servisi.
///
/// Native tarafta `tr.guncelgundem/deeplinks` MethodChannel:
///   - method `initial` → ilk cold-start linki (yoksa null)
///   - event `onLink(url: String)` → foreground/warm-start linki
///
/// Yalnız üretim host'u ([AppConfig.deepLinkHost]) ve bilinen path desenleri
/// kabul edilir. Payload sözleşmesinde olmayan tür üretilmez.
enum DeepLinkTarget { news, blog, home }

class DeepLinkIntent {
  final DeepLinkTarget target;
  final String? slug;
  const DeepLinkIntent(this.target, {this.slug});

  @override
  String toString() => 'DeepLinkIntent($target, slug: $slug)';
}

class DeepLinkService {
  static const MethodChannel channel = MethodChannel(
    'tr.guncelgundem/deeplinks',
  );

  final MethodChannel _channel;
  final StreamController<DeepLinkIntent> _controller =
      StreamController<DeepLinkIntent>.broadcast();
  bool _handlerRegistered = false;

  DeepLinkService({MethodChannel? channel})
    : _channel = channel ?? DeepLinkService.channel;

  Stream<DeepLinkIntent> get onLink => _controller.stream;

  /// Kurulumu tamamlar: cold-start linkini okur ve warm-start akışını başlatır.
  Future<DeepLinkIntent?> initialize() async {
    if (!_handlerRegistered) {
      _handlerRegistered = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onLink') {
          final url =
              (call.arguments is Map
                      ? (call.arguments as Map)['url']
                      : call.arguments)
                  ?.toString();
          final intent = parse(url);
          if (intent != null) _controller.add(intent);
        }
        return null;
      });
    }
    try {
      final initial = await _channel.invokeMethod<String>('initial');
      return parse(initial);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Yalnız üretim host'u ve bilinen desenlerde intent üretir.
  static DeepLinkIntent? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final isHttp = uri.scheme == 'https' || uri.scheme == 'http';
    final isAppScheme = uri.scheme == 'guncelgundem';
    if (!isHttp && !isAppScheme) return null;
    if (isHttp && uri.host != AppConfig.deepLinkHost) return null;
    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return const DeepLinkIntent(DeepLinkTarget.home);
    if (segments.length >= 2 && segments.first == 'haber') {
      return DeepLinkIntent(DeepLinkTarget.news, slug: segments[1]);
    }
    if (segments.length >= 2 &&
        (segments.first == 'bilgi-kosesi' || segments.first == 'blog') &&
        segments[1] != 'kategori') {
      // Web kanonik biçimleri aynı segment sayısına sahiptir:
      //   makale  -> /blog/{slug}      (sonda eğik çizgi YOK)
      //   kategori-> /blog/{kategori}/ (sonda eğik çizgi VAR, alt kategori 3 segment)
      // Kategori bağlantısı makale sanılırsa boş bir detay ekranı açılırdı;
      // bu yüzden kategori biçimi Bilgi Köşesi dizinine yönlendirilir.
      final isCategoryShape =
          uri.path.endsWith('/') || segments.length >= 3;
      if (isCategoryShape) {
        return const DeepLinkIntent(DeepLinkTarget.blog);
      }
      return DeepLinkIntent(DeepLinkTarget.blog, slug: segments[1]);
    }
    return null;
  }

  void dispose() {
    _controller.close();
  }
}
