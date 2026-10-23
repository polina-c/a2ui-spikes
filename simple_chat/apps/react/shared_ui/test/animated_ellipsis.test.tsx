import {act, render, screen} from '@testing-library/react';
import {afterEach, beforeEach, expect, test, vi} from 'vitest';
import {AnimatedEllipsis} from '../src';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

/** All dots, the hidden ones included. */
const dots = () => [...screen.getByRole('status').children] as HTMLElement[];

const visibleDots = () =>
  dots().filter(dot => dot.style.opacity === '1').length;

test('cycles from one dot to three', () => {
  render(<AnimatedEllipsis />);

  const counts = new Set<number>();
  for (let i = 0; i < 12; i++) {
    counts.add(visibleDots());
    act(() => vi.advanceTimersByTime(100));
  }

  expect(counts).toEqual(new Set([1, 2, 3]));
});

test('keeps its width, by keeping the hidden dots in place', () => {
  render(<AnimatedEllipsis />);

  expect(visibleDots()).toBe(1);
  expect(dots()).toHaveLength(3);
});

test('dots are as big as asked', () => {
  render(<AnimatedEllipsis dotSize={14} />);

  expect(dots()[0]).toHaveStyle({width: '14px', height: '14px'});
});
