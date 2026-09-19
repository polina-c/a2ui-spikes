import type {LlmClient, Turn} from './types';
import type {ModelChoice} from '../models';

/**
 * A model running in the browser through WebGPU. The engine is created on the
 * first send, because loading the weights takes a while and there is no reason
 * to pay for it before the user has said anything.
 */
export function webllmClient(label: string, onProgress: (text: string) => void): LlmClient {
  let engine: any;

  return {
    label,
    async send(system: string, turns: Turn[], choice: ModelChoice): Promise<string> {
      if (!engine) {
        const webllm = await import('@mlc-ai/web-llm');
        engine = await webllm.CreateMLCEngine(choice.modelId, {
          initProgressCallback: (p: {text: string}) => onProgress(p.text),
        });
      }

      const reply = await engine.chat.completions.create({
        messages: [
          {role: 'system', content: system},
          ...turns.map(t => ({
            role: t.role === 'model' ? ('assistant' as const) : ('user' as const),
            content: t.text,
          })),
        ],
        temperature: choice.temperature,
        max_tokens: choice.maxOutputTokens,
        response_format: {type: 'json_object'},
      });

      const text = reply?.choices?.[0]?.message?.content;
      if (!text) throw new Error('The local model returned no text.');
      return text;
    },
  };
}
