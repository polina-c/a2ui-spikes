import type {LlmClient, Turn} from './gemini';
import type {ModelChoice} from './models';

/**
 * The local family, for when Jane does not have her key nearby.
 *
 * WebLLM downloads the weights into the browser on first use, which takes
 * minutes, so the engine is created lazily and the progress is reported to the
 * chat rather than hidden.
 */
/**
 * Fails early and clearly when this browser cannot run a model.
 *
 * Without it the failure arrives from inside WebLLM, much later and much less
 * clearly. The two halves fail differently: `navigator.gpu` is absent in an
 * older browser and on a page that is not a secure context, while a machine
 * with no usable GPU has `navigator.gpu` and hands back a null adapter. A
 * headless container is the second kind.
 */
async function requireWebGpu(): Promise<void> {
  const gpu = (navigator as {gpu?: {requestAdapter(): Promise<unknown>}}).gpu;
  if (!gpu) {
    throw new Error(
      'This browser has no WebGPU (navigator.gpu is undefined), which the ' +
        'in-browser model needs. Chrome or Edge 113+ over https or localhost ' +
        'can run it; otherwise pick a Gemini model.',
    );
  }
  const adapter = await gpu.requestAdapter().catch(() => null);
  if (!adapter) {
    throw new Error(
      'WebGPU is present but no GPU adapter is available, so the model cannot ' +
        'run in this browser. This is what a machine with no GPU, or a ' +
        'headless one, reports. Pick a Gemini model instead.',
    );
  }
}

export function webllmClient(modelId: string, onStatus: (s: string) => void): LlmClient {
  let engine: unknown;

  return {
    label: `${modelId} (in this browser)`,
    async send(system: string, turns: Turn[], choice: ModelChoice): Promise<string> {
      const webllm = await import('@mlc-ai/web-llm');
      if (!engine) {
        await requireWebGpu();
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
