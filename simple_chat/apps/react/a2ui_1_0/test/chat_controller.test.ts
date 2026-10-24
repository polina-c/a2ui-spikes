import {beforeEach, expect, test} from 'vitest';
import {MarkdownPart, SurfacePart} from '../src/answer_content';
import {ChatController} from '../src/chat_controller';
import {GeneratedUi} from '../src/generated_ui';
import {questionBlock} from './a2ui_samples';
import {FakeAssistant, flush} from './fake_assistant';

const ui = new GeneratedUi();

let assistant: FakeAssistant;
let chat: ChatController;

beforeEach(() => {
  assistant = new FakeAssistant();
  chat = new ChatController(assistant, ui);
  return () => chat.dispose();
});

const texts = () => chat.messages.map(message => message.text);

/** The text of the last message the assistant was asked to answer. */
const lastRequestText = () => assistant.requests.at(-1)!.at(-1)!.text;

test('sending starts an answer that streams into one message', async () => {
  chat.send('hi');
  expect(chat.status).toBe('streaming');
  expect(assistant.requests).toHaveLength(1);
  expect(lastRequestText()).toBe('hi');

  assistant.write('Hello');
  assistant.write(', there');
  assistant.finish();
  await flush();

  expect(texts()).toEqual(['hi', 'Hello, there']);
  expect(chat.status).toBe('idle');
});

test('thinking shows until the answer starts', async () => {
  chat.send('hi');
  expect(chat.thinking.isVisible).toBe(true);

  assistant.think('Let me see');
  await flush();
  expect(chat.thinking.text).toBe('Let me see');
  expect(texts(), 'thoughts are not the answer').toEqual(['hi', '']);

  assistant.write('Hello');
  await flush();
  expect(chat.thinking.isVisible).toBe(false);
});

test('pausing keeps the partial answer and stops the stream', async () => {
  chat.send('hi');
  assistant.write('Hel');
  await flush();

  chat.pause();

  expect(chat.status).toBe('paused');
  expect(assistant.cancelled).toBe(true);
  expect(texts()).toEqual(['hi', 'Hel']);
  expect(chat.messages.at(-1)!.interrupted).toBe(true);
});

test('pausing while thinking keeps the box, stopped', async () => {
  chat.send('hi');
  assistant.think('Let me see');
  await flush();

  chat.pause();

  expect(chat.thinking.isVisible).toBe(true);
  expect(chat.thinking.isPaused).toBe(true);
  expect(chat.thinking.text).toBe('Let me see');

  chat.resume();
  expect(chat.thinking.isPaused).toBe(false);
});

test('cancelling while thinking drops the empty answer and the box', () => {
  chat.send('hi');
  chat.pause();

  chat.cancel();

  expect(texts()).toEqual(['hi']);
  expect(chat.thinking.isVisible).toBe(false);
});

test('context after a pause while thinking replaces the empty answer', () => {
  chat.send('hi');
  chat.pause();

  chat.send('I rent');

  expect(texts()).toEqual(['hi', 'I rent', '']);
});

test('resuming with nothing added continues the same message', async () => {
  chat.send('hi');
  assistant.write('A space with dedicated');
  await flush();
  chat.pause();

  chat.resume();

  expect(lastRequestText()).toBe('A space with dedicated');
  // A resumed turn often starts without the space it needs.
  assistant.write('water');
  assistant.write(' and a drain?');
  assistant.finish();
  await flush();

  expect(texts()).toEqual(['hi', 'A space with dedicated water and a drain?']);
  expect(chat.messages.at(-1)!.interrupted).toBe(false);
});

test('chunks of one answer are joined as they come', async () => {
  chat.send('hi');
  assistant.write('Hel');
  assistant.write('lo');
  assistant.finish();
  await flush();

  expect(texts()).toEqual(['hi', 'Hello']);
});

test('context sent while streaming waits, then gets its own answer', async () => {
  chat.send('hi');
  assistant.write('Hello');
  await flush();

  chat.send('I rent');
  expect(assistant.requests, 'the answer goes on').toHaveLength(1);
  assistant.write(', there');
  assistant.finish();
  await flush();

  expect(texts()).toEqual(['hi', 'Hello, there', 'I rent', '']);
  expect(chat.status).toBe('streaming');
  expect(lastRequestText()).toBe('I rent');
});

test('resuming after context sent before the pause writes a new answer', async () => {
  chat.send('hi');
  assistant.write('Hel');
  await flush();
  chat.send('I rent');
  chat.pause();

  chat.resume();

  expect(lastRequestText()).toBe('I rent');
  assistant.write('Then the Mini.');
  assistant.finish();
  await flush();
  expect(texts()).toEqual(['hi', 'Hel', 'I rent', 'Then the Mini.']);
});

test('context sent while paused starts a new answer', async () => {
  chat.send('hi');
  assistant.write('Hel');
  await flush();
  chat.pause();

  chat.send('I have a 45 cm gap');
  expect(chat.status).toBe('streaming');
  expect(assistant.requests).toHaveLength(2);

  assistant.write('Then the Slim.');
  assistant.finish();
  await flush();

  expect(texts()).toEqual([
    'hi',
    'Hel',
    'I have a 45 cm gap',
    'Then the Slim.',
  ]);
  expect(chat.messages[1].interrupted).toBe(true);
});

test('cancelling keeps the partial answer and waits for the user', async () => {
  chat.send('hi');
  assistant.write('Hel');
  await flush();
  chat.pause();

  chat.cancel();

  expect(chat.status).toBe('idle');
  expect(texts()).toEqual(['hi', 'Hel']);
  expect(chat.messages.at(-1)!.interrupted).toBe(true);
  expect(assistant.requests).toHaveLength(1);
});

test('an answer shows its text and UI in the order written', async () => {
  chat.send('hi');
  assistant.write('Where will it go?\n\n');
  assistant.write(questionBlock());
  assistant.write('\n\nOr tell me.');
  assistant.finish();
  await flush();

  const parts = chat.contentOf(chat.messages.at(-1)!).parts;
  expect(parts).toHaveLength(3);
  expect(parts[0]).toBeInstanceOf(MarkdownPart);
  expect((parts[0] as MarkdownPart).markdown).toBe('Where will it go?');
  expect(parts[1]).toBeInstanceOf(SurfacePart);
  expect((parts[2] as MarkdownPart).markdown).toBe('Or tell me.');
  expect(
    chat.messages.at(-1)!.text,
    'the model sees its UI in the conversation',
  ).toContain('<a2ui-json>');
});

test('resuming inside a block goes on without a space', async () => {
  const block = questionBlock();
  // Cut in the middle of a key, where a space would break the JSON.
  const cut = block.indexOf('"component"') + '"comp'.length;
  chat.send('hi');
  assistant.write(block.slice(0, cut));
  await flush();
  chat.pause();

  chat.resume();
  assistant.write(block.slice(cut));
  assistant.finish();
  await flush();

  expect(chat.messages.at(-1)!.text).toBe(block);
  const content = chat.contentOf(chat.messages.at(-1)!);
  expect(content.error).toBeNull();
  expect(content.parts).toHaveLength(1);
  expect(content.parts[0]).toBeInstanceOf(SurfacePart);
});

test('a failed answer can be resumed', async () => {
  chat.send('hi');
  assistant.fail(new Error('Gemini returned 503.'));
  await flush();

  expect(chat.status).toBe('paused');
  expect(chat.error).toContain('503');

  chat.resume();
  expect(chat.error).toBeNull();
  expect(assistant.requests).toHaveLength(2);
});
