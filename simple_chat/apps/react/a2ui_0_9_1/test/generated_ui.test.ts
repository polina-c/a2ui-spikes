import type {ActionPayload} from '@a2ui/web_core/v0_9';
import {expect, test} from 'vitest';
import {GeneratedUi, replyOf} from '../src/generated_ui';

const action = (context: Record<string, unknown>): ActionPayload => ({
  name: 'reply',
  surfaceId: 'question',
  sourceComponentId: 'button',
  timestamp: new Date().toISOString(),
  context,
});

test('a button replies with the text in its context', () => {
  expect(replyOf(action({text: ' 45 cm '}))).toBe('45 cm');
});

test('a button without text replies with its name', () => {
  expect(replyOf(action({}))).toBe('reply');
});

test('the prompt teaches the catalog at protocol v0.9.1', () => {
  const ui = new GeneratedUi();

  expect(ui.prompt).toContain(ui.catalog.id);
  expect(ui.prompt).toContain('"version": "v0.9.1"');
  expect(ui.prompt).toContain('"MdCarousel"');
  expect(ui.prompt).not.toContain('"Slider"');
});
