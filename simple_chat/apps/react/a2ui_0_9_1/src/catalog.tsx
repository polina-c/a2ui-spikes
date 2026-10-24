import {
  createComponentImplementation,
  type ReactCatalogComponent,
} from '@a2ui/react/v0_9';
import {spec} from '@a2ui/web_core/catalog';
import {ActionSchema, Catalog, type ComponentApi} from '@a2ui/web_core/v0_9';
import {basicCatalog} from '@a2ui/web_core/v0_9/basic_catalog';
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
 * The components the model builds the chat's UI from.
 *
 * From the basic catalog, it keeps {@link basicComponents} and the `openUrl`
 * function. It adds {@link mdCarousel}, to show options side by side.
 */
export function chatCatalog(): Catalog<ReactCatalogComponent> {
  return new Catalog<ReactCatalogComponent>(
    'https://github.com/polina-c/a2ui-spikes/simple_chat/catalog.json',
    '0.9.1',
    [
      ...basicComponents.map(name => basicCatalog.components.get(name)!),
      mdCarousel,
    ],
    [basicCatalog.functions.get('openUrl')!],
    {themeSchema: basicCatalog.themeSchema},
  );
}

const MdCarouselApi = {
  name: 'MdCarousel',
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
    {mixins: ['ComponentCommon']},
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
const mdCarousel = createComponentImplementation(MdCarouselApi, ({props}) => {
  const cards = new Map<string, string>();
  const actions = new Map<string, () => void>();
  for (const {name, markdown = '', action} of props.items) {
    if (name === undefined) continue;
    cards.set(name, markdown);
    // The binder turns every action into a function that runs it, including
    // one nested in a list, though its types only say so for a top-level one.
    if (action) actions.set(name, action as unknown as () => void);
  }
  return (
    <MdCarouselView
      items={cards}
      onSelect={actions.size === 0 ? undefined : name => actions.get(name)?.()}
    />
  );
});
