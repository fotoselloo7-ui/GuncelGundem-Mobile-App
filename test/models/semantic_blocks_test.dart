import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/news_block_model.dart';

void main() {
  group('Semantic News Blocks Tests', () {
    test('ParagraphNewsBlock correctly parses', () {
      final block = NewsBlockModel.fromJson({
        'type': 'paragraph',
        'text': 'Bu bir paragraftır.',
      });

      expect(block, isA<ParagraphNewsBlock>());
      expect((block as ParagraphNewsBlock).text, 'Bu bir paragraftır.');
    });

    test('HeadingNewsBlock parses heading2 and heading3 aliases', () {
      final h2 = NewsBlockModel.fromJson({
        'type': 'heading2',
        'text': 'Başlık 2',
      });
      expect(h2, isA<HeadingNewsBlock>());
      expect((h2 as HeadingNewsBlock).level, 2);
      expect(h2.text, 'Başlık 2');

      final h3 = NewsBlockModel.fromJson({
        'type': 'heading3',
        'text': 'Başlık 3',
      });
      expect(h3, isA<HeadingNewsBlock>());
      expect((h3 as HeadingNewsBlock).level, 3);
    });

    test('ImageNewsBlock parses absolute URL, caption and credit', () {
      final block = NewsBlockModel.fromJson({
        'type': 'image',
        'url': 'https://guncelgundem.tr/uploads/image.jpg',
        'caption': 'Görsel açıklaması',
        'credit': 'Fotoğrafçı',
      });

      expect(block, isA<ImageNewsBlock>());
      final img = block as ImageNewsBlock;
      expect(img.url, 'https://guncelgundem.tr/uploads/image.jpg');
      expect(img.caption, 'Görsel açıklaması');
      expect(img.credit, 'Fotoğrafçı');
    });

    test('QuoteNewsBlock parses text and author', () {
      final block = NewsBlockModel.fromJson({
        'type': 'quote',
        'text': 'Alıntı yapılan söz.',
        'author': 'Konuşmacı Adı',
      });

      expect(block, isA<QuoteNewsBlock>());
      final q = block as QuoteNewsBlock;
      expect(q.text, 'Alıntı yapılan söz.');
      expect(q.author, 'Konuşmacı Adı');
    });

    test('ListNewsBlock parses ordered and bullet styles', () {
      final bulletList = NewsBlockModel.fromJson({
        'type': 'list',
        'style': 'bullet',
        'items': ['Bir', 'İki'],
      });
      expect(bulletList, isA<ListNewsBlock>());
      expect((bulletList as ListNewsBlock).isOrdered, isFalse);
      expect(bulletList.items.length, 2);

      final orderedList = NewsBlockModel.fromJson({
        'type': 'list',
        'style': 'ordered',
        'items': ['İlk', 'İkinci'],
      });
      expect((orderedList as ListNewsBlock).isOrdered, isTrue);
    });

    test('VideoNewsBlock and HtmlNewsBlock parse safely', () {
      final video = NewsBlockModel.fromJson({
        'type': 'video',
        'url': 'https://guncelgundem.tr/video.mp4',
        'caption': 'Video başlığı',
      });
      expect(video, isA<VideoNewsBlock>());

      final html = NewsBlockModel.fromJson({
        'type': 'html',
        'html': '<p>Serbest html</p>',
      });
      expect(html, isA<HtmlNewsBlock>());
      expect((html as HtmlNewsBlock).html, '<p>Serbest html</p>');
    });

    test('Unknown block type does NOT crash and produces UnknownNewsBlock', () {
      final unknown = NewsBlockModel.fromJson({
        'type': 'future_interactive_chart',
        'data': [1, 2, 3],
        'text': 'Yedek metin',
      });

      expect(unknown, isA<UnknownNewsBlock>());
      final u = unknown as UnknownNewsBlock;
      expect(u.type, 'future_interactive_chart');
      expect(u.textFallback, 'Yedek metin');
    });

    test('NewsBodyModel parses mixed blocks list safely', () {
      final body = NewsBodyModel.fromJson({
        'format': 'blocks',
        'blocks': [
          {'type': 'heading2', 'text': 'Giriş'},
          {'type': 'paragraph', 'text': 'Gelişme'},
          {'type': 'non_existent_type', 'content': 'Fallback'},
        ],
      });

      expect(body.format, 'blocks');
      expect(body.blocks.length, 3);
      expect(body.blocks[0], isA<HeadingNewsBlock>());
      expect(body.blocks[1], isA<ParagraphNewsBlock>());
      expect(body.blocks[2], isA<UnknownNewsBlock>());
    });
  });
}
