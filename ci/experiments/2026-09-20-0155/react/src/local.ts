import type {LlmClient, Turn} from './gemini';
import type {ModelChoice} from './models';

/**
 * The local family, for when Jane does not have her key nearby.
 *
 * WebLLM downloads the weights into the browser on first use, which takes
 * minutes, so the engine is created lazily and the progress is reported to the
 * chat rather than hidden.
 */
export function webllmClient(modelId: string, onStatus: (s: string) => void): LlmClient {
  let engine: unknown;

  return {
    label: `${modelId} (in this browser)`,
    async send(system: string, turns: Turn[], choice: ModelChoice): Promise<string> {
      const webllm = await import('@mlc-ai/web-llm');
      if (!engine) {
        onStatus('Downloading the model into this browser, this takes a few minutes...');
        engine = await webllm.CreateMLCEngine(modelId, {
          initProgressCallback: p => onStatus(p.text),
        });
      }
      onStatus('Thinking...');
      const reply = await (engine as {chat: any}).chat.completions.create({
        messages: [
          {role: 'system', content: system},
          ...turns.map(t => ({role: t.role === 'model' ? 'assistant' : 'user', content: t.text})),
        ],
        temperature: choice.temperature,
        max_tokens: choice.maxOutputTokens,
      });
      return reply.choices[0]?.message?.content ?? '';
    },
  };
}
