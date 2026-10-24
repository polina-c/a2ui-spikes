import {beforeEach, expect, test} from 'vitest';
import {
  MarkdownPart,
  SurfacePart,
  type AnswerContent,
} from '../src/answer_content';
import {GeneratedUi} from '../src/generated_ui';
import {carouselBlock, questionBlock} from './a2ui_samples';

const ui = new GeneratedUi();
let content: AnswerContent;

beforeEach(() => {
  content = ui.read(() => {});
  return () => content.dispose();
});

const texts = () =>
  content.parts.flatMap(part =>
    part instanceof MarkdownPart ? [part.markdown] : [],
  );

/** Feeds `output` to the content in chunks of `size`, then ends it. */
function stream(output: string, size = 7) {
  for (let i = 0; i < output.length; i += size) {
    content.add(output.slice(i, i + size));
  }
  content.close();
}

test('text and a surface stream in, with tags split across chunks', () => {
  stream(`Where?\n\n${questionBlock()}\n\nOr tell me.`);

  expect(content.error).toBeNull();
  expect(content.parts.map(part => part.constructor)).toEqual([
    MarkdownPart,
    SurfacePart,
    MarkdownPart,
  ]);
  expect(texts()).toEqual(['Where?', 'Or tell me.']);
});

test('a carousel streams in', () => {
  stream(`Two fit.\n\n${carouselBlock()}`, 3);

  expect(content.error).toBeNull();
  expect(content.parts.at(-1)).toBeInstanceOf(SurfacePart);
});

test('a carousel cannot go in a card', () => {
  stream(`Two fit.\n\n${carouselBlock('Card')}`, 100);

  expect(content.error?.message).toContain('cannot be placed under');
  expect(texts()).toEqual(['Two fit.']);
});

test('text that could start a tag shows once the answer ends', () => {
  stream('Is it 45 or 60 cm <', 100);

  expect(texts()).toEqual(['Is it 45 or 60 cm <']);
});

test('a block that fails in a later chunk keeps the text around it', () => {
  content.add('Where?\n\n<a2ui-json>[{"version": "v1.0", ');
  content.add('"oops": 1}]</a2ui-json>\n\nOr tell me.');
  content.close();

  expect(content.error).not.toBeNull();
  expect(texts()).toEqual(['Where?', 'Or tell me.']);
});

test('a block left open keeps the text before it', () => {
  content.add('Where?\n\n<a2ui-json>[{"version": "v1.0"');
  content.close();

  expect(texts()).toEqual(['Where?']);
});

test('knows when the output ends inside a block', () => {
  content.add('Where?\n\n<a2ui-json>[');
  expect(content.isInBlock).toBe(true);

  content.add(']</a2ui-json>');
  expect(content.isInBlock).toBe(false);
});
