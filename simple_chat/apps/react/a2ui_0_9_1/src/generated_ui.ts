import {
  A2uiGenerator,
  CatalogConfig,
  DirectJsonFormatFactory,
  type A2uiRequestProcessor,
  type InferenceFormat,
} from '@a2ui/agent';
import {STRICT_VALIDATION} from '@a2ui/web_core';
import type {ActionPayload} from '@a2ui/web_core/v0_9';
import {AnswerContent} from './answer_content';
import {chatCatalog} from './catalog';

export const protocolVersion = 'v0.9.1';

/** The key in a button's action context that holds the user's message. */
const replyKey = 'text';

/**
 * The UI the model can generate in the chat.
 *
 * The app plays both A2UI roles. It renders the catalog, and, since it calls
 * the model itself, it also uses the agent SDK to teach the model the catalog
 * and to read the A2UI in its answers.
 */
export class GeneratedUi {
  readonly catalog = chatCatalog();

  /** Teaches the model the catalog. */
  readonly #agent: A2uiRequestProcessor;

  /** Reads the model's answers. */
  readonly #format: InferenceFormat;

  constructor() {
    // Unlike the default format, direct JSON can be read while it streams, and
    // the progressive keys show text as it is written.
    const formats = new DirectJsonFormatFactory(undefined, {
      progressiveKeys: ['text', 'markdown'],
      validationConfig: STRICT_VALIDATION,
    });
    this.#agent = new A2uiGenerator(
      [new CatalogConfig(this.catalog)],
      undefined,
      formats,
    ).createProcessor({supportedCatalogIds: [this.catalog.id]});
    this.#format = formats.createFormat(this.#agent.activeCatalogs);
  }

  /** Tells the model how to write UI in this chat, for the system prompt. */
  get prompt(): string {
    return `# Generated UI in this chat

The app renders A2UI, protocol version ${protocolVersion}, with the catalog
\`${this.catalog.id}\` described below. Put UI where the user should see it in
a message, in A2UI JSON blocks between parts of the text.

1. Each block builds one new surface: a \`createSurface\` with the catalog id
   above and a surface id that no other block in the message uses, then the
   \`updateComponents\` for that surface. Every message has
   \`"version": "${protocolVersion}"\`.
2. A button answers for the user. Give it an \`event\` action whose \`context\`
   holds \`${replyKey}\`: what the user says by pressing it, written as they
   would type it, such as
   \`{"event": {"name": "reply", "context": {"${replyKey}": "It goes under the counter"}}}\`.
   The app sends that text as the user's next message.
3. A button that opens a link calls \`openUrl\` instead:
   \`{"functionCall": {"call": "openUrl", "args": {"url": "https://..."}, "returnType": "void"}}\`.
4. \`MdCarousel\` shows options side by side. Give each card an action, as for
   a button.
5. The text of a \`Text\` component can use simple Markdown, such as bold and
   \`- \` lists. A heading (\`variant\` h1 to h5) shows its text as written, so
   it has no Markdown.
6. When the UI shows a picture, the text of the message leaves it out.

${this.#agent.promptSnippet}`;
  }

  /**
   * Starts reading an answer.
   *
   * `onReply` receives what the user sends by pressing a button in the
   * answer's UI.
   */
  read(onReply: (text: string) => void): AnswerContent {
    return new AnswerContent(
      this.#format.createParser(),
      this.catalog,
      action => onReply(replyOf(action)),
    );
  }
}

/**
 * What the user sends by triggering `action`: the text the prompt asks the
 * model to put in its context, or, without one, the action's name.
 */
export function replyOf(action: ActionPayload): string {
  const text = action.context[replyKey];
  return typeof text === 'string' && text.trim() !== ''
    ? text.trim()
    : action.name;
}
