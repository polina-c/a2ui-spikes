import {render, screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {beforeEach, expect, test} from 'vitest';
import {ChatInputPane, type ChatStatus} from '../src';

let calls: string[];

beforeEach(() => {
  calls = [];
});

function renderPane(status: ChatStatus, initialText = '') {
  render(
    <ChatInputPane
      status={status}
      initialText={initialText}
      onSend={text => calls.push(`send ${text}`)}
      onPause={() => calls.push('pause')}
      onResume={() => calls.push('resume')}
      onCancel={() => calls.push('cancel')}
    />,
  );
}

const field = () => screen.getByRole('textbox');
const button = (name: string) => screen.getByRole('button', {name});
const queryButton = (name: string) => screen.queryByRole('button', {name});

test('sends the trimmed text and clears the field', async () => {
  renderPane('idle', ' Hi ');

  await userEvent.click(button('Send'));

  expect(calls).toEqual(['send Hi']);
  expect(field()).toHaveValue('');
});

test('send is disabled for whitespace only', () => {
  renderPane('idle', '   ');

  expect(button('Send')).toBeDisabled();
});

test('streaming offers pause next to send', async () => {
  renderPane('streaming');

  expect(field()).toHaveAttribute('placeholder', 'Add context, or pause');
  await userEvent.click(button('Pause'));
  expect(calls).toEqual(['pause']);
  expect(button('Send')).toBeInTheDocument();
});

test('paused offers resume and cancel', async () => {
  renderPane('paused');

  await userEvent.click(button('Resume'));
  await userEvent.click(button('Cancel'));
  expect(calls).toEqual(['resume', 'cancel']);
  expect(queryButton('Pause')).not.toBeInTheDocument();
});

test('typing while paused turns resume into send and resume', async () => {
  renderPane('paused');

  await userEvent.type(field(), 'I rent');
  expect(queryButton('Resume')).not.toBeInTheDocument();

  await userEvent.click(button('Send and resume'));
  expect(calls).toEqual(['send I rent']);
});

test('enter sends, and shift+enter starts a new line', async () => {
  renderPane('idle');

  await userEvent.type(field(), 'I rent{Shift>}{Enter}{/Shift}a flat{Enter}');

  expect(calls).toEqual(['send I rent\na flat']);
});

test('enter with an empty field resumes while paused', async () => {
  renderPane('paused');

  await userEvent.type(field(), '{Enter}');

  expect(calls).toEqual(['resume']);
});
