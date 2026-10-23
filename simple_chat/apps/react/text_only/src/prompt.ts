// The documents are imported from simple_chat/doc, where they are written,
// and Vite builds them into the app.
import chatSpecifications from '../../../../doc/blueprints/0-chat-specifications.md?raw';
import knowledge from '../../../../doc/domain/just_shining/knowledge.md?raw';

/**
 * Every landing page, by path. The folder's README describes the folder, not
 * a product.
 */
const landingPages = import.meta.glob<string>(
  ['../../../../doc/domain/just_shining/landing_pages/*.md', '!**/README.md'],
  {query: '?raw', import: 'default', eager: true},
);

/**
 * The system prompt: how to guide the user, then the domain knowledge, then
 * every landing page.
 */
export const systemPrompt: string = [
  chatSpecifications,
  knowledge,
  ...Object.keys(landingPages)
    .sort()
    .map(path => landingPages[path]),
].join('\n\n---\n\n');
