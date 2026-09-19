import type {LlmClient, Turn} from './types';
import type {ModelChoice} from '../models';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

export function geminiClient(label: string): LlmClient {
  return {
    label,
    async send(system: string, turns: Turn[], choice: ModelChoice): Promise<string> {
      if (!choice.apiKey) throw new Error('No Gemini API key.');

      const res = await fetch(
        `${ENDPOINT}/${choice.modelId}:generateContent?key=${encodeURIComponent(choice.apiKey)}`,
        {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({
            systemInstruction: {parts: [{text: system}]},
            contents: turns.map(t => ({role: t.role, parts: [{text: t.text}]})),
            generationConfig: {
              temperature: choice.temperature,
              maxOutputTokens: choice.maxOutputTokens,
              responseMimeType: 'application/json',
            },
          }),
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
