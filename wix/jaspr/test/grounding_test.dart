import 'package:test/test.dart';
import 'package:wix_ai_chat/grounding.dart';
import 'package:wix_ai_chat/knowledge.dart';

/// The sample content, as the model is given it.
final String source = renderEntries(knowledge);

void main() {
  group('invented contact details', () {
    test('an answer with no contact detail in it passes', () {
      expect(
        inventedContactDetail(
          'A single headshot session is \$180 and includes three retouched '
          'photos.',
          source,
        ),
        isNull,
      );
    });

    test('an email that is in the content passes', () {
      expect(
        inventedContactDetail('Email hello@northwindstudio.example.', source),
        isNull,
      );
    });

    test('an email that is in the content passes whatever its case', () {
      expect(
        inventedContactDetail('Email Hello@NorthwindStudio.example.', source),
        isNull,
      );
    });

    test('an email that is not in the content is caught', () {
      expect(
        inventedContactDetail('Write to bookings@northwind.com.', source),
        'bookings@northwind.com',
      );
    });

    test('a link that is not in the content is caught', () {
      expect(
        inventedContactDetail(
          'See https://northwindstudio.example/prices for the list.',
          source,
        ),
        'https://northwindstudio.example/prices',
      );
    });

    test('a bare www link that is not in the content is caught', () {
      // The trailing full stop is part of the match, as it is in the
      // vanilla widget: the token is reported, never repaired, so where it
      // ends only affects the message in a log.
      expect(
        inventedContactDetail('Book at www.northwind.example.', source),
        'www.northwind.example.',
      );
    });

    test('a link that is in the content passes', () {
      const String content = 'Book at https://northwind.example/book.';
      expect(
        inventedContactDetail('Book at https://northwind.example/book.', content),
        isNull,
      );
    });

    test('a phone number that is not in the content is caught', () {
      // The match starts at the first digit, so the opening bracket is not
      // part of it.
      expect(
        inventedContactDetail('Call us on (503) 555-0147.', source),
        '503) 555-0147',
      );
    });

    test('a bare seven-digit number is caught', () {
      // Observed in the browser: asked for a phone number the content does
      // not have, Qwen2.5-0.5B answered with this one.
      expect(
        inventedContactDetail('Your phone number is 5364217.', source),
        '5364217',
      );
    });

    test('a phone number that is in the content passes', () {
      const String content = 'Call the studio on 503-555-0147.';
      expect(inventedContactDetail('Call 503-555-0147.', content), isNull);
    });

    test('the same number written differently still passes', () {
      const String content = 'Call the studio on (503) 555-0147.';
      expect(inventedContactDetail('Call 5035550147.', content), isNull);
    });

    test('a price is not a phone number', () {
      expect(
        inventedContactDetail('Team headshots are \$120 per person.', source),
        isNull,
      );
    });

    test('opening hours are not a phone number', () {
      expect(
        inventedContactDetail(
          'We are open Tuesday to Saturday, 9am to 6pm.',
          source,
        ),
        isNull,
      );
    });

    test('a street address is not a phone number', () {
      expect(
        inventedContactDetail(
          'We are at 118 NE Alberta Street, Portland.',
          source,
        ),
        isNull,
      );
    });

    test('with no content, every contact detail reads as invented', () {
      // Which is why ChatSession does not run the check at all when
      // knowledge.dart is empty: with nothing to check against, this would
      // withhold every answer that mentions a number.
      expect(inventedContactDetail('Call 503-555-0147.', ''), '503-555-0147');
    });
  });

  group('the content sent with a question', () {
    test('a small site is sent whole', () {
      final String context = contextFor(knowledge, 'when do you open?');
      expect(context, renderEntries(knowledge));
    });

    test('a site with nothing in it sends nothing', () {
      expect(contextFor(const <KnowledgeEntry>[], 'anything'), isEmpty);
    });

    test('a site too big to send picks the entries that were asked about', () {
      final List<KnowledgeEntry> big = <KnowledgeEntry>[
        ...knowledge,
        for (int i = 0; i < 40; i++)
          KnowledgeEntry(
            title: 'Filler $i',
            text: 'Something else about the studio. ' * 20,
          ),
      ];
      expect(renderEntries(big).length, greaterThan(knowledgeBudget));

      final String context = contextFor(big, 'where can I park?');
      expect(context, contains('free street parking on Alberta'));
      expect(context.length, lessThanOrEqualTo(knowledgeBudget));
    });

    test('what is picked stays in the order it was written', () {
      final List<KnowledgeEntry> big = <KnowledgeEntry>[
        ...knowledge,
        for (int i = 0; i < 40; i++)
          KnowledgeEntry(title: 'Filler $i', text: 'Filler text. ' * 40),
      ];
      final String context = contextFor(big, 'what do you charge to park?');
      expect(
        context.indexOf('Prices and packages'),
        lessThan(context.indexOf('Where we are and parking')),
      );
    });
  });

  group('relevance', () {
    test('a title word counts for more than a body word', () {
      const KnowledgeEntry titled = KnowledgeEntry(
        title: 'Parking',
        text: 'Some other text.',
      );
      const KnowledgeEntry mentioned = KnowledgeEntry(
        title: 'Other',
        text: 'There is parking nearby.',
      );
      expect(
        relevance(titled, 'where do I park my car?'),
        greaterThan(relevance(mentioned, 'where do I park my car?')),
      );
    });

    test('a question of nothing but stopwords scores nothing', () {
      expect(relevance(knowledge.first, 'what is it?'), 0);
    });
  });
}
