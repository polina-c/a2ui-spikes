import {chatCatalog} from '../src/catalog';

const catalogId = chatCatalog().id;

/** What the user says by pressing the button in {@link questionBlock}. */
export const underTheCounter = 'It goes under the counter';

/** What the user says by selecting the second card in {@link carouselBlock}. */
export const takeTheEco = 'I will take the Eco';

/**
 * A block with a button that answers for the user, written as the catalog's
 * instructions ask the model to write it.
 */
export const questionBlock = (surfaceId = 'question') => `
<a2ui-json>
[
  {"version": "v1.0", "createSurface": {"surfaceId": "${surfaceId}", "catalogId": "${catalogId}", "components": [
    {"id": "root", "component": "Button", "child": "label", "action": {"event": {"name": "reply", "userMessage": "${underTheCounter}"}}},
    {"id": "label", "component": "Text", "text": "Under the counter"}
  ]}}
]
</a2ui-json>`;

/** A block with two models side by side, each card answering for the user. */
export const carouselBlock = (parent = 'Column') => `
<a2ui-json>
[
  {"version": "v1.0", "createSurface": {"surfaceId": "options", "catalogId": "${catalogId}", "components": [
    {"id": "root", "component": "${parent}", ${parent === 'Card' ? '"child": "cards"' : '"children": ["cards"]'}},
    {"id": "cards", "component": "MdCarousel", "items": [
      {"name": "Silent", "markdown": "**39 dB**", "action": {"event": {"name": "reply", "userMessage": "I will take the Silent"}}},
      {"name": "Eco", "markdown": "**6.8 liters**", "action": {"event": {"name": "reply", "userMessage": "${takeTheEco}"}}}
    ]}
  ]}}
]
</a2ui-json>`;
