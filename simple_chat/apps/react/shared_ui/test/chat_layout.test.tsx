import {render, screen} from '@testing-library/react';
import {expect, test} from 'vitest';
import {ChatLayout} from '../src';

test('shows the messages oldest first, above the input', () => {
  render(
    <ChatLayout
      messages={
        <>
          <p>first</p>
          <p>second</p>
        </>
      }
      input={<p>input</p>}
    />,
  );

  const texts = screen.getAllByText(/./).map(element => element.textContent);
  expect(texts).toEqual(['first', 'second', 'input']);
});

test('caps the width of the column', () => {
  const {container} = render(<ChatLayout messages={null} input={null} />);

  expect(container.firstChild).toHaveStyle({maxWidth: '800px'});
});
