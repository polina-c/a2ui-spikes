import {expect, test} from 'vitest';
import {systemPrompt} from '../src/prompt';

const documents = systemPrompt('# Generated UI').split('\n\n---\n\n');
const titles = documents.map(document => document.split('\n')[0]);

test('is how to chat, the domain knowledge, the landing pages, then the UI', () => {
  expect(titles).toEqual([
    '# Chat assistant in general',
    '# Just shining products',
    '# Just Shining Classic',
    '# Just Shining Eco',
    '# Just Shining Family',
    '# Just Shining Mini',
    '# Just Shining Silent',
    '# Just Shining Slim',
    '# Generated UI',
  ]);
});
