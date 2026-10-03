import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/news_block_model.dart';
import 'package:guncelgundem/features/news/presentation/widgets/article_block_renderer.dart';

void main() {
  testWidgets('ArticleBlockRenderer renders semantic blocks without error', (
    tester,
  ) async {
    const blocks = <NewsBlockModel>[
      HeadingNewsBlock(level: 2, text: 'Haber Başlığı Testi'),
      ParagraphNewsBlock(text: 'Bu bir test paragrafıdır.'),
      QuoteNewsBlock(text: 'Önemli bir alıntı.', author: 'Yetkili Kişi'),
      ListNewsBlock(style: 'bullet', items: ['Madde 1', 'Madde 2']),
      UnknownNewsBlock(
        type: 'future_block_xyz',
        raw: {'type': 'future_block_xyz', 'text': 'Gelecek blok'},
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleBlockRenderer(blocks: blocks),
          ),
        ),
      ),
    );

    expect(find.text('Haber Başlığı Testi'), findsOneWidget);
    expect(find.text('Bu bir test paragrafıdır.'), findsOneWidget);
    expect(find.textContaining('Önemli bir alıntı'), findsOneWidget);
    expect(find.text('— Yetkili Kişi'), findsOneWidget);
    expect(find.text('Madde 1'), findsOneWidget);
    expect(find.text('Madde 2'), findsOneWidget);
    expect(find.text('Gelecek blok'), findsOneWidget);
  });
}
