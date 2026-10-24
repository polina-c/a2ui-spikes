import {
  A2uiGenerator,
  CatalogConfig,
  DirectJsonFormatFactory,
  type A2uiRequestProcessor,
  type InferenceFormat,
} from '@a2ui/agent';
import {STRICT_VALIDATION} from '@a2ui/web_core';
import type {ActionPayload} from '@a2ui/web_core/v1_0';
import {AnswerContent} from './answer_content';
import {chatCatalog} from './catalog';

export const protocolVersion = 'v1.0';

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
a message, in A2UI JSON blocks between parts of the text, and follow the
\`instructions\` of the catalog.

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
 * What the user sends by triggering `action`: its `userMessage`, which the
 * catalog asks the model to write as the user would, or, without one, the
 * action's name.
 */
export function replyOf(action: ActionPayload): string {
  return action.userMessage?.trim() || action.name;
}
