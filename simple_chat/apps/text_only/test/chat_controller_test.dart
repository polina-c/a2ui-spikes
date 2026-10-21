import 'package:flutter_test/flutter_test.dart';
import 'package:text_only/chat_controller.dart';

import 'fake_assistant.dart';

void main() {
  late FakeAssistant assistant;
  late ChatController chat;

  setUp(() {
    assistant = FakeAssistant();
    chat = ChatController(assistant: assistant);
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

  test('pausing before any text drops the empty answer', () async {
    chat.send('hi');
    chat.pause();

    expect(texts(), ['hi']);
  });

  test('resuming with nothing added continues the same message', () async {
    chat.send('hi');
    assistant.write('Hel');
    await pumpEventQueue();
    chat.pause();

    chat.resume();

    expect(assistant.requests.last.last.text, 'Hel');
    assistant.write('lo');
    await assistant.finish();
    await pumpEventQueue();

    expect(texts(), ['hi', 'Hello']);
    expect(chat.messages.last.interrupted, isFalse);
  });

  test(
    'context sent while paused waits for resume, then gets a new answer',
    () async {
      chat.send('hi');
      assistant.write('Hel');
      await pumpEventQueue();
      chat.pause();

      chat.send('I have a 45 cm gap');
      expect(chat.status, ChatStatus.paused);
      expect(assistant.requests, hasLength(1));

      chat.resume();
      assistant.write('Then the Slim.');
      await assistant.finish();
      await pumpEventQueue();

      expect(texts(), ['hi', 'Hel', 'I have a 45 cm gap', 'Then the Slim.']);
      expect(chat.messages[1].interrupted, isTrue);
    },
  );

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
