import {
  ChangeNotifier,
  joinContinuation,
  ThinkingBoxController,
  type ChatStatus,
} from 'shared_ui';

export type {ChatStatus} from 'shared_ui';

export type Role = 'user' | 'model';

let nextMessageId = 0;

export class ChatMessage {
  /** Tells messages apart, so that React keeps each one in its place. */
  readonly id = nextMessageId++;

  readonly role: Role;

  /** Grows while a model answer streams in. */
  text: string;

  /** Whether the user paused this answer before it was finished. */
  interrupted = false;

  constructor(role: Role, text = '') {
    this.role = role;
    this.text = text;
  }
}

/**
 * A piece of a streamed answer: either text of the answer itself, or a thought
 * the model had on the way to it.
 */
export interface AnswerChunk {
  text: string;
  isThought: boolean;
}

export interface Assistant {
  /**
   * Streams the answer to `history`.
   *
   * Aborting `signal` stops the answer.
   */
  answer(
    history: readonly ChatMessage[],
    signal: AbortSignal,
  ): AsyncIterable<AnswerChunk>;
}

/** The conversation, and the answer currently being written. */
export class ChatController extends ChangeNotifier {
  readonly assistant: Assistant;

  /** Shows the model's thinking while the user waits for an answer. */
  readonly thinking = new ThinkingBoxController();

  readonly #messages: ChatMessage[] = [];
  get messages(): readonly ChatMessage[] {
    return this.#messages;
  }

  #status: ChatStatus = 'idle';
  get status(): ChatStatus {
    return this.#status;
  }

  /** Why the last answer stopped, if it failed. */
  #error: string | null = null;
  get error(): string | null {
    return this.#error;
  }

  /** Stops the answer being streamed. */
  #stop: AbortController | null = null;

  /** The answer being written, or the paused one. */
  #current: ChatMessage | null = null;
  get currentAnswer(): ChatMessage | null {
    return this.#current;
  }

  constructor(assistant: Assistant) {
    super();
    this.assistant = assistant;
  }

  /**
   * Adds a user message, and starts an answer that takes it into account.
   *
   * While an answer is streaming, the message waits for that answer to
   * finish. While paused, it starts a new answer straight away.
   */
  send(text: string): void {
    this.#messages.push(new ChatMessage('user', text));
    if (this.#status === 'streaming') {
      this.notifyListeners();
    } else {
      this.#startAnswer();
    }
  }

  pause(): void {
    this.#interrupt();
    this.notifyListeners();
  }

  /**
   * Continues the paused answer in the same message, or writes a new one when
   * the user added context after it.
   */
  resume(): void {
    this.#startAnswer();
  }

  /** Gives up on the paused answer, keeping what was written of it. */
  cancel(): void {
    const answer = this.#current;
    if (answer && answer.text === '') this.#remove(answer);
    this.#current = null;
    this.#status = 'idle';
    this.#error = null;
    this.thinking.isPaused = false;
    this.thinking.isVisible = false;
    this.notifyListeners();
  }

  /** Stops the answer being streamed, if any. */
  dispose(): void {
    this.#stop?.abort();
  }

  #startAnswer(): void {
    // An answer paused before any text has nothing to keep once the user adds
    // context after it; the new answer takes its place.
    const paused = this.#current;
    if (paused && paused.text === '' && paused !== this.#messages.at(-1)) {
      this.#remove(paused);
    }

    // The assistant sees the conversation as it is now: the last message is
    // either the user's, or the partial answer to continue.
    const history = [...this.#messages];
    let answer = this.#messages.at(-1)!;
    if (answer.role === 'user') {
      answer = new ChatMessage('model');
      this.#messages.push(answer);
    }
    this.#current = answer;

    this.#status = 'streaming';
    this.#error = null;
    this.thinking.clear();
    this.thinking.isPaused = false;
    this.thinking.isVisible = true;
    this.notifyListeners();

    this.#stop = new AbortController();
    void this.#stream(answer, history, this.#stop.signal);
  }

  /** Writes the answer into `answer` as it arrives, until it ends. */
  async #stream(
    answer: ChatMessage,
    history: readonly ChatMessage[],
    signal: AbortSignal,
  ): Promise<void> {
    // Set when this stream continues a paused answer, until its first text.
    let isContinuation = answer.text !== '';

    try {
      for await (const chunk of this.assistant.answer(history, signal)) {
        if (signal.aborted) return;
        if (chunk.isThought) {
          this.thinking.addChunk(chunk.text);
          continue;
        }
        this.thinking.isVisible = false;
        answer.text = isContinuation
          ? joinContinuation(answer.text, chunk.text)
          : answer.text + chunk.text;
        isContinuation = false;
        this.notifyListeners();
      }
    } catch (error) {
      if (signal.aborted) return;
      // Failing works like pausing, so resuming is how to try again.
      this.#interrupt();
      this.#error = error instanceof Error ? error.message : String(error);
      this.notifyListeners();
      return;
    }
    if (signal.aborted) return;

    answer.interrupted = false;
    this.#stop = null;
    this.#current = null;
    this.thinking.isVisible = false;
    // Context the user sent while this answer was streaming gets an answer of
    // its own.
    if (this.#messages.at(-1)!.role === 'user') {
      this.#startAnswer();
    } else {
      this.#status = 'idle';
      this.notifyListeners();
    }
  }

  /** Stops the answer and keeps what has been written of it. */
  #interrupt(): void {
    this.#stop?.abort();
    this.#stop = null;
    this.#status = 'paused';
    // A thinking box still on screen stays there, with its dots stopped.
    this.thinking.isPaused = true;
    this.#current!.interrupted = true;
  }

  #remove(message: ChatMessage): void {
    this.#messages.splice(this.#messages.indexOf(message), 1);
  }
}
