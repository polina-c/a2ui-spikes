/**
 * The sales knowledge, embedded at build time.
 *
 * The blueprint allows embedding or fetching over HTTP. Embedding is what Vite
 * makes cheap here, and it keeps the app a static bundle with no backend.
 */

import knowledge from '../../../../domain/knowledge.md?raw';
import classic from '../../../../domain/landing_pages/classic.md?raw';
import eco from '../../../../domain/landing_pages/eco.md?raw';
import family from '../../../../domain/landing_pages/family.md?raw';
import mini from '../../../../domain/landing_pages/mini.md?raw';
import silent from '../../../../domain/landing_pages/silent.md?raw';
import slim from '../../../../domain/landing_pages/slim.md?raw';

export const KNOWLEDGE = knowledge;

export const LANDING_PAGES: Record<string, string> = {
  classic,
  eco,
  family,
  mini,
  silent,
  slim,
};

/** The knowledge base plus every landing page, as one block for the prompt. */
export function domainCorpus(): string {
  const pages = Object.entries(LANDING_PAGES)
    .map(([name, body]) => `--- landing page: ${name} ---\n${body}`)
    .join('\n\n');
  return `${KNOWLEDGE}\n\n${pages}`;
}
