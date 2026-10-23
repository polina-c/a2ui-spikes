import {act, fireEvent, render, screen} from '@testing-library/react';
import {beforeEach, expect, test} from 'vitest';
import {ThinkingBox, ThinkingBoxController} from '../src';

let controller: ThinkingBoxController;

beforeEach(() => {
  controller = new ThinkingBoxController();
});

const renderBox = () => render(<ThinkingBox controller={controller} />);

/** Changes the controller outside of React, as a streaming chat does. */
const update = (change: () => void) => act(change);

const ellipsis = () => screen.queryByRole('status');

/** The part of the box that scrolls the thought. */
const scroller = () =>
  document.querySelector<HTMLElement>('.thinking-box__thought');

test('shows nothing while not visible', () => {
  const {container} = renderBox();

  expect(container).toBeEmptyDOMElement();
});

test('stays hidden while not visible, even with thought', () => {
  const {container} = renderBox();

  update(() => controller.addChunk('thinking about it'));

  expect(container).toBeEmptyDOMElement();
});

test('visible with no thought shows just the ellipsis', () => {
  renderBox();

  update(() => (controller.isVisible = true));

  expect(ellipsis()).toBeInTheDocument();
  // No markdown, and so nothing to scroll.
  expect(scroller()).toBeNull();
});

test('shows the thought once a chunk arrives', () => {
  renderBox();
  update(() => (controller.isVisible = true));

  update(() => controller.addChunk('thinking about it'));

  expect(screen.getByText('thinking about it')).toBeInTheDocument();
  expect(ellipsis()).toBeInTheDocument();
});

test('chunks accumulate into one thought', () => {
  renderBox();
  update(() => (controller.isVisible = true));

  update(() => {
    controller.addChunk('first ');
    controller.addChunk('second');
  });

  expect(controller.text).toBe('first second');
  expect(screen.getByText('first second')).toBeInTheDocument();
});

test('clear falls back to the ellipsis, staying visible', () => {
  renderBox();
  update(() => {
    controller.isVisible = true;
    controller.addChunk('a thought');
  });

  update(() => controller.clear());

  expect(controller.isEmpty).toBe(true);
  expect(screen.queryByText('a thought')).not.toBeInTheDocument();
  expect(ellipsis()).toBeInTheDocument();
});

test('hiding removes the box', () => {
  const {container} = renderBox();
  update(() => {
    controller.isVisible = true;
    controller.addChunk('a thought');
  });

  update(() => (controller.isVisible = false));

  expect(container).toBeEmptyDOMElement();
});

test('pausing keeps the box and its thought, without dots', () => {
  renderBox();
  update(() => {
    controller.isVisible = true;
    controller.addChunk('a thought');
  });

  update(() => (controller.isPaused = true));

  expect(screen.getByText('a thought')).toBeInTheDocument();
  expect(ellipsis()).not.toBeInTheDocument();

  update(() => (controller.isPaused = false));
  expect(ellipsis()).toBeInTheDocument();
});

// jsdom does no layout, so the tests below give the scroller the metrics a
// browser would: a 120px box, with 20px of content per paragraph.

function fakeLayout(element: HTMLElement) {
  const clientHeight = 120;
  const scrollHeight = () => 20 * element.querySelectorAll('p').length;
  let scrollTop = 0;
  Object.defineProperties(element, {
    clientHeight: {get: () => clientHeight},
    scrollHeight: {get: scrollHeight},
    scrollTop: {
      get: () => scrollTop,
      set: (value: number) => {
        scrollTop = Math.max(0, Math.min(value, scrollHeight() - clientHeight));
      },
    },
  });
}

const isAtEnd = (element: HTMLElement) =>
  element.scrollTop === element.scrollHeight - element.clientHeight;

/** Scrolls `element` as the user would. */
function scrollTo(element: HTMLElement, top: number) {
  element.scrollTop = top;
  fireEvent.scroll(element);
}

function addLines(prefix: string, count: number) {
  update(() => {
    for (let i = 0; i < count; i++) controller.addChunk(`${prefix} ${i}\n\n`);
  });
}

/** Shows a thought much longer than the box, and returns its scroller. */
function renderLongThought(): HTMLElement {
  renderBox();
  update(() => (controller.isVisible = true));
  addLines('line', 1);
  fakeLayout(scroller()!);
  addLines('more', 60);
  return scroller()!;
}

test('stops growing and shows the tail', () => {
  const element = renderLongThought();

  expect(element.scrollHeight).toBeGreaterThan(element.clientHeight);
  expect(isAtEnd(element), 'pinned to the newest thought').toBe(true);
});

test('scrolling up stops the auto-follow', () => {
  const element = renderLongThought();

  // Read back through the thought.
  scrollTo(element, 100);

  // More thought arrives; the view must stay where it was left.
  addLines('later', 1);
  expect(element.scrollTop).toBe(100);
});

test('scrolling back to the bottom resumes the auto-follow', () => {
  const element = renderLongThought();
  scrollTo(element, 100);

  scrollTo(element, element.scrollHeight);

  addLines('later', 1);
  expect(isAtEnd(element)).toBe(true);
});

test('clearing restores the auto-follow', () => {
  scrollTo(renderLongThought(), 100);

  update(() => controller.clear());
  addLines('fresh', 1);
  const element = scroller()!;
  fakeLayout(element);
  addLines('fresher', 60);

  expect(isAtEnd(element)).toBe(true);
});
