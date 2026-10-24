import type {ActionPayload} from '@a2ui/web_core/v1_0';
import {expect, test} from 'vitest';
import {GeneratedUi, replyOf} from '../src/generated_ui';

const action = (userMessage?: string): ActionPayload => ({
  name: 'reply',
  surfaceId: 'question',
  sourceComponentId: 'button',
  timestamp: new Date().toISOString(),
  context: {},
  userMessage,
});

test('a button replies with its user message', () => {
  expect(replyOf(action(' 45 cm '))).toBe('45 cm');
});

test('a button without a user message replies with its name', () => {
  expect(replyOf(action())).toBe('reply');
  expect(replyOf(action(' '))).toBe('reply');
});

test('the prompt teaches the catalog and its instructions at v1.0', () => {
  const ui = new GeneratedUi();

  expect(ui.prompt).toContain(ui.catalog.id);
  expect(ui.prompt).toContain('"version":{"const":"v1.0"}');
  expect(ui.prompt).toContain(JSON.stringify(ui.catalog.instructions));
  expect(ui.prompt).toContain('"MdCarousel"');
  expect(ui.prompt).toContain('"allowedParents":["Surface","Column"]');
  expect(ui.prompt).not.toContain('"Slider"');
});
