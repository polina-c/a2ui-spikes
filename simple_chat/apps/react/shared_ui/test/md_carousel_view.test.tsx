import {fireEvent, render, screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, expect, test, vi} from 'vitest';
import {MdCarouselView} from '../src';

afterEach(() => vi.restoreAllMocks());

const items = new Map([
  ['Slim', 'For a 45 cm gap.'],
  ['Mini', 'No plumbing **needed**.'],
]);

test('shows a card per item, in order, with its markdown rendered', () => {
  render(<MdCarouselView items={items} />);

  const names = screen.getAllByText(/^(Slim|Mini)$/).map(e => e.textContent);
  expect(names).toEqual(['Slim', 'Mini']);
  expect(screen.getByText('needed').tagName).toBe('STRONG');
});

test('select calls back with the name and markdown of its card', async () => {
  const selected: [string, string][] = [];
  render(
    <MdCarouselView
      items={items}
      onSelect={(name, markdown) => selected.push([name, markdown])}
    />,
  );

  await userEvent.click(screen.getAllByRole('button', {name: 'Select'})[1]);

  expect(selected).toEqual([['Mini', 'No plumbing **needed**.']]);
});

test('has no select buttons without a callback', () => {
  render(<MdCarouselView items={items} />);

  expect(
    screen.queryByRole('button', {name: 'Select'}),
  ).not.toBeInTheDocument();
});

test('shows nothing without items', () => {
  const {container} = render(<MdCarouselView items={new Map()} />);

  expect(container).toBeEmptyDOMElement();
});

// jsdom does no layout, so the tests below give the list the metrics a
// browser would: 300px of it showing, out of 1000px.

let scrollLeft = 0;

function fakeLayout() {
  scrollLeft = 0;
  vi.spyOn(Element.prototype, 'clientWidth', 'get').mockReturnValue(300);
  vi.spyOn(Element.prototype, 'scrollWidth', 'get').mockReturnValue(1000);
  vi.spyOn(Element.prototype, 'scrollLeft', 'get').mockImplementation(
    () => scrollLeft,
  );
}

const list = () => document.querySelector('.md-carousel-view__list')!;

/** The arrow and what surrounds it, which is inert while it is hidden. */
const arrow = (name: string) =>
  screen.getByRole('button', {name}).parentElement!;

test('shows each arrow only while there is more to scroll its way', () => {
  fakeLayout();
  render(<MdCarouselView items={items} />);

  expect(arrow('Scroll left')).toHaveAttribute('inert');
  expect(arrow('Scroll right')).not.toHaveAttribute('inert');

  scrollLeft = 700;
  fireEvent.scroll(list());

  expect(arrow('Scroll left')).not.toHaveAttribute('inert');
  expect(arrow('Scroll right')).toHaveAttribute('inert');
});

test('an arrow scrolls by a whole card', async () => {
  fakeLayout();
  render(<MdCarouselView items={items} />);
  const scrollBy = vi.fn();
  list().scrollBy = scrollBy;

  await userEvent.click(screen.getByRole('button', {name: 'Scroll right'}));

  expect(scrollBy).toHaveBeenCalledWith({left: 272, behavior: 'smooth'});
});
