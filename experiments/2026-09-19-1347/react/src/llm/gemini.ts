import type {LlmClient, Turn} from './types';
import type {ModelChoice} from '../models';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Gemini returns these when it is busy rather than when anything is wrong. */
const TRANSIENT = new Set([429, 500, 503]);

const wait = (ms: number) => new Promise(r => setTimeout(r, ms));

export function geminiClient(label: string): LlmClient {
  return {
    label,
    async send(system: string, turns: Turn[], choice: ModelChoice): Promise<string> {
      if (!choice.apiKey) throw new Error('No Gemini API key.');

      const res = await postWithRetry(
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
        const body = await res.text();
        throw new Error(`Gemini returned ${res.status}: ${body.slice(0, 400)}`);
      }

      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts
        ?.map((p: {text?: string}) => p.text ?? '')
        .join('');

      if (!text) {
        const reason = data?.candidates?.[0]?.finishReason ?? 'unknown';
        throw new Error(`Gemini returned no text (finishReason: ${reason}).`);
      }
      return text;
    },
  };
}

/**
 * Posts, and tries again when Gemini says it is overloaded. Without this a
 * single busy moment ends the conversation, which during a recorded run means
 * starting over.
 */
async function postWithRetry(url: string, body: unknown, attempts = 4): Promise<Response> {
  let res!: Response;
  for (let i = 0; i < attempts; i++) {
    res = await fetch(url, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    if (res.ok || !TRANSIENT.has(res.status) || i === attempts - 1) return res;
    await wait(2000 * 2 ** i);
  }
  return res;
}
