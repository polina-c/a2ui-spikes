import {
  createComponentImplementation,
  type ReactCatalogComponent,
} from '@a2ui/react';
import {spec} from '@a2ui/web_core/catalog';
import {basicCatalog} from '@a2ui/web_core/catalogs/basic/v1';
import {ActionSchema, Catalog, type ComponentApi} from '@a2ui/web_core/v1_0';
import {MdCarouselView} from 'shared_ui';
import {z} from 'zod';

/**
 * What a question with likely answers, or a recommendation card with a link,
 * needs from the basic catalog.
 */
const basicComponents = [
  'Text',
  'Image',
  'Row',
  'Column',
  'Card',
  'Divider',
  'Button',
];

/**
 * How the model uses the catalog in this chat.
 *
 * Since v1.0, a catalog carries its own usage rules, and the model reads them
 * with the catalog's schema.
 */
const instructions = `How to use this catalog in the chat:

1. Each A2UI block builds one new surface with a single \`createSurface\`
   message that holds all of the surface's \`components\`. No other block in
   the message uses the same surface id.
2. A button answers for the user. Give it an \`event\` action named \`reply\`
   whose \`userMessage\` is what the user says by pressing it, written as they
   would type it, such as
   \`{"event": {"name": "reply", "userMessage": "It goes under the counter"}}\`.
   The app sends that text as the user's next message.
3. A button that opens a link calls \`openUrl\` instead:
   \`{"functionCall": {"@call": "openUrl", "args": {"url": "https://..."}}}\`.
4. \`MdCarousel\` shows options side by side. Give each card an action, as for
   a button.
5. The text of a \`Text\` component can use simple Markdown, such as
   \`### \` headings, bold and \`- \` lists.
6. When the UI shows a picture, the text of the message leaves it out.`;

/**
 * The components the model builds the chat's UI from.
 *
 * From the basic catalog, it keeps {@link basicComponents} and the `openUrl`
 * function. It adds {@link mdCarousel}, to show options side by side.
 */
export function chatCatalog(): Catalog<ReactCatalogComponent> {
  return new Catalog<ReactCatalogComponent>(
    'https://github.com/polina-c/a2ui-spikes/simple_chat/catalog_v1.json',
    '1.0',
    [
      ...basicComponents.map(name => basicCatalog.components.get(name)!),
      mdCarousel,
    ],
    [basicCatalog.functions.get('openUrl')!],
    {instructions},
  );
}

const MdCarouselApi = {
  name: 'MdCarousel',
  // A carousel scrolls sideways, so it takes the whole width of the surface,
  // or of a column in it.
  allowedParents: ['Surface', 'Column'],
  schema: spec(
    z
      .object({
        items: z
          .array(
            // The model writes both the name and the Markdown of a card, but
            // while the card streams in, it has only the first of them, or
            // neither.
            spec(
              z.object({
                name: z
                  .string()
                  .describe(
                    'Shown at the top of the card. No two cards may share a ' +
                      'name.',
                  )
                  .optional(),
                markdown: z
                  .string()
                  .describe(
                    'Shown below the name. A few short lines fit without ' +
                      'scrolling.',
                  )
                  .optional(),
                action: ActionSchema.describe(
                  "REF:#/$defs/Action|Runs when the user presses 'Select'.",
                ).optional(),
              }),
              {keywords: {required: ['name', 'markdown']}},
            ),
          )
          // Not at least one: while the list streams in, it starts empty.
          .describe('The cards, in the order they are shown.'),
      })
      .describe(
        'Options side by side, as cards in a row that scrolls sideways. ' +
          'Each card shows a name above Markdown text, and a Select button ' +
          'when it has an action.',
      )
      .strict(),
    {mixins: []},
  ),
} satisfies ComponentApi;

/**
 * {@link MdCarouselView} as an A2UI component: cards in a row that scrolls
 * sideways, each with a name, Markdown, and a 'Select' button that runs the
 * card's action.
 *
 * Each card carries its own action, as a basic `Button` does, so the agent
 * learns from the action which card the user picked.
 */
const mdCarousel: ReactCatalogComponent = {
  ...createComponentImplementation(MdCarouselApi, ({props}) => {
    const cards = new Map<string, string>();
    const actions = new Map<string, () => void>();
    for (const {name, markdown = '', action} of props.items) {
      if (name === undefined) continue;
      cards.set(name, markdown);
      // The binder turns every action into a function that runs it, including
      // one nested in a list, though its types only say so for a top-level
      // one.
      if (action) actions.set(name, action as unknown as () => void);
    }
    return (
      <MdCarouselView
        items={cards}
        onSelect={
          actions.size === 0 ? undefined : name => actions.get(name)?.()
        }
      />
    );
  }),
  // The implementation keeps only the name and the schema of the API.
  allowedParents: MdCarouselApi.allowedParents,
};
