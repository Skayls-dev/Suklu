import 'package:flutter_test/flutter_test.dart';
import 'package:suklu_mobile/features/ai_tutor/domain/chat_models.dart';

void main() {
  group('parseImageReferences', () {
    test('returns unchanged text and empty images when no tag exists', () {
      final (text, images) = parseImageReferences('Réponse sans image');
      expect(text, 'Réponse sans image');
      expect(images, isEmpty);
    });

    test('extracts one IMAGE tag', () {
      final (text, images) = parseImageReferences(
        'Regarde ceci [IMAGE:https://cdn.example.com/schema.png] Légende utile\nSuite',
      );

      expect(images.length, 1);
      expect(images.first.url, 'https://cdn.example.com/schema.png');
      expect(images.first.caption, 'Légende utile');
      expect(text, contains('Regarde ceci'));
      expect(text, isNot(contains('[IMAGE:')));
    });

    test('extracts two IMAGE tags', () {
      final (_, images) = parseImageReferences(
        '[IMAGE:https://a.com/1.png] Premier\nTexte\n[IMAGE:https://a.com/2.png] Deuxième',
      );

      expect(images.length, 2);
      expect(images[0].url, 'https://a.com/1.png');
      expect(images[1].url, 'https://a.com/2.png');
    });

    test('ignores malformed tags', () {
      final (text, images) = parseImageReferences('Tag cassé [IMAGE:notaurl] ignoré');
      expect(images, isEmpty);
      expect(text, 'Tag cassé [IMAGE:notaurl] ignoré');
    });
  });
}
