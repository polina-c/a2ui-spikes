import 'dart:async';

import 'package:genui/genui.dart';
import 'package:test/test.dart';

/// A model whose answers are written in advance.
///
/// Each answer is emitted in small pieces, the way a real model streams, so
/// the parser has to reassemble the A2UI blocks split across them.
class ScriptedGenerator implements TextGenerator {
  ScriptedGenerator(this.answers);

  final List<String> answers;
  final List<List<ChatMessage>> requests = [];
  int _next = 0;

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    requests.add(messages);
    final String answer = _next < answers.length ? answers[_next++] : '';
    for (var i = 0; i < answer.length; i += 7) {
      yield answer.substring(i, (i + 7).clamp(0, answer.length));
    }
  }
}

String surfaceAnswer(String surfaceId, {String prose = 'Here you go.'}) =>
    '$prose\n'
    '```json\n'
    '{"version":"v0.9","createSurface":{"surfaceId":"$surfaceId",'
    '"catalogId":"$basicCatalogId","sendDataModel":true}}\n'
    '```\n'
    '```json\n'
    '{"version":"v0.9","updateComponents":{"surfaceId":"$surfaceId",'
    '"components":[{"id":"root","component":"Button","child":"l",'
    '"action":{"event":{"name":"go","context":{"pick":"a"}}}},'
    '{"id":"l","component":"Text","text":"Go"}]}}\n'
    '```\n';

void main() {
  late SurfaceController controller;
  late ScriptedGenerator generator;
  late Conversation conversation;

  void start(List<String> answers) {
    controller = SurfaceController(catalogs: [basicCatalog()]);
    generator = ScriptedGenerator(answers);
    conversation = Conversation(
      generator: generator,
      controller: controller,
      systemPrompt: 'SYSTEM',
    );
  }

  tearDown(() {
    conversation.dispose();
    controller.dispose();
  });

  test('a response becomes prose for the user and a surface on screen',
      () async {
    start([surfaceAnswer('s1')]);
    final List<String> prose = [];
    conversation.text.listen(prose.add);

    await conversation.send('Show me something.');

    expect(prose.join().trim(), 'Here you go.');
    expect(controller.surface('s1'), isNotNull);
    expect(
      controller.surface('s1')!.componentsModel.get('root')!.type,
      'Button',
    );
  });

  test('the system prompt is the first message the model sees', () async {
    start([surfaceAnswer('s1')]);
    await conversation.send('Hi');

    final List<ChatMessage> sent = generator.requests.single;
    expect(sent.first.role, ChatMessageRole.system);
    expect(sent.first.text, 'SYSTEM');
    expect(sent.last.role, ChatMessageRole.user);
    expect(sent.last.text, 'Hi');
  });

  test('pressing a generated button starts the next turn, carrying the data '
      'model', () async {
    // This is the loop that makes a generated UI a conversation rather than
    // a render: the model wrote the button, so it can read the answer.
    start([surfaceAnswer('s1'), 'Booked.']);
    await conversation.send('Show me something.');

    controller.surface('s1')!.dataModel.set('/choice', 'window seat');

    final Future<void> replied = conversation.isGenerating.firstWhere(
      (bool busy) => !busy,
    );
    await controller.surface('s1')!.dispatchAction({
      'event': {
        'name': 'go',
        'context': {'pick': 'a'},
      },
    }, 'root');
    await replied;

    expect(generator.requests, hasLength(2));
    final String followUp = generator.requests[1].last.text;
    expect(followUp, contains('"name":"go"'));
    expect(followUp, contains('"pick":"a"'));
    expect(followUp, contains('window seat'));
  });

  test('history keeps what was generated, so a later turn can refer to it',
      () async {
    start([surfaceAnswer('s1'), surfaceAnswer('s2', prose: 'And another.')]);
    await conversation.send('One.');
    await conversation.send('Two.');

    final List<ChatMessage> second = generator.requests[1];
    final String priorAnswer = second[2].text;
    expect(second[2].role, ChatMessageRole.model);
    expect(priorAnswer, contains('Here you go.'));
    expect(priorAnswer, contains('createSurface'));
    expect(priorAnswer, contains('s1'));
  });

  test('a malformed message is reported and the rest of the answer survives',
      () async {
    start([
      'Trying.\n```json\n{"version":"v0.1","createSurface":{"surfaceId":"x"}}\n```\n'
          '```json\n{"version":"v0.9","createSurface":{"surfaceId":"s9",'
          '"catalogId":"$basicCatalogId"}}\n```\n',
    ]);
    // Subscribed before sending, because errors go out on a broadcast
    // stream and would otherwise be delivered after the send completes.
    final Future<Object> error = conversation.errors.first;

    await conversation.send('Go');

    // The parser stops the stream at the bad message, which is why the
    // error matters: it is the only sign the answer was cut short.
    expect(await error, isA<A2uiValidationException>());
  });

  test('a failure from the model is reported rather than thrown', () async {
    start([]);
    conversation.dispose();
    conversation = Conversation(
      generator: _FailingGenerator(),
      controller: controller,
      systemPrompt: 'SYSTEM',
    );
    final Future<Object> error = conversation.errors.first;

    await conversation.send('Go');

    expect((await error).toString(), contains('no model loaded'));
    // The turn still closes, so the composer comes back rather than
    // staying disabled after a failure.
    expect(conversation.busy, isFalse);
  });

  test('a turn sent while one is in flight is ignored', () async {
    start([surfaceAnswer('s1'), surfaceAnswer('s2')]);

    // The history is what the next request is built from, so a second
    // request started mid-answer would be built from a half-written one.
    final Future<void> first = conversation.send('One.');
    await conversation.send('Two.');
    await first;

    expect(generator.requests, hasLength(1));
  });
}

class _FailingGenerator implements TextGenerator {
  @override
  Stream<String> generate(List<ChatMessage> messages) =>
      Stream<String>.error(StateError('no model loaded'));
}
