import type {ModelChoice} from './models';

/** One turn of the conversation, in the shape the Gemini API wants. */
export interface Turn {
  role: 'user' | 'model';
  text: string;
}

export interface LlmClient {
  label: string;
  send(system: string, turns: Turn[], choice: ModelChoice): Promise<string>;
}

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Statuses Gemini returns when it is busy rather than when the request is bad. */
const TRANSIENT = new Set([429, 500, 502, 503]);

const wait = (ms: number) => new Promise(r => setTimeout(r, ms));

export function geminiClient(label: string): LlmClient {
  return {
    label,
    async send(system, turns, choice) {
      if (!choice.apiKey) throw new Error('No Gemini API key.');
      const res = await post(
        `${ENDPOINT}/${choice.modelId}:generateContent?key=${encodeURIComponent(choice.apiKey)}`,
        {
          systemInstruction: {parts: [{text: system}]},
          contents: turns.map(t => ({role: t.role, parts: [{text: t.text}]})),
          generationConfig: {
            temperature: choice.temperature,
            maxOutputTokens: choice.maxOutputTokens,
            responseMimeType: 'application/json',
          },
        },
      );
      if (!res.ok) {
        // The body can carry the key back in an error echo, so only the status
        // and a short excerpt are surfaced.
        throw new Error(`Gemini returned ${res.status}.`);
      }
      const data = await res.json();
      const text: string = (data?.candidates?.[0]?.content?.parts ?? [])
        .map((p: {text?: string}) => p.text ?? '')
        .join('');
      if (!text) {
        throw new Error(
          `Gemini returned no text (finishReason: ${data?.candidates?.[0]?.finishReason ?? 'unknown'}).`,
        );
      }
      return text;
    },
  };
}

/**
 * Posts, and tries again when Gemini says it is overloaded. Without a retry a
 * single busy moment ends the conversation, which in a recorded run means
 * recording it again.
 */
async function post(url: string, body: unknown, attempts = 4): Promise<Response> {
  let res!: Response;
  for (let i = 0; i < attempts; i++) {
    res = await fetch(url, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    if (res.ok || !TRANSIENT.has(res.status) || i === attempts - 1) return res;
    await wait(1500 * 2 ** i);
  }
  return res;
}
