import {describe, expect, it} from 'vitest';
import {corpus, LANDING_URLS, MODEL_IDS} from '../knowledge';

describe('the embedded knowledge base', () => {
  it('has a landing page address for every machine', () => {
    for (const id of MODEL_IDS) {
      expect(LANDING_URLS[id], `no address for ${id}`).toBeTruthy();
      // A missing path segment here is a customer sent to a 404.
      expect(LANDING_URLS[id]).toContain('/ci/domain/landing_pages/');
    }
  });

  it('puts the knowledge base and every landing page in the prompt', () => {
    const text = corpus();
    expect(text).toContain('Just Shining Eco');
    expect(text).toContain('--- landing page: eco ---');
    expect(text).toContain('heat exchanger');
  });
});
