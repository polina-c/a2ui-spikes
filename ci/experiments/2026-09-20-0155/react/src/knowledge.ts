/**
 * The sales knowledge, embedded at build time.
 *
 * The blueprint allows either embedding or fetching over HTTP. Vite's `?raw`
 * import makes embedding a one-liner and leaves the app a static bundle with
 * no backend to run, so that is what this arm does.
 */
import knowledge from '../../../../domain/knowledge.md?raw';
import classic from '../../../../domain/landing_pages/classic.md?raw';
import eco from '../../../../domain/landing_pages/eco.md?raw';
import family from '../../../../domain/landing_pages/family.md?raw';
import mini from '../../../../domain/landing_pages/mini.md?raw';
import silent from '../../../../domain/landing_pages/silent.md?raw';
import slim from '../../../../domain/landing_pages/slim.md?raw';

const PAGES: Record<string, string> = {classic, eco, family, mini, silent, slim};

/**
 * The landing page URL of each model, read out of the knowledge base.
 *
 * The app resolves the link itself from the model id rather than taking a URL
 * the language model repeats back: asked to echo the URL, `gemini-flash-latest`
 * dropped a path segment and sent the user to a 404.
 */
export const LANDING_URLS: Record<string, string> = Object.fromEntries(
  [...knowledge.matchAll(/\((https:\/\/[^)\s]*landing_pages\/([a-z]+)\.md)\)/g)].map(m => [
    m[2],
    m[1],
  ]),
);

/** The ids the model may ask for, which are the landing page file names. */
export const MODEL_IDS = Object.keys(PAGES);

/** The knowledge base and every landing page, as one block for the prompt. */
export function corpus(): string {
  const pages = Object.entries(PAGES)
    .map(([name, body]) => `--- landing page: ${name} ---\n${body}`)
    .join('\n\n');
  return `${knowledge}\n\n${pages}`;
}
