import type {ModelChoice} from '../models';

export interface Turn {
  role: 'user' | 'model';
  text: string;
}

export interface LlmClient {
  /** Human readable name, shown in the chat header. */
  label: string;
  /** Sends the conversation and returns the raw text of the reply. */
  send(system: string, turns: Turn[], choice: ModelChoice): Promise<string>;
}
