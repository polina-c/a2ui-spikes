import 'package:flutter_test/flutter_test.dart';
import 'package:a2ui_9_1/answer_content.dart';
import 'package:a2ui_9_1/chat_controller.dart';
import 'package:a2ui_9_1/generated_ui.dart';

import 'a2ui_samples.dart';
import 'fake_assistant.dart';

void main() {
  final ui = GeneratedUi();
  late FakeAssistant assistant;
  late ChatController chat;

  setUp(() {
    assistant = FakeAssistant();
    chat = ChatController(assistant: assistant, ui: ui);
    addTearDown(chat.dispose);
  });

  List<String> texts() => [for (final m in chat.messages) m.text];

  test('sending starts an answer that streams into one message', () async {
    chat.send('hi');
    expect(chat.status, ChatStatus.streaming);
    expect(assistant.requests.single.single.text, 'hi');

    assistant.write('Hello');
    assistant.write(', there');
    await assistant.finish();
    await pumpEventQueue();

    expect(texts(), ['hi', 'Hello, there']);
    expect(chat.status, ChatStatus.idle);
  });

  test('thinking shows until the answer starts', () async {
    chat.send('hi');
    expect(chat.thinking.isVisible, isTrue);

    assistant.think('Let me see');
    await pumpEventQueue();
    expect(chat.thinking.text, 'Let me see');
    expect(texts(), ['hi', ''], reason: 'thoughts are not the answer');

    assistant.write('Hello');
    await pumpEventQueue();
    expect(chat.thinking.isVisible, isFalse);
  });

  test('pausing keeps the partial answer and stops the stream', () async {
    chat.send('hi');
    assistant.write('Hel');
    await pumpEventQueue();

    chat.pause();

    expect(chat.status, ChatStatus.paused);
    expect(assistant.cancelled, isTrue);
    expect(texts(), ['hi', 'Hel']);
    expect(chat.messages.last.interrupted, isTrue);
  });

  test('pausing while thinking keeps the box, stopped', () async {
    chat.send('hi');
    assistant.think('Let me see');
    await pumpEventQueue();

    chat.pause();

    expect(chat.thinking.isVisible, isTrue);
    expect(chat.thinking.isPaused, isTrue);
    expect(chat.thinking.text, 'Let me see');

    chat.resume();
    expect(chat.thinking.isPaused, isFalse);
  });

  test('cancelling while thinking drops the empty answer and the box', () {
    chat.send('hi');
    chat.pause();

    chat.cancel();

    expect(texts(), ['hi']);
    expect(chat.thinking.isVisible, isFalse);
  });

  test('context after a pause while thinking replaces the empty answer', () {
    chat.send('hi');
    chat.pause();

    chat.send('I rent');

    expect(texts(), ['hi', 'I rent', '']);
  });

  test('resuming with nothing added continues the same message', () async {
    chat.send('hi');
    assistant.write('A space with dedicated');
    await pumpEventQueue();
    chat.pause();

    chat.resume();

    expect(assistant.requests.last.last.text, 'A space with dedicated');
    // A resumed turn often starts without the space it needs.
    assistant.write('water');
    assistant.write(' and a drain?');
    await assistant.finish();
    await pumpEventQueue();

    expect(texts(), ['hi', 'A space with dedicated water and a drain?']);
    expect(chat.messages.last.interrupted, isFalse);
  });

  test('chunks of one answer are joined as they come', () async {
    chat.send('hi');
    assistant.write('Hel');
    assistant.write('lo');
    await assistant.finish();
    await pumpEventQueue();

    expect(texts(), ['hi', 'Hello']);
  });

  test(
    'context sent while streaming waits, then gets its own answer',
    () async {
      chat.send('hi');
      assistant.write('Hello');
      await pumpEventQueue();

      chat.send('I rent');
      expect(assistant.requests, hasLength(1), reason: 'the answer goes on');
      assistant.write(', there');
      await assistant.finish();
      await pumpEventQueue();

      expect(texts(), ['hi', 'Hello, there', 'I rent', '']);
      expect(chat.status, ChatStatus.streaming);
      expect(assistant.requests.last.last.text, 'I rent');
    },
  );

  test(
    'resuming after context sent before the pause writes a new answer',
    () async {
      chat.send('hi');
      assistant.write('Hel');
      await pumpEventQueue();
      chat.send('I rent');
      chat.pause();

      chat.resume();

      expect(assistant.requests.last.last.text, 'I rent');
      assistant.write('Then the Mini.');
      await assistant.finish();
      await pumpEventQueue();
      expect(texts(), ['hi', 'Hel', 'I rent', 'Then the Mini.']);
    },
  );

  test('context sent while paused starts a new answer', () async {
    chat.send('hi');
    assistant.write('Hel');
    await pumpEventQueue();
    chat.pause();

    chat.send('I have a 45 cm gap');
    expect(chat.status, ChatStatus.streaming);
    expect(assistant.requests, hasLength(2));

    assistant.write('Then the Slim.');
    await assistant.finish();
    await pumpEventQueue();

    expect(texts(), ['hi', 'Hel', 'I have a 45 cm gap', 'Then the Slim.']);
    expect(chat.messages[1].interrupted, isTrue);
  });

  test('cancelling keeps the partial answer and waits for the user', () async {
    chat.send('hi');
    assistant.write('Hel');
    await pumpEventQueue();
    chat.pause();

    chat.cancel();

    expect(chat.status, ChatStatus.idle);
    expect(texts(), ['hi', 'Hel']);
    expect(chat.messages.last.interrupted, isTrue);
    expect(assistant.requests, hasLength(1));
  });

  test('an answer shows its text and UI in the order written', () async {
    chat.send('hi');
    assistant.write('Where will it go?\n\n');
    assistant.write(questionBlock());
    assistant.write('\n\nOr tell me.');
    await assistant.finish();
    await pumpEventQueue();

    final List<AnswerPart> parts = chat.contentOf(chat.messages.last).parts;
    expect(parts, [
      isA<MarkdownPart>().having(
        (p) => p.markdown,
        'markdown',
        'Where will it go?',
      ),
      isA<SurfacePart>(),
      isA<MarkdownPart>().having((p) => p.markdown, 'markdown', 'Or tell me.'),
    ]);
    expect(
      chat.messages.last.text,
      contains('<a2ui-json>'),
      reason: 'the model sees its UI in the conversation',
    );
  });

  test('resuming inside a block goes on without a space', () async {
    final String block = questionBlock();
    // Cut in the middle of a key, where a space would break the JSON.
    final int cut = block.indexOf('"component"') + '"comp'.length;
    chat.send('hi');
    assistant.write(block.substring(0, cut));
    await pumpEventQueue();
    chat.pause();

    chat.resume();
    assistant.write(block.substring(cut));
    await assistant.finish();
    await pumpEventQueue();

    expect(chat.messages.last.text, block);
    final AnswerContent content = chat.contentOf(chat.messages.last);
    expect(content.error, isNull);
    expect(content.parts.single, isA<SurfacePart>());
  });

  test('a failed answer can be resumed', () async {
    chat.send('hi');
    assistant.fail('Gemini returned 503.');
    await pumpEventQueue();

    expect(chat.status, ChatStatus.paused);
    expect(chat.error, contains('503'));

    chat.resume();
    expect(chat.error, isNull);
    expect(assistant.requests, hasLength(2));
  });
}
