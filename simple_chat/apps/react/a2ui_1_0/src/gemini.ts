import type {
  AnswerChunk,
  Assistant,
  ChatMessage,
  Role,
} from './chat_controller';

/** Hidden turns that tell the model about a pause. */
const Note = {
  resume:
    '(The answer above was paused by the user and is now resumed. ' +
    'Continue it exactly where it stopped, without repeating anything.)',
  interrupted: '(The user stopped the answer above before it was finished.)',
} as const;

const model = 'gemini-flash-latest';

const endpoint =
  'https://generativelanguage.googleapis.com/v1beta/models/' +
  `${model}:streamGenerateContent?alt=sse`;

/** One turn of the conversation, in Gemini's format. */
export interface Content {
  role: Role;
  parts: {text: string}[];
}

/** The part of a Gemini response that the app reads. */
interface GenerateContentResponse {
  candidates?: {content?: {parts?: {text?: string; thought?: boolean}[]}}[];
}

/** Streams answers from the Gemini API, called directly from the app. */
export class GeminiAssistant implements Assistant {
  readonly apiKey: string;
  readonly systemPrompt: string;

  constructor(apiKey: string, systemPrompt: string) {
    this.apiKey = apiKey;
    this.systemPrompt = systemPrompt;
  }

  async *answer(
    history: readonly ChatMessage[],
    signal: AbortSignal,
  ): AsyncGenerator<AnswerChunk> {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': this.apiKey,
      },
      body: JSON.stringify({
        systemInstruction: {parts: [{text: this.systemPrompt}]},
        contents: contentsOf(history),
        generationConfig: {thinkingConfig: {includeThoughts: true}},
      }),
      signal,
    });
    if (!response.ok) throw new Error(`Gemini returned ${response.status}.`);

    // Server-sent events: each 'data:' line holds one JSON response.
    for await (const line of linesOf(response.body!)) {
      if (!line.startsWith('data:')) continue;
      const json = JSON.parse(line.slice(5)) as GenerateContentResponse;
      for (const part of json.candidates?.[0]?.content?.parts ?? []) {
        if (!part.text) continue;
        yield {text: part.text, isThought: part.thought === true};
      }
    }
  }
}

/**
 * The conversation in Gemini's format, with notes about paused answers.
 *
 * Gemini expects the roles to alternate, so consecutive turns of one role,
 * such as context added during a pause, are merged into one.
 */
export function contentsOf(history: readonly ChatMessage[]): Content[] {
  const turns: [Role, string][] = [];
  for (const message of history) {
    if (message.text === '') continue;
    turns.push([message.role, message.text]);
    if (message.interrupted) {
      const isLast = message === history.at(-1);
      turns.push(['user', isLast ? Note.resume : Note.interrupted]);
    }
  }

  const contents: Content[] = [];
  for (const [role, text] of turns) {
    const previous = contents.at(-1);
    if (previous?.role === role) {
      previous.parts.push({text});
    } else {
      contents.push({role, parts: [{text}]});
    }
  }
  return contents;
}

/** Splits a stream of bytes into lines of text. */
async function* linesOf(
  body: ReadableStream<Uint8Array>,
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  // The end of the last chunk, which the next chunk may continue.
  let rest = '';
  while (true) {
    const {value, done} = await reader.read();
    if (done) break;
    const lines = (rest + decoder.decode(value, {stream: true})).split(/\r?\n/);
    rest = lines.pop()!;
    yield* lines;
  }
  if (rest !== '') yield rest;
}
