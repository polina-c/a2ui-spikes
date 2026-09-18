import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:test/test.dart';

Future<List<GenerationEvent>> parse(List<String> chunks) {
  return Stream<String>.fromIterable(
    chunks,
  ).transform(const A2uiParserTransformer()).toList();
}

void main() {
  group('A2uiParserTransformer', () {
    test('separates prose from an A2UI message', () async {
      final List<GenerationEvent> events = await parse([
        'Here you go.\n```json\n'
            '{"version":"v0.9","createSurface":{"surfaceId":"s1",'
            '"catalogId":"c"}}\n```\n',
      ]);

      final String prose = events
          .whereType<TextEvent>()
          .map((e) => e.text)
          .join();
      expect(prose.trim(), 'Here you go.');

      final core.A2uiMessage message =
          events.whereType<A2uiMessageEvent>().single.message;
      expect(message, isA<core.CreateSurfaceMessage>());
      expect((message as core.CreateSurfaceMessage).surfaceId, 's1');
    });

    test('joins a message split across chunks', () async {
      // This is the case that matters: a model streams tokens, so a JSON
      // block almost never arrives whole.
      final List<GenerationEvent> events = await parse([
        '```json\n{"version":"v0.9","crea',
        'teSurface":{"surfaceId":"s',
        '2","catalogId":"c"}}\n```',
      ]);

      final A2uiMessageEvent event =
          events.whereType<A2uiMessageEvent>().single;
      expect((event.message as core.CreateSurfaceMessage).surfaceId, 's2');
    });

    test('keeps fences out of the prose at every chunk boundary', () async {
      // A model streams "```" and "json" as separate tokens, so the fence
      // routinely straddles a chunk. Splitting it must not turn the
      // backticks into something the user reads.
      const String answer =
          'Here you go.\n'
          '```json\n{"version":"v0.9","createSurface":'
          '{"surfaceId":"s1","catalogId":"c"}}\n```\n'
          'And more.\n'
          '```json\n{"version":"v0.9","deleteSurface":'
          '{"surfaceId":"s1"}}\n```\n';

      for (final int size in [1, 2, 3, 4, 5, 7, 8, 11, 16, 64]) {
        final chunks = <String>[
          for (var i = 0; i < answer.length; i += size)
            answer.substring(i, (i + size).clamp(0, answer.length)),
        ];
        final List<GenerationEvent> events = await parse(chunks);

        expect(
          events.whereType<A2uiMessageEvent>(),
          hasLength(2),
          reason: 'chunk size \$size',
        );
        expect(
          events.whereType<TextEvent>().map((e) => e.text).join(),
          isNot(contains('`')),
          reason: 'chunk size \$size',
        );
      }
    });

    test('reads several messages from one response', () async {
      final List<GenerationEvent> events = await parse([
        '```json\n{"version":"v0.9","createSurface":'
            '{"surfaceId":"s3","catalogId":"c"}}\n```\n'
            '```json\n{"version":"v0.9","updateComponents":'
            '{"surfaceId":"s3","components":[{"id":"root",'
            '"component":"Text","text":"hi"}]}}\n```',
      ]);

      expect(events.whereType<A2uiMessageEvent>(), hasLength(2));
    });

    test('keeps unfenced JSON objects as messages', () async {
      final List<GenerationEvent> events = await parse([
        '{"version":"v0.9","deleteSurface":{"surfaceId":"s4"}}',
      ]);

      expect(
        (events.single as A2uiMessageEvent).message,
        isA<core.DeleteSurfaceMessage>(),
      );
    });

    test('reports a versioned message it cannot parse', () async {
      final Stream<GenerationEvent> events = Stream<String>.value(
        '```json\n{"version":"v0.1","createSurface":{"surfaceId":"s"}}\n```',
      ).transform(const A2uiParserTransformer());

      await expectLater(events, emitsError(isA<A2uiValidationException>()));
    });

    test('passes plain JSON that is not a message through as text', () async {
      final List<GenerationEvent> events = await parse([
        '```json\n{"note":"not a2ui"}\n```',
      ]);

      expect(events.single, isA<TextEvent>());
    });
  });

  group('JsonBlockParser', () {
    test('finds a fenced block', () {
      expect(
        JsonBlockParser.parseFirstJsonBlock('say\n```json\n{"a":1}\n```'),
        {'a': 1},
      );
    });

    test('finds a bare object after prose', () {
      expect(JsonBlockParser.parseFirstJsonBlock('here: {"a":1} done'), {
        'a': 1,
      });
    });

    test('returns null when there is no JSON', () {
      expect(JsonBlockParser.parseFirstJsonBlock('nothing here'), isNull);
    });

    test('strips a block out of the prose around it', () {
      expect(JsonBlockParser.stripJsonBlock('before ```json\n{}\n``` after'),
          'before  after');
    });
  });
}
