/** The models the picker offers, and the choice it produces. */

export interface ModelChoice {
  familyId: 'gemini' | 'local';
  modelId: string;
  temperature: number;
  maxOutputTokens: number;
  apiKey?: string;
}

export interface Family {
  id: 'gemini' | 'local';
  label: string;
  note: string;
  models: {id: string; label: string}[];
  needsKey: boolean;
}

export const FAMILIES: Family[] = [
  {
    id: 'gemini',
    label: 'Gemini',
    note: 'Runs in the cloud. Needs an API key, which stays in this browser tab.',
    models: [
      {id: 'gemini-flash-latest', label: 'gemini-flash-latest (recommended)'},
      {id: 'gemini-flash-lite-latest', label: 'gemini-flash-lite-latest'},
    ],
    needsKey: true,
  },
  {
    id: 'local',
    label: 'In this browser',
    note: 'Runs the model on this machine with WebLLM. No key, but a long first load, and it needs a browser with WebGPU.',
    models: [
      {id: 'Llama-3.2-3B-Instruct-q4f16_1-MLC', label: 'Llama 3.2 3B'},
      {id: 'Qwen2.5-3B-Instruct-q4f16_1-MLC', label: 'Qwen 2.5 3B'},
    ],
    needsKey: false,
  },
];

/** What the picker opens on: the model the experiment is run with. */
export const DEFAULT_CHOICE: ModelChoice = {
  familyId: 'gemini',
  modelId: 'gemini-flash-latest',
  temperature: 0.7,
  maxOutputTokens: 4096,
};

/** The key from the environment, when the app was built with one. */
export const ENV_KEY: string = (import.meta.env.VITE_GEMINI_API_KEY as string) ?? '';
