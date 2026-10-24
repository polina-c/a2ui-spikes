// @vitest-environment node
import {afterEach, expect, test, vi} from 'vitest';
import {ChatMessage} from '../src/chat_controller';
import {contentsOf, GeminiAssistant, type Content} from '../src/gemini';

afterEach(() => vi.unstubAllGlobals());

const roles = (contents: Content[]) => contents.map(content => content.role);

const textsOf = (content: Content) => content.parts.map(part => part.text);

/** An answer that the user paused. */
function paused(text: string): ChatMessage {
  const message = new ChatMessage('model', text);
  message.interrupted = true;
  return message;
}

test('alternates user and model turns', () => {
  const contents = contentsOf([
    new ChatMessage('user', 'hi'),
    new ChatMessage('model', 'Hello'),
    new ChatMessage('user', 'a dishwasher'),
  ]);

  expect(roles(contents)).toEqual(['user', 'model', 'user']);
});

test('asks to continue an answer paused with nothing added', () => {
  const contents = contentsOf([new ChatMessage('user', 'hi'), paused('Hel')]);

  expect(roles(contents)).toEqual(['user', 'model', 'user']);
  expect(textsOf(contents.at(-1)!)).toEqual([
    expect.stringContaining('Continue'),
  ]);
});

test('merges added context into one turn after a note', () => {
  const contents = contentsOf([
    new ChatMessage('user', 'hi'),
    paused('Hel'),
    new ChatMessage('user', '45 cm'),
    new ChatMessage('user', 'two people'),
  ]);

  expect(roles(contents)).toEqual(['user', 'model', 'user']);
  const added = textsOf(contents.at(-1)!);
  expect(added).toHaveLength(3);
  expect(added[0]).toContain('stopped');
  expect(added.slice(1)).toEqual(['45 cm', 'two people']);
});

/** A response of server-sent events, arriving in pieces that split lines. */
function eventStream(events: object[]): Response {
  const bytes = new TextEncoder().encode(
    events.map(event => `data: ${JSON.stringify(event)}\r\n\r\n`).join(''),
  );
  const pieceSize = 7;
  return new Response(
    new ReadableStream({
      start(controller) {
        for (let i = 0; i < bytes.length; i += pieceSize) {
          controller.enqueue(bytes.slice(i, i + pieceSize));
        }
        controller.close();
      },
    }),
  );
}

async function answerTo(text: string) {
  const assistant = new GeminiAssistant('key', 'prompt');
  const chunks = [];
  const history = [new ChatMessage('user', text)];
  const signal = new AbortController().signal;
  for await (const chunk of assistant.answer(history, signal)) {
    chunks.push(chunk);
  }
  return chunks;
}

test('streams the thoughts and the text of an answer', async () => {
  const parts = (...parts: object[]) => ({candidates: [{content: {parts}}]});
  vi.stubGlobal(
    'fetch',
    vi.fn(async () =>
      eventStream([
        parts({text: 'Weighing it', thought: true}),
        parts({text: 'Pick the '}, {text: 'Slim.'}),
      ]),
    ),
  );

  expect(await answerTo('hi')).toEqual([
    {text: 'Weighing it', isThought: true},
    {text: 'Pick the ', isThought: false},
    {text: 'Slim.', isThought: false},
  ]);
});

test('fails with the status when Gemini refuses', async () => {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () => new Response('', {status: 503})),
  );

  await expect(answerTo('hi')).rejects.toThrow('Gemini returned 503.');
});
