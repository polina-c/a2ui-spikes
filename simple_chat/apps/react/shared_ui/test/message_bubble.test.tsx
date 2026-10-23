import {fireEvent, render, screen} from '@testing-library/react';
import {expect, test} from 'vitest';
import {MessageBubble} from '../src';

test('shows the text of a user message as typed', () => {
  render(<MessageBubble text="I **rent**" isUser />);

  expect(screen.getByText('I **rent**')).toBeInTheDocument();
});

test('renders a model message as Markdown', () => {
  const {container} = render(
    <MessageBubble text="Pick the **Slim**." isUser={false} />,
  );

  expect(container).not.toHaveTextContent('**');
  expect(container).toHaveTextContent('Pick the Slim.');
  expect(screen.getByText('Slim').tagName).toBe('STRONG');
});

test('marks an interrupted answer as paused or stopped', () => {
  const {rerender} = render(
    <MessageBubble text="Partial" isUser={false} interrupted isPaused />,
  );
  expect(screen.getByText('Paused')).toBeInTheDocument();

  rerender(<MessageBubble text="Partial" isUser={false} interrupted />);
  expect(screen.getByText('Stopped')).toBeInTheDocument();
});

test('opens links in a new tab', () => {
  render(
    <MessageBubble text="[Slim](https://example.com/slim)" isUser={false} />,
  );

  expect(screen.getByRole('link', {name: 'Slim'})).toHaveAttribute(
    'target',
    '_blank',
  );
});

test('shows the alt text when an image cannot load', () => {
  render(
    <MessageBubble
      text="![Just Shining Eco](https://example.com/eco.png)"
      isUser={false}
    />,
  );

  // jsdom loads no images, so the failure is simulated.
  fireEvent.error(screen.getByRole('img'));

  expect(screen.queryByRole('img')).not.toBeInTheDocument();
  expect(screen.getByText('Just Shining Eco')).toBeInTheDocument();
});
