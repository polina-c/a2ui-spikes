import {expect, test} from 'vitest';
import {systemPrompt} from '../src/prompt';

const documents = systemPrompt.split('\n\n---\n\n');
const titles = documents.map(document => document.split('\n')[0]);

test('is how to chat, then the domain knowledge, then the landing pages', () => {
  expect(titles).toEqual([
    '# Chat assistant in general',
    '# Just shining products',
    '# Just Shining Classic',
    '# Just Shining Eco',
    '# Just Shining Family',
    '# Just Shining Mini',
    '# Just Shining Silent',
    '# Just Shining Slim',
  ]);
});
