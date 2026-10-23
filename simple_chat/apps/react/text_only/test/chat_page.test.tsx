import {act, render, screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {beforeEach, expect, test} from 'vitest';
import {ChatPage, firstPrompt} from '../src/chat_page';
import {FakeAssistant, flush} from './fake_assistant';

let assistant: FakeAssistant;

beforeEach(() => {
  assistant = new FakeAssistant();
});

const renderPage = () => render(<ChatPage assistant={assistant} />);

const field = () => screen.getByRole('textbox');
const button = (name: string) => screen.getByRole('button', {name});
const queryButton = (name: string) => screen.queryByRole('button', {name});

/** The animated dots, in the thinking box or under the answer. */
const ellipses = () => screen.queryAllByRole('status');

/** Lets the page catch up with what the assistant wrote. */
const pump = (write: () => void = () => {}) =>
  act(async () => {
    write();
    await flush();
  });

async function sendFirstPrompt() {
  renderPage();
  await userEvent.click(button('Send'));
}

async function pumpAnswerAndPause() {
  await sendFirstPrompt();
  await pump(() => assistant.write('Partial'));
  await userEvent.click(button('Pause'));
}

test('starts with the first prompt ready to send', () => {
  renderPage();

  expect(field()).toHaveValue(firstPrompt);
  expect(button('Send')).toBeEnabled();
});

test('renders the answer as Markdown', async () => {
  await sendFirstPrompt();

  await pump(() => assistant.write('Pick the **Slim**.'));

  expect(document.body).not.toHaveTextContent('**');
  expect(document.body).toHaveTextContent('Pick the Slim.');
});

test('dots stay under the answer while it streams', async () => {
  await sendFirstPrompt();

  await pump(() => assistant.write('Partial'));
  expect(ellipses()).toHaveLength(1);

  await pump(() => assistant.finish());
  expect(ellipses()).toHaveLength(0);
});

test('context can be sent while the answer streams', async () => {
  await sendFirstPrompt();
  await pump(() => assistant.write('Partial'));

  expect(button('Pause')).toBeInTheDocument();
  expect(button('Send')).toBeInTheDocument();
  expect(field()).toHaveAttribute('placeholder', 'Add context, or pause');

  await userEvent.type(field(), 'I rent');
  await userEvent.click(button('Send'));
  expect(field(), 'the message was sent').toHaveValue('');
  expect(screen.getByText('I rent')).toBeInTheDocument();
  expect(assistant.requests).toHaveLength(1);

  await pump(() => assistant.finish());
  expect(assistant.requests).toHaveLength(2);
});

test('paused shows resume and cancel, and explains them', async () => {
  await pumpAnswerAndPause();

  expect(screen.getByText('Paused')).toBeInTheDocument();
  expect(button('Resume')).toBeInTheDocument();
  expect(button('Cancel')).toBeInTheDocument();
  expect(queryButton('Pause')).not.toBeInTheDocument();
  expect(field()).toHaveAttribute(
    'placeholder',
    'Add context and resume, just resume, or cancel',
  );
});

test('typing while paused turns resume into send and resume', async () => {
  await pumpAnswerAndPause();

  await userEvent.type(field(), 'I rent');
  expect(button('Send and resume')).toBeInTheDocument();
  expect(queryButton('Resume')).not.toBeInTheDocument();

  await userEvent.clear(field());
  await userEvent.type(field(), '  ');
  expect(button('Resume')).toBeInTheDocument();
});

test('send is disabled for whitespace only', async () => {
  renderPage();
  expect(button('Send')).toBeEnabled();

  await userEvent.clear(field());
  await userEvent.type(field(), '   ');

  expect(button('Send')).toBeDisabled();
});

test('pausing while thinking keeps the thinking box, without dots', async () => {
  await sendFirstPrompt();
  await pump(() => assistant.think('Weighing the options'));

  await userEvent.click(button('Pause'));

  expect(screen.getByText('Weighing the options')).toBeInTheDocument();
  expect(ellipses()).toHaveLength(0);
});

test('sending context while paused resumes', async () => {
  await pumpAnswerAndPause();

  await userEvent.type(field(), 'I rent');
  await userEvent.click(button('Send and resume'));

  expect(screen.getByText('I rent')).toBeInTheDocument();
  expect(assistant.requests).toHaveLength(2);
  expect(assistant.requests.at(-1)!.at(-1)!.text).toBe('I rent');
  expect(button('Pause')).toBeInTheDocument();
});

test('resume with the field empty continues the answer', async () => {
  await pumpAnswerAndPause();

  await userEvent.click(button('Resume'));

  expect(assistant.requests).toHaveLength(2);
  expect(assistant.requests.at(-1)!.at(-1)!.text).toBe('Partial');
  expect(button('Pause')).toBeInTheDocument();
  expect(screen.queryByText('Stopped'), 'it is being written again').toBeNull();
  expect(screen.queryByText('Paused')).toBeNull();
});

test('cancel stops the answer for good', async () => {
  await pumpAnswerAndPause();

  await userEvent.click(button('Cancel'));

  expect(screen.getByText('Stopped')).toBeInTheDocument();
  expect(queryButton('Cancel')).not.toBeInTheDocument();
  expect(field()).toHaveAttribute('placeholder', 'Message');
  expect(assistant.requests).toHaveLength(1);
});

test('a failed answer shows the error, and resume tries again', async () => {
  await sendFirstPrompt();

  await pump(() => assistant.fail(new Error('Gemini returned 503.')));

  expect(screen.getByText(/Gemini returned 503/)).toBeInTheDocument();
  await userEvent.click(button('Resume'));
  expect(screen.queryByText(/Gemini returned 503/)).not.toBeInTheDocument();
  expect(assistant.requests).toHaveLength(2);
});
