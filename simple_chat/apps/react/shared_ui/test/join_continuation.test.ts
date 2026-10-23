import {expect, test} from 'vitest';
import {joinContinuation} from '../src';

test('adds the space a resumed turn leaves out', () => {
  expect(joinContinuation('dedicated', 'water')).toBe('dedicated water');
  expect(joinContinuation('question:', 'where')).toBe('question: where');
  expect(joinContinuation('Ну', 'да')).toBe('Ну да');
});

test('keeps the space a resumed turn brings', () => {
  expect(joinContinuation('dedicated', ' water')).toBe('dedicated water');
  expect(joinContinuation('dedicated', '\n\nwater')).toBe('dedicated\n\nwater');
});

test('adds no space before punctuation or after a space', () => {
  expect(joinContinuation('dedicated', ', water')).toBe('dedicated, water');
  expect(joinContinuation('dedicated ', 'water')).toBe('dedicated water');
  expect(joinContinuation('(', 'like')).toBe('(like');
  expect(joinContinuation('**', 'Slim**')).toBe('**Slim**');
});
