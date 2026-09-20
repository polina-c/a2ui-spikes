/**
 * The model families offered on the opening screen, with the range the UI
 * allows for every parameter the user can change.
 */

export interface ParamSpec {
  key: 'temperature' | 'maxOutputTokens';
  label: string;
  min: number;
  max: number;
  step: number;
  value: number;
}

export interface ModelOption {
  id: string;
  label: string;
  note: string;
  params: ParamSpec[];
}

export interface ModelFamily {
  id: 'gemini' | 'local';
  label: string;
  note: string;
  models: ModelOption[];
}

const temperature = (value: number): ParamSpec => ({
  key: 'temperature',
  label: 'Temperature',
  min: 0,
  max: 2,
  step: 0.1,
  value,
});

const maxOutputTokens = (value: number): ParamSpec => ({
  key: 'maxOutputTokens',
  label: 'Max output tokens',
  min: 256,
  max: 8192,
  step: 256,
  value,
});

export const FAMILIES: ModelFamily[] = [
  {
    id: 'gemini',
    label: 'Gemini',
    note: 'Runs on Google servers. Needs an API key.',
    models: [
      {
        id: 'gemini-flash-latest',
        label: 'Gemini Flash (latest)',
        note: 'The default. Fast, and reliable at emitting strict JSON.',
        params: [temperature(0.7), maxOutputTokens(4096)],
      },
      {
        id: 'gemini-pro-latest',
        label: 'Gemini Pro (latest)',
        note: 'Slower and stronger. Better at long chains of questions.',
        params: [temperature(0.7), maxOutputTokens(8192)],
      },
      {
        id: 'gemini-2.5-flash-lite',
        label: 'Gemini 2.5 Flash Lite',
        note: 'The cheapest, and the most likely to get the schema wrong.',
        params: [temperature(0.7), maxOutputTokens(4096)],
      },
    ],
  },
  {
    id: 'local',
    label: 'Local (WebLLM)',
    note: 'Runs in this browser through WebGPU. No key, no network after the download.',
    models: [
      {
        id: 'Llama-3.2-3B-Instruct-q4f32_1-MLC',
        label: 'Llama 3.2 3B Instruct',
        note: 'About 2 GB to download the first time.',
        params: [temperature(0.7), maxOutputTokens(2048)],
      },
      {
        id: 'Phi-3.5-mini-instruct-q4f16_1-MLC',
        label: 'Phi 3.5 Mini Instruct',
        note: 'Smaller and quicker to load, weaker at strict JSON.',
        params: [temperature(0.7), maxOutputTokens(2048)],
      },
      {
        id: 'Qwen2.5-7B-Instruct-q4f16_1-MLC',
        label: 'Qwen 2.5 7B Instruct',
        note: 'The strongest of the three, and the slowest to download.',
        params: [temperature(0.7), maxOutputTokens(2048)],
      },
    ],
  },
];

export const DEFAULT_FAMILY = FAMILIES[0];
export const DEFAULT_MODEL = DEFAULT_FAMILY.models[0];

export interface ModelChoice {
  familyId: 'gemini' | 'local';
  modelId: string;
  temperature: number;
  maxOutputTokens: number;
  apiKey?: string;
}
