import {describe, expect, it} from 'vitest';
import {parseReply, systemPrompt} from '../prompt';

describe('parseReply', () => {
  it('reads the spoken half and the messages', () => {
    const reply = parseReply('{"say":"Where will it go?","a2ui":[{"version":"v0.9"}]}');
    expect(reply.say).toBe('Where will it go?');
    expect(reply.a2ui).toHaveLength(1);
  });

  it('tolerates the markdown fence the model sometimes adds', () => {
    const reply = parseReply('```json\n{"say":"Hello","a2ui":[]}\n```');
    expect(reply.say).toBe('Hello');
    expect(reply.a2ui).toEqual([]);
  });

  it('a reply with no object at all is an error, not empty output', () => {
    expect(() => parseReply('I am sorry, I cannot.')).toThrow();
  });
});

describe('systemPrompt', () => {
  it('carries the catalog, the corpus and the machine names', () => {
    const prompt = systemPrompt({components: {}}, 'test-catalog', 'THE KNOWLEDGE', [
      'mini',
      'eco',
    ]);
    expect(prompt).toContain('test-catalog');
    expect(prompt).toContain('THE KNOWLEDGE');
    expect(prompt).toContain('mini, eco');
    // The app opens the landing pages itself, so the model must not write one.
    expect(prompt).toContain('do not write a URL');
  });
});
